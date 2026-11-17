#!/usr/bin/env bash
# 이슈가 바꾼 코드로 push 전에 돌릴 gradle 작업을 한 줄에 하나씩 찍는다(ORCH-059). 전체 시험은 묶음 빌드·CINX 가 한다.
# 쓰기: cd <worktree>/backend && mapfile -t t < <(bash <레포 루트>/.claude/skills/orchestrate/module-tests.sh)
#   비교 시작점은 받지 않고 HEAD 가 origin/main 에서 갈라진 곳(merge-base)을 매번 찾는다. rebase 로 기준이 옮겨 가도
#   그 사이 main 에 들어온 남의 이슈 파일이 섞이지 않는다(ORCH-068). 옛 지침대로 <START> 를 줘도 쓰지 않는다.
#   그다음 full-build.sh --push <로그> "${t[@]}". 찍은 것이 없으면(문서만 바뀜) 시험 없이 push 한다.
# 모듈 시험 전체(--tests 없는 :test)는 고르지 않는다(ORCH-088). build-logic·gradle·루트 빌드 파일이 바뀌었을 때만 test(모든 모듈)다.
# 고르는 법(merge-base..HEAD 의 backend 파일, .md 빼고):
#   닿은 모듈: 바뀐 모듈, 그리고 src/test 밖이 바뀐 모듈을 project(...) 로 쓰는 모듈(되풀이). 서비스가 닿으면 launcher 도 닿는다
#   닿은 모듈마다 시험 클래스를 --tests 로 고른다:
#     그 모듈의 바뀐 시험 클래스(*Test·*Tests)
#     바뀐 패키지(어느 모듈이든 src/main·testFixtures 의 바뀐 .java, 그 모듈 src/test 의 시험 이름이 아닌 바뀐 .java)에 있거나 그것을 import 하는 시험
#     src/test 밖이 바뀐 서비스는 그 서비스의 *ArchTest. launcher 는 늘 *ArchTest·계약 시험(net.spacenx.work.contract.*)
#   고른 시험이 없으면 :compileTestJava 만. resources·빌드 파일만 바뀐 모듈도 그렇다. 나머지는 묶음 빌드·CINX 가 본다
#   시험이 읽지 않는 파일은 뺀다: backend 최상위 Dockerfile·.dockerignore·compose.yaml·compose.fake-sso.yaml·.env.example,
#     docker/·templates/·.claude/ 아래 전부, src/ 밖의 그림 파일(png·svg·jpg·jpeg·gif). 빼고 나서 비면 아무것도 찍지 않는다(ORCH-085).
#     compose.test-db.yaml 은 시험이 읽으니 빼지 않는다(test)
#   주석·빈 줄만 바뀐 파일은 뺀다. 그것뿐이면 launcher *ArchTest·*StructureTest 만(ORCH-085)
#   contracts/transitions/* 와 authz-matrix.csv 는 그 파일 이름이나 상대 경로 <p> 를 담은 모듈(services·libs·gateways·launcher 의 build.gradle.kts·src)만
#     그 모듈의 빌드 파일이 바뀐 것처럼 고른다. 못 찾거나 그 밖의 contracts(samples·consumers.yaml, 폴더째 읽음)면 test(ORCH-085)
#   libs/test-support 시험 기본값(application*.yaml)에서 바뀐 줄이 모두 workbench.<서비스> 칸 안이면 그 서비스 resources 가 바뀐 것처럼(ORCH-087)
set -eu
start=$(git merge-base HEAD origin/main)
cd "$(git rev-parse --show-toplevel)/backend"
files=$(git diff --name-only "$start" HEAD -- . ':(exclude,glob)**/*.md' | sed 's|^backend/||')
[ -n "$files" ] || exit 0

# 주석·빈 줄만 바뀐 파일(java·kts·kt 의 //·/*·*, yaml·properties·sh 의 #)은 시험 결과를 바꾸지 않으니 뺀다(ORCH-085).
# 줄 끝 주석이 붙은 코드 줄, 내용 줄이 없는 변경(이진·이름만 바꿈), .sql(Flyway 체크섬)은 바뀐 것으로 본다.
# 남은 파일이 없으면 소스 글자를 읽는 구조 시험(launcher *ArchTest·*StructureTest)만 돈다
comment_only() {
	case $1 in
	*.java | *.kts | *.kt) re='^[[:space:]]*(//|/\*|\*/|\*([[:space:]]|$))' ;;
	*.yaml | *.yml | *.properties | *.sh) re='^[[:space:]]*#' ;;
	*) return 1 ;;
	esac
	body=$(git diff -U0 "$start" HEAD -- "$1" | awk '/^@@/ { h = 1; next } h && /^[-+]/ { print substr($0, 2) }')
	[ -n "$body" ] || return 1
	! echo "$body" | grep -qvE "$re|^[[:space:]]*\$"
}
cmt=$(echo "$files" | while IFS= read -r f; do if comment_only "$f"; then echo "$f"; fi; done)
if [ -n "$cmt" ]; then
	files=$(echo "$files" | grep -vxF -e "$cmt" || true)
	if [ -z "$files" ]; then
		if echo "$cmt" | grep -qE '\.(java|kts|kt)$'; then printf '%s\n' :launcher:test --tests '*ArchTest' --tests '*StructureTest'; fi
		exit 0
	fi
fi

# 시험이 읽지 않는 파일은 뺀다(ORCH-085). compose.test-db.yaml 은 시험이 읽으니 남긴다
files=$(echo "$files" | awk '
	/^(Dockerfile|\.dockerignore|compose\.yaml|compose\.fake-sso\.yaml|\.env\.example)$/ { next }
	/^(docker|templates|\.claude)\// { next }
	/\.(png|svg|jpg|jpeg|gif)$/ && !/(^|\/)src\// { next }
	{ print }')
[ -n "$files" ] || exit 0

# contracts/<p> 는 그것을 읽는 모듈만. 그 파일 이름이나 상대 경로를 담은 모듈마다 가짜 빌드 파일 경로를 files 에 넣어
# 아래 규칙이 그 모듈의 빌드 파일이 바뀐 것처럼 고르게 한다(가짜 경로는 [ -f ] 를 보는 시험 전용 분기에 들어가지 않는다). 못 찾으면 test
cfiles=$(echo "$files" | grep '^contracts/' || true)
if [ -n "$cfiles" ]; then
	files=$(echo "$files" | grep -v '^contracts/' || true)
	roots=$(for r in services/*/build.gradle.kts services/*/src libs/*/build.gradle.kts libs/*/src gateways/*/build.gradle.kts gateways/*/src launcher/build.gradle.kts launcher/src; do
		[ -e "$r" ] && echo "$r"
	done || true)
	fake=
	while IFS= read -r c; do
		p=${c#contracts/}
		# samples·consumers.yaml 은 ContractSamples 가 폴더째 읽어 이름으로 찾을 수 없다. 이름으로 읽는 전이 표·권한 표만 좁힌다
		case $p in transitions/* | authz-matrix.csv) ;; *) echo test; exit 0;; esac
		hits=
		if [ -n "$roots" ]; then hits=$(grep -rlF -e "$(basename "$p")" -e "$p" $roots 2>/dev/null || true); fi
		[ -n "$hits" ] || { echo test; exit 0; }
		fake=$(printf '%s\n%s\n' "$fake" "$(echo "$hits" | sed -E 's#^((services|libs|gateways)/[^/]+|launcher)/.*#\1/build.gradle.kts#')")
	done <<< "$cfiles"
	files=$(printf '%s\n%s\n' "$files" "$fake" | grep . | sort -u || true)
fi

# test-support 의 시험 기본값(application*.yaml)은 workbench.<서비스> 칸마다 그 서비스 설정이다. 바뀐 줄이 모두 서비스 칸 안이면
# 그 서비스 resources 가 바뀐 것처럼 그 서비스·쓰는 서비스·launcher 의 그 도메인만 고른다. 공통 칸이면 그대로 libs 규칙(전체)(ORCH-087)
# $1 판, $2 파일, $3 줄 번호들(공백으로 나눔) → 그 줄의 칸(서비스 칸 이름, 아니면 '공통'). 주석·빈 줄은 건너뛴다
yaml_sections() {
	MSYS_NO_PATHCONV=1 git show "$1:./$2" 2>/dev/null | awk -v want=" $3 " '
		/^[^ #]/ { top = $0; sub(/:.*/, "", top); sec = "" }
		/^  [^ #]/ { if (top == "workbench") { sec = $0; sub(/^  /, "", sec); sub(/:.*/, "", sec) } }
		index(want, " " NR " ") && $0 !~ /^[[:space:]]*(#|$)/ {
			if (top == "workbench" && sec != "" && $0 ~ /^  /) print sec; else print "공통"
		}'
}
# diff -U0 의 @@ 줄에서 한쪽($1 이 - 면 옛 판, + 면 새 판)의 바뀐 줄 번호
hunk_lines() {
	sed -nE "s/^@@ -([0-9]+)(,([0-9]+))? \\+([0-9]+)(,([0-9]+))? @@.*/\\1 \\3 \\4 \\6/p" | awk -v side="$1" '{
		if (side == "-") { a = $1; n = ($2 == "") ? 1 : $2 } else { a = $3; n = ($4 == "") ? 1 : $4 }
		for (i = 0; i < n; i++) printf "%d ", a + i }'
}
for y in $(echo "$files" | grep -E '^libs/test-support/src/main/resources/application[^/]*\.ya?ml$' || true); do
	hunks=$(git diff -U0 "$start" HEAD -- "$y" | grep '^@@' || true)
	old=$(echo "$hunks" | hunk_lines -)
	new=$(echo "$hunks" | hunk_lines +)
	secs=$({ [ -z "$old" ] || yaml_sections "$start" "$y" "$old"; [ -z "$new" ] || yaml_sections HEAD "$y" "$new"; } | sort -u)
	[ -n "$secs" ] || continue
	echo "$secs" | while read -r s; do [ -d "services/$s" ] || exit 1; done || continue
	files=$({ echo "$files" | grep -vxF "$y" || true; for s in $secs; do echo "services/$s/src/main/resources/application-default.yaml"; done; } | grep . | sort -u)
done

if echo "$files" | grep -qvE '^(services|gateways|launcher|libs)/'; then echo test; exit 0; fi

# 받은 모듈($1 은 services 나 libs)에 같은 종류의 그것을 쓰는 모듈을 더 늘지 않을 때까지 더한다
with_users() {
	k=$1
	s=$2
	while :; do
		more=$(for x in $s; do grep -l "project(\":$k:$x\")" $k/*/build.gradle.kts 2>/dev/null | cut -d/ -f2; done)
		next=$(printf '%s\n%s\n' "$s" "$more" | grep . | sort -u || true)
		[ "$next" = "$s" ] && break
		s=$next
	done
	echo "$s"
}
# 파일 경로를 모듈 폴더(services/X, libs/L, gateways/G, launcher)로
mod_of() { sed -E 's#^launcher/.*#launcher#; s#^((services|libs|gateways)/[^/]+)/.*#\1#'; }
changed=$(echo "$files" | mod_of | sort -u)
# 다른 모듈은 src/test 를 classpath 에 두지 않으니(testFixtures 만 나눈다) src/test 밖이 바뀐 모듈만 쓰는 모듈로 넓힌다(ORCH-078)
visible=$(echo "$files" | grep -vE '^((services|libs|gateways)/[^/]+|launcher)/src/test/' | mod_of | sort -u || true)
libs=$(with_users libs "$(echo "$visible" | sed -n 's|^libs/||p')")
lusers=$(for x in $libs; do grep -l "project(\":libs:$x\")" services/*/build.gradle.kts gateways/*/build.gradle.kts launcher/build.gradle.kts 2>/dev/null; done | sort -u)
services=$(with_users services "$(printf '%s\n%s\n' "$(echo "$visible" | sed -n 's|^services/||p')" \
	"$(echo "$lusers" | sed -n 's|^services/\([^/]*\)/.*|\1|p')" | grep . | sort -u || true)")
mods=$(printf '%s\n' $changed $(for l in $libs; do echo "libs/$l"; done) $(for s in $services; do echo "services/$s"; done) \
	$(echo "$lusers" | sed -n 's|^\(gateways/[^/]*\)/.*|\1|p') | grep . | sort -u || true)
if [ -n "$services" ] || echo "$lusers" | grep -q '^launcher/'; then mods=$(printf '%s\nlauncher\n' "$mods" | grep . | sort -u); fi

pkgs=$(echo "$files" | sed -nE 's#^((services|libs|gateways)/[^/]+|launcher)/src/(main|testFixtures)/java/(.*)/[^/]+\.java$#\4#p' | tr / . | sort -u)
# $1 시험 폴더(src/test/java)에서 $2 패키지(줄마다 하나)에 있거나(경로로 본다) 그 클래스를 import 하는 시험 클래스(*Test·*Tests) 이름.
# 하위 패키지는 다른 패키지다
tests_of() {
	[ -d "$1" ] && [ -n "$2" ] || return 0
	re=$(echo "$2" | sed 's/\./\\./g' | paste -sd'|')
	{
		find "$1" \( -name '*Test.java' -o -name '*Tests.java' \) | sed "s|^$1/||; s|\.java\$||; s|/|.|g" | grep -E "^($re)\.[^.]+\$" || true
		grep -rlE --include='*Test.java' --include='*Tests.java' "^import (static )?($re)\.(\*|[A-Z])" "$1" | sed "s|^$1/||; s|\.java\$||; s|/|.|g" || true
	} | LC_ALL=C sort -u
}
# 찍는 순서는 gateways, libs, services, launcher
for m in $(echo "$mods" | grep '^gateways/' || true) $(echo "$mods" | grep '^libs/' || true) \
	$(echo "$mods" | grep '^services/' || true) $(echo "$mods" | grep -x launcher || true); do
	d=$m/src/test/java
	mf=$(echo "$files" | grep "^$d/.*\.java\$" || true)
	own=$(for f in $mf; do case $f in *Test.java | *Tests.java) [ -f "$f" ] && echo "$f";; esac; done | sed "s|^$d/||; s|\.java\$||; s|/|.|g")
	helpers=$(for f in $mf; do case $f in *Test.java | *Tests.java) ;; *) dirname "${f#$d/}";; esac; done | tr / . | sort -u)
	cls=$(printf '%s\n%s\n' "$own" "$(tests_of "$d" "$(printf '%s\n%s\n' "$pkgs" "$helpers" | grep . || true)")" | grep . | LC_ALL=C sort -u || true)
	case $m in
	services/*) if echo "$visible" | grep -qx "$m" && [ -d "$d" ]; then
			cls=$(printf '%s\n%s\n' "$cls" "$(find "$d" -name '*ArchTest.java' | sed "s|^$d/||; s|\.java\$||; s|/|.|g")" | grep . | LC_ALL=C sort -u || true)
		fi ;;
	esac
	if [ "$m" = launcher ]; then
		echo :launcher:test
		for c in $cls; do echo --tests; echo "$c"; done
		printf '%s\n' --tests '*ArchTest' --tests 'net.spacenx.work.contract.*'
	elif [ -n "$cls" ]; then
		echo ":${m%/*}:${m#*/}:test"; for c in $cls; do echo --tests; echo "$c"; done
	else
		echo ":${m%/*}:${m#*/}:compileTestJava"
	fi
done
