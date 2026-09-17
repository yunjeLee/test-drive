#!/bin/bash
# test-drive 공용 함수. run.sh 가 맨 위에서 source 한다.
# macOS /bin/bash 3.2 로 실행된다. 연관 배열 · ${v,,} · mapfile 을 쓰지 않는다.
#
# 필수 환경변수
#   TD_PKG      대상 applicationId
#   TD_RUN_DIR  결과 폴더 (<작업폴더>/runs/NNN_S<시작>-S<끝>)
# 선택 환경변수
#   ANDROID_SERIAL  기기 serial. 2대 이상 연결 시 필수
#   ADB             adb 절대경로. 없으면 스스로 찾는다
#   TD_START_FROM   이 번호보다 앞 시나리오는 건너뛴다. 기본 1
#   TD_TAP_WAIT     td_tap · td_wait_ui 대기 초. 기본 10

set -u

ADB=${ADB:-$(ls "$HOME/Library/Android/sdk/platform-tools/adb" 2>/dev/null || command -v adb)}
EMULATOR=${EMULATOR:-$HOME/Library/Android/sdk/emulator/emulator}
TD_START_FROM=${TD_START_FROM:-1}
TD_TAP_WAIT=${TD_TAP_WAIT:-10}
TD_TMP=$(mktemp -d)
TD_PASS=0
TD_FAIL=0
TD_BG_PIDS=""
TD_FWD_PORTS=""
TD_SCN_LIST=""
TD_SCN_STATUS=()
TD_SCN_REASON=()
TD_CUR_FAIL=0
TD_CUR_SID=""
TD_CUR_BLOCK=""

td_log() { echo "[$(date +%H:%M:%S)] $*"; }

# ── 정리 ──────────────────────────────────────────────
# 중단은 pkill -f "bash run.sh" 로 한다. TERM 을 받으면 EXIT trap 이 정리한다.
td_bg() {  # 명령을 백그라운드로 실행하고 종료 시 kill 대상에 넣는다
  "$@" &
  TD_BG_PIDS="$TD_BG_PIDS $!"
}

td_forward() {  # $1 = 로컬 포트, $2 = 원격. 종료 시 제거 대상에 넣는다
  td_adb forward "tcp:$1" "$2" >/dev/null && TD_FWD_PORTS="$TD_FWD_PORTS $1"
}

td_cleanup() {
  local p
  for p in $TD_BG_PIDS; do kill "$p" 2>/dev/null; done
  for p in $TD_FWD_PORTS; do "$ADB" forward --remove "tcp:$p" >/dev/null 2>&1; done
  rm -r "$TD_TMP" 2>/dev/null
}

trap td_cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

td_require_env() {
  local missing=""
  [ -n "${TD_PKG:-}" ]     || missing="$missing TD_PKG"
  [ -n "${TD_RUN_DIR:-}" ] || missing="$missing TD_RUN_DIR"
  [ -x "$ADB" ]            || missing="$missing ADB"
  [ -z "$missing" ] || { td_log "환경변수 없음:$missing"; exit 1; }
  mkdir -p "$TD_RUN_DIR/fail" "$TD_RUN_DIR/evidence"
  TD_WORK_DIR=$(cd "$TD_RUN_DIR/../.." && pwd)
  TD_RUN_NO=$(basename "$TD_RUN_DIR" | cut -c1-3)
  # 실행 중인 run.sh 를 남긴다. run 폴더의 스냅샷으로 재실행할 때는 복사하지 않는다.
  if [ -f "$0" ] && ! [ "$0" -ef "$TD_RUN_DIR/run.sh" ]; then
    cp "$0" "$TD_RUN_DIR/run.sh"
  fi
  [ -f "$TD_WORK_DIR/failures.md" ] || printf '%s\n' \
    "| ID | run | 스텝 | 종류 | 분류 | 원인 | 조치 | 캡처 |" \
    "|---|---|---|---|---|---|---|---|" > "$TD_WORK_DIR/failures.md"
}

# ── 기기 ──────────────────────────────────────────────
td_adb() { "$ADB" "$@"; }

td_boot_wait() {  # $1 = AVD 이름. 부팅 후 ANDROID_SERIAL 을 export 한다.
  local avd=$1 serial=""
  "$EMULATOR" -avd "$avd" >/dev/null 2>&1 &
  td_log "에뮬레이터 부팅 대기: $avd"
  while [ -z "$serial" ]; do
    serial=$("$ADB" devices | awk '/^emulator-.*device$/{print $1; exit}')
    [ -z "$serial" ] && sleep 2
  done
  while [ "$("$ADB" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do sleep 2; done
  "$ADB" -s "$serial" shell input keyevent KEYCODE_WAKEUP
  export ANDROID_SERIAL=$serial
  td_log "부팅 완료: $serial"
}

td_top() { td_adb shell dumpsys activity activities | grep -m1 -E "topResumedActivity"; }

# recents 에 실제로 떠 있는 task 만 센다. `Recent #N:` 접두어가 없으면
# mHiddenTasks 의 숨은 task 까지 잡혀 오판한다.
td_tasks() {
  td_adb shell dumpsys activity recents \
    | grep -oE "Recent #[0-9]+: Task\{[0-9a-f]+ #[0-9]+ type=standard A=[0-9]+:$TD_PKG" \
    | grep -oE "#[0-9]+ type" | grep -oE "[0-9]+"
}

td_clear_tasks() {
  local t
  for t in $(td_tasks); do td_adb shell am stack remove "$t"; done
  td_log "task 제거 완료"
}

# ── 앱 ────────────────────────────────────────────────
td_install() {  # $1 = apk 경로, 나머지 = install 플래그
  local apk=$1; shift
  [ -f "$apk" ] || { td_log "APK 없음: $apk"; return 1; }
  td_log "설치: $(basename "$apk")"
  # adb 는 실패 시 끝에 빈 줄을 붙인다. tail -1 로 잡으면 실패가 빈 문자열이 된다.
  local out rc
  out=$(td_adb install -r "$@" "$apk" 2>&1); rc=$?
  printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | sed 's/^/    /'
  [ "$rc" -eq 0 ] || { td_log "설치 실패 — adb 종료코드 $rc"; return 1; }
  printf '%s' "$out" | grep -q "Success" || { td_log "설치 실패 — Success 없음"; return 1; }
}

# 서명 인증서 SHA-256 을 출력한다. 두 APK 가 서로 덮이는지 미리 판정할 때 쓴다.
td_apk_sig() {
  local bt; bt=$(ls -d "$HOME/Library/Android/sdk/build-tools/"*/ 2>/dev/null | sort -V | tail -1)
  [ -n "$bt" ] || return 1
  "${bt}apksigner" verify --print-certs "$1" 2>/dev/null | grep -m1 -oE "SHA-256 digest: [0-9a-f]+" | awk '{print $3}'
}

# 설치본 base.apk 의 서명을 출력한다. 미설치면 1 을 반환한다.
td_installed_sig() {
  local path
  path=$(td_adb shell pm path "$TD_PKG" 2>/dev/null | tr -d '\r' | grep -m1 'base\.apk$' | sed 's/^package://')
  [ -n "$path" ] || return 1
  td_adb pull "$path" "$TD_TMP/installed.apk" >/dev/null 2>&1 || return 1
  td_apk_sig "$TD_TMP/installed.apk"
}

td_launch() { td_adb shell monkey -p "$TD_PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; }

# ── 화면 조작 ─────────────────────────────────────────
td_ui_find() {  # $1 = python 술어. 조건에 맞는 첫 노드의 중심 좌표를 출력한다.
  rm -f "$TD_TMP/ui.xml"
  td_adb shell uiautomator dump /sdcard/td-ui.xml >/dev/null 2>&1
  td_adb pull /sdcard/td-ui.xml "$TD_TMP/ui.xml" >/dev/null 2>&1
  [ -f "$TD_TMP/ui.xml" ] || return 1
  python3 - "$TD_TMP/ui.xml" "$1" <<'PY'
import sys, re, xml.etree.ElementTree as ET
try:
    tree = ET.parse(sys.argv[1])
except Exception:
    sys.exit(1)
pred = sys.argv[2]
for n in tree.iter('node'):
    g = lambda k: (n.get(k) or '')
    try:
        hit = eval(pred)
    except Exception:
        hit = False
    if hit:
        b = list(map(int, re.findall(r'\d+', g('bounds'))))
        print((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)
        sys.exit(0)
sys.exit(1)
PY
}

td_wait_ui() {  # $1 = python 술어, $2 = 초(기본 TD_TAP_WAIT). 2초 간격으로 찾는다
  local limit=${2:-$TD_TAP_WAIT} start=$SECONDS
  until td_ui_find "$1"; do
    [ $((SECONDS - start)) -ge "$limit" ] && return 1
    sleep 2
  done
}

td_tap() {  # $1 = python 술어, $2 = 설명
  local xy
  xy=$(td_wait_ui "$1") || { td_log "탭 실패 — 못 찾음: ${2:-$1}"; return 1; }
  [ -n "$xy" ] || { td_log "탭 실패 — 못 찾음: ${2:-$1}"; return 1; }
  td_adb shell input tap $xy
  td_log "탭: ${2:-$1} ($xy)"
}

# ── 사람 스텝 ─────────────────────────────────────────
td_human() {  # $1 = 사람에게 할 말, $2 = 감지 명령. 상한 없이 기다린다.
  td_log "👉 사람: $1"
  local n=0
  until eval "$2" >/dev/null 2>&1; do
    sleep 2; n=$((n + 1))
    [ $((n % 150)) -eq 0 ] && td_log "   대기 $((n / 30))분 — $1"
  done
  td_log "감지됨: $1"
}

td_human_chat() {  # $1 = 사람에게 할 말, $2 = 마커 이름. agent 가 touch 할 때까지 기다린다.
  td_log "👉 사람(채팅): $1"
  td_log "   재개: touch $TD_RUN_DIR/$2.ok"
  local n=0
  until [ -f "$TD_RUN_DIR/$2.ok" ]; do
    sleep 2; n=$((n + 1))
    [ $((n % 150)) -eq 0 ] && td_log "   대기 $((n / 30))분 — $1"
  done
  td_log "확인됨: $1"
}

# ── 로그 ──────────────────────────────────────────────
td_logcat_start() {  # $1 = 파일, 나머지 = logcat 인자
  local f=$1; shift
  td_bg "$ADB" logcat -v time ${1+"$@"} > "$f" 2>&1
}

td_mark() {  # $1 = 파일. 현재 줄 수를 출력한다
  if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi
}

td_since() {  # $1 = 파일, $2 = td_mark 값. 그 다음 줄부터 출력한다
  tail -n +"$(($2 + 1))" "$1" 2>/dev/null
}

# ── 판정 ──────────────────────────────────────────────
td_crash_clear() { td_adb logcat -c >/dev/null 2>&1; td_adb logcat -b crash -c >/dev/null 2>&1; }

td_crash_count() { td_adb logcat -d -b crash 2>/dev/null | grep -c "FATAL EXCEPTION"; }

td_crash_dump() { td_adb logcat -d -b crash > "$TD_RUN_DIR/evidence/${1:-crash}.txt" 2>/dev/null; }

td_sid() {  # $1 = 번호(8 또는 8.4). S08 · S08.4 를 출력한다
  case $1 in
    *.*) printf 'S%02d.%s' "$((10#${1%%.*}))" "${1#*.}" ;;
    *)   printf 'S%02d' "$((10#$1))" ;;
  esac
}

td_capture_failure() {  # $1 = 번호, $2 = 종류(step|check), $3 = 설명
  local sid base n=1 rows
  sid=$(td_sid "$1")
  base="${sid}_$2"
  while [ -e "$TD_RUN_DIR/fail/$base.png" ]; do
    n=$((n + 1)); base="${sid}_${2}_$n"
  done
  td_adb shell screencap -p /sdcard/td-shot.png >/dev/null 2>&1
  td_adb pull /sdcard/td-shot.png "$TD_RUN_DIR/fail/$base.png" >/dev/null 2>&1
  td_adb shell uiautomator dump /sdcard/td-ui.xml >/dev/null 2>&1
  td_adb pull /sdcard/td-ui.xml "$TD_RUN_DIR/fail/$base.xml" >/dev/null 2>&1
  rows=$(grep -c '^| F' "$TD_WORK_DIR/failures.md" 2>/dev/null)
  printf '| F%02d | %s | %s | %s | 미분류 | %s | - | %s |\n' \
    "$((${rows:-0} + 1))" "$TD_RUN_NO" "$sid" "$2" "${3//|/\\|}" \
    "runs/$(basename "$TD_RUN_DIR")/fail/$base.png" >> "$TD_WORK_DIR/failures.md"
  td_log "실패 캡처: fail/$base.png · $base.xml — $3"
}

td_require() {  # $1 = 설명, $2 = 조건 명령. 실패하면 사유를 남기고 1 을 반환한다
  if eval "$2" >/dev/null 2>&1; then
    td_log "사전조건 OK: $1"
    return 0
  fi
  td_log "사전조건 미충족: $1 → 실행불가"
  TD_CUR_BLOCK=$1
  return 1
}

td_check() {  # $1 = 번호, $2 = 설명, $3 = 기준 명령
  if eval "$3" >/dev/null 2>&1; then
    TD_PASS=$((TD_PASS + 1)); td_log "PASS  $1 $2"
  else
    TD_FAIL=$((TD_FAIL + 1)); TD_CUR_FAIL=$((TD_CUR_FAIL + 1))
    td_log "FAIL  $1 $2"
    td_capture_failure "$1" check "$2"
  fi
}

td_step() {  # $1 = 번호, $2 = 설명, $3 = 명령. 실패하면 캡처하고 1 을 반환한다
  td_log "[$1] $2"
  eval "$3" && return 0
  td_log "스텝 $1 실패: $2"
  td_capture_failure "$1" step "$2"
  TD_CUR_SID=$(td_sid "$1")
  return 1
}

# ── 시나리오 ──────────────────────────────────────────
td_scn_set() {  # $1 = 번호, $2 = 상태, $3 = 사유
  TD_SCN_STATUS[$1]=$2
  TD_SCN_REASON[$1]=$3
  td_log "시나리오 $1 → $2${3:+ ($3)}"
}

# 본문 반환: 0 = 끝까지 실행 · 1 = td_step 실패 · 2 = td_require 미충족
td_scenario() {  # $1 = 번호, $2 = 제목, $3 = 본문 함수, $4 = 복구 함수|-, 나머지 = 의존 번호
  local no=$1 title=$2 body=$3 recover=$4 dep rc status reason=""
  shift 4
  td_log "════════ 시나리오 $no — $title"
  TD_SCN_LIST="$TD_SCN_LIST $no"
  if [ "$no" -lt "$TD_START_FROM" ]; then
    td_scn_set "$no" 건너뜀 ""
    return 0
  fi
  for dep in ${1+"$@"}; do
    case "${TD_SCN_STATUS[$dep]:-}" in
      PASS|건너뜀) ;;
      *)
        td_scn_set "$no" 실행불가 "의존 $(td_sid "$dep") ${TD_SCN_STATUS[$dep]:-미실행}"
        return 0
        ;;
    esac
  done
  TD_CUR_FAIL=0
  TD_CUR_SID=""
  TD_CUR_BLOCK=""
  "$body"; rc=$?
  case $rc in
    0) if [ "$TD_CUR_FAIL" -eq 0 ]; then status=PASS; else status=FAIL; fi ;;
    2) status=실행불가; reason=$TD_CUR_BLOCK ;;
    *) status=중단; reason=${TD_CUR_SID:-$(td_sid "$no")} ;;
  esac
  [ "$recover" = "-" ] || "$recover"
  td_scn_set "$no" "$status" "$reason"
}

td_summary() {
  local no s nfail=0 nblock=0 abort="" suffix=""
  for no in $TD_SCN_LIST; do
    s=${TD_SCN_STATUS[$no]:-}
    td_log "$(td_sid "$no") $s${TD_SCN_REASON[$no]:+ ${TD_SCN_REASON[$no]}}"
    case $s in
      FAIL)     nfail=$((nfail + 1)) ;;
      실행불가) nblock=$((nblock + 1)) ;;
      중단)     [ -n "$abort" ] || abort=${TD_SCN_REASON[$no]} ;;
    esac
  done
  td_log "판정 PASS $TD_PASS / FAIL $TD_FAIL"
  [ "$nfail" -eq 0 ]  || suffix="${suffix}_FAIL-$nfail"
  [ -z "$abort" ]     || suffix="${suffix}_중단@$abort"
  [ "$nblock" -eq 0 ] || suffix="${suffix}_실행불가-$nblock"
  suffix=${suffix#_}
  echo "TD_SUFFIX=${suffix:-완료}"
  if [ -z "$suffix" ]; then
    echo "TD_EXIT=0"; return 0
  fi
  echo "TD_EXIT=1"; return 1
}
