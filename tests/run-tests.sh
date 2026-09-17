#!/bin/bash
# test-drive 스크립트 테스트. 실행: /bin/bash tests/run-tests.sh
# adb 는 tests/fake-adb 로 대체한다. 기기가 필요 없다.

set -u

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
LIB=$REPO/scripts/td-lib.sh
FAKE_ADB=$REPO/tests/fake-adb
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "PASS  $1"; }
ng() { FAIL=$((FAIL + 1)); echo "FAIL  $1"; [ -z "${2:-}" ] || echo "      $2"; }

expect() {  # $1 = 이름, $2 = 조건
  if eval "$2" >/dev/null 2>&1; then ok "$1"; else ng "$1" "$2"; fi
}

# 케이스마다 새 샌드박스를 만든다.
#   $WORK = 작업 폴더, $RUN = runs/001_S01-S02, $OUT = run.sh 출력
setup() {
  T=$(cd "$(mktemp -d)" && pwd -P)
  WORK=$T/work
  RUN=$WORK/runs/001_S01-S02
  OUT=$T/out.txt
  mkdir -p "$RUN" "$T/fake"
  export FAKE_DIR=$T/fake
  export FAKE_ADB_LOG=$T/adb.log
  : > "$FAKE_ADB_LOG"
}

cleanup() { rm -rf "$T"; }

write_ui() {  # $1 = 경로. 확인 버튼(540,1200) · 닫기 아이콘 · 비클릭 루트
  cat > "$1" <<'EOF'
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy rotation="0">
<node index="0" text="" resource-id="" class="android.widget.FrameLayout" package="com.example.app" content-desc="" clickable="false" bounds="[0,0][1080,2400]">
<node index="0" text="확인" resource-id="com.example.app:id/btn_ok" class="android.widget.Button" package="com.example.app" content-desc="" clickable="true" bounds="[440,1100][640,1300]" />
<node index="1" text="" resource-id="com.example.app:id/iv_close" class="android.widget.ImageView" package="com.example.app" content-desc="닫기" clickable="true" bounds="[0,0][100,100]" />
</node>
</hierarchy>
EOF
}

write_run() {  # stdin = run.sh 본문. 머리(source · env · td_require_env)를 붙인다
  {
    cat <<EOF
#!/bin/bash
source "$LIB"
export TD_PKG=com.example.app
export TD_RUN_DIR="$RUN"
td_require_env
EOF
    cat
  } > "$WORK/run.sh"
}

run_sh() {  # $1 = 제한 초, 나머지 = 환경변수 할당. 작업 폴더에서 bash run.sh 를 실행한다
  local limit=$1 pid n=0; shift
  (cd "$WORK" && exec env ADB="$FAKE_ADB" "$@" /bin/bash run.sh) > "$OUT" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    n=$((n + 1))
    if [ "$n" -gt $((limit * 5)) ]; then
      kill -TERM "$pid" 2>/dev/null; echo "(시간 초과)" >> "$OUT"; break
    fi
    sleep 0.2
  done
  wait "$pid" 2>/dev/null
}

# ── T1 · T4 의존 실패 ─────────────────────────────────
t1() {
  write_run <<'EOF'
s1() { td_step 1.1 "첫 스텝 실패" 'false' || return 1; }
s2() { td_adb shell echo s2-body; }
td_scenario 1 "첫 시나리오" s1 -
td_scenario 2 "의존 시나리오" s2 - 1
td_summary
EOF
  run_sh 20
  expect "T1 S1 중단" 'grep -q "S01 중단" "$OUT"'
  expect "T1 S2 실행불가 · 사유 의존 S01 중단" 'grep -q "S02 실행불가 의존 S01 중단" "$OUT"'
  expect "T1 S2 기기 조작 없음" 'grep -q "S02 실행불가" "$OUT" && ! grep -q "s2-body" "$FAKE_ADB_LOG"'
  expect "T4 TD_SUFFIX=중단@S01.1_실행불가-1" 'grep -qxF "TD_SUFFIX=중단@S01.1_실행불가-1" "$OUT"'
  expect "T4 TD_EXIT=1 (중단)" 'grep -qxF "TD_EXIT=1" "$OUT"'
}

# ── T2 TD_START_FROM ─────────────────────────────────
t2() {
  write_run <<'EOF'
s1() { td_adb shell echo s1-body; }
s2() { td_adb shell echo s2-body; }
td_scenario 1 "첫 시나리오" s1 -
td_scenario 2 "의존 시나리오" s2 - 1
td_summary
EOF
  run_sh 20 TD_START_FROM=2
  expect "T2 S1 건너뜀" 'grep -q "S01 건너뜀" "$OUT"'
  expect "T2 S1 본문 미실행" 'grep -q "S01 건너뜀" "$OUT" && ! grep -q "s1-body" "$FAKE_ADB_LOG"'
  expect "T2 의존 S2 실행" 'grep -q "s2-body" "$FAKE_ADB_LOG"'
}

# ── T3 td_check 실패 캡처 · failures.md ──────────────
t3() {
  write_ui "$FAKE_DIR/ui.xml"
  write_run <<'EOF'
s8() { td_check 8.4 "단계 조회 없음" 'false'; }
td_scenario 8 "종료 안내" s8 -
td_summary
EOF
  run_sh 20
  expect "T3 fail/S08.4_check.png" '[ -f "$RUN/fail/S08.4_check.png" ]'
  expect "T3 fail/S08.4_check.xml" '[ -f "$RUN/fail/S08.4_check.xml" ]'
  expect "T3 failures.md F01 행" 'grep -qF "| F01 | 001 | S08.4 | check | 미분류 |" "$WORK/failures.md"'
  expect "T3 failures.md 캡처 경로" 'grep -qF "runs/001_S01-S02/fail/S08.4_check.png" "$WORK/failures.md"'
}

# ── T4 전부 PASS ─────────────────────────────────────
t4() {
  write_run <<'EOF'
s1() { td_step 1.1 "통과 스텝" 'true' || return 1; td_check 1.2 "통과 판정" 'true'; }
td_scenario 1 "전부 통과" s1 -
td_summary
EOF
  run_sh 20
  expect "T4 S1 PASS" 'grep -q "S01 PASS" "$OUT"'
  expect "T4 TD_SUFFIX=완료" 'grep -qxF "TD_SUFFIX=완료" "$OUT"'
  expect "T4 TD_EXIT=0 (완료)" 'grep -qxF "TD_SUFFIX=완료" "$OUT" && grep -qxF "TD_EXIT=0" "$OUT"'
}

# ── T5 TERM 시 td_bg 정리 ────────────────────────────
t5() {
  local pid n=0
  write_run <<'EOF'
td_bg sleep 3017
while :; do sleep 0.2; done
EOF
  (cd "$WORK" && exec env ADB="$FAKE_ADB" /bin/bash run.sh) > "$OUT" 2>&1 &
  pid=$!
  until pgrep -f "sleep 3017" >/dev/null || [ "$n" -ge 25 ]; do sleep 0.2; n=$((n + 1)); done
  if ! pgrep -f "sleep 3017" >/dev/null; then
    ng "T5 TERM 후 td_bg 프로세스 정리" "td_bg 로 sleep 이 시작되지 않음"
    kill -KILL "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    return
  fi
  kill -TERM "$pid"
  n=0
  while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 25 ]; do sleep 0.2; n=$((n + 1)); done
  kill -KILL "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  sleep 0.3
  expect "T5 TERM 후 td_bg 프로세스 정리" '! pgrep -f "sleep 3017"'
  pkill -f "sleep 3017" 2>/dev/null
}

# ── T6 td_tap 대기 ───────────────────────────────────
t6() {
  write_ui "$T/ui.src.xml"
  write_run <<'EOF'
tap_ok() { td_tap "g('text') == '확인'" "확인 버튼"; }
s1() { td_step 1.1 "늦게 뜨는 버튼 탭" tap_ok || return 1; }
td_scenario 1 "지연 화면" s1 -
td_summary
EOF
  (sleep 3; cp "$T/ui.src.xml" "$FAKE_DIR/ui.xml") &
  run_sh 30 TD_TAP_WAIT=10
  wait
  expect "T6 3초 뒤 뜬 버튼 탭" 'grep -q "input tap 540 1200" "$FAKE_ADB_LOG"'
  expect "T6 S1 PASS" 'grep -q "S01 PASS" "$OUT"'
}

# ── T7 run.sh 스냅샷 ─────────────────────────────────
t7() {
  write_run <<'EOF'
td_summary
EOF
  run_sh 20
  expect "T7 run 폴더에 run.sh 스냅샷" 'cmp -s "$WORK/run.sh" "$RUN/run.sh"'
}

# ── T8 td-new-run.sh ─────────────────────────────────
t8() {
  rmdir "$RUN"
  mkdir -p "$WORK/runs/001_S01-S12" "$WORK/runs/002_S01-S12_FAIL-1"
  NEWRUN_OUT=$("$REPO/scripts/td-new-run.sh" "$WORK" 2 12 2>&1)
  expect "T8 003_S02-S12 생성" '[ -d "$WORK/runs/003_S02-S12" ]'
  expect "T8 절대경로 한 줄 출력" '[ "$NEWRUN_OUT" = "$WORK/runs/003_S02-S12" ]'
}

# ── T9 td-finalize.sh ────────────────────────────────
t9() {
  local new=$WORK/runs/001_S01-S02_FAIL-1 open=$WORK/runs/002_S01-S01
  cat > "$RUN/run.log" <<'EOF'
[10:00:00] ════════ 시나리오 1 — 첫 시나리오
[10:00:05] PASS  1.2 통과 판정
[10:00:06] ════════ 시나리오 2 — 둘째 시나리오
[10:00:09] FAIL  2.3 조회 없음
[10:00:10] S01 PASS
[10:00:10] S02 FAIL
[10:00:10] 판정 PASS 1 / FAIL 1
TD_SUFFIX=FAIL-1
TD_EXIT=1
EOF
  cat > "$WORK/failures.md" <<'EOF'
| ID | run | 스텝 | 종류 | 분류 | 원인 | 조치 | 캡처 |
|---|---|---|---|---|---|---|---|
| F01 | 001 | S02.3 | check | 미분류 | 조회 없음 | - | runs/001_S01-S02/fail/S02.3_check.png |
EOF
  FIN_OUT=$("$REPO/scripts/td-finalize.sh" "$RUN" 2>&1)
  expect "T9 폴더 이름에 접미사" '[ -d "$new" ] && [ ! -d "$RUN" ]'
  expect "T9 새 절대경로 출력" '[ "$FIN_OUT" = "$new" ]'
  expect "T9 failures.md 경로 갱신" 'grep -qF "runs/001_S01-S02_FAIL-1/fail/S02.3_check.png" "$WORK/failures.md"'
  expect "T9 result.md 초안 · <채움>" 'grep -qF "<채움>" "$new/result.md"'
  expect "T9 result.md 초안 · 시각" 'grep -qF "10:00:00" "$new/result.md" && grep -qF "10:00:10" "$new/result.md"'
  expect "T9 result.md 초안 · 판정 원문" 'grep -qF "PASS  1.2 통과 판정" "$new/result.md" && grep -qF "FAIL  2.3 조회 없음" "$new/result.md"'
  FIN_OUT=$("$REPO/scripts/td-finalize.sh" "$new" 2>&1)
  expect "T9 재실행 시 이름 유지" '[ -d "$new" ] && [ ! -d "${new}_FAIL-1" ]'

  mkdir -p "$open"
  printf '[10:00:00] ════════ 시나리오 1 — 첫 시나리오\n' > "$open/run.log"
  FIN_OUT=$("$REPO/scripts/td-finalize.sh" "$open" 2>&1)
  FIN_RC=$?
  expect "T9 TD_SUFFIX 없음 → 안내 · exit 1 · 이름 유지" 'printf "%s" "$FIN_OUT" | grep -qF "실행이 끝나지 않음" && [ "$FIN_RC" -eq 1 ] && [ -d "$open" ]'
}

# ── T10 td-probe.sh ──────────────────────────────────
t10() {
  write_ui "$T/ui.xml"
  PROBE_OUT=$("$REPO/scripts/td-probe.sh" "$T/ui.xml" 2>&1)
  expect "T10 IDS 줄" 'printf "%s\n" "$PROBE_OUT" | grep -E "^IDS" | grep -q "btn_ok"'
  expect "T10 TEXT 줄" 'printf "%s\n" "$PROBE_OUT" | grep -E "^TEXT" | grep "확인" | grep -q "닫기"'
  expect "T10 CLICK 줄" 'printf "%s\n" "$PROBE_OUT" | grep -qE "^CLICK 540 1200 "'
  expect "T10 CLICK 은 clickable 노드만" '[ "$(printf "%s\n" "$PROBE_OUT" | grep -c "^CLICK")" -eq 2 ]'
}

# ── T11 guard-bash hook ──────────────────────────────
hook_decision() {  # $1 = tool_name, $2 = command, $3 = run_in_background. 출력 없으면 none
  python3 -c 'import json, sys; print(json.dumps({"tool_name": sys.argv[1], "tool_input": {"command": sys.argv[2], "run_in_background": sys.argv[3] == "true"}}))' "$1" "$2" "$3" \
    | bash "$REPO/hooks/guard-bash.sh" \
    | python3 -c 'import json, sys
d = sys.stdin.read().strip()
print(json.loads(d)["hookSpecificOutput"]["permissionDecision"] if d else "none")'
}

t11() {
  if [ ! -f "$REPO/hooks/guard-bash.sh" ]; then
    ng "T11 guard-bash" "hooks/guard-bash.sh 없음"
    return
  fi
  expect "T11 포그라운드 bash run.sh → deny" '[ "$(hook_decision Bash "bash run.sh" false)" = deny ]'
  expect "T11 포그라운드 START_FROM=2 bash run.sh → deny" '[ "$(hook_decision Bash "START_FROM=2 bash run.sh" false)" = deny ]'
  expect "T11 백그라운드 bash run.sh → 출력 없음" '[ "$(hook_decision Bash "cd /tmp/w && bash run.sh" true)" = none ]'
  expect "T11 bash -n run.sh → 출력 없음" '[ "$(hook_decision Bash "bash -n run.sh" false)" = none ]'
  expect "T11 adb uninstall → ask" '[ "$(hook_decision Bash "adb -s X uninstall pkg" false)" = ask ]'
  expect "T11 td_adb pm clear → ask" '[ "$(hook_decision Bash "td_adb shell pm clear pkg" false)" = ask ]'
  expect "T11 ls → 출력 없음" '[ "$(hook_decision Bash "ls" false)" = none ]'
  expect "T11 tool_name=Edit → 출력 없음" '[ "$(hook_decision Edit "bash run.sh" false)" = none ]'
}

for t in t1 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11; do
  setup
  "$t"
  cleanup
done

echo "PASS $PASS / FAIL $FAIL"
[ "$FAIL" -eq 0 ]
