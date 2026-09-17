#!/bin/bash
# run 종료 후 폴더 이름에 결과 접미사를 붙이고 result.md 초안을 만든다.
# 사용: td-finalize.sh <run폴더>
#   run.log 의 마지막 TD_SUFFIX= 값을 접미사로 쓴다. 없으면 exit 1
#   작업 폴더 failures.md 의 캡처 경로를 새 이름으로 바꾼다
#   새 폴더의 절대경로를 출력한다

set -u

[ $# -eq 1 ] || { echo "사용: td-finalize.sh <run폴더>" >&2; exit 1; }
run=$(cd "$1" && pwd) || exit 1
work=$(cd "$run/../.." && pwd)
name=$(basename "$run")

suffix=$(grep -E '^TD_SUFFIX=' "$run/run.log" 2>/dev/null | tail -1 | cut -d= -f2-)
[ -n "$suffix" ] || { echo "실행이 끝나지 않음: $run/run.log 에 TD_SUFFIX 없음"; exit 1; }

new=$run
case $name in
  *_"$suffix") ;;
  *)
    new=$(dirname "$run")/${name}_$suffix
    mv "$run" "$new" || exit 1
    if [ -f "$work/failures.md" ]; then
      python3 - "$work/failures.md" "runs/$name/" "runs/${name}_$suffix/" <<'PY'
import sys
path, old, new = sys.argv[1:]
with open(path, encoding='utf-8') as f:
    s = f.read()
with open(path, 'w', encoding='utf-8') as f:
    f.write(s.replace(old, new))
PY
    fi
    ;;
esac

[ -f "$new/result.md" ] || python3 - "$new" <<'PY'
import os, re, sys, datetime

run = sys.argv[1]
log = os.path.join(run, 'run.log')
lines = open(log, encoding='utf-8').read().splitlines()

def esc(s):
    return s.replace('|', '\\|')

times = [m.group(1) for m in (re.match(r'^\[(\d\d:\d\d:\d\d)\]', l) for l in lines) if m]
date = datetime.date.fromtimestamp(os.path.getmtime(log)).isoformat()
when = '%s %s ~ %s' % (date, times[0], times[-1]) if times else '<채움>'

order, title, status, reason, judged = [], {}, {}, {}, {}
for l in lines:
    m = re.match(r'^\[[\d:]+\] ════════ 시나리오 (\d+) — (.*)$', l)
    if m:
        no = int(m.group(1))
        if no not in order:
            order.append(no)
        title[no] = m.group(2)
        continue
    m = re.match(r'^\[[\d:]+\] S(\d+) (PASS|FAIL|중단|실행불가|건너뜀)(?: (.*))?$', l)
    if m:
        no = int(m.group(1))
        status[no] = m.group(2)
        reason[no] = m.group(3) or ''
        continue
    m = re.match(r'^\[[\d:]+\] ((PASS|FAIL)  (\d+)[.\s].*)$', l)
    if m:
        judged.setdefault(int(m.group(3)), []).append(m.group(1))

out = [
    '# <채움> — %s' % os.path.basename(run),
    '',
    '## 실행',
    '| 항목 | 값 |',
    '|---|---|',
    '| 시각 | %s |' % when,
    '| 기기 | <채움> |',
    '| 빌드 | <채움> |',
    '| 시나리오 | <채움> |',
    '| 근거 자료 | <채움> |',
    '| 로그 | `run.log` |',
    '',
    '## 판정',
    '| # | 시나리오 | 결과 | 근거 |',
    '|---|---|---|---|',
]
count = {}
for no in order:
    st = status.get(no, '<채움>')
    count[st] = count.get(st, 0) + 1
    basis = ['`%s`' % esc(j) for j in judged.get(no, [])]
    if reason.get(no):
        basis.append(esc(reason[no]))
    out.append('| %d | %s | %s | %s |' % (no, esc(title[no]), st, '<br>'.join(basis) or '-'))
out.append('')
out.append(' / '.join('%s %d' % (k, count.get(k, 0)) for k in ('PASS', 'FAIL', '중단', '실행불가', '건너뜀')))

fails = sorted(f[:-4] for f in os.listdir(os.path.join(run, 'fail')) if f.endswith('.png')) \
    if os.path.isdir(os.path.join(run, 'fail')) else []
if fails:
    out += ['', '## 실패 상세']
    for base in fails:
        out += [
            '### %s' % base,
            '- 결함: <채움>',
            '- 원인: <채움>',
            '- 캡처: `fail/%s.png` · `fail/%s.xml`' % (base, base),
        ]

with open(os.path.join(run, 'result.md'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(out) + '\n')
PY

echo "$new"
