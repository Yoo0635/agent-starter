#!/usr/bin/env bash
# 합치기 전에 작업이 꼬였는지 git 으로 본다(ORCH-051).
# 쓰기: bash <레포 루트>/.claude/skills/orchestrate/check-tangle.sh <통합 worktree> <NNN> [합칠 작업 worktree]
# 끝 코드: 0 꼬임 없음 1 꼬임 있음(꼬임 N: 줄) 2 인자가 모자람
#   꼬임 1 통합 worktree 의 backend 에 커밋 안 된 파일(ORCH-047)
#   꼬임 2 통합 worktree 안의 작업 worktree(.claude/worktrees/orch-<NNN>-*) 둘 이상이 함께 고친 파일(ORCH-031). 통합 worktree 에 이미 있는 커밋은 뺀다
#   꼬임 3 합칠 작업 worktree 에 커밋 안 된 변경
[ $# -ge 2 ] || { echo "쓰기: check-tangle.sh <통합 worktree> <NNN> [합칠 작업 worktree]"; exit 2; }
integ=$1 nnn=$2 merge=${3:-}
found=0

while read -r st; do
	echo "꼬임 1: 통합 worktree 에 커밋 안 된 파일 $st"; found=1
done < <(git -C "$integ" status --porcelain -- backend)

head=$(git -C "$integ" rev-parse HEAD)
top=$(git -C "$integ" rev-parse --show-toplevel)
# 작업 worktree 는 통합 worktree 안의 .claude/worktrees/orch-<NNN>-* 다. 다른 통합 worktree 의 것은 보지 않는다
# 작업 worktree 마다 "통합 worktree 에 없는 커밋이 고친 파일 + 커밋 안 된 파일"을 "파일<TAB>worktree" 로 모은다
changes=$(git -C "$integ" worktree list --porcelain | sed -n 's/^worktree //p' | grep -F "$top/.claude/worktrees/orch-$nnn-" | while read -r wt; do
	{
		git -C "$wt" log --cherry-pick --right-only --no-merges --name-only --format= "$head...HEAD"
		git -C "$wt" status --porcelain | sed 's/^...//; s/.* -> //'
	} | grep -v '^$' | sort -u | sed "s|\$|	${wt##*/}|"
done)
while IFS=$'\t' read -r f wts; do
	echo "꼬임 2: $f ($wts)"; found=1
done < <(printf '%s\n' "$changes" | grep -v '^$' | awk -F'\t' '{ n[$1]++; w[$1] = w[$1] (n[$1] > 1 ? ", " : "") $2 } END { for (f in n) if (n[f] > 1) print f "\t" w[f] }' | sort)

if [ -n "$merge" ]; then
	while read -r st; do
		echo "꼬임 3: 합칠 작업 worktree 에 커밋 안 된 변경 $st"; found=1
	done < <(git -C "$merge" status --porcelain)
fi

[ $found -eq 0 ] && echo "꼬임 없음"
exit $found
