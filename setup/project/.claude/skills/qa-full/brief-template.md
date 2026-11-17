# qa 브리프: <묶음> (<도메인> <첫 spec>~<끝 spec>)

<!-- qa-full 스킬이 묶음마다 채워 `<OUT>/brief-<묶음>.md`로 쓴다. `<...>`는 모두 실제 값으로 바꾼다. -->

너는 `.claude/agents/qa.md`대로 확인한다. 아래가 이번 확인의 값이다. qa.md 와 다르면 이 브리프를 따른다. 소스·시험·spec·문서는 고치지 않는다. 파일을 쓰지 말고 보고를 마지막 응답으로 돌려준다.

## 대상

- 레포: `<WT>` (detach, `<전체 SHA>`). 명령은 `<WT>/backend`에서 돌린다.
- spec(이 worktree에는 없다. 메인 폴더에서 읽기만 한다):
  - `<메인>/docs/spec/<도메인>/<NNN-기능>/spec.md` — 시나리오 <N>개, 성공 기준 <N>개
  - <...>
- 각 spec 의 "인수 시나리오"와 "성공 기준"(SC)을 전부 확인한다. 번호는 `<spec 번호> US<스토리>-<번호>`, `<spec 번호> SC-<NNN>`으로 적는다.

## 빌드 결과 (다시 돌리지 않는다)

- SHA `<전체 SHA>`, `./gradlew :launcher:bootJar` 성공(시험은 돌리지 않았다)
- 로그: `<OUT>/build-<SHA>.log`
- 앱 jar: `<WT>/backend/launcher/build/libs/launcher-*-SNAPSHOT.jar`(plain 아님)

## 띄우기

절차는 `<메인>/docs/concept/guide/GUIDE-037-로컬에서-로그인-토큰-받기.md`를 따르되 아래 값으로 바꾼다. GUIDE 의 `wb-qa-db`·`13399`·`18080`·`18081`은 모두 아래 값으로 읽는다.

| 항목 | 값 |
|---|---|
| DB 컨테이너 | `qafull-<묶음>-db`, `mariadb:12.0.2`, 호스트 포트 `<D+i>`, `<WT>/backend/docker/db-init` 마운트 |
| 마운트 | Git Bash 가 컨테이너 쪽 경로를 바꿔 버린다. `MSYS_NO_PATHCONV=1 docker run ... -v "$(pwd -W)/docker/db-init:/docker-entrypoint-initdb.d:ro"`로 쓴다(2026-10-28 실측: 안 쓰면 `/x`가 `X:/`로 바뀐다). 앱 로그에서 `identity_app` 접속이 되는지 본다 |
| 작업 폴더 | 응답 본문·쿠키 파일은 `<OUT>/tmp-<묶음>/`에만 둔다. 다른 qa 가 같은 worktree 에서 동시에 돈다 |
| DB 비밀번호 5개 | 이 컨테이너에서만 쓰는 값을 직접 정한다(작은따옴표 금지) |
| 앱 | `java -Duser.timezone=UTC -jar <jar> <GUIDE-037 3단계 인자>`, `--server.port=<B+80+10i>` |
| 가짜 SsoNX | 이미 떠 있다. issuer `http://127.0.0.1:<SSO 포트>`, client-id `worknx-local`, client-secret `<값>`. 끄지 않는다 |
| 앱 로그 | `<OUT>/qa-<묶음>-app.log` |

- 시드는 GUIDE-037 "사용자 시드 넣기"대로 넣는다. `identity_link.issuer`는 `http://127.0.0.1:<SSO 포트>`다. 시나리오가 요구하는 시드(권한 투영 등)는 spec 의 Given 대로 더 넣는다.
- 토큰은 실제 로그인 경로(`/api/v1/auth/login` → 가짜 SsoNX → `/api/v1/auth/callback`)로 받는다. `login_hint`로 `sub`를 고른다.
- 조직 확인은 2시간이 지나면 낡는다(`workbench.identity.org-max-age`). 시작한 지 2시간이 넘으면 `org_sync_run`의 세 시각을 `UTC_TIMESTAMP(6)`로 다시 바꾼다.

## 시간과 출력

- 항목 하나에 10분을 넘기지 않는다. 큰 데이터가 필요한 항목은 spec 이 요구하는 가장 작은 크기로 만든다. 10분 안에 끝나지 않으면 `건너뜀(시간 초과: <얼마나 진행됐는지>)`으로 적고 다음 항목으로 간다.
- 응답은 상태 코드와 본문 앞 300자만 잡는다(예: `curl -s -o <OUT>/tmp-<묶음>/body.json -w '%{http_code}'` 후 `head -c 300` 으로 본다). 헤더가 판정에 필요한 항목만 `-i`를 쓴다.

## 판정

- 상태는 `통과 | 실패 | 건너뜀(이유)` 셋이다. 건너뜀은 HTTP로 확인할 수 없는 항목만 쓴다. 예: 비서 토큰 필요(비서 establish 미구현), 내부 시계·스케줄러만 바뀌는 항목, PostgreSQL 이 필요한 항목.
- 그 항목을 덮는 자동 시험이 있으면 `건너뜀(시험으로 확인: <시험 클래스>)`로 적는다. 시험 결과는 이 실행에서 보지 않는다.
- 실제 응답(상태 코드, 본문 일부)을 잡지 않은 항목은 통과로 적지 않는다.
- spec 에 `[확인 필요]`가 남아 Then 을 정할 수 없으면 건너뜀으로 적고 이유에 그 문구를 옮긴다.

## 정리

- 끝나면(실패해도) 앱 프로세스를 끄고 포트 `<B+80+10i>`가 비었는지 본다. `docker rm -f -v qafull-<묶음>-db`.
- 가짜 SsoNX(<SSO 포트>), `backend-db-1`, `backend_db-data`, `workbench-test-db`는 건드리지 않는다.
- 이 기기에는 python 이 없다. 응답 가공은 grep·sed·node 로 한다.

## 보고

qa.md "출력 형식"대로 쓰되, 통과한 항목은 번호만 한 줄로 묶는다(예: `통과: 004 US1-1~5, US2-1~3, SC-001~004`). 실패와 건너뜀만 TC 로 자세히 쓴다. 맨 끝에 spec 별 `통과/실패/건너뜀` 수 표를 붙인다.
