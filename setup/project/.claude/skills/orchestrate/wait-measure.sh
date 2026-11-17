#!/usr/bin/env bash
# 전후 측정(full-build.sh --measure)이 도는 동안 기다린다(ORCH-042). 워커는 DB를 쓰는 시험을 돌리기 전에 부른다.
# 다른 카드의 워커 시험이 측정과 겹치면 DB 연결·메모리를 나눠 써서 측정이 깨지거나 시간이 섞인다.
# 쓰기: bash <레포 루트>/.claude/skills/orchestrate/wait-measure.sh
lock="${FULL_BUILD_LOCK:-$HOME/.workbench/full-build.lock}"
said=
while [ -e "$lock/measure" ]; do
	pid=$(cat "$lock/pid" 2>/dev/null)
	since=$(cat "$lock/since" 2>/dev/null)
	# 측정이 죽고 잠금만 남았으면 기다리지 않는다(full-build.sh 가 버려진 잠금으로 보는 조건과 같다)
	if [ -n "$pid" ] && { ! kill -0 "$pid" 2>/dev/null || [ $(( $(date +%s) - since )) -gt 5400 ]; }; then
		break
	fi
	[ -n "$said" ] || { echo "측정 중이라 기다린다: $(cat "$lock/owner" 2>/dev/null)"; said=1; }
	sleep 10
done
