#!/usr/bin/env bash
# module-tests.sh 시험(ORCH-059). 임시 레포에 모듈 몇 개와 의존 줄을 두고 바뀐 파일마다 고른 작업을 본다.
# 쓰기: bash .claude/skills/orchestrate/module-tests-test.sh
set -u
script="$(cd "$(dirname "$0")" && pwd)/module-tests.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

git init -q -b main "$tmp/r"
cd "$tmp/r"
git config user.email t@t; git config user.name t; git config core.autocrlf false
for m in services/care services/knowledge services/task services/notification libs/kernel libs/edge libs/solo launcher gateways/host; do
	mkdir -p "backend/$m/src/main"; echo a > "backend/$m/src/main/A.java"; : > "backend/$m/build.gradle.kts"
done
printf '%s
' 'implementation(project(":services:care"))' '// contracts/transitions/faq.csv' > backend/services/knowledge/build.gradle.kts
echo 'implementation(project(":services:task"))' > backend/services/notification/build.gradle.kts
printf '%s\n' 'implementation(project(":services:care"))' 'implementation(project(":libs:kernel"))' > backend/launcher/build.gradle.kts
echo 'testImplementation(testFixtures(project(":libs:kernel")))' > backend/services/task/build.gradle.kts
echo 'implementation(project(":libs:kernel"))' > backend/libs/edge/build.gradle.kts
echo 'implementation(project(":libs:edge"))' > backend/gateways/host/build.gradle.kts
# 쓰는 서비스는 바뀐 패키지를 import 할 때만 시험한다(ORCH-074). notification 은 task.api·task.domain 을, launcher 의
# notification 시험은 task.application 을(static), launcher 의 knowledge 시험은 launcher care 시험 패키지를 쓴다
J=src/main/java/net/spacenx/work
W=backend/launcher/src/test/java/net/spacenx/work
mkdir -p "backend/services/notification/$J/notification" "$W/notification" "$W/knowledge" "$W/care" "$W/task/api"
printf '%s\n' 'package net.spacenx.work.notification;' 'import net.spacenx.work.task.api.AccessCheckApi;' 'import net.spacenx.work.task.domain.*;' \
	> "backend/services/notification/$J/notification/N.java"
printf '%s\n' 'package net.spacenx.work.notification;' 'import static net.spacenx.work.task.application.InputFreshness.of;' > "$W/notification/DTest.java"
printf '%s\n' 'package net.spacenx.work.knowledge;' 'import net.spacenx.work.care.CareBase;' > "$W/knowledge/KTest.java"
echo 'package net.spacenx.work.care;' > "$W/care/CareBase.java"
# launcher 공용 시험 폴더(ORCH-077): crossflow 기반과 같은 패키지 시험, 그것을 import 하는 다른 공용 폴더 시험
mkdir -p "$W/common/crossflow" "$W/common/support"
echo 'package net.spacenx.work.common.crossflow;' > "$W/common/crossflow/FlowBase.java"
echo 'package net.spacenx.work.common.crossflow;' > "$W/common/crossflow/F1Test.java"
printf '%s\n' 'package net.spacenx.work.common.support;' 'import net.spacenx.work.common.crossflow.FlowBase;' > "$W/common/support/STest.java"
# 시험 클래스만 고를 때(ORCH-076): 시험은 *Test·*Tests 이름만, 패키지는 경로로 본다
S=src/test/java/net/spacenx/work
mkdir -p "backend/services/task/$S/task/schedule" "backend/services/notification/$S/notification" "backend/services/care/$S/care/architecture"
: > "backend/services/task/$S/task/schedule/ScheduleTest.java"
printf '%s
' 'import net.spacenx.work.task.api.AccessCheckApi;' 'import net.spacenx.work.task.domain.*;' > "backend/services/notification/$S/notification/NTest.java"
: > "backend/services/care/$S/care/architecture/CareArchTest.java"
: > "$W/task/api/TaskApiTest.java"
# test-support 시험 기본값: 공통 칸(events)과 서비스 칸(care) (ORCH-087)
TY=backend/libs/test-support/src/main/resources/application-default.yaml
mkdir -p "$(dirname "$TY")"; : > backend/libs/test-support/build.gradle.kts
printf '%s\n' '# 시험 기본값' 'workbench:' '  events:' '    enabled: false' '  care:' '    gc: P1D' > "$TY"
mkdir -p docs; echo d > docs/d.md; echo r > backend/README.md
git add -A; git commit -qm init
start=$(git rev-parse HEAD)
git update-ref refs/remotes/origin/main "$start"

# $1 설명, $2 기대 출력(줄을 | 로 이음), $3 고칠 파일들
try() {
	git reset -q --hard "$start"
	for f in $3; do mkdir -p "$(dirname "$f")"; echo "$RANDOM" >> "$f"; done
	git add -A; git commit -qm change
	got=$(cd backend && bash "$script" | paste -sd'|')
	if [ "$got" = "$2" ]; then echo "통과: $1"; else echo "실패: $1 (기대 $2, 실제 $got)"; fail=1; fi
}
L='--tests|*ArchTest|--tests|net.spacenx.work.contract.*'
CA='--tests|net.spacenx.work.care.architecture.CareArchTest'
# 모듈 시험 전체(--tests 없는 :test)는 고르지 않는다(ORCH-088). java 패키지가 없는 파일만 바뀌면 시험 없이 컴파일만, launcher 는 ArchTest·계약
try "서비스 하나: 그 모듈 ArchTest, 쓰는 서비스는 컴파일, launcher 는 ArchTest·계약" \
	":services:care:test|$CA|:services:knowledge:compileTestJava|:launcher:test|$L" backend/services/care/src/main/A.java
try "쓰는 서비스가 없는 서비스" ":services:knowledge:compileTestJava|:launcher:test|$L" backend/services/knowledge/src/main/A.java
try "gateway 도 모듈 시험 전체를 돌지 않는다" ":gateways:host:compileTestJava" backend/gateways/host/src/main/A.java
try "launcher 코드도 launcher 전체를 돌지 않는다" ":launcher:test|$L" backend/launcher/src/main/A.java
try "launcher 시험 클래스는 그 클래스만" ":launcher:test|--tests|net.spacenx.work.care.XTest|$L" "$W/care/XTest.java"
try "launcher 공용 시험 기반: 같은 패키지 시험과 import 하는 시험" \
	":launcher:test|--tests|net.spacenx.work.common.crossflow.F1Test|--tests|net.spacenx.work.common.support.STest|$L" "$W/common/crossflow/FlowBase.java"
try "launcher 시험 기반 둘" \
	":launcher:test|--tests|net.spacenx.work.common.crossflow.F1Test|--tests|net.spacenx.work.common.support.STest|--tests|net.spacenx.work.knowledge.KTest|$L" \
	"$W/care/X.java $W/common/crossflow/FlowBase.java"
try "서비스 resources 는 컴파일만" \
	":services:knowledge:compileTestJava|:launcher:test|--tests|net.spacenx.work.common.crossflow.F1Test|--tests|net.spacenx.work.common.support.STest|$L" \
	"backend/services/knowledge/src/main/resources/a.yml $W/common/crossflow/FlowBase.java"
try "launcher 시험 resources 도 launcher 전체를 돌지 않는다" \
	":launcher:test|--tests|net.spacenx.work.common.crossflow.F1Test|--tests|net.spacenx.work.common.support.STest|$L" \
	"backend/launcher/src/test/resources/a.yml $W/common/crossflow/FlowBase.java"
try "서비스 코드와 launcher 시험 기반을 함께" \
	":services:notification:compileTestJava|:services:task:compileTestJava|:launcher:test|--tests|net.spacenx.work.knowledge.KTest|$L" \
	"backend/services/task/src/main/A.java $W/care/X.java"
try "libs: 그 libs, 쓰는 libs·서비스·gateway 는 컴파일, launcher 는 ArchTest·계약" \
	":gateways:host:compileTestJava|:libs:edge:compileTestJava|:libs:kernel:compileTestJava|:services:notification:compileTestJava|:services:task:compileTestJava|:launcher:test|$L" \
	backend/libs/kernel/src/main/A.java
try "launcher 가 안 쓰는 libs 는 쓰는 모듈만" ":gateways:host:compileTestJava|:libs:edge:compileTestJava" backend/libs/edge/src/main/A.java
try "아무도 안 쓰는 libs 는 그 libs 만" ":libs:solo:compileTestJava" backend/libs/solo/src/main/A.java
try "libs 와 서비스를 함께" \
	":libs:solo:compileTestJava|:services:care:test|$CA|:services:knowledge:compileTestJava|:launcher:test|$L" \
	"backend/libs/solo/src/main/A.java backend/services/care/src/main/A.java"
T=backend/services/task/$J/task
# 바뀐 패키지에 있거나 그 패키지를 import 하는 시험 클래스만 고른다(ORCH-076). 없는 모듈은 컴파일만
try "바뀐 패키지의 시험만, 그 패키지를 안 쓰는 쓰는 서비스는 컴파일만" \
	":services:notification:compileTestJava|:services:task:test|--tests|net.spacenx.work.task.schedule.ScheduleTest|:launcher:test|$L" "$T/schedule/S.java"
try "쓰는 서비스·launcher 는 그 패키지를 import 하거나 같은 패키지인 시험만, 시험 없는 바뀐 서비스는 컴파일만" \
	":services:notification:test|--tests|net.spacenx.work.notification.NTest|:services:task:compileTestJava|:launcher:test|--tests|net.spacenx.work.task.api.TaskApiTest|$L" "$T/api/X.java"
try "와일드카드 import 도 쓴 것으로 본다" \
	":services:notification:test|--tests|net.spacenx.work.notification.NTest|:services:task:compileTestJava|:launcher:test|$L" "$T/domain/Z.java"
try "launcher 시험의 static import 도 쓴 것으로 본다" \
	":services:notification:compileTestJava|:services:task:compileTestJava|:launcher:test|--tests|net.spacenx.work.notification.DTest|$L" "$T/application/Y.java"
try "하위 패키지는 다른 패키지로 본다" \
	":services:notification:compileTestJava|:services:task:compileTestJava|:launcher:test|$L" "$T/api/sub/X.java"
# libs·서비스의 src/test(testFixtures 빼고)만 바뀌면 다른 모듈은 그 코드를 쓰지 않으니 그 모듈의 바뀐 시험만(ORCH-078)
KT=backend/libs/kernel/src/test/java/net/spacenx/work/kernel/clock/ClockTest.java
TT=backend/services/task/$S/task/api/XTest.java
try "libs 시험 코드만 바뀌면 그 libs 의 바뀐 시험 클래스만" ":libs:kernel:test|--tests|net.spacenx.work.kernel.clock.ClockTest" "$KT"
try "서비스 시험 코드만 바뀌면 그 서비스의 바뀐 시험 클래스만" ":services:task:test|--tests|net.spacenx.work.task.api.XTest" "$TT"
try "두 모듈의 시험 코드만 바뀌면 모듈마다 바뀐 시험 클래스만" \
	":libs:kernel:test|--tests|net.spacenx.work.kernel.clock.ClockTest|:services:task:test|--tests|net.spacenx.work.task.api.XTest" "$KT $TT"
try "시험 기반 클래스만 바뀌면 그 모듈에서 그 패키지에 있거나 import 하는 시험" \
	":services:task:test|--tests|net.spacenx.work.task.schedule.ScheduleTest" "backend/services/task/$S/task/schedule/ScheduleSupport.java"
try "시험 resources 만 바뀌면 컴파일만" ":libs:kernel:compileTestJava" backend/libs/kernel/src/test/resources/a.yml
K=":gateways:host:compileTestJava|:libs:edge:compileTestJava|:libs:kernel:test|--tests|net.spacenx.work.kernel.clock.ClockTest|:services:notification:compileTestJava|:services:task:compileTestJava|:launcher:test|$L"
try "시험 코드에 testFixtures 가 섞이면 쓰는 모듈은 import 하는 시험만" "$K" "$KT backend/libs/kernel/src/testFixtures/java/net/spacenx/work/kernel/F.java"
try "시험 코드에 src/main 이 섞여도 바뀐 시험만" "$K" "$KT backend/libs/kernel/src/main/A.java"
try "서비스 시험과 launcher 시험이 섞이면 모듈마다 바뀐 시험만" \
	":services:task:test|--tests|net.spacenx.work.task.api.XTest|:launcher:test|--tests|net.spacenx.work.task.api.TaskApiTest|$L" \
	"$TT $W/task/api/TaskApiTest.java"
try "바뀐 서비스의 ArchTest 는 함께 돈다" \
	":services:care:test|$CA|:services:knowledge:compileTestJava|:launcher:test|$L" "backend/services/care/$J/care/api/C.java"
try "java 밖(resources)만 바뀌면 컴파일만" \
	":services:notification:compileTestJava|:services:task:compileTestJava|:launcher:test|$L" backend/services/task/src/main/resources/a.yaml
try "빌드 설정은 전체 시험" "test" backend/build-logic/x.kts
# 시험이 안 읽는 파일은 뺀다(ORCH-085). compose.test-db.yaml 은 시험이 읽으니 test
try "Dockerfile 만 바뀌면 없음" "" backend/Dockerfile
try "docker/ 와 서비스 java 가 함께 바뀌면 test 가 아니라 서비스 쪽만" \
	":services:care:test|$CA|:services:knowledge:compileTestJava|:launcher:test|$L" \
	"backend/docker/x.sh backend/services/care/src/main/A.java"
try "src 밖 png 만 바뀌면 없음" "" backend/services/care/a.png
try "src 아래 png 는 뺀 파일이 아니라 그 모듈 시험" \
	":services:care:test|$CA|:services:knowledge:compileTestJava|:launcher:test|$L" \
	backend/services/care/src/main/resources/a.png
try "contracts 파일 이름을 빌드 파일에 담은 모듈만" \
	":services:knowledge:compileTestJava|:launcher:test|$L" backend/contracts/transitions/faq.csv
try "아무도 안 읽는 contracts 파일은 test" "test" backend/contracts/zzz/none.csv
try "contracts samples 는 ContractSamples 가 폴더째 읽어 test" "test" backend/contracts/samples/x.json
try "compose.test-db.yaml 은 test" "test" backend/compose.test-db.yaml
# $1 설명, $2 기대 출력, $3 파일, $4 덧붙일 줄: 주석만 바꾼 변경(ORCH-085)
tryc() {
	git reset -q --hard "$start"
	mkdir -p "$(dirname "$3")"; printf '%s\n' "$4" >> "$3"
	git add -A; git commit -qm change
	got=$(cd backend && bash "$script" | paste -sd'|')
	if [ "$got" = "$2" ]; then echo "통과: $1"; else echo "실패: $1 (기대 $2, 실제 $got)"; fail=1; fi
}
tryc "launcher java 주석만: 구조 시험만" ":launcher:test|--tests|*ArchTest|--tests|*StructureTest" backend/launcher/src/main/A.java "// 설명 $RANDOM"
tryc "java 블록 주석 줄만" ":launcher:test|--tests|*ArchTest|--tests|*StructureTest" backend/launcher/src/main/A.java " * 설명 $RANDOM"
tryc "줄 끝 주석이 붙은 코드는 코드" ":launcher:test|$L" backend/launcher/src/main/A.java "int a = $RANDOM; // 설명"
tryc "yaml 주석만: 없음" "" backend/services/care/src/main/resources/application.yaml "# 설명 $RANDOM"
tryc "sql 주석은 체크섬이 바뀌어 코드로 본다" ":services:care:test|$CA|:services:knowledge:compileTestJava|:launcher:test|$L" \
	backend/services/care/src/main/resources/db/migration/V1__a.sql "-- 설명 $RANDOM"
# $1 설명, $2 기대 출력, $3 실행할 변경 명령(ORCH-087)
tryx() {
	git reset -q --hard "$start"
	eval "$3"
	git add -A; git commit -qm change
	got=$(cd backend && bash "$script" | paste -sd'|')
	if [ "$got" = "$2" ]; then echo "통과: $1"; else echo "실패: $1 (기대 $2, 실제 $got)"; fail=1; fi
}
C=":services:care:test|$CA|:services:knowledge:compileTestJava|:launcher:test|$L"
tryx "test-support 기본값의 서비스 칸 값만: 그 서비스만" "$C" "sed -i 's/gc: P1D/gc: P2D/' $TY"
tryx "test-support 기본값에 서비스 칸을 새로 더함: 그 서비스만" \
	":services:knowledge:compileTestJava|:launcher:test|$L" "printf '%s\n' '  knowledge:' '    gc: P1D' >> $TY"
tryx "test-support 기본값의 공통 칸: libs 규칙 그대로" ":libs:test-support:compileTestJava" "sed -i 's/enabled: false/enabled: true/' $TY"
tryx "test-support 기본값의 서비스 칸과 공통 칸을 함께: libs 규칙 그대로" ":libs:test-support:compileTestJava" \
	"sed -i 's/enabled: false/enabled: true/; s/gc: P1D/gc: P2D/' $TY"
tryx "서비스 칸 지우기: 그 서비스만" "$C" "sed -i '/^  care:/,\$d' $TY"
tryx "서비스 이름이 아닌 칸은 공통" ":libs:test-support:compileTestJava" "printf '%s\n' '  nosuch:' '    a: 1' >> $TY"
try "문서만 바뀌면 없음" "" "docs/d.md backend/README.md"

# 시험 클래스를 지우기만 했으면 고를 시험이 없어 컴파일만(ORCH-078)
git reset -q --hard "$start"
git rm -q "backend/services/task/$S/task/schedule/ScheduleTest.java"; git commit -qm del
got=$(cd backend && bash "$script" | paste -sd'|')
if [ "$got" = ":services:task:compileTestJava" ]; then echo "통과: 시험 클래스만 지우면 컴파일만"; else echo "실패: 시험 클래스만 지우면 컴파일만 (실제 $got)"; fail=1; fi

# rebase 로 기준이 옮겨 가면 그 사이 main 에 들어온 남의 파일은 고르지 않는다. 옛 START 를 줘도 같다(ORCH-068)
git reset -q --hard "$start"
echo "$RANDOM" >> backend/services/care/src/main/A.java; git commit -qam other
git update-ref refs/remotes/origin/main HEAD
echo "$RANDOM" >> backend/gateways/host/src/main/A.java; git commit -qam mine
for arg in "" "$start"; do
	got=$(cd backend && bash "$script" $arg | paste -sd'|')
	if [ "$got" = ":gateways:host:compileTestJava" ]; then echo "통과: rebase 뒤 내 변경만(인자 '${arg:0:7}')"; else echo "실패: rebase 뒤 내 변경만(인자 '${arg:0:7}', 실제 $got)"; fail=1; fi
done

exit $fail
