# agent-starter
AI 코딩 에이전트(Claude Code, Codex)와 일할 때 쓰는 규칙·문서 템플릿

## 구조

```text
global/
└── AGENTS.md               # 전역 규칙: 모든 프로젝트 공통 행동 원칙
project/                    # 새 레포 루트에 그대로 복사
├── AGENTS.md               # 레포별 규칙: 개요, 스택, 검증 명령, 문서 위치
└── docs/memory.md          # 현재 상태와 인수인계
templates/                  # 필요할 때 레포의 docs/ 아래로 복사해서 채움
├── planning/prd.md         # 제품: 왜, 누구를 위해, 무엇을
├── planning/spec.md        # 기능: 무엇을, 왜
├── design/plan.md          # 기능: 어떻게
├── dev/tasks.md            # 기능: 구현 순서와 체크리스트
└── adr/ADR-TEMPLATE.md     # 되돌리기 어려운 결정 기록
```

## 문서 흐름

```text
PRD (제품당 1개)
 └─ 기능마다: spec → plan → tasks → 구현
ADR: 되돌리기 어려운 결정이 생길 때
memory: 세션이나 담당자가 바뀔 때
```

레포 안에서는 `docs/prd.md`, `docs/specs/NNN-<기능>/{spec,plan,tasks}.md`, `docs/adr/`, `docs/memory.md`에 둔다.

## 설치

### 전역 규칙

실제 파일은 `~/.claude/AGENTS.md` 하나만 둔다. Claude Code는 `~/.claude/CLAUDE.md`의 import로 읽고, Codex는 하드 링크로 같은 파일을 읽는다.

```bash
cp global/AGENTS.md ~/.claude/AGENTS.md
```

`~/.claude/CLAUDE.md`에는 아래 한 줄만 둔다. Claude Code가 전역으로 읽는 파일은 `CLAUDE.md`뿐이라 이 줄이 필요하다.

```text
@AGENTS.md
```

`~/.codex/AGENTS.md`를 하드 링크로 만든다.

```powershell
# Windows (PowerShell)
New-Item -ItemType HardLink -Path "$HOME\.codex\AGENTS.md" -Target "$HOME\.claude\AGENTS.md"
```

```bash
# macOS / Linux
ln ~/.claude/AGENTS.md ~/.codex/AGENTS.md
```

`global/AGENTS.md`를 고친 뒤에는 `cp`로 `~/.claude/AGENTS.md`에 덮어쓴다. 파일을 지우고 새로 만들거나 탐색기에서 "파일 바꾸기"로 덮어쓰면 하드 링크가 끊긴다.

### 새 프로젝트

Claude Code(v2.1.277 이상)와 Codex 모두 프로젝트 루트의 `AGENTS.md`를 바로 읽으므로 `CLAUDE.md`는 두지 않는다.

```bash
cp -r project/. <새 레포 경로>/
cp -r templates <새 레포 경로>/docs/templates
```

복사한 뒤 `AGENTS.md`의 `<...>` 자리표시자를 채운다.

## 참고

`spec`, `plan`, `tasks` 템플릿은 [github/spec-kit](https://github.com/github/spec-kit)(MIT)의 템플릿 구조를 참고해 한국어로 다시 썼다. 라이선스 전문은 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에 있다.
