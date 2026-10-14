# agent-starter
AI 코딩 에이전트(Claude Code, Codex)와 일할 때 쓰는 규칙·문서 템플릿

## 구조

```text
.claude/                    # Claude Code 설정 (프로젝트로 복사)
├── AGENTS.md               # 모든 프로젝트 공통 행동 원칙
├── CLAUDE.md               # @AGENTS.md (Claude Code가 공통 원칙을 읽는 입구)
└── skills/
    ├── spec/SKILL.md       # /spec: 기능 문서(spec → plan → tasks) 작성
    └── adr/SKILL.md        # /adr: ADR 작성
.codex/                     # 전역 규칙: ~/.codex/에 그대로 복사
└── AGENTS.md               # .claude/AGENTS.md와 같은 내용
AGENTS.md                   # 레포별 규칙: 개요, 스택, 검증 명령, 문서 위치 (프로젝트로 복사)
CONTRIBUTING.md             # 개발 환경, 브랜치·커밋 규칙, PR 절차 (프로젝트로 복사)
.github/                    # 이슈·PR 템플릿과 워크플로 (프로젝트로 복사)
templates/                  # 원본 템플릿: 에이전트가 보고 docs/의 같은 경로에 작성 (프로젝트로 복사)
├── product/problem-TEMPLATE.md     # 제품: 검증할 고객 문제
├── product/research-TEMPLATE.md    # 제품: 시장, 경쟁사, 사용자 조사
├── product/prd-TEMPLATE.md         # 제품: 왜, 누구를 위해, 무엇을
├── spec/spec-TEMPLATE.md           # 기능: 무엇을, 왜
├── spec/plan-TEMPLATE.md           # 기능: 어떻게
├── spec/tasks-TEMPLATE.md          # 기능: 구현 순서와 체크리스트
├── spec/worklog-TEMPLATE.md        # 기능: 작업마다 한 일과 다음 할 일
├── design/architecture-TEMPLATE.md # 전체 구조와 구성 요소
├── design/db-TEMPLATE.md           # 데이터 모델
├── design/api-TEMPLATE.md          # API 엔드포인트
├── design/infra-TEMPLATE.md        # 실행 환경, 배포, 운영
├── adr/adr-TEMPLATE.md             # 되돌리기 어려운 결정 기록
└── memory-TEMPLATE.md              # 현재 상태와 인수인계
```

## 문서 흐름

```text
문제 정의 → 리서치 → PRD (제품당 1개)
 └─ 기능마다: spec → plan → tasks → 구현 (작업마다 worklog에 기록)
ADR: 되돌리기 어려운 결정이 생길 때
memory: 세션이나 담당자가 바뀔 때
```

문서는 미리 만들어 두지 않는다. 문서 작성을 부탁하면 에이전트가 `templates/<경로>/<이름>-TEMPLATE.md`를 보고 그 양식대로 `docs/<경로>/<이름>.md`에 작성한다. 예를 들어 "PRD 써줘"라고 하면 `templates/product/prd-TEMPLATE.md`를 보고 `docs/product/prd.md`를 만든다.

```text
templates/                          docs/
├── product/prd-TEMPLATE.md     →   ├── product/prd.md
├── design/db-TEMPLATE.md       →   ├── design/db.md
├── spec/spec-TEMPLATE.md       →   ├── spec/001-login/spec.md
├── adr/adr-TEMPLATE.md         →   ├── adr/ADR-001-<결정>.md
└── memory-TEMPLATE.md          →   └── memory.md
```

번호가 붙는 두 가지만 예외다. 기능 문서는 `docs/spec/NNN-<기능>/{spec,plan,tasks,worklog}.md`, ADR은 `docs/adr/ADR-NNN-<결정>.md`에 둔다. `NNN`은 001부터 1씩 늘어나는 번호다. 이 두 가지는 Claude Code에서 `/spec`, `/adr` 스킬로 작성할 수 있다.

## 설치

### 프로젝트에 끼워넣기

이 레포를 클론한 뒤 쓰려는 프로젝트에 복사한다. 프로젝트에 같은 이름의 파일이 있으면 덮어쓰므로 먼저 확인한다.

```bash
cp -r .claude .github templates AGENTS.md CONTRIBUTING.md <프로젝트 경로>/
```

Claude Code는 프로젝트의 `.claude/CLAUDE.md`에 있는 `@AGENTS.md`로 공통 원칙을 읽고, `.claude/skills/`의 스킬을 자동으로 찾는다. Claude Code(v2.1.277 이상)와 Codex 모두 프로젝트 루트의 `AGENTS.md`를 바로 읽으므로 루트에는 `CLAUDE.md`를 두지 않는다.

Codex는 프로젝트 안의 `.codex/AGENTS.md`를 읽지 않으므로 공통 원칙을 홈에 한 번 설치한다.

```bash
cp .codex/AGENTS.md ~/.codex/
```

복사한 뒤 `AGENTS.md`의 `<...>` 자리표시자를 채우고, `.github/workflows/`는 프로젝트에 맞게 고치거나 지운다.

규칙을 고칠 때는 레포의 `.claude/AGENTS.md`를 고치고 `.codex/AGENTS.md`에도 같은 내용을 복사한다.

## 참고

템플릿은 널리 쓰이는 공개 템플릿을 한국어로 옮겨 썼다. 원본과 라이선스는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에 있다.
