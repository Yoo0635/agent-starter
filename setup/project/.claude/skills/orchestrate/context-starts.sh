#!/usr/bin/env bash
# 시험 컨텍스트 기동을 세어 알린다(common/013 R-TEST-14). 고치지는 않는다.
# 쓰기: cd <worktree>/backend && bash <레포 루트>/.claude/skills/orchestrate/context-starts.sh <START>
#   전체 빌드 뒤 시험 결과 XML(build/test-results/test*/)을 읽는다.
# 1) 모듈별 `Started … in` 줄 수
# 2) START..HEAD 에서 바뀐 시험 클래스(또는 그 부모)가 컨텍스트를 띄웠으면 그 클래스·부모·예외 줄(`R-TEST-14 예외`) 유무
#    같은 설정을 쓰는 묶음에서 처음 돈 클래스도 걸린다. 공통 기반 클래스·맨몸 모양이면 문제가 아니다.

start=$1
[ -n "$start" ] || { echo "쓰기: context-starts.sh <START>" >&2; exit 2; }
pat='Started [A-Za-z0-9_]+ in [0-9.]+ seconds'
changed=$(git diff --name-only "$start"..HEAD -- '*/src/test/java/*.java' | sed 's|.*/||; s|\.java$||' | sort -u)
xmls=$(find . -path '*/build/test-results/test*/TEST-*.xml' 2>/dev/null)

echo "== 모듈별 기동 수"
for d in $(echo "$xmls" | xargs -r -n1 dirname | sort -u); do
	n=$(cat "$d"/TEST-*.xml | grep -cE "$pat")
	[ "$n" -gt 0 ] && echo "$n ${d#./}"
done

echo "== 바뀐 시험이 띄운 컨텍스트"
[ -n "$changed" ] || { echo "(바뀐 시험 없음)"; exit 0; }
sources=$(git ls-files '*/src/test/java/*.java')
for f in $(echo "$xmls" | xargs -r grep -lE "$pat"); do
	# 이름이 긴 클래스는 XML 파일 이름이 줄어 있어 testsuite 이름을 읽는다
	cls=$(grep -oE '<testsuite name="[^"]+"' "$f" | head -1 | sed 's/.*name="//; s/"$//')
	simple=${cls##*.}
	src=$(echo "$sources" | grep -F "/src/test/java/$(echo "$cls" | tr . /).java" | head -1)
	parent=$(grep -oE "extends [A-Za-z0-9_]+" "$src" 2>/dev/null | head -1 | cut -d' ' -f2)
	echo "$changed" | grep -qxE "$simple${parent:+|$parent}" || continue
	psrc=${parent:+$(echo "$sources" | grep "/$parent\.java$" | head -1)}
	mark=없음
	grep -qs "R-TEST-14 예외" "$src" $psrc && mark=있음
	echo "$simple (부모 ${parent:-없음}) 예외 줄 $mark"
done
