# setup: AtMessenger 에서 쓰던 에이전트 설정 그대로

AtMessenger 프로젝트에서 쓰던 에이전트·스킬·템플릿·md·hook·전역/지역 설정을 경로 그대로 옮겨 둔 것이다. 새 프로젝트에서 같은 환경으로 바로 시작할 때 쓴다.

## 구조

```text
setup/
├── install.ps1                   # 아래 두 폴더를 프로젝트·홈에 복사
├── project/                      # → 새 프로젝트 루트에 그대로
│   ├── .claude/
│   │   ├── agents/               # be-worker, orchestrator, reviewer, qa 서브에이전트
│   │   ├── skills/               # orchestrate, orch-report, qa-full, qa-browser
│   │   └── settings.local.json   # 프로젝트 지역 권한
│   ├── backend/
│   │   ├── AGENTS.md             # 레포 규칙(문서 위치·검증 명령 등)
│   │   ├── .claude/              # CLAUDE.md(@AGENTS.md), 공통 AGENTS.md, adr·diagram 스킬
│   │   └── templates/            # adr, backlog, concept, daily, memory, orch-report, qa, troubleshooting
│   └── frontend/CLAUDE.md        # 프런트 규칙
└── global/                       # → 홈(C:\Users\<나>\)에 그대로
    ├── .claude/
    │   ├── CLAUDE.md, AGENTS.md  # 전역 지침
    │   ├── settings.json         # 전역 설정(hook 등록, 플러그인, 모델, autoMode)
    │   ├── settings.local.json   # 전역 지역 권한
    │   ├── keybindings.json
    │   └── hooks/                # orca-card-status.js, kill-idle-terminal-shells.ps1, be-worker-gate.js
    └── .codex/
        ├── AGENTS.md             # Codex 전역 지침
        └── hooks.json            # Codex hook 등록
```

## 설치

```powershell
cd setup
.\install.ps1 -Project C:\path\to\new-project   # 프로젝트 파일만
.\install.ps1 -Global                          # 전역 파일만(기존 파일은 .bak 로 남김)
```

프로젝트에 같은 이름의 파일이 있으면 건너뛴다. 덮어쓰려면 `-Force` 를 붙인다.

## 복사한 뒤 고칠 것

- AtMessenger 전용 내용(도메인, cafe24, Gradle 명령, spec 경로 등)이 그대로 들어 있다. `backend/AGENTS.md`, `.claude/skills/*`, `.claude/agents/*` 를 새 프로젝트에 맞게 고친다. 프로젝트에 `backend/`·`frontend/` 가 없으면 해당 파일을 알맞은 위치로 옮긴다.
- 이 레포는 공개라서 `global/.claude/CLAUDE.md` 와 `settings.json` 의 사내 기기 IP 는 `<air IP>` 같은 자리표시자로 바꿔 두었다. 전역 설치 뒤 실제 값으로 채운다.
- hook 경로는 `C:/Users/user/...`, `C:/Users/user/.orca/...` 로 박혀 있다. 사용자 이름이나 Orca 설치 위치가 다르면 `settings.json`·`hooks.json`·`hooks/*.js` 의 경로를 고친다.
- `settings.json` 의 `autoMode.environment` 는 AtMessenger 를 신뢰 레포로 적어 둔 값이다. 새 프로젝트에 맞게 고친다.

## 넣지 않은 것

- 로그인 정보·기계 상태: `~/.claude/.credentials.json`, `.claude.json`, `~/.codex/auth.json`, `~/.codex/config.toml`(프로젝트 신뢰 목록·플러그인 상태라 기계마다 다름)
- 전역 스킬 `~/.claude/skills/*`: 사내 계정·운영 정보가 섞여 있고 대부분 외부에서 받은 스킬이라 뺐다. 플러그인은 `settings.json` 의 `enabledPlugins` 로 다시 설치된다.
- 프로젝트 메모리(`~/.claude/projects/.../memory/`)와 AtMessenger 의 `docs/` 내용
- AtMessenger 에서 아직 커밋하지 않은 수정(이 스냅숏은 커밋된 HEAD 기준)
