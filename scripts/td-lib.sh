#!/bin/bash
# test-drive 공용 함수. run.sh 가 맨 위에서 source 한다.
#
# 필수 환경변수
#   TD_PKG      대상 applicationId
#   TD_RUN_DIR  결과 폴더 (runs/<순번>-<라벨>)
# 선택 환경변수
#   ANDROID_SERIAL  기기 serial. 2대 이상 연결 시 필수
#   ADB             adb 절대경로. 없으면 스스로 찾는다

set -u

ADB=${ADB:-$(ls "$HOME/Library/Android/sdk/platform-tools/adb" 2>/dev/null || command -v adb)}
EMULATOR=${EMULATOR:-$HOME/Library/Android/sdk/emulator/emulator}
TD_TMP=$(mktemp -d)
TD_PASS=0
TD_FAIL=0
TD_BLOCKED=""
TD_FAIL_SEQ=0
trap 'rm -r "$TD_TMP" 2>/dev/null' EXIT

td_log() { echo "[$(date +%H:%M:%S)] $*"; }

td_require_env() {
  local missing=""
  [ -n "${TD_PKG:-}" ]     || missing="$missing TD_PKG"
  [ -n "${TD_RUN_DIR:-}" ] || missing="$missing TD_RUN_DIR"
  [ -x "$ADB" ]            || missing="$missing ADB"
  [ -z "$missing" ] || { td_log "환경변수 없음:$missing"; exit 1; }
  mkdir -p "$TD_RUN_DIR"
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

td_launch() { td_adb shell monkey -p "$TD_PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; }

# ── 화면 조작 ─────────────────────────────────────────
td_ui_find() {  # $1 = python 술어. 조건에 맞는 첫 노드의 중심 좌표를 출력한다.
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

td_tap() {  # $1 = python 술어, $2 = 설명
  local xy
  xy=$(td_ui_find "$1") || { td_log "탭 실패 — 못 찾음: ${2:-$1}"; return 1; }
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

# ── 판정 ──────────────────────────────────────────────
td_crash_clear() { td_adb logcat -c >/dev/null 2>&1; td_adb logcat -b crash -c >/dev/null 2>&1; }

td_crash_count() { td_adb logcat -d -b crash 2>/dev/null | grep -c "FATAL EXCEPTION"; }

td_crash_dump() { td_adb logcat -d -b crash > "$TD_RUN_DIR/${1:-crash}.txt" 2>/dev/null; }

td_capture_failure() {  # $1 = 설명
  TD_FAIL_SEQ=$((TD_FAIL_SEQ + 1))
  local base; base=$(printf "fail-%02d" "$TD_FAIL_SEQ")
  td_adb shell screencap -p /sdcard/td-shot.png >/dev/null 2>&1
  td_adb pull /sdcard/td-shot.png "$TD_RUN_DIR/$base.png" >/dev/null 2>&1
  td_adb shell uiautomator dump /sdcard/td-ui.xml >/dev/null 2>&1
  td_adb pull /sdcard/td-ui.xml "$TD_RUN_DIR/$base.xml" >/dev/null 2>&1
  td_log "실패 캡처: $base.png · $base.xml — ${1:-}"
}

td_require() {  # $1 = 설명, $2 = 조건 명령. 실패하면 시나리오를 실행불가로 만든다.
  if eval "$2" >/dev/null 2>&1; then
    td_log "사전조건 OK: $1"
  else
    td_log "사전조건 미충족: $1 → 실행불가"
    TD_BLOCKED="$1"
    return 1
  fi
}

td_check() {  # $1 = 설명, $2 = 기준 명령
  if eval "$2" >/dev/null 2>&1; then
    TD_PASS=$((TD_PASS + 1)); td_log "PASS  $1"
  else
    TD_FAIL=$((TD_FAIL + 1)); td_log "FAIL  $1"; td_capture_failure "$1"
  fi
}

td_step() {  # $1 = 번호, $2 = 설명, $3 = 명령. 실패하면 캡처하고 1 을 반환한다.
  td_log "[$1] $2"
  eval "$3" && return 0
  td_log "스텝 $1 실패: $2"
  td_capture_failure "스텝 $1 — $2"
  return 1
}

# 스텝 실패 시 복구를 실행하고 종료한다. run.sh 가 td_recover 를 정의한다.
td_abort() {
  td_log "중단 — 복구 실행"
  declare -F td_recover >/dev/null && td_recover
  td_summary
  exit 1
}

td_summary() {
  td_log "PASS $TD_PASS / FAIL $TD_FAIL${TD_BLOCKED:+ / 실행불가: $TD_BLOCKED}"
  echo "TD_PASS=$TD_PASS"
  echo "TD_FAIL=$TD_FAIL"
  echo "TD_BLOCKED=${TD_BLOCKED}"
  echo "TD_EXIT=$([ "$TD_FAIL" -eq 0 ] && [ -z "$TD_BLOCKED" ] && echo 0 || echo 1)"
}
