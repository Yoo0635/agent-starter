#!/usr/bin/env bash
# check-tangle.sh 시험(ORCH-051). 임시 레포에 통합·작업 worktree 를 만들어 꼬임을 하나씩 넣어 본다.
# 쓰기: bash .claude/skills/orchestrate/check-tangle-test.sh
set -u
check="$(cd "$(dirname "$0")" && pwd)/check-tangle.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

git init -q -b main "$tmp/r"
cd "$tmp/r"
git config user.email t@t; git config user.name t; git config core.autocrlf false
mkdir -p backend/a/src docs
echo a > backend/a/src/A.java; echo b > backend/a/src/B.java; echo c > backend/a/src/C.java; echo d > docs/d.md
git add -A; git commit -qm init
integ="$tmp/r/.claude/worktrees/orch-007"
git worktree add -q --detach "$integ" HEAD

# 작업 worktree 를 통합 worktree HEAD 에서 만들고 $2 파일을 고쳐 커밋한다
task() {
	git -C "$integ" worktree add -q --detach "$integ/.claude/worktrees/orch-007-$1" HEAD
	for f in $2; do echo "$RANDOM" >> "$integ/.claude/worktrees/orch-007-$1/$f"; done
	git -C "$integ/.claude/worktrees/orch-007-$1" commit -qam "$1"
}
# $1 기대 끝 코드, $2 설명, $3 출력에 있어야 할 글(없으면 빈칸), 나머지는 check-tangle.sh 인자
try() {
	want=$1 desc=$2 grepfor=$3; shift 3
	out=$(bash "$check" "$@" 2>&1); got=$?
	if [ "$got" = "$want" ] && { [ -z "$grepfor" ] || printf '%s\n' "$out" | grep -qF "$grepfor"; }; then
		echo "통과: $desc"
	else
		echo "실패: $desc (기대 $want '$grepfor', 실제 $got)"; printf '%s\n' "$out" | sed 's/^/    /'; fail=1
	fi
}

task T001 backend/a/src/A.java
task T002 backend/a/src/B.java
try 0 "서로 다른 파일을 고친 두 작업" "꼬임 없음" "$integ" 007 "$integ/.claude/worktrees/orch-007-T001"

echo x >> "$integ/docs/d.md"
try 0 "통합 worktree 의 docs 변경은 보지 않음" "꼬임 없음" "$integ" 007
git -C "$integ" checkout -q -- docs/d.md

echo x > "$integ/backend/a/src/Leak.java"
try 1 "통합 worktree 에 워커가 남긴 파일" "꼬임 1" "$integ" 007
rm "$integ/backend/a/src/Leak.java"

echo x >> "$integ/.claude/worktrees/orch-007-T002/backend/a/src/C.java"
try 1 "합칠 작업 worktree 에 커밋 안 된 변경" "꼬임 3" "$integ" 007 "$integ/.claude/worktrees/orch-007-T002"
task T003 backend/a/src/C.java
try 1 "커밋 안 된 변경과 다른 작업의 커밋이 같은 파일" "꼬임 2: backend/a/src/C.java" "$integ" 007
git -C "$integ/.claude/worktrees/orch-007-T002" checkout -q -- backend/a/src/C.java

task T004 backend/a/src/A.java
try 1 "두 작업이 같은 파일을 커밋" "꼬임 2: backend/a/src/A.java" "$integ" 007

# T001 을 합치면 그 커밋은 통합 worktree 에 있으니 더는 겹침으로 보지 않는다(ORCH-018 처럼 worktree 가 남아도)
git -C "$integ" cherry-pick >/dev/null HEAD.."$(git -C "$integ/.claude/worktrees/orch-007-T001" rev-parse HEAD)"
try 0 "합친 T001 과 남은 T004 가 같은 파일이어도 합친 커밋은 겹침에서 뺌" "꼬임 없음" "$integ" 007

other="$tmp/r/.claude/worktrees/other-integ"
git worktree add -q --detach "$other" HEAD
git -C "$other" worktree add -q --detach "$other/.claude/worktrees/orch-007-T001" HEAD
echo x >> "$other/.claude/worktrees/orch-007-T001/backend/a/src/A.java"
try 0 "다른 통합 worktree 안의 같은 번호 작업은 보지 않음" "꼬임 없음" "$integ" 007

try 2 "인자가 모자람" "" "$integ"
try 0 "다른 이슈 번호의 worktree 는 보지 않음" "꼬임 없음" "$integ" 008

[ $fail -eq 0 ] && echo "모두 통과" || echo "실패 있음"
exit $fail
