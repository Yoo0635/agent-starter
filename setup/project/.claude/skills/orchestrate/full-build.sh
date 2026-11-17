#!/usr/bin/env bash
# 전체 시험(./gradlew build·test)을 이 기기 전체에서 한 번에 하나만 돌린다(ORCH-022).
# 다른 오케스트레이션이 돌리는 중이면 끝날 때까지 기다린 뒤 돌린다.
# 쓰기: cd <worktree>/backend && bash <레포 루트>/.claude/skills/orchestrate/full-build.sh [--push | --measure | --batch] <로그 경로> [gradle 작업…]
#   gradle 작업을 비우면 build. 로그 첫 줄에 잠금을 기다린 초를, 끝 줄에 `EXIT <코드>`를, 그 앞 줄에 할 일 `다음:`을 적는다.
#   gradle 이 실패하면 `EXIT` 앞에 `실패 요약:` 과 실패한 작업·컴파일 오류·시험 줄을 적고 화면에도 보인다(ORCH-045).
# 잠금은 ~/.workbench/full-build.lock 폴더다. 잡은 프로세스가 죽었거나 90분이 넘었으면 버려진 것으로 보고 지운다.
#   끝날 때는 잠금의 pid 가 이 실행일 때만 지운다(ORCH-022 덧붙임).
# gradle 은 `--continue` 로 불러 시험이 실패해도 다른 모듈 시험까지 끝까지 돈다(ORCH-024). 실패한 작업에 의존하는 작업은 여전히 건너뛴다.
# --push 를 주면 잠금을 잡은 뒤 origin/main 으로 rebase 하고, 빌드가 통과하면 잠금을 쥔 채 main 에 push 한다(ORCH-025).
#   빌드하는 동안 다른 오케스트레이션의 코드가 main 에 들어오지 못하니, rebase 때문에 다시 빌드할 일이 없다.
#   이슈의 --push 는 module-tests.sh 가 고른 좁은 시험만 준다. rebase 로 main 코드가 들어와도 넓히지 않는다(ORCH-059).
#   --push 에 작업이 없으면 build 로 넓히지 않고 2 로 거절한다. 문서만 바뀌었으면 help 를 준다(ORCH-065).
#   HEAD 가 이미 origin/main 에 들어 있으면 빌드하지 않고 `이미 main 에 있음` 을 적고 0 으로 끝낸다(ORCH-028).
#   rebase 뒤 이 실행이 새로 더한 백로그 파일 번호가 main 과 겹치면 그 자리에서 다음 번호로 바꿔 커밋한다(ORCH-052).
#   끝 코드: 0 push 함, 3 rebase 실패(되돌림), 4 바꿀 수 없는 백로그 번호 겹침·옛 형식 파일 섞임, 5 fetch 실패·push 거절, 그 밖은 gradle 끝 코드.
# 같은 worktree 에서 이 스크립트가 이미 돌거나 잠금을 기다리는 중이면 로그를 건드리지 않고 6 으로 바로 끝낸다(ORCH-028).
# --batch 는 하루 1~2번 도는 묶음 전체 빌드다(ORCH-059). origin/main 으로 옮겨 build 를 돌리고
#   결과를 ~/.workbench/batch-status 에 `ok|fail <짧은 해시> <로그> <시각>` 한 줄로 남긴다. 작업은 주지 않는다.
# 실행이 끝날 때마다 ~/.workbench/build-times.tsv(FULL_BUILD_TIMES 로 바꾼다)에 탭으로 나눈 한 줄을 덧붙인다(ORCH-086):
#   끝난 시각, worktree 폴더, 모드(push|measure|batch|plain), 잠금 대기 초, gradle 이 돈 초, EXIT 코드, gradle 작업. 쓰기가 실패해도 끝 코드는 그대로다.
# --measure 는 전후 측정(ORCH-039)이다. 잠금 안에 measure 표시를 두어, 워커가 wait-measure.sh 로 DB 시험을 미루게 한다(ORCH-042).

push=
measure=
batch=
[ "$1" = --push ] && { push=1; shift; }
[ "$1" = --measure ] && { measure=1; shift; }
[ "$1" = --batch ] && { batch=1; shift; }
mode=plain
[ -z "$push" ] || mode=push
[ -z "$measure" ] || mode=measure
[ -z "$batch" ] || mode=batch
log=$1
shift
usage="쓰기: full-build.sh [--push | --measure | --batch] <로그 경로> [gradle 작업…]"
[ -n "$log" ] || { echo "$usage" >&2; exit 2; }
[ -z "$batch" ] || [ $# -eq 0 ] || { echo "--batch 는 작업을 받지 않는다. $usage" >&2; exit 2; }
[ -z "$push" ] || [ $# -gt 0 ] || { echo "--push 는 module-tests.sh 가 고른 작업을 받는다(문서만 바뀌었으면 help, ORCH-065). $usage" >&2; exit 2; }
[ $# -gt 0 ] || set -- build

# killed 알림 뒤에도 Windows 에서는 앞 실행이 살아 있을 수 있어 worktree 마다 pid 를 남긴다
mine="$(git rev-parse --absolute-git-dir)/full-build.pid"
other=$(cat "$mine" 2>/dev/null)
if [ -n "$other" ] && kill -0 "$other" 2>/dev/null; then
	echo "이 worktree 에서 full-build.sh 가 이미 돈다(pid $other). 그 로그의 EXIT 줄을 기다려라" >&2
	exit 6
fi
echo $$ > "$mine"
trap 'rm -f "$mine"' EXIT

# --push 는 모듈 시험 전체를 돌지 않는다(ORCH-088). --tests 가 붙지 않은 시험 작업(test·:<모듈>:test·testOther…)과 build·check 는
#   module-tests.sh 가 test(빌드 설정이 바뀜)를 고른 때만 받는다. 컴파일과 --tests 로 클래스를 지정한 작업은 받는다
if [ -n "$push" ]; then
	wide=
	prev=
	for a in "$@" ""; do
		[ -n "$prev" ] && [ "$a" != --tests ] && wide="$wide $prev"
		prev=
		echo "$a" | grep -qE '^(:.*:)?(test|testMariadb|testPostgresql|testOther|build|check)$' && prev=$a
	done
	if [ -n "$wide" ] && ! bash "$(cd "$(dirname "$0")" && pwd)/module-tests.sh" 2>/dev/null | grep -qx test; then
		echo "--push 는 모듈 시험 전체를 돌지 않는다:$wide 에 --tests 가 없다. 첫 실행은 module-tests.sh 가 고른 작업을, 실패 뒤에는 compileJava compileTestJava 와 실패한 클래스(<작업> --tests '<클래스>')만 준다(ORCH-079·088). $usage" >&2
		exit 2
	fi
fi

# FULL_BUILD_LOCK 은 이 스크립트를 시험할 때만 준다
lock="${FULL_BUILD_LOCK:-$HOME/.workbench/full-build.lock}"
mkdir -p "$(dirname "$lock")" "$(dirname "$log")"

start=$(date +%s)
said=
until mkdir "$lock" 2>/dev/null; do
	pid=$(cat "$lock/pid" 2>/dev/null)
	since=$(cat "$lock/since" 2>/dev/null)
	# pid 를 쓰기 전의 잠금은 막 잡힌 것이라 건드리지 않는다
	if [ -n "$pid" ] && { ! kill -0 "$pid" 2>/dev/null || [ $(( $(date +%s) - since )) -gt 5400 ]; }; then
		rm -rf "$lock"
		continue
	fi
	[ -n "$said" ] || { echo "전체 시험 잠금 대기: $(cat "$lock/owner" 2>/dev/null)"; said=1; }
	sleep 10
done
echo $$ > "$lock/pid"
# 잠금은 아직 이 실행 것일 때만 푼다. 남이 지우고 다시 잡은 잠금을 끝날 때 지우면 그 실행이 도는데 다음 실행이 들어온다
trap '[ "$(cat "$lock/pid" 2>/dev/null)" = $$ ] && rm -rf "$lock"; rm -f "$mine"' EXIT
date +%s > "$lock/since"
echo "$PWD $*" > "$lock/owner"
[ -z "$measure" ] || : > "$lock/measure"

waited=$(( $(date +%s) - start ))
tasks=$*
gradle_start=
gradle_secs=0
echo "전체 시험 잠금 대기 ${waited}초" > "$log"

# 끝 코드마다 orchestrator 가 할 일을 `다음:` 한 줄로 남긴다. orchestrator.md 는 끝 코드별 처리를 이 줄에 맡긴다
next() {
	if [ -n "$batch" ]; then
		if [ "$1" = 0 ]; then echo "다음: 끝났다. 묶음 전체 빌드 통과"
		else echo "다음: 묶음 전체 빌드 실패. 시험·컴파일 실패 줄이 없으면 같은 명령을 한 번만 다시 돌리고, 있으면 실패 요약을 사용자에게 알린다. 고칠 때까지 오케스트레이션은 마지막 4번 push 전에 멈춘다"; fi
		return
	fi
	case $1 in
	0) if grep -q '^백로그 번호 바꿈:' "$log"; then echo "다음: 끝났다. 백로그 번호 바꿈 줄의 새 번호로 worklog 를 고치고 보고로 간다"
		elif [ -n "$push" ]; then echo "다음: 끝났다. 보고로 간다"; fi ;;
	3) echo "다음: 통합 worktree 에서 origin/main 위로 충돌을 풀고(코드를 고쳐야 하면 fixN) 다시 --push 로 돈다" ;;
	4) echo "다음: 위 겹침 줄을 보고 겹친 번호를 그 도메인의 tasks/·completed/ 통틀어 가장 큰 번호+1 로 바꾸거나 옛 형식 파일을 tasks/<도메인>/ 로 옮겨 커밋하고 다시 --push 로 돈다" ;;
	5) echo "다음: 다시 --push 로 돈다" ;;
	*) if ! grep -qE 'tests completed, [0-9]+ failed|compile(Test)?Java FAILED' "$log"; then
			echo "다음: 시험·컴파일 실패 줄이 없으니 실행 환경 실패다. 같은 명령을 한 번만 다시 돌린다"
		elif [ -n "$push" ]; then
			echo "다음: 실패 요약의 시험·컴파일 오류만 fixN 으로 나눠 고쳐 가져온 뒤, 같은 worktree 에서 compileJava compileTestJava 와 실패한 클래스만(<작업> --tests '<클래스>') 다시 --push 로 돈다. 컴파일 오류였어도 module-tests.sh 로 다시 고르지 않는다(ORCH-079·088, clean·--rerun 없이)"
		else
			echo "다음: 실패 요약의 시험·컴파일 오류만 fixN 으로 나눠 고쳐 가져온다. 마지막 4번 전체 빌드가 다시 확인한다"
		fi ;;
	esac
}
finish() {
	next "$1" >> "$log"
	echo "EXIT $1" >> "$log"
	# 실행마다 시간 한 줄(ORCH-086). 쓰기가 실패해도 끝 코드는 바뀌지 않는다
	{
		times="${FULL_BUILD_TIMES:-$HOME/.workbench/build-times.tsv}"
		mkdir -p "$(dirname "$times")"
		[ -s "$times" ] || printf '끝난 시각\tworktree\t모드\t대기초\tgradle초\tEXIT\t작업\n' > "$times"
		printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$(basename "$(git rev-parse --show-toplevel)")" "$mode" \
			"$waited" "$gradle_secs" "$1" "$(printf '%s' "$tasks" | tr '\t\n' '  ')" >> "$times"
	} 2>/dev/null || true
	if grep -q '^실패 요약:$' "$log"; then sed -n '/^실패 요약:$/,$p' "$log"; else tail -4 "$log"; fi
	exit "$1"
}
# $1..$2 사이 main 커밋이 backend 의 .md 아닌 파일(코드·빌드 설정)을 바꿨는지
code_changed() {
	[ -n "$(git diff --name-only "$1" "$2" -- ':(top)backend' ':(top,exclude,glob)backend/**/*.md')" ]
}

if [ -n "$push" ]; then
	before=$(git rev-parse --short HEAD)
	git fetch -q origin >> "$log" 2>&1 || { echo "fetch 실패" >> "$log"; finish 5; }
	if git merge-base --is-ancestor HEAD origin/main; then
		echo "이미 main 에 있음: $before" >> "$log"
		finish 0
	fi
	base=$(git merge-base HEAD origin/main)
	if ! git rebase -q origin/main >> "$log" 2>&1; then
		git rebase --abort 2>/dev/null
		echo "rebase 실패: origin/main $(git rev-parse --short origin/main) 위로 올리지 못해 되돌렸다" >> "$log"
		finish 3
	fi
	echo "rebase $before → $(git rev-parse --short HEAD)" >> "$log"
	backlog="$(git rev-parse --show-toplevel)/docs/backlog"
	# 도메인 폴더(tasks/<도메인>/)가 있는 트리에 옛 형식 task-N 파일이 남았으면 번호 체계가 섞인 것이다
	old=$(ls "$backlog/tasks" "$backlog/completed" 2>/dev/null | grep -m1 '^task-[0-9][0-9]* - ')
	if [ -n "$old" ] && [ -n "$(ls -d "$backlog"/tasks/*/ "$backlog"/completed/*/ 2>/dev/null)" ]; then
		echo "옛 형식 백로그 파일: $old — tasks/<도메인>/ 로 옮기고 도메인 번호를 다시 매겨라" >> "$log"; finish 4
	fi
	# 같은 id(task-N 또는 <접두>-N)가 두 파일에 있으면 겹침이다. 옛 구조는 tasks/·completed/ 바로 아래, 새 구조는 도메인 폴더 아래를 본다
	dups() { ls "$backlog/tasks" "$backlog/completed" "$backlog"/tasks/*/ "$backlog"/completed/*/ 2>/dev/null | sed -n 's/^\([a-z][a-z]*-[0-9][0-9]*\) - .*/\1/p' | sort | uniq -d; }
	# 겹친 것이 이 실행이 새로 더한 도메인 폴더 파일이면 잠금 안에서 그 도메인의 가장 큰 번호+1 로 바로 바꾼다(ORCH-052).
	# 잠금 밖에서 바꾸면 다시 잠금을 기다리는 사이 다른 카드가 그 번호를 또 가져갔다
	top=$(git rev-parse --show-toplevel)
	added=$(git -c core.quotepath=false diff --name-only --diff-filter=A origin/main HEAD -- "$backlog")
	others=$(git -c core.quotepath=false diff --name-only --diff-filter=M origin/main HEAD -- "$backlog")
	moved=; mine=
	for id in $(dups); do
		f=$(echo "$added" | grep -E "^docs/backlog/(tasks|completed)/[^/]+/$id - ")
		ID=$(echo "$id" | tr a-z A-Z)
		if [ -z "$f" ] || [ "$(echo "$f" | wc -l)" -ne 1 ]; then
			echo "백로그 번호 겹침: $id — 이 실행이 새로 더한 파일이 아니다" >> "$log"; finish 4
		fi
		# 이 실행이 고친 남의 파일이 옛 번호를 가리킬 때, main 판에 그 번호가 없으면 그 줄은 모두 이 실행 것이라 같이 바꾼다.
		# main 판에도 있으면 그 줄이 누구 것인지 스크립트가 가를 수 없다
		ref=$(echo "$others" | while read -r o; do [ -n "$o" ] && grep -qE "(^|[^0-9A-Za-z])$ID([^0-9]|$)" "$top/$o" && echo "$o"; done)
		bad=$(echo "$ref" | while read -r o; do [ -n "$o" ] && git -C "$top" show "origin/main:$o" 2>/dev/null | grep -qE "(^|[^0-9A-Za-z])$ID([^0-9]|$)" && echo "$o"; done)
		[ -z "$bad" ] || { echo "백로그 번호 겹침: $id — 이 실행이 고친 $bad 가 main 판에서도 $ID 를 가리킨다" >> "$log"; finish 4; }
		mine="$mine
$ref"
		dir=$(dirname "$f"); dom=$(basename "$dir"); pre=${id%-*}
		max=$(ls "$backlog/tasks/$dom" "$backlog/completed/$dom" 2>/dev/null | sed -n "s/^$pre-\([0-9][0-9]*\) - .*/\1/p" | sort -n | tail -1)
		new="$pre-$((max + 1))"; NEW=$(echo "$new" | tr a-z A-Z)
		nf="$dir/$new${f#"$dir/$id"}"
		git -C "$top" mv "$f" "$nf"
		added=$(echo "$added" | sed "s|^$f\$|$nf|")
		# 이 실행이 새로 더한 파일 안의 옛 id(머리의 id: 줄, 짝 항목을 가리키는 줄)와 위에서 가른 고친 파일의 옛 id 는 모두 이 실행의 것이다
		printf '%s\n%s\n' "$added" "$ref" | while read -r m; do
			[ -n "$m" ] && sed -i -E "s/(^|[^0-9A-Za-z])$ID([^0-9]|$)/\1$NEW\2/g" "$top/$m"
		done
		moved="$moved $ID→$NEW"
	done
	if [ -n "$moved" ]; then
		printf '%s\n%s\n' "$added" "$mine" | while read -r m; do [ -n "$m" ] && git -C "$top" add "$m"; done
		git commit -q -m "docs(backlog): 겹친 백로그 번호를 바꾼다 ($(echo $moved | sed 's/ /, /g'))" >> "$log" 2>&1
		echo "백로그 번호 바꿈:$moved ($(git rev-parse --short HEAD))" >> "$log"
	fi
	[ -z "$(dups)" ] || { echo "백로그 번호 겹침: $(dups | tr '\n' ' ')" >> "$log"; finish 4; }
	# 좁게 돌릴 때 rebase 로 들어온 main 코드는 넓혀 시험하지 않는다. 합친 상태 전체는 묶음 빌드가 본다(ORCH-059)
	if [ "$*" != build ] && code_changed "$base" origin/main; then
		echo "rebase 로 main 코드가 들어왔지만 '$*' 그대로 돈다(묶음 빌드가 본다)" >> "$log"
	fi
fi
if [ -n "$batch" ]; then
	{ git fetch -q origin && git checkout -q --detach origin/main; } >> "$log" 2>&1 || { echo "fetch·checkout 실패" >> "$log"; finish 5; }
	echo "묶음 빌드 $(git rev-parse --short HEAD)" >> "$log"
fi

# gradle 실패 때 실패한 작업·컴파일 오류·시험만 몇 줄로 뽑는다(ORCH-045). 시험은 이번 실행이 쓴 결과 XML만 본다
failures() {
	grep -E '^> Task .* FAILED$|\.java:[0-9]+: error:' "$log" | head -10
	find . -path '*/build/test-results/*' -name 'TEST-*.xml' -newer "$started" -exec awk '
		/<testcase / { match($0, / name="[^"]*"/); n = substr($0, RSTART + 7, RLENGTH - 8)
			match($0, / classname="[^"]*"/); c = substr($0, RSTART + 12, RLENGTH - 13); sub(/.*\./, "", c) }
		/<(failure|error) / { m = ""; if (match($0, / message="[^"]*"/)) m = substr($0, RSTART + 10, RLENGTH - 11)
			gsub(/&#10;/, " ", m); gsub(/&quot;/, "\"", m); gsub(/&lt;/, "<", m); gsub(/&gt;/, ">", m); gsub(/&amp;/, "\\&", m)
			print c "." n ": " substr(m, 1, 150) }
	' {} + | head -20
}
started=$(mktemp)

# 앞에서 기다리면 bash 가 신호를 받아도 gradle 이 끝날 때까지 trap 을 미루니, 뒤에 띄우고 wait 한다
gradle_start=$(date +%s)
./gradlew --continue "$@" >> "$log" 2>&1 &
gradle=$!
trap 'kill "$gradle" 2>/dev/null; exit 143' TERM INT HUP
wait "$gradle"
code=$?
gradle_secs=$(( $(date +%s) - gradle_start ))

if [ $code -ne 0 ]; then
	summary=$(failures)
	# 뽑을 줄이 없으면 시험 워커가 죽은 것 같은 실행 환경 실패다. 원인이 보이게 로그 끝을 붙인다
	[ -n "$summary" ] || summary="(실패한 작업·시험 줄 없음, 로그 끝 5줄)
$(tail -5 "$log")"
	printf '실패 요약:\n%s\n' "$summary" >> "$log"
fi
rm -f "$started"
if [ -n "$batch" ]; then
	echo "$([ $code -eq 0 ] && echo ok || echo fail) $(git rev-parse --short HEAD) $log $(date '+%Y-%m-%dT%H:%M')" > "${BATCH_STATUS:-$HOME/.workbench/batch-status}"
fi

if [ $code -eq 0 ] && [ -n "$push" ]; then
	if ! git push -q origin HEAD:main >> "$log" 2>&1; then
		# 잠금 없이 누가 push 했다. 문서뿐이면 그 위로 올려 다시 push 하고, 코드면 다시 빌드해야 한다
		built=$(git rev-parse --short HEAD)
		git fetch -q origin >> "$log" 2>&1
		if code_changed "$(git merge-base HEAD origin/main)" origin/main \
			|| ! git rebase -q origin/main >> "$log" 2>&1 \
			|| ! git push -q origin HEAD:main >> "$log" 2>&1; then
			git rebase --abort 2>/dev/null
			echo "push 거절: 빌드한 $built 뒤 main 에 코드가 들어왔거나 다시 올리지 못했다" >> "$log"
			finish 5
		fi
	fi
	echo "push $(git rev-parse --short HEAD) → main" >> "$log"
fi
finish $code
