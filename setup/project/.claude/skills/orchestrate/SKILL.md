---
name: orchestrate
description: 이 레포의 spec 하나(docs/spec/<도메인>/<NNN-기능>/)를 be-worker → reviewer → qa 서브에이전트로 나눠 구현할 때 사용. "/orchestrate", "오케스트레이션 돌려줘", "이 spec 오케로 구현해" 같은 요청에 쓴다. 지금 세션이 orchestrator가 되어 worker를 worktree별로 병렬로 보낸다. Orca 탭을 지휘하는 orchestration 스킬, Agent Factory 팀 run과는 다르다.
argument-hint: 이슈: <이슈 제목>, spec: <spec 폴더 경로>
---

# spec 하나를 오케스트레이션으로 구현

요청: $ARGUMENTS

지금 세션이 orchestrator다. orchestrator 서브에이전트를 따로 띄우지 않는다. 서브에이전트는 다시 서브에이전트를 부를 수 없어서, 띄우면 be-worker를 못 보낸다.

## 지침

`.claude/agents/orchestrator.md`의 본문(머리말 아래 전부)을 이 작업의 지침으로 읽고 그대로 따른다. 아래는 이 세션에서 돌릴 때 덧붙는 규칙이다.

## 이 세션에서 돌릴 때

- **be-worker 부르기:** Agent 도구의 `subagent_type: be-worker`(sonnet, effort medium)로 바로 부른다. 병렬로 돌릴 작업은 한 메시지에 Agent 호출을 여러 개 넣는다. 결과는 각자 끝나는 대로 돌아온다(ORCH-053).
- **reviewer·qa 부르기:** Agent 도구로 바로 보내지 않는다. orchestrator.md "워커 보내기"대로 Orca 에이전트 탭에 Codex(reviewer는 `gpt-6.1-sol` effort medium, qa는 `gpt-6.1-terra` effort low)를 먼저 띄운다. 그 절의 3번(사용량 소진·Codex 실패)에서만 Agent 도구로 `reviewer`(opus)·`qa`(sonnet)를 부른다.
- **경로:** 메인 폴더(`Desktop/AtMessenger`)에서 띄웠으면 orchestrator.md "시작"대로 통합 worktree를 먼저 만들고 그 안에서 진행한다. 이 세션의 작업 폴더가 `backend/`일 수 있다. git과 worktree 명령은 레포 루트(`git rev-parse --show-toplevel`) 기준으로 `git -C <루트> ...`로 쓴다. worktree는 `<루트>/.claude/worktrees/orch-<NNN>-TNNN`에 만들고, 브리프에는 그 절대 경로를 적는다. 같은 폴더의 `orch-`가 아닌 worktree는 데스크톱 앱 것이니 건드리지 않는다.
- **시작 조건:** 요청에 이슈 제목과 spec 경로가 없으면 묻는다. `.claude/`는 git이 추적하지 않는 로컬 설정이라 '커밋 안 된 변경'으로 세지 않는다.
- **진행 표시:** 작업(TNNN)마다 시작·리뷰·합침·완료를 짧게 알린다. 병렬로 보낸 작업은 무엇을 동시에 보냈는지 한 줄로 적는다.
- **Orca 카드 상태:** 시작할 때 세션 폴더의 레포 루트(`git rev-parse --show-toplevel`)를 `<카드>`로 잡고 `"$O" worktree show --worktree path:<카드> --json`으로 확인한다. `O=/c/Users/user/AppData/Local/Programs/orca/resources/bin/orca.cmd`다(PATH에 없음). 실패하거나 `isMainWorktree`가 true면(메인 폴더 카드) 이 규칙은 통째로 건너뛴다. 아니면 아래 시점에 `"$O" worktree set --worktree path:<카드> ... --json`을 부른다. `--worktree active`는 쓰지 않는다. 명령이 실패해도 오케스트레이션은 멈추지 않는다.
  - 시작: `--workspace-status in-progress --comment "<TNNN 범위> 시작"`
  - 작업을 합칠 때: `--comment "<TNNN> 합침, <끝난 수>/<전체 수>"`
  - 사용자 판단이 필요해 멈출 때: `--comment "<TNNN> 막힘: <한 줄 이유>" --unread`
  - main push 끝: `--comment "main push <짧은 해시>, 최종 리뷰 지적 <수>" --unread`(상태는 넣지 않는다. 카드는 Build에 둔다)
  - 칸 이동은 전역 hook(`~/.claude/hooks/orca-card-status.js`)이 한다. qa가 뜨면(Codex qa 탭을 띄우는 `agent launch`도 같다) `in-review`(QA), "마지막" 4번의 `full-build.sh --push`를 부르면 `completed`(Build, 보드의 Done 칸 이름을 바꾼 것), 빌드가 실패해 be-worker를 부르거나 `src/main`·`src/test`를 고치기 시작하면 QA, 다시 `--push`로 돌리면 Build로 간다. 그래서 상태는 위 규칙에 적지 않는다. ORCH-018 check의 `full-build.sh <로그> …`(`--push` 없음)는 Build로 옮기지 않는다.
  - 보드에서 카드를 손으로 Build(`completed`) 칸에 끌면 워크트리가 지워져 `backend/build/orchestrate/` 산출물이 사라진다(CLI로 `completed`를 넣으면 카드만 옮겨지고 워크트리는 남는다, 2026-10-28 확인).
- **오래 걸리는 명령:** `full-build.sh`(전체 빌드, check)는 Bash `run_in_background`로 돌리고, 기다리는 동안 다른 작업의 리뷰를 진행한다. 끝나면 로그 끝의 `다음:` 줄대로 한다. "마지막" 1번 컴파일은 짧으니 기다렸다가, 결과가 나오면 2번 qa와 3번 최종 리뷰를 한 메시지에서 함께 건다(둘 다 코드를 고치지 않는다, ORCH-023).
- **메모리 부족으로 멈춘 것:** 빌드·시험·워커(Codex 탭, 서브에이전트)가 메모리 부족으로 끝나면(`OutOfMemoryError`, `paging file`, "메모리 부족"으로 강제 중단 등) 1분 기다렸다가 같은 명령을 다시 돌린다. 기다림은 Bash `run_in_background`로 `sleep 60; <같은 명령>`처럼 붙여서 한다. 다시 돌리기는 한 대상에 10번까지다. 10번째도 메모리 부족이면 멈추고 사용자에게 알린다. 이 경우는 orchestrator.md의 "실행 환경 실패는 한 번만 다시 돌린다"(ORCH-023)보다 이 규칙을 따른다. 횟수는 `worklog.md`에 적는다.
- **컨텍스트 기동 알리기:** "마지막" 4번의 `full-build.sh`가 끝나면(끝 코드와 상관없이 시험이 돌았으면) 통합 worktree의 `backend`에서 `bash <레포 루트>/.claude/skills/orchestrate/context-starts.sh <START>`를 돌린다. 이 이슈에서 바뀐 시험이 띄운 컨텍스트가 나와도 공통 기반 클래스·맨몸 모양(`@SpringBootTest` + 방언 `@Import`만)을 물려받았거나 예외 줄이 있으면 넘어간다. 나머지만 5번 보고에 "새 컨텍스트"(클래스·부모·모듈별 기동 수)로 적는다. 묶거나 고치지는 않는다(R-TEST-14, common/013).
- **python 없음:** 이 기기에는 python이 없다. 집계·가공은 grep·sed·node로 한다. 브리프에도 이 점과 "파일은 Write·Edit 도구로 쓴다"를 적는다.
- **끝:** `main` push는 사용자에게 묻지 않는다. "마지막" 4번의 `full-build.sh --push`가 한다. 코드(`backend` 의 `.md` 아닌 파일)가 든 main push를 그 밖에서 하면 git `pre-push` hook이 거절한다(ORCH-035). 마지막에 `git worktree list`로 이 이슈의 worktree가 남지 않았는지 확인한다.
- **Gradle 데몬 끄기:** 그다음 `<루트>/backend`에서 `./gradlew --status`를 본다. `BUSY` 데몬이 없을 때만 `./gradlew --stop`으로 데몬을 끈다(메모리 반납). `--stop`은 이 기기의 같은 Gradle 버전 데몬을 전부 끄므로, `BUSY`가 하나라도 있으면 다른 실행의 빌드이니 끄지 않고 둔다(30분 쉬면 저절로 꺼진다).
