#!/bin/bash
# 화면 구조를 요약한다. 시나리오 작성 전 사전 탐색에 쓴다.
# 사용: td-probe.sh [xml] [술어]
#   xml 이 없거나 "" 이면 기기 화면을 dump 한다 (ANDROID_SERIAL · ADB 사용)
#   술어는 td_ui_find 와 같은 python 식이다. 매칭 노드마다 MATCH 줄을 출력한다
# 출력: TOP(기기 모드만) · PKGS · IDS · TEXT · CLICK <x> <y> <id|text> · MATCH <속성…>

set -u

xml=${1:-}
pred=${2:-}
tmp=$(mktemp -d)
trap 'rm -r "$tmp" 2>/dev/null' EXIT

if [ -z "$xml" ]; then
  ADB=${ADB:-$(ls "$HOME/Library/Android/sdk/platform-tools/adb" 2>/dev/null || command -v adb)}
  "$ADB" shell uiautomator dump /sdcard/td-ui.xml >/dev/null 2>&1
  "$ADB" pull /sdcard/td-ui.xml "$tmp/ui.xml" >/dev/null 2>&1 || { echo "화면 dump 실패" >&2; exit 1; }
  xml=$tmp/ui.xml
  echo "TOP $("$ADB" shell dumpsys activity activities | grep -m1 topResumedActivity | tr -d '\r' | sed 's/^ *topResumedActivity=//')"
fi

[ -f "$xml" ] || { echo "xml 없음: $xml" >&2; exit 1; }

python3 - "$xml" "$pred" <<'PY'
import sys, re, xml.etree.ElementTree as ET

nodes = list(ET.parse(sys.argv[1]).iter('node'))
pred = sys.argv[2]

def uniq(xs):
    out = []
    for x in xs:
        if x and x not in out:
            out.append(x)
    return out

def short_id(n):
    rid = n.get('resource-id') or ''
    return rid.split(':id/', 1)[1] if ':id/' in rid else ''

print('PKGS ' + ' '.join(uniq(n.get('package') for n in nodes)))
print('IDS ' + ' '.join(uniq(short_id(n) for n in nodes)))
print('TEXT ' + ' | '.join(uniq(v for n in nodes for v in (n.get('text'), n.get('content-desc')))))

for n in nodes:
    if n.get('clickable') != 'true':
        continue
    b = list(map(int, re.findall(r'\d+', n.get('bounds') or '')))
    if len(b) < 4:
        continue
    label = short_id(n) or n.get('text') or n.get('content-desc') or '-'
    print('CLICK %d %d %s' % ((b[0] + b[2]) // 2, (b[1] + b[3]) // 2, label))

if pred:
    hits = 0
    for n in nodes:
        g = lambda k: (n.get(k) or '')
        try:
            hit = eval(pred)
        except Exception:
            hit = False
        if hit:
            hits += 1
            print('MATCH ' + ' '.join('%s="%s"' % kv for kv in n.attrib.items()))
    if hits == 0:
        print('MATCH 없음')
        sys.exit(1)
PY
