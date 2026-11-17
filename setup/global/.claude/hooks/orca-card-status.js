// Orca 칸반 카드 자동 이동: 프롬프트를 받으면 in-progress, qa 서브에이전트가 뜨면 in-review(QA), 전체 빌드를 시작하면 completed(Build),
// 턴이 끝나면 in-review + 읽지 않음(Build 카드는 Build 그대로 읽지 않음만).
// qa 는 오케스트레이션(orchestrate·qa-full)이든 그냥 구현하다 qa 를 보내든 같은 SubagentStart(matcher qa)로 잡힌다.
// orchestrate 가 Codex qa 를 Orca 탭으로 띄우는 Bash(PreToolUse)도 같게 잡는다.
// qa 가 뜨면 그 세션은 QA 단계다. 서브에이전트 알림·다른 세션 안내로 새 턴이 들어와도 in-progress 로 되돌리지 않는다.
// QA 단계는 백그라운드 작업이 모두 끝난 Stop 에서 끝난다.
// 전체 빌드는 `full-build.sh --push`(오케스트레이션 마지막 4번) 또는 `gradlew build`(그냥 구현할 때)다. 빌드가 실패해 고치기 시작하면
// (src/main·src/test 를 Edit·Write 하거나 be-worker 를 띄우면) QA 로 돌리고, 다시 전체 빌드를 시작하면 Build 로 간다.
// Build 칸은 보드에서 Done 이던 completed 의 이름만 바꾼 것이다. Build 카드에 새 프롬프트가 와도 in-progress 로 되돌리지 않는다.
// 메인 폴더 카드, Orca 카드가 아닌 폴더는 건드리지 않는다.
// 턴이 끝나도 백그라운드 작업(서브에이전트·백그라운드 Bash)이 아직 돌고 있으면 옮기지 않는다.
// 무엇이 실패해도 조용히 끝낸다(UserPromptSubmit 의 stdout 은 대화에 들어가므로 아무것도 찍지 않는다).
const { execFileSync, execSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ORCA = 'C:/Users/user/AppData/Local/Programs/orca/resources/bin/orca.cmd';
const QA_MARK_DIR = path.join(os.tmpdir(), 'orca-card-qa'); // 세션별 QA 단계 표시
const BUILD_MARK_DIR = path.join(os.tmpdir(), 'orca-card-build'); // 세션별 전체 빌드 표시(안에 카드 selector)
const BUILD = 'completed'; // 보드의 Build 칸

function orca(args) {
  return execSync(`"${ORCA}" ${args.map((a) => `"${a}"`).join(' ')}`, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
    timeout: 8000,
  });
}

// 전체 빌드인가: full-build.sh --push, 또는 gradlew 의 작업에 build 가 있다(:모듈:build·compileJava·bootJar 는 아님).
// 명령 맨 앞이나 ;·&&·| 뒤에서 부를 때만 센다(커밋 메시지 안의 글자는 아님).
const CMD_START = String.raw`(?:^|[;&|\n(]\s*)(?:\w+=\S*\s+)*`;
function isFullBuild(command) {
  if (new RegExp(CMD_START + String.raw`(?:bash\s+|sh\s+)?\S*full-build\.sh\b[^;&|\n]*--push`).test(command)) return true;
  for (const m of command.matchAll(new RegExp(CMD_START + String.raw`\S*gradlew(?:\.bat)?([^;&|\n]*)`, 'g'))) {
    if (m[1].split(/\s+/).includes('build')) return true;
  }
  return false;
}

// 세션 기록에서 띄운 작업과 끝났다는 <task-notification> 을 순서대로 맞춰 아직 안 끝난 작업이 있는지 본다.
function hasPendingBackgroundTask(transcriptPath) {
  const running = new Set();
  for (const line of fs.readFileSync(transcriptPath, 'utf8').split('\n')) {
    let d;
    try {
      d = JSON.parse(line);
    } catch {
      continue; // 빈 줄이나 아직 쓰는 중인 마지막 줄
    }
    let text = '';
    if (d.type === 'user') {
      const r = d.toolUseResult;
      if (r && r.status === 'async_launched' && r.agentId) running.add(r.agentId);
      if (r && r.backgroundTaskId) running.add(r.backgroundTaskId);
      if (r && r.resumedAgentId) running.add(r.resumedAgentId); // SendMessage 로 다시 깨운 에이전트
      if (r && r.task_id && String(r.message).startsWith('Successfully stopped')) running.delete(r.task_id); // TaskStop 은 알림이 없다
      const c = d.message && d.message.content;
      text = typeof c === 'string' ? c : Array.isArray(c) ? c.map((x) => x.text || '').join('\n') : '';
    } else if (d.type === 'attachment' && d.attachment && d.attachment.type === 'queued_command') {
      text = String(d.attachment.prompt || ''); // 턴 도중에 도착한 알림
    }
    for (const m of text.matchAll(/<task-notification>\s*<task-id>([^<]+)<\/task-id>/g)) running.delete(m[1]);
  }
  return running.size > 0;
}

function showCard(card) {
  return JSON.parse(orca(['worktree', 'show', '--worktree', card, '--json'])).result.worktree;
}

try {
  const input = JSON.parse(fs.readFileSync(0, 'utf8'));
  const event = input.hook_event_name;
  const qaMark = path.join(QA_MARK_DIR, String(input.session_id));
  const buildMark = path.join(BUILD_MARK_DIR, String(input.session_id));

  // 빌드가 실패해 고치기 시작함: Build → QA. 카드는 빌드를 시작할 때 적어 둔 것을 쓴다(be-worker 는 다른 worktree 에서 고친다).
  const toolInput = input.tool_input || {};
  const fixing =
    (event === 'PreToolUse' &&
      input.tool_name !== 'Bash' &&
      /\/src\/(main|test)\//.test(String(toolInput.file_path || toolInput.notebook_path || '').replace(/\\/g, '/'))) ||
    (event === 'SubagentStart' && input.agent_type === 'be-worker') ||
    (event === 'PreToolUse' && input.tool_name === 'Bash' && /\bcodex exec\b/.test(String(toolInput.command || '')));
  if (fixing) {
    if (!fs.existsSync(buildMark)) process.exit(0);
    const card = fs.readFileSync(buildMark, 'utf8');
    fs.rmSync(buildMark, { force: true });
    fs.mkdirSync(QA_MARK_DIR, { recursive: true });
    fs.writeFileSync(qaMark, new Date().toISOString()); // Stop 까지 알림 턴이 in-progress 로 되돌리지 못하게
    const wt = showCard(card);
    if (wt && wt.workspaceStatus === BUILD) orca(['worktree', 'set', '--worktree', card, '--workspace-status', 'in-review', '--json']);
    process.exit(0);
  }

  // Codex qa 탭(orchestrator.md "qa 보내기"의 `orca agent launch ... 너는 qa다`)을 띄우는 것도 qa 서브에이전트가 뜬 것과 같다.
  const command = String(toolInput.command || '');
  const qaStart =
    (event === 'SubagentStart' && input.agent_type === 'qa') ||
    (event === 'PreToolUse' && input.tool_name === 'Bash' && new RegExp(CMD_START + String.raw`\S+\s+agent\s+launch\b[^;&|]*너는 qa다`).test(command));
  let status = qaStart ? 'in-review' : { UserPromptSubmit: 'in-progress', Stop: 'in-review', PreToolUse: BUILD }[event];
  if (!status) process.exit(0);
  if (event === 'PreToolUse' && !qaStart && !(input.tool_name === 'Bash' && isFullBuild(command))) process.exit(0);
  if (event === 'Stop' && hasPendingBackgroundTask(input.transcript_path)) process.exit(0);

  if (qaStart) {
    fs.mkdirSync(QA_MARK_DIR, { recursive: true });
    fs.writeFileSync(qaMark, new Date().toISOString());
  }
  if (event === 'UserPromptSubmit' && fs.existsSync(qaMark)) process.exit(0);
  if (event === 'Stop') fs.rmSync(qaMark, { force: true });

  const root = execFileSync('git', ['-C', input.cwd, 'rev-parse', '--show-toplevel'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
  }).trim();
  const card = `path:${root}`;
  const wt = showCard(card);
  if (!wt || wt.isMainWorktree) process.exit(0);
  if (event === 'PreToolUse' && !qaStart) {
    fs.mkdirSync(BUILD_MARK_DIR, { recursive: true });
    fs.writeFileSync(buildMark, card); // 빌드 결과를 보고 고치기 시작하면 위 fixing 이 QA 로 돌린다(다음 턴이어도)
  }
  if (wt.workspaceStatus === BUILD) {
    if (event === 'UserPromptSubmit') process.exit(0); // Build 카드는 고치기 시작할 때만 QA 로 간다
    if (event === 'Stop') status = BUILD; // 빌드가 끝난 턴이면 Build 에 둔 채 읽지 않음만
  }

  const args = ['worktree', 'set', '--worktree', card, '--workspace-status', status, '--json'];
  if (event === 'Stop') args.push('--unread');
  orca(args);
} catch {}
