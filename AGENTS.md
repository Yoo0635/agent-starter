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
| 기능 명세 | `docs/specs/NNN-<기능>/spec.md` | `docs/templates/spec/spec-TEMPLATE.md` | 기능의 무엇과 왜 |
| 구현 계획 | `docs/specs/NNN-<기능>/plan.md` | `docs/templates/dev/plan-TEMPLATE.md` | 기능의 어떻게 |
| 작업 목록 | `docs/specs/NNN-<기능>/tasks.md` | `docs/templates/dev/tasks-TEMPLATE.md` | 구현 순서와 체크리스트 |
| ADR | `docs/adr/ADR-NNN-<결정>.md` | `docs/templates/adr/adr-TEMPLATE.md` | 되돌리기 어려운 결정 |
| 메모리 | `docs/memory.md` | `docs/templates/dev/memory-TEMPLATE.md` | 현재 상태와 인수인계 |

문서는 반드시 위 템플릿대로 작성한다. 템플릿을 복사한 뒤 섹션 제목과 순서는 바꾸지 않고 내용만 채우며, 템플릿 안의 안내문(`>`)을 따른다.

### 언제 어떤 문서를 쓰나

| 상황 | 할 일 |
|---|---|
| 오타, 설정값, 한두 파일짜리 버그 수정 | 문서 없이 바로 작업 |
| 새 기능, 여러 파일에 걸친 변경 | `spec.md` → `plan.md` → `tasks.md` 순서로 작성 |
| 요구사항이 모호함 | `spec.md`에 `[확인 필요]`로 표시. 남아 있으면 `plan.md`로 넘어가지 않음 |
| 새 제품이나 큰 방향 전환 | `problem.md` → `research.md` → `prd.md` 순서로 작성 |
| 제품 방향, 대상 사용자, 기능 목록이 바뀜 | `docs/product/prd.md` 갱신 |
| 기술 선택, 구조, 데이터 형식처럼 되돌리기 어려운 결정 | ADR 작성 |
| 작업 시작 | `docs/memory.md` 읽기 |
| 작업 종료, 세션이나 담당자 교체 | `docs/memory.md` 갱신 |

## 이 레포의 주의점

- <건드리면 안 되는 영역, 민감 파일, 배포 절차 등>
