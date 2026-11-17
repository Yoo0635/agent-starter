#!/usr/bin/env bash
# pre-push.sh 시험(ORCH-035). 임시 원격·clone 을 만들어 main 으로 push 해 본다.
# 쓰기: bash .claude/skills/orchestrate/pre-push-test.sh
set -u
hook="$(cd "$(dirname "$0")" && pwd)/pre-push.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

git init -q --bare -b main "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/w" 2>/dev/null
cd "$tmp/w"
git config user.email t@t; git config user.name t; git config core.autocrlf false
mkdir -p docs backend/launcher .claude
echo a > docs/a.md; echo a > backend/AGENTS.md; echo a > backend/launcher/A.java; echo a > .claude/x
git add -A; git commit -qm init; git push -q origin HEAD:main
printf '#!/usr/bin/env bash\nexec bash "%s" "$@"\n' "$hook" > .git/hooks/pre-push

export FULL_BUILD_LOCK="$tmp/lock"
# 앞 시험의 커밋을 지우고 파일을 바꿔 push 해 본다. $1 기대(ok·reject), $2 설명, $3 바꿀 파일(빈칸으로 여럿), $4 원격 브랜치
try() {
	git reset -q --hard origin/main
	for f in $3; do echo "$RANDOM" >> "$f"; done; git commit -qam "$2"
	if git push -q origin "HEAD:${4:-main}" 2>/dev/null; then got=ok; else got=reject; fi
	[ "$got" = "$1" ] && echo "통과: $2" || { echo "실패: $2 (기대 $1, 실제 $got)"; fail=1; }
	git fetch -q origin
}

try ok "잠금 없이 문서만 바꾼 push" docs/a.md
try ok "잠금 없이 .claude 만 바꾼 push" .claude/x
try ok "잠금 없이 backend 의 .md 만 바꾼 push" backend/AGENTS.md
try reject "잠금 없이 .md 와 코드를 함께 바꾼 push" "backend/AGENTS.md backend/launcher/A.java"
try reject "잠금 없이 코드를 바꾼 push" backend/launcher/A.java
try ok "잠금 없이 코드를 바꿔 main 아닌 브랜치로 push" backend/launcher/A.java topic

# full-build.sh 가 남기는 잠금처럼 쓴다. 살아 있는 pid 는 이 셸이다
mkdir -p "$FULL_BUILD_LOCK"; echo $$ > "$FULL_BUILD_LOCK/pid"
echo "$PWD/backend build" > "$FULL_BUILD_LOCK/owner"
try ok "이 worktree 의 full-build.sh 가 잠금을 쥔 채 코드 push" backend/launcher/A.java
echo "$tmp/other/backend build" > "$FULL_BUILD_LOCK/owner"
try reject "다른 worktree 가 쥔 잠금으로 코드 push" backend/launcher/A.java
echo "$PWD/backend build" > "$FULL_BUILD_LOCK/owner"; echo 999999 > "$FULL_BUILD_LOCK/pid"
try reject "죽은 실행이 남긴 잠금으로 코드 push" backend/launcher/A.java

[ $fail -eq 0 ] && echo "모두 통과" || echo "실패 있음"
exit $fail
