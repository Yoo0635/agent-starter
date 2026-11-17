#!/usr/bin/env bash
# Orca 에이전트 탭의 Codex 가 턴을 끝낼 때까지 기다린다(ORCH-043).
# tui-idle 신호는 Codex 가 끝나도 가끔 늦게 오거나 오지 않으므로, 짧게 기다린 뒤 매번 화면을 직접 본다.
# 쓰기: bash <레포 루트>/.claude/skills/orchestrate/wait-codex.sh <탭 핸들>
# 끝 코드: 0 끝남(마지막 화면 줄을 찍는다) 2 사용량 소진 3 탭을 읽을 수 없음 4 한 시간 넘게 안 끝남
O=/c/Users/user/AppData/Local/Programs/orca/resources/bin/orca.cmd
h=$1
step_ms=${CODEX_WAIT_STEP_MS:-90000}
deadline=$(( $(date +%s) + ${CODEX_WAIT_TOTAL_S:-3600} ))
fails=0
while :; do
	"$O" terminal wait --terminal "$h" --for tui-idle --timeout-ms "$step_ms" --json >/dev/null 2>&1
	if ! scr=$("$O" terminal read --terminal "$h" --screen 2>/dev/null) || [ -z "$scr" ]; then
		fails=$((fails + 1))
		[ "$fails" -ge 3 ] && { echo "탭을 읽을 수 없음: $h"; exit 3; }
		sleep 5
		continue
	fi
	fails=0
	tail=$(printf '%s\n' "$scr" | grep -v '^\s*$' | tail -20)
	if printf '%s\n' "$scr" | grep -qi 'hit your usage limit\|usage_limit_reached'; then
		printf '%s\n' "$tail"; exit 2
	fi
	# 일하는 중이면 상태 줄에 "esc to interrupt" 가 있고, 턴이 끝나면 "Worked for" 구분선이 남는다
	if ! printf '%s\n' "$tail" | grep -q 'esc to interrupt\|Messages to be submitted' &&
		printf '%s\n' "$tail" | grep -q 'Worked for'; then
		printf '%s\n' "$tail"; exit 0
	fi
	[ "$(date +%s)" -ge "$deadline" ] && { printf '%s\n' "$tail"; exit 4; }
done
