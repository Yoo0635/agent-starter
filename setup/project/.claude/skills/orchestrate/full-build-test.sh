#!/usr/bin/env bash
# full-build.sh --push 의 백로그 번호 바꾸기 시험(ORCH-052). 임시 원격·clone 두 개와 가짜 gradlew 로 돈다.
# 쓰기: bash .claude/skills/orchestrate/full-build-test.sh
set -u
script="$(cd "$(dirname "$0")" && pwd)/full-build.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export FULL_BUILD_LOCK="$tmp/lock"
export FULL_BUILD_TIMES="$tmp/times.tsv"
fail=0
P=docs/backlog/tasks/project

# 원격과, 이 카드(w)·다른 카드(o) clone 을 새로 만든다
setup() {
	rm -rf "$tmp/origin.git" "$tmp/w" "$tmp/o"
	git init -q --bare -b main "$tmp/origin.git"
	git clone -q "$tmp/origin.git" "$tmp/w" 2>/dev/null
	cd "$tmp/w"
	git config user.email t@t; git config user.name t; git config core.autocrlf false
	mkdir -p "$P" docs/backlog/completed/project backend
	printf '#!/bin/sh\nexit 0\n' > backend/gradlew
	printf -- '---\nid: PRJ-46\n---\n' > "$P/prj-46 - 앞-항목.md"
	git add -A; git commit -qm init; git push -q origin HEAD:main
	git clone -q -c core.autocrlf=false "$tmp/origin.git" "$tmp/o" 2>/dev/null
	git -C "$tmp/o" config user.email t@t; git -C "$tmp/o" config user.name t
}
# $1 clone, $2 번호, $3 이름, $4 본문 한 줄
item() { printf -- '---\nid: PRJ-%s\n---\n%s\n' "$2" "$4" > "$1/$P/prj-$2 - $3.md"; }
run() { (cd "$tmp/w/backend" && bash "$script" --push "$tmp/full.log" help >/dev/null 2>&1); echo $?; }
check() { if [ "$2" = "$3" ]; then echo "통과: $1"; else echo "실패: $1 (기대 $2, 실제 $3)"; fail=1; fi; }
on_main() { git -C "$tmp/w" fetch -q origin; git -C "$tmp/w" show "origin/main:$P/$1" 2>/dev/null; }

setup
item "$tmp/o" 47 남-판정 "남의 일"; item "$tmp/o" 48 남-Minor "남의 Minor"
git -C "$tmp/o" add -A; git -C "$tmp/o" commit -qm other; git -C "$tmp/o" push -q origin HEAD:main
item "$tmp/w" 47 이번-판정 "보류는 PRJ-48 에 둔다"; item "$tmp/w" 48 이번-Minor "이번 Minor"
git add -A; git commit -qm mine
check "겹친 두 번호를 바꿔 push" 0 "$(run)"
check "판정 항목이 PRJ-49 가 됨" "id: PRJ-49" "$(on_main 'prj-49 - 이번-판정.md' | grep '^id:')"
check "Minor 항목이 PRJ-50 이 됨" "id: PRJ-50" "$(on_main 'prj-50 - 이번-Minor.md' | grep '^id:')"
check "짝을 가리키는 줄도 새 번호" "보류는 PRJ-50 에 둔다" "$(on_main 'prj-49 - 이번-판정.md' | tail -1)"
check "남의 항목은 그대로" "id: PRJ-47" "$(on_main 'prj-47 - 남-판정.md' | grep '^id:')"
check "바꾼 줄이 로그에 남음" 1 "$(grep -c '^백로그 번호 바꿈: PRJ-47→PRJ-49 PRJ-48→PRJ-50' "$tmp/full.log")"

setup
item "$tmp/o" 47 남-판정 "남의 일"
git -C "$tmp/o" add -A; git -C "$tmp/o" commit -qm other; git -C "$tmp/o" push -q origin HEAD:main
item "$tmp/w" 47 이번-판정 "이번 일"; echo "- [ ] 이어서 PRJ-47 에 적음" >> "$P/prj-46 - 앞-항목.md"
git add -A; git commit -qm mine
check "고친 남의 파일이 옛 번호를 가리켜도 main 판에 없으면 바꿔 push" 0 "$(run)"
check "고친 남의 파일의 줄도 새 번호" "- [ ] 이어서 PRJ-48 에 적음" "$(on_main 'prj-46 - 앞-항목.md' | tail -1)"

setup
item "$tmp/o" 47 남-판정 "남의 일"; sed -i '1a 남이 PRJ-47 을 가리킴' "$tmp/o/$P/prj-46 - 앞-항목.md"
git -C "$tmp/o" add -A; git -C "$tmp/o" commit -qm other; git -C "$tmp/o" push -q origin HEAD:main
item "$tmp/w" 47 이번-판정 "이번 일"; echo "- [ ] 이어서 PRJ-47 에 적음" >> "$P/prj-46 - 앞-항목.md"
git add -A; git commit -qm mine
check "고친 남의 파일이 main 판에서도 옛 번호를 가리키면 멈춤" 4 "$(run)"

setup
item "$tmp/w" 47 이번-판정 ""
git add -A; git commit -qm mine
check "겹치지 않으면 그대로 push" 0 "$(run)"
check "번호 바꾸기 커밋 없음" 0 "$(grep -c '^백로그 번호 바꿈' "$tmp/full.log")"

# 도는 동안 잠금이 남(이 시험 셸)에게 넘어가면 끝날 때 그 잠금을 지우지 않는다(ORCH-022 덧붙임)
setup
printf '#!/bin/sh\nsleep 3\n' > backend/gradlew
(cd backend && bash "$script" "$tmp/own.log" >/dev/null 2>&1) &
until [ -s "$FULL_BUILD_LOCK/pid" ]; do sleep 0.2; done
rm -rf "$FULL_BUILD_LOCK"; mkdir "$FULL_BUILD_LOCK"; echo $$ > "$FULL_BUILD_LOCK/pid"
wait
check "끝난 실행이 남의 잠금을 지우지 않음" "$$" "$(cat "$FULL_BUILD_LOCK/pid" 2>/dev/null)"
rm -rf "$FULL_BUILD_LOCK"

# 좁힌 시험으로 --push 할 때 rebase 로 main 코드가 들어와도 build 로 넓히지 않는다(ORCH-059). 전체는 묶음 빌드가 본다
setup
printf '#!/bin/sh\necho "$@" > "%s"\n' "$tmp/args" > backend/gradlew
git add -A; git commit -qm gradlew; git push -q origin HEAD:main
git -C "$tmp/o" pull -q origin main
echo x > "$tmp/o/backend/Other.java"; git -C "$tmp/o" add -A; git -C "$tmp/o" commit -qm other; git -C "$tmp/o" push -q origin HEAD:main
echo y > backend/Mine.java; git add -A; git commit -qm mine
check "rebase 로 코드가 들어와도 좁힌 시험으로 push" 0 "$( (cd "$tmp/w/backend" && bash "$script" --push "$tmp/full.log" :services:task:test >/dev/null 2>&1); echo $?)"
check "gradle 에 넘긴 작업이 그대로" "--continue :services:task:test" "$(cat "$tmp/args")"
# 작업 없는 --push 는 build 로 넓히지 않고 거절한다(ORCH-065)
check "--push 에 작업이 없으면 거절" 2 "$( (cd "$tmp/w/backend" && bash "$script" --push "$tmp/full.log" >/dev/null 2>&1); echo $?)"

# --push 는 --tests 없는 모듈 시험·build 를 거절한다. 빌드 설정이 바뀐 때(module-tests.sh 가 test)만 받는다(ORCH-088)
setup
printf '#!/bin/sh\necho "$@" > "%s"\n' "$tmp/args" > backend/gradlew
git add -A; git commit -qm gradlew; git push -q origin HEAD:main
mkdir -p backend/services/task/src/main; echo y > backend/services/task/src/main/A.java; git add -A; git commit -qm mine
pushed() { (cd "$tmp/w/backend" && bash "$script" --push "$tmp/full.log" "$@" >/dev/null 2>&1); echo $?; }
check "--tests 없는 모듈 시험은 거절" 2 "$(pushed :services:task:test)"
check "build 도 거절" 2 "$(pushed build)"
check "방언 작업도 --tests 없으면 거절" 2 "$(pushed compileJava :launcher:testOther)"
check "컴파일과 실패한 클래스만은 돎" 0 "$(pushed compileJava compileTestJava :services:task:testOther --tests '*XTest')"
check "gradle 에 그대로 넘김" "--continue compileJava compileTestJava :services:task:testOther --tests *XTest" "$(cat "$tmp/args")"

# --batch 는 origin/main 으로 옮겨 build 를 돌리고 결과를 상태 파일에 남긴다(ORCH-059)
export BATCH_STATUS="$tmp/batch-status"
batch() { (cd "$tmp/w/backend" && bash "$script" --batch "$tmp/batch.log" >/dev/null 2>&1); echo $?; }
setup
printf '#!/bin/sh\necho "$@" > "%s"\n' "$tmp/args" > backend/gradlew
git add -A; git commit -qm gradlew; git push -q origin HEAD:main
git -C "$tmp/o" pull -q origin main
echo x > "$tmp/o/backend/Other.java"; git -C "$tmp/o" add -A; git -C "$tmp/o" commit -qm other; git -C "$tmp/o" push -q origin HEAD:main
check "묶음 빌드 통과" 0 "$(batch)"
check "묶음 빌드가 origin/main 을 빌드함" "$(git -C "$tmp/o" rev-parse --short HEAD)" "$(git -C "$tmp/w" rev-parse --short HEAD)"
check "묶음 빌드는 build" "--continue build" "$(cat "$tmp/args")"
check "통과를 상태 파일에 적음" "ok $(git -C "$tmp/o" rev-parse --short HEAD)" "$(cut -d' ' -f1-2 "$BATCH_STATUS")"
printf '#!/bin/sh\nexit 1\n' > "$tmp/w/backend/gradlew"
check "묶음 빌드 실패" 1 "$(batch)"
check "실패를 상태 파일에 적음" fail "$(cut -d' ' -f1 "$BATCH_STATUS")"
check "실패 다음 줄은 사용자에게 알리기" 1 "$(grep -c '^다음: 묶음 전체 빌드 실패' "$tmp/batch.log")"
check "--batch 에 작업을 주면 거절" 2 "$( (cd "$tmp/w/backend" && bash "$script" --batch "$tmp/batch.log" test >/dev/null 2>&1); echo $?)"

# 실행마다 시간 한 줄을 남긴다(ORCH-086). 머리 줄, 7칸, 모드·EXIT·작업. 쓰기가 실패해도 끝 코드는 그대로다
setup
rm -f "$FULL_BUILD_TIMES"
printf '#!/bin/sh\nexit 0\n' > backend/gradlew
(cd backend && bash "$script" "$tmp/t.log" :a:test --tests 'x.Y' >/dev/null 2>&1)
check "시간 파일에 머리 줄과 한 줄" 2 "$(wc -l < "$FULL_BUILD_TIMES" | tr -d ' ')"
row=$(tail -1 "$FULL_BUILD_TIMES")
check "시간 줄은 7칸" 7 "$(echo "$row" | awk -F'\t' '{print NF}')"
# 대기·gradle 초는 기기가 바쁘면 1 이 되기도 해서 숫자인지만 본다
check "시간 줄: worktree 폴더·모드·대기·gradle·EXIT·작업" "w|plain|N|N|0|:a:test --tests x.Y" "$(echo "$row" | awk -F'\t' '{ d = ($4 ~ /^[0-9]+$/) ? "N" : $4; g = ($5 ~ /^[0-9]+$/) ? "N" : $5; print $2 "|" $3 "|" d "|" g "|" $6 "|" $7 }')"
printf '#!/bin/sh\nexit 1\n' > backend/gradlew
(cd backend && bash "$script" --measure "$tmp/t.log" :b:test >/dev/null 2>&1)
check "머리 줄은 한 번만" 3 "$(wc -l < "$FULL_BUILD_TIMES" | tr -d ' ')"
check "실패 실행: 모드 measure, EXIT 1" "measure|1|:b:test" "$(tail -1 "$FULL_BUILD_TIMES" | awk -F'\t' '{print $3 "|" $6 "|" $7}')"
check "시간 파일을 못 써도 gradle 끝 코드 그대로" 1 "$(cd backend && FULL_BUILD_TIMES="$tmp/t.log/x/times.tsv" bash "$script" "$tmp/t2.log" :c:test >/dev/null 2>&1; echo $?)"

exit $fail
