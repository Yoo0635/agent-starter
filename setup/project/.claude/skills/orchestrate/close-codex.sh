#!/usr/bin/env bash
# 사용: close-codex.sh <핸들> — 끝난 Codex 워커 탭을 프로세스부터 끝내고 탭까지 닫은 뒤 목록에서 사라졌는지 본다 (ORCH-067·081)
# 첫 close 뒤 Orca 가 같은 탭에 새 핸들을 붙여 옛 핸들의 --tab 이 terminal_handle_stale 로 실패한다. 그래서 tabId·leafId 로 탭을 다시 찾는다
# 끝 코드: 0 닫힘(이미 없음 포함), 1 탭이 남음
set -u
O=${ORCA_CMD:-/c/Users/user/AppData/Local/Programs/orca/resources/bin/orca.cmd}
h=${1:?usage: close-codex.sh <handle>}
# find <field> <value>: terminal list 에서 그 칸이 같은 터미널의 "handle tabId leafId" 를 찍는다
find() {
  "$O" terminal list --json 2>/dev/null | node -e '
    let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
      try{for(const t of JSON.parse(d).result.terminals){if(t[process.argv[1]]===process.argv[2])console.log(t.handle,t.tabId,t.leafId)}}catch(e){process.exit(3)}})' "$1" "$2"
}
read -r _ tab leaf < <(find handle "$h")
if [ -z "${tab:-}" ]; then echo "닫음: $h 이미 목록에 없음"; exit 0; fi
for try in 1 2 3; do
  r=$("$O" terminal close --terminal "$h" --json 2>&1); echo "close $h: $(echo "$r" | tr -d ' \n' | grep -o '"ok":[a-z]*\|"ptyKilled":[a-z]*\|"code":"[^"]*"' | tr '\n' ' ')"
  cur=$(find tabId "$tab" | awk -v l="$leaf" '$3==l{print $1}' | head -1)
  [ -z "$cur" ] && { echo "닫음: $h (탭 $tab 사라짐)"; exit 0; }
  r=$("$O" terminal close --terminal "$cur" --tab --json 2>&1); echo "close --tab $cur: $(echo "$r" | tr -d ' \n' | grep -o '"ok":[a-z]*\|"code":"[^"]*"' | tr '\n' ' ')"
  cur=$(find tabId "$tab" | awk -v l="$leaf" '$3==l{print $1}' | head -1)
  [ -z "$cur" ] && { echo "닫음: $h (탭 $tab 사라짐)"; exit 0; }
  h=$cur; sleep 3
done
echo "남음: 탭 $tab leaf $leaf 핸들 $cur"; exit 1
