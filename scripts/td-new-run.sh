#!/bin/bash
# 새 run 폴더를 만들고 절대경로 한 줄을 출력한다.
# 사용: td-new-run.sh <작업폴더> <시작번호> <끝번호>
#   → <작업폴더>/runs/NNN_S<시작>-S<끝>  (NNN = 기존 최대 번호 + 1)

set -u

[ $# -eq 3 ] || { echo "사용: td-new-run.sh <작업폴더> <시작번호> <끝번호>" >&2; exit 1; }
work=$(cd "$1" && pwd) || exit 1
mkdir -p "$work/runs"

last=$(ls "$work/runs" | grep -oE '^[0-9]{3}' | sort -n | tail -1)
next=$(printf '%03d' "$((10#${last:-0} + 1))")
dir=$(printf '%s/runs/%s_S%02d-S%02d' "$work" "$next" "$((10#$2))" "$((10#$3))")

mkdir "$dir" || exit 1
echo "$dir"
