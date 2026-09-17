#!/bin/bash
# test-drive PreToolUse hook. SKILL.md frontmatter 가 등록한다.
# 스킬 hook 은 호출 후 세션 끝까지 유지된다. test-drive 명령이 아니면 출력 없이 exit 0 한다.
#   H1 포그라운드 bash run.sh      → deny
#   H2 adb uninstall · pm clear    → ask

exec python3 -c '
import json, re, sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if data.get("tool_name") != "Bash":
    sys.exit(0)
tool_input = data.get("tool_input") or {}
cmd = tool_input.get("command") or ""

def decide(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}, ensure_ascii=False))
    sys.exit(0)

if re.search(r"(^|[;&|\s])(bash|sh)\s+([^;&|\s]*/)?run\.sh(\s|$)", cmd) \
        and tool_input.get("run_in_background") is not True:
    decide("deny", "test-drive: run.sh 는 run_in_background: true 로 실행한다")

if (re.search(r"\b(td_)?adb\b", cmd) and re.search(r"\buninstall\b", cmd)) \
        or re.search(r"\bpm\s+clear\b", cmd):
    decide("ask", "test-drive: 앱 데이터·로그인이 삭제된다")
'
