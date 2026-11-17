# AGENTS.md

이 레포에만 적용되는 규칙이다. 공통 행동 원칙은 전역 `AGENTS.md`(`~/.codex/AGENTS.md`)를 따르며 여기서 반복하지 않는다.

<!-- `<...>` 자리표시자를 실제 값으로 바꾼다. 바꾸지 않은 자리표시자는 사실로 취급하지 않는다. -->

## 프로젝트 개요

- WorkNX 업무 데스크(워크벤치): 고객사 설치·유지보수를 맡는 서버 개발자의 하루 업무(할 일, 고객 문의·장애, 외근, 설치, 업무일지)를 한 곳에서 처리하는 웹 앱
- 목표: WorkNX 산출물 v3.11을 설계 정본으로 구현한다. 정본은 [`docs/00-문서모음.md`](../docs/00-문서모음.md)이며, 제품의 왜·누구·무엇은 [`docs/product/01-제품요구사항정의서-PRD.md`](../docs/product/01-제품요구사항정의서-PRD.md)에 있다. 2026-10-30 중간 점검, 2026-11-09~11-13 알파(범위 "로그인 + 할 일 + 인앱 알림", [확인 필요: 이사님 확정]) 일정이다. 운영 실행 환경은 k8s다([ADR-012](../docs/adr/ADR-012-운영-실행-환경을-k8s로-하기.md)). 클러스터·레지스트리는 미정이다(INF-10).
- 비목표: PRD(01)의 범위 밖 항목은 구현 범위에 포함하지 않는다.
- 구현 순서: [`docs/plan/14-WBS.md`](../docs/plan/14-WBS.md)의 WBS 순서를 따른다(WBS ID 기준).

## 구조

이 파일이 있는 `backend/`를 기준으로 한 경로다.

```text
backend/
├── AGENTS.md            # 이 파일. 레포 규칙
├── README.md            # 사람이 보는 안내: 작업별로 어떤 문서를 어디에 쓰나
├── .claude/             # Claude Code 공통 원칙과 스킬
├── settings.gradle.kts  # Gradle 모듈 목록 (build-logic, gradle/libs.versions.toml, gradlew 함께)
├── build-logic/         # 모듈 공통 빌드 설정 convention 플러그인 (included build)
├── launcher/            # WorkbenchApplication, application*.yaml, 실행 JAR. 여러 서비스를 함께 보는 시험과, 서비스 모듈만으로 컨텍스트가 뜨지 않는 시험(common/011 #n)
│                        #   여러 모듈 시험이 함께 쓰는 도우미는 그 모듈의 src/testFixtures에 둔다(libs/authz, services/identity, services/client; common/011 #l)
├── gateways/            # 독립 실행 게이트웨이
├── libs/                # 공통 라이브러리 모듈: kernel, authz, persistence-dialect(-postgresql, -mariadb), eventing(-transport-inprocess, -tck), test-support
├── services/            # 서비스 모듈: edge, identity, client, task, notification
│                        #   (모듈 안: src/main/java/net/spacenx/work/<모듈>/, src/test/java/…, 마이그레이션 src/main/resources/db/migration/<서비스>/)
├── contracts/           # 계약 파일. transitions/task.csv = 할 일 전이 표(task/004), 시험 리소스로 읽는다
└── templates/           # 문서 템플릿. 아래 '문서' 참고
```

문서는 `backend/` 밖, 저장소 루트의 `docs/`에 둔다. 이 문서와 규칙 안의 문서 경로(`docs/...`)는 저장소 루트 기준이다. 마크다운 링크만 이 파일 위치 기준(`../docs/...`)이다. `templates/...` 는 `backend/templates/` 다.

```text
docs/                    # 저장소 루트
├── 00-문서모음.md       # 산출물 v3.11 문서 지도 (설계 정본의 입구)
├── product/             # 01 PRD, 02 IA, 04 디자인 가이드
├── design/              # 05~09 설계·데이터 문서 (WorkNX-storyboard.md 원본 자료는 로컬 전용)
├── interface/           # 10~12 인터페이스·API·흐름도
├── dev/                 # 13 개발자 구현 규칙
├── plan/                # 14 WBS, 15 테스트 결과, 16 설계 리뷰
├── spec/                # 기능 명세: <도메인>/<NNN-기능>/ 에 spec·plan·tasks·worklog
├── adr/                 # 되돌리기 어려운 결정
├── concept/
│   ├── guide/           # 따라 하기: "X를 하려면 어떻게 하나"
│   └── research/        # 조사: 구조 분석, 기술 조사, 비교, 추천
├── agents/              # 예전 서브에이전트·오케스트레이션 정의. 로컬에만 둔다
├── troubleshooting/     # 문제 해결 기록
├── qa/                  # 도메인별 전체 QA 요약 (/qa-full)
├── orch-report/         # 오케스트레이션 실행별 소요 시간 보고 (/orch-report)
├── daily/               # 일일 기록 (로컬에만 둔다)
└── memory.md            # 현재 상태와 인수인계 (로컬에만 둔다)
```

배포에 관한 설계와 구현은 `backend/` 밖, 저장소 루트의 `deploy/`에 둔다([ADR-012](../docs/adr/ADR-012-운영-실행-환경을-k8s로-하기.md)). 지금은 로컬 k8s 값만 있다([deploy/001](../docs/spec/deploy/001-k8s-배치-껍데기/spec.md)).

```text
deploy/
├── docs/spec/<NNN-기능>/  # 배포 설계
└── k8s/
    ├── namespace.yaml      # 네임스페이스 workbench
    ├── local-db/           # 로컬 개발용 MariaDB
    ├── migrate/            # 마이그레이션 Job
    ├── app/                # 앱 Deployment + Service + ConfigMap
    ├── local-login/        # app 에 가짜 SsoNX·시험 사용자 seed 를 덧붙인 로컬 로그인 overlay
    └── local-up.sh         # 로컬 k8s 를 한 줄로 띄운다 (deploy/002)
```

## 기술 스택

[ADR-001](../docs/adr/ADR-001-백엔드-기술-스택-선택.md)로 정했다.

- 언어/런타임: Java 21
- 프레임워크: Spring Boot 4.0.8 (패키지 `net.spacenx.work`)
- 패키지 매니저: Gradle (`gradlew`). Kotlin DSL 멀티 모듈이다([ADR-011](../docs/adr/ADR-011-Gradle-멀티-모듈과-Kotlin-DSL로-나누기.md), [common/011 멀티 모듈 전환](../docs/spec/common/011-멀티-모듈-전환/spec.md))
- DB: 제품 미정(MQ-1, PostgreSQL 16+ 또는 MariaDB 11.4+). 지금 코드는 MariaDB 드라이버([ADR-003](../docs/adr/ADR-003-DB를-MariaDB로-바꾸기.md), MQ-1 결정 대기)
- 테스트/린트: JUnit 5. 로컬은 Testcontainers, CINX CI는 전용 DB([ADR-007](../docs/adr/ADR-007-TDD로-개발하기.md)). 린트는 아직 없다
- 입구: Spring Cloud Gateway webflux(`spring-cloud-starter-gateway-server-webflux`). k8s gateway Pod 하나다([ADR-015](../docs/adr/ADR-015-nginx를-Spring-Cloud-Gateway로-바꾸기.md)). cafe24 호스트 입구는 traefik Ingress 로 바꾼다([ADR-017](../docs/adr/ADR-017-호스트-nginx를-traefik-Ingress로-바꾸기.md))
- 설계 정본: [ADR-008](../docs/adr/ADR-008-WorkNX-산출물-v3.11을-설계-정본으로-하기.md)

## 검증 명령

이 레포에서 실제로 동작하는 명령만 적는다. `backend/`에서 실행한다. 린트는 아직 없다.

```bash
./gradlew test
./gradlew build
./gradlew :services:client:test --tests '*ClientApi*'   # 모듈 하나만
./gradlew :services:client:testOther --tests '*ClientReadController*' # 방언별: testMariadb / testPostgresql / testOther
./gradlew :launcher:bootJar                              # 실행 JAR (launcher/build/libs)
```

Testcontainers 테스트는 Docker가 필요하다. 로컬에서 Docker를 못 찾아 테스트가 하나라도 건너뛰어지면(skipped) `test`가 실패한다. Docker 없이 돌려야 하면 `CI=1 ./gradlew test`처럼 준다(CI에서는 건너뛴 테스트를 실패로 보지 않는다). `CI=1`은 Docker 없이 돌리는 우회로라 DB 시험이 건너뛰어지며, 이는 통과가 아니다.

`test`는 `testMariadb`(`MariaDb*Test`와 중첩 클래스), `testPostgresql`(`Postgres*Test`와 중첩 클래스), `testOther`(나머지)를 부른다. 기존 `test --tests '패턴'`도 세 태스크에 필터를 전달한다. UTC·공용 DB 전달·skipped 검사는 세 태스크에 모두 적용한다. 공용 DB URL 두 값 중 하나라도 비어 있으면 MariaDB → PostgreSQL → 기타 순서로 실행한다. 빈 환경 변수로 gradle.properties의 공용 DB 설정도 끌 수 있다.

방언별 시험 태스크는 공용 DB 연결 상한을 지키도록 방언마다 빌드 전체에서 한 번에 하나씩만 실행한다.
방언별 시험 태스크의 Spring 시험 컨텍스트 캐시는 8로 둔다(컨텍스트 하나당 연결 40개를 쓰며 공용 PostgreSQL을 다른 세션과 나눠 쓴다).

여러 세션이 동시에 시험을 돌리면 공용 시험 DB를 쓴다(ORCH-012). `docker compose -f compose.test-db.yaml up -d`로 한 번 띄우고, `~/.gradle/gradle.properties`에 `TEST_DB_URL_MARIADB`·`TEST_DB_URL_POSTGRESQL` 두 줄(값은 `compose.test-db.yaml` 맨 위 주석)을 넣는다. 그러면 모든 worktree의 `./gradlew test`가 시험 컨텍스트마다 컨테이너를 띄우지 않고, 그 DB에 실행마다 따로 만든 database·계정을 쓴다. 두 값이 없으면 지금처럼 Testcontainers를 쓴다. 시험 클래스가 직접 띄우는 컨테이너(`@Container`)는 공용 DB를 써도 그대로 뜬다.

코드를 고치는 동안과 작업 커밋 전에는 `./gradlew compileJava`나 `./gradlew :services:client:test --tests '*ClientApi*'`처럼 바꾼 모듈과 영역만 좁혀 돌린다. 전체 `./gradlew build`는 한 이슈의 작업과 마지막 단계 수정을 모두 합친 뒤 push 직전에 한 번만 돈다. qa 전에는 `./gradlew compileJava compileTestJava`만 돌린다(ORCH-023). 커밋한 뒤 같은 HEAD에서 바로 전체 `./gradlew build`를 돌릴 때(예: 마지막 단계 수정, 수정 하나를 바로 push할 때)는 영역 시험을 건너뛴다. 고친 시험 클래스만 RED·GREEN으로 확인하고 전체 빌드로 간다. 공용 DB URL 두 값과 설정 캐시가 있으면 같은 모듈의 세 시험 태스크도 동시에 돈다. 각 태스크의 포크는 하나로 유지한다. 포크를 늘리면 Docker 탐지가 포크별로 가끔 실패해 테스트가 조용히 건너뛰어졌기 때문이다(`build-logic`의 convention 플러그인).

전체 테스트는 한 번에 하나만 돌린다. 둘을 동시에 돌리면 CPU와 Docker를 나눠 써서 각각 2~3배 느려진다(혼자 약 7분 30초, 둘이면 17~18분). 10분 넘게 걸릴 수 있으니 출력을 로그 파일로 남기고 백그라운드로 돌린다. 도구 시간 제한에 끊기면 남은 흔적 때문에 다음 실행이 `in-progress-results-generic.bin`으로 실패한다.

빌드와 테스트는 세션마다 자기 worktree에서만 돌린다. 메인 폴더(`Desktop/AtMessenger`)에서는 돌리지 않는다. 여러 세션이 메인 폴더의 같은 `build/`를 함께 쓰면 결과 파일이 깨져 `EOFException`으로 실패하고 처음부터 다시 돌려야 한다(2026-10-27). 메인 폴더의 커밋을 빌드해야 하면 그 커밋으로 worktree를 만들어 거기서 돌린다.

자기 worktree에서 이미 빌드가 돌고 있으면 누가 돌리는지 사용자에게 묻지 않고 직접 확인한다. `build/orchestrate/<NNN>/full-<SHA>.log`의 SHA와 지금 HEAD를 비교하고, 작업 트리에 바뀐 파일이 없는지 본다. 같은 SHA이고 바뀐 파일이 없으면 그 빌드가 끝나기를 기다려 결과를 쓴다. 아니면 그 빌드가 끝난 뒤 자기 빌드를 돌린다.

## 문서

| 문서 | 위치 | 템플릿 | 용도 |
|---|---|---|---|
| 설계 산출물 | `docs/00-문서모음.md` 아래 `product/`·`design/`·`interface/`·`dev/`·`plan/` | 없음 | 산출물 v3.11 정본. 내용은 원본 개정으로만 바꾼다 |
| 기능 명세 | `docs/spec/<도메인>/<NNN-기능>/spec.md` | `templates/spec/spec-TEMPLATE.md` | 기능 하나의 사용자 스토리·요구사항 |
| 구현 계획 | `docs/spec/<도메인>/<NNN-기능>/plan.md` | `templates/spec/plan-TEMPLATE.md` | spec을 어떻게 구현할지 (기술 접근, 구조) |
| 작업 목록 | `docs/spec/<도메인>/<NNN-기능>/tasks.md` | `templates/spec/tasks-TEMPLATE.md` | plan을 쪼갠 작업과 체크박스 |
| 작업 기록 | `docs/spec/<도메인>/<NNN-기능>/worklog.md` | `templates/spec/worklog-TEMPLATE.md` | tasks 작업별로 한 일과 인계 |
| 배포 명세 묶음 | 저장소 루트 `docs/spec/deploy/<NNN-기능>/`의 `spec.md`·`plan.md`·`tasks.md`·`worklog.md` | `templates/spec/` 네 파일 | 배포(k8s) 기능 하나. 기능 명세와 같은 형식이고 위치만 다르다. git에 올라간다 |
| ADR | `docs/adr/ADR-NNN-<결정>.md` | `templates/adr/adr-TEMPLATE.md` | 되돌리기 어려운 결정 |
| 오케스트레이션 결정 | `docs/adr/orchestration/00-목록.md` 한 문서 | 문서 머리말의 형식 | 오케스트레이션·빌드 흐름을 바꾼 결정. 흐름에 맞는 절 끝에 다음 ORCH 번호 제목으로 더하고, 앞으로 바꿀 후보도 같은 문서에 둔다 |
| 따라 하기 | `docs/concept/guide/GUIDE-NNN-<할 일>.md` | `templates/concept/guide/guide-TEMPLATE.md` | "X를 하려면 어떻게 하나"에 답하는 단계별 절차 (도구 사용법, 설정 방법) |
| 조사 | `docs/concept/research/RESEARCH-NNN-<주제>.md` | `templates/concept/research/research-TEMPLATE.md` | 구조 분석, 기술 조사, 비교, 추천의 결과 |
| 트러블슈팅 | `docs/troubleshooting/TROUBLESHOOTING-NNN-<증상>.md` | `templates/troubleshooting/troubleshooting-TEMPLATE.md` | 막힌 문제의 증상, 조사 과정, 원인, 해결 |
| 일일 기록 | `docs/daily/YYYY-MM-DD.md` | `templates/daily/daily-TEMPLATE.md` | 날짜별로 한 일, 다음 할 일, 막힌 것 |
| 메모리 | `docs/memory.md` | `templates/memory-TEMPLATE.md` | 현재 상태와 인수인계 |
| 백로그 | `docs/backlog/tasks/<도메인>/`(미해결)·`docs/backlog/completed/<도메인>/`(해결)의 `<접두 소문자>-N - <제목>.md` | `templates/backlog/task-TEMPLATE.md` | 아직 정하지 않은 것(`결정필요`)과 나중에 할 일(`나중할일`). 한 항목이 한 파일이다. 쓰는 규칙은 `docs/backlog/readme.md` |
| 전체 QA 요약 | `docs/qa/YYYY-MM-DD-<짧은 SHA>-<도메인들>.md` | `templates/qa/qa-TEMPLATE.md` | `/qa-full` 한 번의 spec별 결과와 이전 실행 대비 바뀐 것. 쓴 뒤 고치지 않는다 |
| 오케스트레이션 보고 | `docs/orch-report/YYYY-MM-DD-<도메인>-<NNN>.md` | `templates/orch-report/orch-report-TEMPLATE.md` | `/orchestrate` 한 번이 왜 그만큼 걸렸는지: 단계별 시간, 이유, 개선안. 쓴 뒤 고치지 않는다 |

`docs/design/WorkNX-storyboard.md`는 템플릿 없는 원본 자료다(로컬 전용, 저장소에 올리지 않는다). 고치지 않고 근거로만 인용한다.

문서는 반드시 위 템플릿대로 작성한다. 템플릿을 복사한 뒤 섹션 제목과 순서는 바꾸지 않고 내용만 채우며, 템플릿 안의 안내문(`>`, `<!-- -->`)을 따른다.

문서는 짧고 읽기 쉽게 쓴다.

- 결론을 맨 앞에 둔다. 독자가 바로 할 일(입력값, 명령)을 근거보다 먼저 쓴다.
- 한 문장에는 한 가지만 쓴다. 표 칸에는 짧은 말만 넣고, 긴 설명은 표 밖으로 뺀다.
- 근거 경로와 조사 과정은 뒤쪽에 짧게 모은다. 같은 내용을 여러 섹션에 반복하지 않는다.
- 행이 많은 표는 묶어서 줄인다(예: spec 23행 → "있음 / 일부 / 없음" 3행).

문서 위치는 템플릿 경로와 똑같이 맞춘다. `backend/templates/<경로>/<이름>-TEMPLATE.md`로 만드는 문서는 저장소 루트의 `docs/<경로>/<이름>.md`에 둔다(예: `backend/templates/memory-TEMPLATE.md` → `docs/memory.md`). 문서가 아직 없으면 부탁받았을 때 템플릿을 복사해 만든다. 예외는 한 폴더에 여러 개가 쌓이는 다섯 가지다.

- ADR: `docs/adr/ADR-NNN-<결정>.md`
- 따라 하기: `docs/concept/guide/GUIDE-NNN-<할 일>.md` (할 일은 동사로 끝낸다. 예: `GUIDE-003-start-spring-io로-프로젝트-만들기.md`)
- 조사: `docs/concept/research/RESEARCH-NNN-<주제>.md`
- 트러블슈팅: `docs/troubleshooting/TROUBLESHOOTING-NNN-<증상>.md` (증상이나 대상을 이름으로 쓴다. 예: `TROUBLESHOOTING-006-GitNX-push-자격증명-설정.md`)
- 일일 기록: `docs/daily/YYYY-MM-DD.md` (하루에 한 파일. 그날 파일이 있으면 새로 만들지 않고 항목을 추가한다)
- 전체 QA 요약: `docs/qa/YYYY-MM-DD-<짧은 SHA>-<도메인들>.md` (실행 한 번에 한 파일)
- 오케스트레이션 보고: `docs/orch-report/YYYY-MM-DD-<도메인>-<NNN>.md` (실행 한 번에 한 파일)
- 백로그: `docs/backlog/tasks/<도메인>/<접두 소문자>-N - <제목>.md` (제목의 빈칸은 `-`로 바꾼다. 도메인과 접두는 common=CMN, customer=CUS, identity=IDN, task=TSK, notification=NTF, infra=INF(배포·CI·서버·외부 인프라), project=PRJ(일정·승인·설계 정본·운영 절차)이고 앞머리 id는 `<접두>-N`이다. 형식은 [Backlog.md](https://github.com/MrLesk/Backlog.md)를 따른다. `N`은 세 자리가 아니라 그 도메인의 `tasks/<도메인>/`와 `completed/<도메인>/`을 통틀어 가장 큰 번호에 1을 더한다. 옛 `TASK-N` 번호는 `docs/backlog/old-numbers.md`에서 찾는다. `tasks/`는 미해결, `completed/`는 해결이다. 정할 것을 모두 체크한 항목만 `completed/`로 옮기고, 일부만 끝난 항목은 끝난 줄만 체크해 `tasks/`에 둔다)
- 기능 명세 묶음: `docs/spec/<도메인>/<NNN-기능>/` 폴더 하나에 `spec.md`·`plan.md`·`tasks.md`·`worklog.md` 네 파일을 둔다(예: `docs/spec/customer/002-고객-등록-조회/`). `NNN`은 도메인 폴더 안에서 매긴다.

`NNN`은 세 자리 번호다. 새 문서를 만들 때는 같은 폴더에서 가장 큰 번호에 1을 더한다. 지금은 다음 ADR이 `ADR-013`, 다음 따라 하기가 `GUIDE-039`, 다음 조사가 `RESEARCH-022`, 다음 트러블슈팅이 `TROUBLESHOOTING-008`이다. 지운 번호는 다시 쓰지 않는다. 예전 `CONCEPT-NNN` 문서는 2026-10-19에 `GUIDE-NNN`과 `RESEARCH-NNN`으로 나눠 옮겼다. `CONCEPT-NNN` 번호는 더 쓰지 않는다. 예전 `docs/concept/plan/PLAN-NNN` 계획 문서는 2026-10-20에 없앴다. 계획 순서는 `docs/plan/14-WBS.md`를 따른다.

따라 하기와 조사가 헷갈리면 이렇게 고른다. 단계를 따라 하면 끝나는 문서는 따라 하기, 알아낸 사실과 판단을 남기는 문서는 조사다. 한 질문에 둘 다 필요하면 조사 문서에 근거를 쓰고, 따라 하기 문서에는 절차만 쓴 뒤 조사 문서를 링크한다.

### 언제 어떤 문서를 쓰나

| 시점 | 상황 | 할 일 |
|---|---|---|
| 세션 시작 | 어떤 작업이든 시작할 때 | `docs/memory.md`가 있으면 읽기 |
| 제품 | 제품 방향, 대상 사용자, 기능 목록이 바뀜 | 산출물 정본 `product/01`은 직접 고치지 않고 변경 요청을 기록 |
| 기능 | 오타, 설정값, 한두 파일짜리 버그 수정 | 문서 없이 바로 작업 |
| 기능 | WBS 작업 하나 구현 | `docs/plan/14-WBS.md`의 WBS ID에 해당하는 근거 문서를 읽고 아래 '기능 구현 흐름'대로 진행 |
| 기능 | `docs/spec/<도메인>/<NNN-기능>/spec.md`를 구현 | 같은 폴더에 `plan.md` → `tasks.md` 순으로 작성. `tasks.md`를 만들 때 `worklog.md`도 복사 |
| 기능 | `tasks.md`의 작업 하나를 시작·끝냄 | 시작 전 `tasks.md`와 `worklog.md` 마지막 항목을 읽고, 끝나면 `worklog.md`에 항목 추가 후 `tasks.md` 체크 |
| 기능 | 요구사항 모호 | `[확인 필요]`를 Workbench NX 이슈에 남기고 확인한다 |
| 설계 | 기술 선택, 구조, 데이터 형식처럼 되돌리기 어려운 결정 | `docs/adr/ADR-NNN-<결정>.md` 작성 |
| 조사 | 구조, 흐름, 기술 조사, 비교, 추천을 부탁받음 | `docs/concept/research/RESEARCH-NNN-<주제>.md` 작성. 추천을 채택하면 ADR을 쓰고, 조사 문서의 상태를 `결정됨`으로 바꿔 링크 |
| 절차 | 도구 사용법이나 설정 방법을 정리해 달라는 부탁을 받음 | `docs/concept/guide/GUIDE-NNN-<할 일>.md` 작성 |
| 백로그 | 사람이 정해야 할 것이 남았거나 일을 뒤로 미룸 | `docs/backlog/tasks/<도메인>/`(미해결)에 항목 추가. 작업을 시작할 때 관련 항목이 있는지 본다. 정해진 줄은 결과·근거·날짜를 붙여 체크하고, 모두 체크되면 `completed/`(해결)로 옮긴다 |
| 문제 | 막힌 문제를 해결했거나, 해결하지 못했지만 조사 내용을 남길 때 | `docs/troubleshooting/TROUBLESHOOTING-NNN-<증상>.md` 작성 |
| 기록 | 오늘 한 일을 기록해 달라는 요청을 받음 | `docs/daily/YYYY-MM-DD.md`에 작성. 있으면 항목 추가 |
| 세션 종료 | 작업 종료, 세션이나 담당자 교체 | `docs/memory.md` 갱신 |

### 기능 구현 흐름 (제안 — 사용자 확정 전)

1. **작업 고르기**: `docs/plan/14-WBS.md`에서 WBS ID를 고르고, Workbench NX(사내 메신저 프로젝트·이슈)에 그 WBS ID로 이슈를 만든다.
2. **근거 읽기**: 05 기본 설계서 해당 절, 07 도메인 설계, 08 ERD·09 테이블 명세서, 10·11 인터페이스·API, 12 흐름도, 13 구현 규칙을 읽는다.
3. **구현**: TDD([ADR-007](../docs/adr/ADR-007-TDD로-개발하기.md))로 진행한다. 커밋 메시지에 WBS ID를 쓴다.
4. **검증·기록**: 검증 결과를 이슈에 남기고, 그날 `docs/daily/`에 기록한다. 설계와 다르게 해야 하면 구현 전에 멈추고 묻는다.

Agent Factory Dev 팀으로 진행할 때는 이슈와 daily를 작업 기록의 기준으로 삼는다. Orchestrator는 흐름에 따라 작업을 배분하고 판정을 이슈와 daily에 남긴다.

## 이 레포의 주의점

- 저장소가 공개되어 있다. 서버 주소, 계정, 비밀번호, 토큰 같은 접속 정보는 문서에도 코드에도 쓰지 않는다.
- `docs/design/WorkNX-storyboard.md`는 원본이므로 고치지 않는다. 해석은 산출물(01 PRD·02 IA)에 있다.
- 스토리보드의 숫자(처리 기한 4·8시간, 계약 만료 30일 등)는 시안의 예시다. 코드에 상수로 박지 않고 설정값으로 둔다.
- 커밋과 push는 사용자가 요청하지 않아도 한다. 맡은 작업이 끝나고 검증이 통과하면 자기 변경만 골라 커밋하고 main에 push한다. 다른 세션이 남긴 커밋 안 된 변경은 커밋하지 않는다. 서브에이전트는 자기 역할 정의를 따른다(be-worker는 자기 worktree에 커밋만 하고, reviewer·qa는 커밋하지 않는다).
- 설계 정본은 산출물 v3.11이다. 산출물 md는 옮길 때 링크·사내 정보 가림·호칭만 바꿨고, 내용 변경은 원본 개정으로 한다.
- 작업이 끝난 세션과 컨테이너는 삭제한다.
- 애매하거나 사람이 결정해야 할 내용이 있으면 먼저 설계 문서와 pro 서버를 보고 결정한다. 그래도 결정이 필요한 것이 남으면 사람에게 알린다.
- 어떤 작업이든 끝낼 때 남은 일과 정하지 못한 것을 `docs/backlog/tasks/<도메인>/`에 항목으로 적는다. 정하지 못한 것은 `결정필요`, 미룬 일은 `나중할일` 라벨을 붙인다. 같은 내용의 항목이 이미 있으면 새로 만들지 않고 그 항목에 덧붙인다. 이번 작업으로 정해진 줄은 결과·근거·날짜를 붙여 체크한다. 모든 줄이 체크된 항목은 `status: 끝남`으로 바꿔 `docs/backlog/completed/`로 옮기고, 남은 줄이 있으면 `tasks/`에 둔다. worklog·daily·memory에 남긴 보류도 백로그에 함께 적는다.
