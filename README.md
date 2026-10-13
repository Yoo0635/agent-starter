# agent-starter
AI 코딩 에이전트(Claude Code, Codex)와 일할 때 쓰는 규칙·문서 템플릿

## 구조

```text
.claude/                    # 전역 규칙: ~/.claude/에 그대로 복사
├── AGENTS.md               # 모든 프로젝트 공통 행동 원칙
└── CLAUDE.md               # @AGENTS.md (Claude Code가 전역 규칙을 읽는 입구)
.codex/                     # 전역 규칙: ~/.codex/에 그대로 복사
└── AGENTS.md               # .claude/AGENTS.md와 같은 내용
AGENTS.md                   # 레포별 규칙: 개요, 스택, 검증 명령, 문서 위치 (새 레포로 복사)
CONTRIBUTING.md             # 개발 환경, 브랜치·커밋 규칙, PR 절차 (새 레포로 복사)
.github/                    # 이슈·PR 템플릿과 워크플로 (새 레포로 복사)
docs/                       # 템플릿을 정해진 경로에 미리 복사해 둔 문서 (새 레포로 복사)
├── product/{problem,research,prd}.md
├── spec/000-example/{spec,plan,tasks,worklog}.md
├── design/{architecture,db,api,infra}.md
├── adr/ADR-001-example.md
└── memory.md
templates/                  # 원본 템플릿: 새 레포의 docs/templates/로 복사
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

레포 안에서는 템플릿 경로와 똑같이 `docs/` 아래에 둔다(`templates/design/db-TEMPLATE.md` → `docs/design/db.md`). 번호가 붙는 기능 문서는 `docs/spec/NNN-<기능>/{spec,plan,tasks,worklog}.md`, ADR은 `docs/adr/ADR-NNN-<결정>.md`에 둔다. `NNN`은 001부터 1씩 늘어나는 번호다 (`docs/spec/001-login/`, `docs/adr/ADR-001-<결정>.md`).

## 설치

### 전역 규칙

레포의 `.claude/`, `.codex/`를 홈 폴더의 같은 경로에 복사한다. Claude Code는 `~/.claude/CLAUDE.md`의 `@AGENTS.md`로 전역 규칙을 읽고(전역으로 읽는 파일이 `CLAUDE.md`뿐이라 필요하다), Codex는 `~/.codex/AGENTS.md`를 바로 읽는다.

```bash
cp .claude/AGENTS.md .claude/CLAUDE.md ~/.claude/
cp .codex/AGENTS.md ~/.codex/
```

규칙을 고칠 때는 레포의 `.claude/AGENTS.md`를 고치고 `.codex/AGENTS.md`에도 같은 내용을 복사한 뒤, 위 명령으로 다시 설치한다.

### 새 프로젝트

Claude Code(v2.1.277 이상)와 Codex 모두 프로젝트 루트의 `AGENTS.md`를 바로 읽으므로 `CLAUDE.md`는 두지 않는다.

```bash
cp AGENTS.md CONTRIBUTING.md <새 레포 경로>/
cp -r .github docs <새 레포 경로>/
cp -r templates <새 레포 경로>/docs/templates
```

복사한 뒤 `AGENTS.md`와 `docs/`의 `<...>` 자리표시자를 채운다. `docs/spec/000-example`과 `docs/adr/ADR-001-example.md`는 첫 기능과 첫 결정의 이름으로 바꾼다. `.github/workflows/`는 새 레포에 맞게 고치거나 지운다.

## 참고

템플릿은 널리 쓰이는 공개 템플릿을 한국어로 옮겨 썼다. 원본과 라이선스는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에 있다.
