---
name: orch-report
description: /orchestrate 실행 하나(spec 하나)의 세션 기록을 보고 "왜 이만큼 걸렸나" 보고서를 쓴다. 단계별 시간, 오래 걸린 이유, 워커가 규칙대로 돌았는지, 다음 오케스트레이션의 개선안을 docs/orch-report/ 에 남긴다. 코드와 그 실행의 파일은 고치지 않고, 돌고 있는 orchestrator 에 아무것도 보내지 않는다. "identity 011 왜 이렇게 걸렸어", "오케 시간 분석", "오케스트레이션 보고서", "/orch-report" 같은 요청에 쓴다. spec 을 구현하는 orchestrate, 전체 QA 인 qa-full 과 다르다.
argument-hint: <도메인>-<NNN> (예: identity-011)
---

# 오케스트레이션 보고서: 왜 이만큼 걸렸나

요청: $ARGUMENTS

끝난 실행을 돌아보는 보고서다. 진행 중인 실행이면 지금까지만 쓰고 머리말에 "진행 중"이라고 적는다. 그 실행의 코드, spec·plan·tasks·worklog, 브리프, 백로그를 고치지 않고 orchestrator 터미널에 아무것도 보내지 않는다. 네가 쓰는 파일은 보고서 하나와, 사용자가 고르면 `00-목록.md` 몇 줄뿐이다. 이 기기에는 python 이 없다. 집계는 [timeline.mjs](timeline.mjs)(node, 출력 항목은 파일 머리 주석)·grep·sed 로 한다.

## 경로

- `<메인>`: `C:/Users/user/Desktop/AtMessenger`. `<SPEC>`: `<메인>/docs/spec/<도메인>/<NNN>-*/`. git 밖이라 메인 폴더에만 있다.
- `<이름>`: 인자(예: `identity-011`). 비면 `ls -t ~/.claude/projects | grep -E 'orca-workspaces-AtMessenger-[a-z]+-[0-9]{3}$' | head -1`(가장 최근 Orca 실행 폴더)의 끝을 쓰고, 무엇을 골랐는지 알린다.
- `<LOG>`: 세션 기록 폴더. `~/.claude/projects/`에서 그 실행을 띄운 폴더 경로에서 영숫자가 아닌 글자(`:`·`/`·`.` 등)를 `-`로 바꾼 이름이다. Orca 카드면 `C--Users-user-orca-workspaces-AtMessenger-<이름>`, 메인 폴더에서 띄웠으면 `C--Users-user-Desktop-AtMessenger`다. 어느 쪽인지는 `<SPEC>/worklog.md`의 "통합 worktree" 줄로 안다. 그 줄이 없는 옛 worklog 면 두 폴더 모두 1번 grep 을 한다.
- 산출물(브리프·리뷰·diff·빌드 로그): 통합 worktree 의 `backend/build/orchestrate/<이름 또는 NNN>/`. Orca 카드는 보드에서 Done 으로 옮기면 worktree 째 지워져 **대개 없다.** `<메인>/backend/build/orchestrate/<NNN>/`은 도메인을 가리지 않아 다른 도메인 것일 수 있다. 그래서 그 안에 worklog 에 적힌 `full-<SHA>.log`가 있을 때만 쓴다. 아니면 "지워짐"으로 보고 세션 기록에서 읽는다:
  - 빌드 시간: timeline.mjs 의 백그라운드 표. 시험 수·결과는 worklog.
  - 리뷰 내용: 본 세션 기록에서 그 reviewer 의 완료 알림(`<task-notification>`, `queue-operation`)의 `<result>` 본문. reviewer 는 `subagents/*.meta.json`의 `description`으로 찾고 `toolUseId`로 알림을 맞춘다.
  - 브리프: 워커 `subagents/*.jsonl`에서 그 워커가 처음 읽은 `task-TNNN-brief.md`의 결과. orchestrator 는 브리프를 Write 말고 Bash(heredoc·`sed -i`)로도 쓰고 고치니, 워커가 실제로 본 최종 판은 거기 있다.

## 순서

1. **세션 고르기**: `grep -l '<spec 폴더 이름>' <LOG>/*.jsonl`로 이 실행의 세션을 좁힌다(spec 폴더 이름 예: `011-시계-감시`). 걸린 세션마다 `node <이 스킬 폴더>/timeline.mjs <LOG> --session <세션 id 앞 8자>`를 돌려 머리의 "첫 /orchestrate"와 "push" 줄을 본다. orchestrate 스킬 본문에도 `git push origin HEAD:main` 글자가 있어 grep 으로는 push 한 세션을 못 가른다. timeline 은 결과에 `<a>..<b>  HEAD -> main`이 나온 것만 push 로 센다. push 범위가 worklog 의 push 범위와 같은 세션이 본 실행이다. 그 두 ISO 를 그대로 `--since`·`--until`에 넣어 다시 돌린 것을 본 표로 쓴다. 같은 spec 으로 먼저 시작했다가 push 없이 끝난 세션은 머리말에 "앞선 시도 HH:MM~HH:MM(N분)"으로만 적는다. worklog 에 이 세션보다 앞선 날짜의 작업이 있으면(앞 실행이 이미 main 에 올린 것을 이어 받은 실행) 머리말에 "앞선 실행: <날짜> <작업들>(worklog)"으로 적고 이 세션만 잰다.
2. **모으기**: `<SPEC>/worklog.md`에서 판정, 보류, 수정 라운드, rebase, push 를 적은 줄(`push:`, `**push 완료**:` 등)의 커밋 범위를 읽는다. 커밋은 `git -C <메인> log --oneline <범위>`로 본다. worklog 의 다른 SHA 는 rebase 전 것이라 커밋 제목으로 맞춘다. 작업 수는 `tasks.md`의 체크박스 줄(`- [x] TNNN`) 수다(수정·fix 는 세지 않는다). orchestrator 가 남긴 "회고" 항목(ORCH-021)이 있으면 함께 읽는다. 옛 worklog 에는 없다.
3. **단계 나누기**: 단계는 이름으로 정한다. 준비, `tasks.md`의 Phase 마다 하나, 마지막(컴파일·qa·최종 리뷰·마지막 수정·전체 빌드), push(마지막 전체 빌드 완료 알림부터 push 까지)다. 각 단계의 시작은 그 단계의 첫 워커(Agent)나 전체 빌드·check 를 보낸 시각(timeline 표의 초 단위 시각)이고, 끝은 다음 단계의 시작이다. 그래서 단계 합이 기간과 같다. 다음 단계 것이 앞 단계가 끝나기 전에 나갔어도 단계를 합치지 않는다. 앞 단계에서 넘어와 겹쳐 돈 워커는 "비고"에 적는다. 사용자 지시로 생긴 수정은 그때 단계에 넣고 비고에 "사용자 지시"라고 적는다. "병렬"은 timeline "변화"에서 그 단계 안의 최대값이고, 그때 전체 빌드가 돌았으면 "+빌드"를 붙인다.
4. **이유 찾기**: 가장 긴 단계부터, 끝을 정한 것을 파고든다.
   - 워커면 표의 도구·모델·승인 대기 분을 비교한다.
     - 승인 대기: 사용자 권한 허락이나 질문. 무엇을 하다 막혔는지 그 도구 호출을 본다.
     - 도구: gradle 인지(어느 시험을 몇 번), 탐색인지(무엇을 Read·Grep 했나, 브리프에 적었으면 줄었을까), 같은 실패를 되풀이했는지 본다.
     - 모델: 가장 긴 모델 공백이 어디였는지 본다(예: 워커 여러 명이 동시에 뜬 직후).
   - 수정 라운드면 계기(리뷰, 판정, NEEDS_CONTEXT·BLOCKED, 사용자, 전체 빌드 실패)를 가르고, 같은 종류의 지적이 여러 작업에서 나왔는지 본다.
   - 기다림이면 무엇을 기다렸는지 본다: 전체 빌드, 앞 작업(순서대로 보낸 이유가 worklog 에 있나), 사용자 메시지, 승인, AskUserQuestion. 사용자 개입으로 늘어난 시간은 "그것이 없었으면 push 했을 시각"과 비교해 적는다. 3분 안쪽의 기다림은 멈춤 목록에 안 잡히니 단계표로 판단한다.
   - 회고가 있으면 orchestrator 가 꼽은 이유를 측정값과 맞댄다. 맞으면 근거로 쓰고, 어긋나면 "오래 걸린 이유"의 그 줄에 "회고는 X라 했으나 측정은 Y"로 적는다. 회고의 "사람이 봐야 할 곳"은 측정할 것이 아니니 보고서에 옮기지 않는다.
5. **규칙 대조**: 그 실행이 읽은 판의 규칙으로 대조한다. 그 판은 본 세션 기록에 있다. orchestrate SKILL.md 는 `/orchestrate` 메시지 바로 뒤의 스킬 본문("Base directory for this skill")이고, orchestrator.md 는 그 뒤 그 파일을 읽은 Read 나 Bash(`cat`·`sed -n`) 결과다. 기록에서 못 찾으면 worklog 의 처음 START 에서 `git -C <메인> show <START>:.claude/agents/orchestrator.md`(SKILL.md 도 같게)로 본다. 실행 중 rebase 로 `.claude/`가 바뀌어도 이미 읽은 판은 그대로다. 본 세션이 그 뒤 다시 읽었을 때만 그 뒤 단계에 새 판을 댄다. 주로 볼 것:
   - 병렬로 보낼 수 있는데 순서대로 보냄(ORCH-015)
   - 앞 작업의 리뷰 승인 전에 그 작업이 필요한 다음 작업을 보냄(ORCH-008 거절. ORCH-018 의 먼저 합치기에 맞으면 어긋남이 아니다)
   - worktree 를 만들기 전에 fetch 를 빠뜨림(ORCH-013)
   - 작업마다 전체 시험(ORCH-011)
   - 리뷰어 하나에 여러 작업(ORCH-017)
   - 수정에 앞 be-worker 를 이어 씀(ORCH-009)
   - 메인 폴더에서 빌드(ORCH-006)
   - 전체 시험을 동시에 둘(ORCH-002)
   - qa 전에 전체 빌드를 돌림, 최종 리뷰를 qa 와 함께 보내지 않음(ORCH-023. 2026-10-29 전 실행은 ORCH-007: 최종 리뷰를 전체 빌드가 끝난 뒤에 보냄)
   - 마지막 단계 수정을 한 워커에 몰아줌(ORCH-016)
   - 시험만 고치는 지적에 수정 라운드를 기다림, 브리프에 기존 시험 패턴·확인한 동작을 안 적어 워커가 헤맴(ORCH-018)
   - 워커가 자기 worktree 밖에 파일을 씀
   - 마지막 4번의 재빌드 조건과 다르게 함

   NEEDS_CONTEXT·BLOCKED 와 "끝남"이 아니오인 워커도 적는다. 판정으로 규칙과 다르게 했으면 그 판정이 타당한지 함께 적는다.
6. **개선안**: `<메인>/docs/adr/orchestration/00-목록.md`의 ORCH 결정과 "앞으로 바꿀 것"을 읽는다. 이미 있는 것은 새로 내지 않고 이번 측정값만 더한다(예: ORCH-009 수정 라운드 분, timeline 끝 줄의 훅 오류 수). 새 제안은 4번에서 찾은 이유에서만, 절감이 큰 순으로 세 개까지 낸다.
7. **이전 보고**: 메인 폴더는 origin/main 보다 뒤처져 있을 수 있다. `git -C <메인> fetch origin` 후 `git -C <메인> ls-tree --name-only origin/main docs/orch-report/`로 앞 보고를 찾고 `git show origin/main:<경로>`로 읽는다. 앞 보고가 있으면 가장 최근 것과 단계별 분을 맞대고, 그 개선안이 이번에 반영됐는지 본다.
8. **쓰기·커밋**:
   - `git -C <메인> fetch origin` 후 `git -C <메인> worktree add --detach <메인>/.claude/worktrees/orch-report-<이름> origin/main`을 만든다.
   - 그 안에서 `mkdir -p docs/orch-report`를 하고, `backend/templates/orch-report/orch-report-TEMPLATE.md`를 복사해 `docs/orch-report/YYYY-MM-DD-<도메인>-<NNN>.md`를 채운다. 날짜는 본 세션의 첫 /orchestrate 날짜이고, 같은 이름이 있으면 `-2`를 붙인다. 섹션 제목과 순서는 바꾸지 않는다.
   - 그 파일만 커밋한다. 메시지는 `docs(orch-report): <도메인> <NNN> 오케스트레이션 소요 시간 보고`다.
   - `git push origin HEAD:main`으로 push 한다. 거절되면 `git fetch origin` → `git rebase origin/main` 뒤 다시 push 한다.
   - 그다음 `git -C <메인> worktree remove`로 worktree 를 지운다.

## 보고

사용자에게 보고서의 "결론", 단계별 표, 오래 걸린 이유, 개선안, push 한 커밋을 짧게 알린다. 그다음 개선안 중 어느 것을 `00-목록.md` "앞으로 바꿀 것"에 올릴지 묻는다. 고른 것만 줄마다 측정값과 보고서 경로를 붙여 더하고, 8번처럼 새 worktree 에서 그 파일만 커밋해 push 한다. 고르지 않은 개선안은 보고서에만 남기고 백로그에 쓰지 않는다(사용자가 정한 것이라 남은 일이 아니다). ORCH-NNN 결정을 쓰거나 orchestrator.md 를 고치는 일은 따로 하는 작업이라 하지 않는다.
