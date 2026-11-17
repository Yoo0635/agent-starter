#!/usr/bin/env bash
# main 으로 가는 push 에 코드(.md 가 아닌 backend 파일)가 들어 있으면 이 worktree 의 full-build.sh 가 잠금을 쥐고 있을 때만 보낸다(ORCH-035).
# 문서(저장소 루트 docs, backend 의 .md)·.claude 만 바꾼 push 는 그대로 보낸다(ORCH-025). full-build.sh 의 code_changed 와 같은 기준이다.
# .git/hooks/pre-push 에서 부른다. 설치는 ORCH-035 참고.

lock="${FULL_BUILD_LOCK:-$HOME/.workbench/full-build.lock}"
zero=0000000000000000000000000000000000000000
# full-build.sh 는 잠금에 pid 와 "<worktree>/backend <gradle 작업>" 을 남긴다
top=$(cd "$(git rev-parse --show-toplevel)" && pwd)

while read -r local_ref local_sha remote_ref remote_sha; do
	[ "$remote_ref" = refs/heads/main ] || continue
	[ "$local_sha" = "$zero" ] && continue
	# 원격 끝을 모르면 fast-forward 가 아니라 git 이 어차피 거절한다
	git cat-file -e "$remote_sha^{commit}" 2>/dev/null || continue
	[ -n "$(git diff --name-only "$remote_sha" "$local_sha" -- ':(top)backend' ':(top,exclude,glob)backend/**/*.md')" ] || continue
	pid=$(cat "$lock/pid" 2>/dev/null)
	owner=$(cat "$lock/owner" 2>/dev/null)
	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "${owner%% *}" = "$top/backend" ]; then
		continue
	fi
	echo "push 거절: main 에 코드(.md 아님)를 올리려면 full-build.sh --push 로 보낸다(ORCH-025·035)." >&2
	echo "  cd <worktree>/backend && bash <레포 루트>/.claude/skills/orchestrate/full-build.sh --push <로그 경로> <module-tests.sh 가 고른 작업…>" >&2
	exit 1
done
exit 0
