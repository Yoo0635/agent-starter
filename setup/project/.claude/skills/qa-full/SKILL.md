---
name: qa-full
description: 지금 origin/main 을 도메인별로 전체 QA 한다. 실행 jar 만 빌드한 뒤 spec 인수 시나리오를 묶음으로 나눠 qa 서브에이전트를 병렬로 보내고, 요약을 docs/qa/ 에 남겨 이전 실행과 비교한다. 코드는 고치지 않는다. "/qa-full", "전체 QA 돌려줘", "도메인별 QA", "연동 전·후 QA" 같은 요청에 쓴다. spec 하나를 구현하는 orchestrate 와 다르다.
argument-hint: [identity|customer ...] [비교: <docs/qa/이전 파일>]
---

# 도메인별 전체 QA

요청: $ARGUMENTS

지금 세션이 지휘한다. qa 서브에이전트만 부른다. 코드·시험·spec 은 고치지 않는다. 네가 쓰는 파일은 브리프, 보고 원본, `docs/qa/` 요약, 백로그 항목뿐이다. 시작할 때 `backend/AGENTS.md`를 읽는다. 이 기기에는 python이 없다. 집계는 grep·sed·node로 한다.

## 인자

- 도메인: 비면 `docs/spec/` 아래 HTTP 시나리오가 있는 도메인 전부(지금 identity, customer). common 은 보지 않는다. 시험은 push 전 `full-build.sh` 와 CINX 가 돌리므로 여기서는 돌리지 않는다.
- 비교: 비면 spec 마다 `docs/qa/`에서 그 spec 행이 있는 가장 최근 파일(이름순 마지막). 없으면 그 spec 은 비교하지 않는다. 도메인을 나눠 따로 돌린 실행끼리도 이렇게 맞대어진다.

## 경로

- `<루트>`: `git rev-parse --show-toplevel`(이 세션의 폴더. Orca 카드면 그 worktree). `<메인>`: `git worktree list --porcelain`의 첫 `worktree` 줄(메인 폴더 `Desktop/AtMessenger`). `<WT>`: `<루트>/.claude/worktrees/qa-full-<짧은 SHA>-<도메인들>`. `<OUT>`: `<WT>/backend/build/orchestrate/qa-full/<짧은 SHA>-<도메인들>/`. `<도메인들>`은 대상 도메인을 `-`로 이은 것(예: `identity`, `identity-customer`).
- `docs/spec/`, `docs/concept/guide/`, `application-local.yaml`은 git에 없어 `<WT>`에도 Orca 카드에도 없다. 메인 폴더에만 있다. spec 과 GUIDE-037 은 `<메인>/docs/...` 절대 경로로 읽게 한다. DB·SSO 설정은 환경 변수와 앱 인자로만 넣는다.
- 도메인을 나눠 여러 세션에서 동시에 돌려도 되게 자원은 도메인마다 따로 둔다. 도메인 기준값: identity `B=28000, D=13400`, customer `B=29000, D=13500`, 그 밖의 도메인은 `B=30000, D=13600`부터 1000·100씩 올린다.

## 순서

1. **준비:**
   - `git -C <루트> fetch origin` 후 `git -C <루트> worktree add --detach <WT> origin/main`. 전체 SHA를 기록하고 `mkdir -p <OUT>`.
   - 대상 spec 마다 확인 항목 수를 센다: 시나리오 `grep -c -E '^[0-9]+\. \*\*Given\*\*'`, 성공 기준 `grep -c -E '^- \*\*SC-[0-9]+\*\*'`. 둘을 더한 값이 그 spec 의 항목 수다.
2. **빌드:** `<WT>/backend`에서 `./gradlew :launcher:bootJar > <OUT>/build-<SHA>.log 2>&1`만 돌린다. 시험은 돌리지 않는다(push 전 `full-build.sh` 와 CINX 가 본다).
   - 컴파일 실패나 jar(`backend/launcher/build/libs/launcher-*-SNAPSHOT.jar`, plain 아님)가 없으면 QA 없이 실패를 보고하고 6번(백로그)·7번·8번만 한다.
3. **묶음:** 도메인마다 spec 을 번호순으로 이어 붙이다 항목 합이 50을 넘기기 직전에 끊는다. spec 하나를 두 묶음으로 나누지 않는다. spec 하나가 50을 넘으면 그 spec 만으로 한 묶음이다. 묶음 이름은 `<도메인>-a`, `-b`…. 도메인 안에서 번호 `i`(0부터)를 매긴다. 묶음 `i`의 자원: 앱 포트 `B+80+10i`, DB 컨테이너 `qafull-<묶음>-db` 호스트 포트 `D+i`, 작업 폴더 `<OUT>/tmp-<묶음>/`. 띄우기 전에 그 포트와 컨테이너 이름이 비었는지 본다(`netstat -ano | grep :<포트>`, `docker ps -a --filter name=`).
   - 동시에 4묶음까지 띄운다. 4번을 보내기 직전에 빈 메모리(`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory"`, KB)가 6GB 미만이면 2묶음까지로 줄인다. 남은 묶음은 앞 묶음이 끝나는 대로 보낸다.
   - 가짜 SsoNX 는 네가 하나만 띄워 모든 묶음이 같이 쓴다(`FakeSsoServer`는 `redirect_uri`를 요청마다 받고 코드를 동시성 맵에 둔다). 포트는 대상 도메인 중 첫 도메인의 `B+79`다(`<SSO 포트>`). `<WT>/backend`에서 `./gradlew fakeSso -Pport=<SSO 포트> > <OUT>/fake-sso.log 2>&1 &`로 띄우고 로그의 `client-secret`을 브리프에 적는다.
   - 앱은 `bootRun` 대신 2번이 만든 jar 를 `java -Duser.timezone=UTC -jar`로 띄우게 한다. 같은 worktree에서 Gradle 을 여럿 동시에 돌리지 않기 위해서다.
4. **qa 보내기:** 묶음마다 [brief-template.md](brief-template.md)를 채워 `<OUT>/brief-<묶음>.md`로 쓰고, 한 메시지에서 동시에 보낼 묶음 수만큼 qa 를 부른다(`subagent_type: qa`). 프롬프트에는 브리프 경로만 준다. NEEDS_CONTEXT 면 맥락을 더해 그 묶음만 다시 보낸다.
5. **취합:**
   - 보고를 `<OUT>/report-<묶음>.md`로 저장한다.
   - `건너뜀(시험으로 확인: <클래스>)`은 그대로 둔다. 시험 결과는 이 실행에서 보지 않는다.
   - `backend/templates/qa/qa-TEMPLATE.md`를 복사해 `<WT>/docs/qa/YYYY-MM-DD-<짧은 SHA>-<도메인들>.md`를 채운다. 같은 이름이 있으면 `-2`, `-3`을 붙인다.
   - spec 마다 비교 대상 파일의 "항목 수"가 같은지 먼저 본다. 다르면 그 spec 은 "spec 바뀜, 비교 안 함"으로만 적는다. 같으면 이전의 "실패"·"건너뛴 항목" 표와 맞대어 상태가 바뀐 항목만 "이전 대비 바뀐 것"에 적는다(두 표에 없는 항목은 통과다).
6. **백로그:** 쓰기 직전에 `git fetch origin`으로 받아 `origin/main`의 `tasks/<도메인>/`·`completed/<도메인>/`에서 도메인마다 가장 큰 번호를 다시 센다(다른 세션이 그사이 번호를 썼을 수 있다). 실패를 원인별로 묶어 `docs/backlog/tasks/<도메인>/`에 항목 하나씩 쓴다(`docs/backlog/readme.md` 규칙, labels `나중할일`, references 에 요약 파일). 같은 원인의 항목이 이미 있으면 거기에 줄을 더한다. 요약의 "실패" 표에 항목 번호를 적는다. 고치지 않는다. 고치기는 사용자가 정해 따로 `/orchestrate` 로 한다.
7. **커밋·push:** `<WT>`에서 요약과 백로그만 커밋한다. `git fetch origin` → `git rebase origin/main` → `git push origin HEAD:main`. rebase 로 들어온 커밋에 같은 백로그 id(`<접두>-N`)가 있으면 내 항목의 번호를 올려 다시 커밋한다. 문서만 바뀌니 빌드를 다시 돌리지 않는다.
8. **정리:** 이 실행의 가짜 SsoNX 를 끈다. qa 가 끄지 못한 이 실행의 앱 프로세스와 포트, `qafull-<이 실행의 묶음>-db` 컨테이너와 볼륨(`docker rm -f -v`)이 남지 않았는지 본다. 다른 실행의 `qafull-*`, `backend-db-1`, `backend_db-data`, 공용 시험 DB(`workbench-test-db`)는 건드리지 않는다. `<OUT>`을 `<메인>/backend/build/orchestrate/qa-full/`로 복사하고 `git -C <루트> worktree remove <WT>`.

## Orca 카드 상태

1번 준비에서 `"$O" worktree show --worktree path:<루트> --json`으로 확인한다. `O=/c/Users/user/AppData/Local/Programs/orca/resources/bin/orca.cmd`다(PATH에 없음). 실패하거나 `isMainWorktree`가 true면(메인 폴더 카드) 이 절은 통째로 건너뛴다. 아니면 아래 시점에 `"$O" worktree set --worktree path:<루트> ... --json`을 부른다. `--worktree active`는 쓰지 않는다. 명령이 실패해도 QA 는 멈추지 않는다.

- 1번 시작: `--workspace-status in-progress --comment "qa-full <도메인들> <짧은 SHA> 시작"`
- 2번 빌드 끝: `--comment "jar 빌드 끝"`
- 묶음 보고를 받을 때: `--comment "<묶음> 끝, <끝난 묶음 수>/<전체 묶음 수>"`
- "멈추고 묻는 경우"로 멈출 때: `--comment "멈춤: <한 줄 이유>" --unread`
- 7번 push 끝: `--workspace-status in-review --comment "push <짧은 해시>, QA 실패 <수>, 백로그 <id들>" --unread`
- `completed`(Done)는 넣지 않는다. 사용자가 요약을 보고 보드에서 직접 옮긴다.

## 보고

사용자에게 요약 파일의 "결론"과 "이전 대비 바뀐 것", 새로 쓴 백로그 번호, push한 커밋을 짧게 알린다. 실패를 고칠지는 묻기만 한다.

## 멈추고 묻는 경우

Docker 가 없음, 포트·컨테이너 이름이 이미 쓰이고 있음(남의 것일 수 있음). spec 의 `[확인 필요]`는 멈추지 않는다. 그 항목을 건너뜀으로 적고 요약에 모은다.
