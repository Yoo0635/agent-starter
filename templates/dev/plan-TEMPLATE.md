# 구현 계획: <기능 이름>

**브랜치**: `<NNN-기능-이름>` | **작성일**: <YYYY-MM-DD> | **명세**: <링크>

**입력**: `docs/specs/<NNN-기능-이름>/spec.md`의 기능 명세

**참고**: 이 템플릿은 plan 단계에서 채운다. 작업 흐름은 `AGENTS.md`를 따른다.

## 요약

<기능 명세에서 뽑은 핵심 요구사항 + 조사로 정한 기술 접근>

## 기술 맥락

<!--
  조치 필요: 이 섹션의 내용을 프로젝트의 기술 세부 사항으로 바꾼다.
  여기 구조는 반복 작업을 돕기 위한 권장안이다.
-->

**언어/버전**: <예: Python 3.11, Swift 5.9, Rust 1.75 또는 확인 필요>

**주요 의존성**: <예: FastAPI, UIKit, LLVM 또는 확인 필요>

**저장소**: <해당하면, 예: PostgreSQL, CoreData, 파일 또는 해당 없음>

**테스트**: <예: pytest, XCTest, cargo test 또는 확인 필요>

**대상 플랫폼**: <예: Linux 서버, iOS 15+, WASM 또는 확인 필요>

**프로젝트 유형**: <예: library/cli/web-service/mobile-app/compiler/desktop-app 또는 확인 필요>

**성능 목표**: <도메인별, 예: 초당 1000요청, 초당 1만 줄, 60fps 또는 확인 필요>

**제약**: <도메인별, 예: p95 200ms 미만, 메모리 100MB 미만, 오프라인 동작 또는 확인 필요>

**규모/범위**: <도메인별, 예: 사용자 1만 명, 코드 100만 줄, 화면 50개 또는 확인 필요>

## 규칙 확인

*관문: Phase 0 조사 전에 통과해야 한다. Phase 1 설계 뒤에 다시 확인한다.*

<전역 `AGENTS.md`와 프로젝트 `AGENTS.md`에서 정한 관문>

## 프로젝트 구조

### 문서 (이 기능)

```text
docs/specs/<NNN-기능>/
├── plan.md              # 이 파일 (plan 단계 산출물)
├── research.md          # Phase 0 산출물 (plan 단계)
├── data-model.md        # Phase 1 산출물 (plan 단계)
├── quickstart.md        # Phase 1 산출물 (plan 단계)
├── contracts/           # Phase 1 산출물 (plan 단계)
└── tasks.md             # Phase 2 산출물 (tasks 단계 - plan 단계에서 만들지 않음)
```

### 소스 코드 (레포 루트)
<!--
  조치 필요: 아래 자리표시자 트리를 이 기능의 실제 구조로 바꾼다.
  쓰지 않는 선택지는 지우고, 고른 구조를 실제 경로(예: apps/admin, packages/something)로 넓힌다.
  완성된 계획에는 "선택지" 표시가 남아 있으면 안 된다.
-->

```text
# [안 쓰면 삭제] 선택지 1: 단일 프로젝트 (기본)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [안 쓰면 삭제] 선택지 2: 웹 애플리케이션 ("frontend" + "backend"가 있을 때)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [안 쓰면 삭제] 선택지 3: 모바일 + API ("iOS/Android"가 있을 때)
api/
└── <위 backend와 같음>

ios/ 또는 android/
└── <플랫폼별 구조: 기능 모듈, UI 흐름, 플랫폼 테스트>
```

**구조 결정**: <고른 구조를 기록하고 위에 적은 실제 디렉터리를 참조한다>

## 복잡도 기록

> **규칙 확인에서 어긋난 점이 있고 그 이유를 밝혀야 할 때만 채운다**

| 어긋난 점 | 필요한 이유 | 더 단순한 대안을 버린 이유 |
|-----------|------------|-------------------------------------|
| <예: 네 번째 프로젝트> | <현재 필요> | <프로젝트 3개로 부족한 이유> |
| <예: 저장소(Repository) 패턴> | <구체적인 문제> | <DB 직접 접근으로 부족한 이유> |
