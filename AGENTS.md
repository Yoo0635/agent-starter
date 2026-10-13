# AGENTS.md

이 레포에만 적용되는 규칙이다. 공통 행동 원칙은 전역 `AGENTS.md`(`~/.codex/AGENTS.md`)를 따르며 여기서 반복하지 않는다.

<!-- `<...>` 자리표시자를 실제 값으로 바꾼다. 바꾸지 않은 자리표시자는 사실로 취급하지 않는다. -->

## 프로젝트 개요

- <프로젝트 이름>: <한 줄 설명>
- 목표:
- 비목표:

## 구조

```text
.
├── src/       # <역할>
├── tests/     # <역할>
└── docs/      # 문서 (아래 '문서' 참고)
```

## 기술 스택

- 언어/런타임:
- 프레임워크:
- 패키지 매니저:
- 테스트/린트:

## 검증 명령

이 레포에서 실제로 동작하는 명령만 적는다.

```bash
<테스트 명령>
<린트/타입체크 명령>
<빌드 명령>
```

## 문서

| 문서 | 위치 | 템플릿 | 용도 |
|---|---|---|---|
| 문제 정의 | `docs/product/problem.md` | `docs/templates/product/problem-TEMPLATE.md` | 검증할 고객 문제와 우선순위(RICE) |
| 리서치 | `docs/product/research.md` | `docs/templates/product/research-TEMPLATE.md` | PRD 근거가 되는 시장, 경쟁사, 사용자 조사 |
| PRD | `docs/product/prd.md` | `docs/templates/product/prd-TEMPLATE.md` | 제품 전체의 왜, 누구, 무엇 (레포당 1개) |
| 기능 명세 | `docs/spec/NNN-<기능>/spec.md` | `docs/templates/spec/spec-TEMPLATE.md` | 기능의 무엇과 왜 |
| 구현 계획 | `docs/spec/NNN-<기능>/plan.md` | `docs/templates/spec/plan-TEMPLATE.md` | 기능의 어떻게 |
| 작업 목록 | `docs/spec/NNN-<기능>/tasks.md` | `docs/templates/spec/tasks-TEMPLATE.md` | 구현 순서와 체크리스트 |
| 작업 기록 | `docs/spec/NNN-<기능>/worklog.md` | `docs/templates/spec/worklog-TEMPLATE.md` | 작업마다 한 일과 다음 할 일 (에이전트 간 인계) |
| 아키텍처 | `docs/design/architecture.md` | `docs/templates/design/architecture-TEMPLATE.md` | 전체 구조와 구성 요소 |
| 데이터 모델 | `docs/design/db.md` | `docs/templates/design/db-TEMPLATE.md` | 엔터티, 필드, 관계, 검증 규칙 |
| API | `docs/design/api.md` | `docs/templates/design/api-TEMPLATE.md` | 엔드포인트별 요청과 응답 |
| 인프라 | `docs/design/infra.md` | `docs/templates/design/infra-TEMPLATE.md` | 실행 환경, 배포, 모니터링, 백업 |
| ADR | `docs/adr/ADR-NNN-<결정>.md` | `docs/templates/adr/adr-TEMPLATE.md` | 되돌리기 어려운 결정 |
| 메모리 | `docs/memory.md` | `docs/templates/memory-TEMPLATE.md` | 현재 상태와 인수인계 |

문서는 반드시 위 템플릿대로 작성한다. 템플릿을 복사한 뒤 섹션 제목과 순서는 바꾸지 않고 내용만 채우며, 템플릿 안의 안내문(`>`)을 따른다.

문서 위치는 템플릿 경로와 똑같이 맞춘다. `docs/templates/<경로>/<이름>-TEMPLATE.md`로 만드는 문서는 `docs/<경로>/<이름>.md`에 둔다. 예외는 번호가 붙는 두 가지뿐이다. 기능 문서(`spec/`)는 `docs/spec/NNN-<기능>/` 폴더 안에, ADR은 `docs/adr/ADR-NNN-<결정>.md`로 만든다.

`NNN`은 001부터 시작하는 세 자리 번호다. 새 기능 폴더나 ADR을 만들 때는 `docs/spec/`이나 `docs/adr/`에서 가장 큰 번호에 1을 더한다(예: `docs/spec/001-login/` 다음은 `docs/spec/002-payment/`, `docs/adr/ADR-001-<결정>.md` 다음은 `ADR-002-<결정>.md`). 지운 번호는 다시 쓰지 않는다.

### 언제 어떤 문서를 쓰나

| 시점 | 상황 | 할 일 |
|---|---|---|
| 세션 시작 | 어떤 작업이든 시작할 때 | `docs/memory.md` 읽기 |
| 제품 | 새 제품이나 큰 방향 전환 | `problem.md` → `research.md` → `prd.md` 순서로 작성 |
| 제품 | 제품 방향, 대상 사용자, 기능 목록이 바뀜 | `docs/product/prd.md` 갱신 |
| 기능 | 오타, 설정값, 한두 파일짜리 버그 수정 | 문서 없이 바로 작업 |
| 기능 | 새 기능, 여러 파일에 걸친 변경 | `docs/spec/NNN-<기능>/`을 만들고 `spec.md` → `plan.md` → `tasks.md` 순서로 작성. `tasks.md`를 만들 때 `worklog.md`도 같은 폴더에 만듦 |
| 기능 | 요구사항이 모호함 | `spec.md`에 `[확인 필요]`로 표시. 남아 있으면 `plan.md`로 넘어가지 않음 |
| 설계 | 새 엔터티나 필드가 필요함 | `plan.md`를 쓰면서 `docs/design/db.md` 갱신 |
| 설계 | API 엔드포인트를 추가하거나 바꿈 | `plan.md`를 쓰면서 `docs/design/api.md` 갱신 |
| 설계 | 구성 요소가 생기거나 연결 방식이 바뀜 | `docs/design/architecture.md` 갱신 |
| 설계 | 인프라나 배포 방식이 바뀜 | `docs/design/infra.md` 갱신 |
| 설계 | 기술 선택, 구조, 데이터 형식처럼 되돌리기 어려운 결정 | ADR 작성, `architecture.md`의 '주요 결정'에 링크 |
| 작업 | `tasks.md`의 작업 하나를 시작 | `tasks.md`와 `worklog.md`의 마지막 항목 읽기 |
| 작업 | `tasks.md`의 작업 하나를 끝냄 | `worklog.md` 맨 아래에 항목 추가, `tasks.md` 체크 |
| 세션 종료 | 작업 종료, 세션이나 담당자 교체 | `docs/memory.md` 갱신 |

## 이 레포의 주의점

- <건드리면 안 되는 영역, 민감 파일, 배포 절차 등>
