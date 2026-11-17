// be-worker 서브에이전트 문지기: 오케스트레이션의 be-worker 일은 Codex(Orca 에이전트 탭)가 먼저 한다(orchestrator.md "워커 보내기").
// Agent 도구로 be-worker 를 띄우려 하면, 프롬프트의 브리프 경로가 가리키는 이슈 폴더(build/orchestrate/<NNN>/)에
// codex-exhausted 파일이 있을 때만 통과시킨다. orchestrator 는 Codex 사용량 소진·실패를 화면에서 본 뒤에만 그 파일을 쓴다.
// be-worker 가 아닌 호출과 입력을 못 읽은 경우는 그냥 통과시킨다.
const fs = require('fs');
const path = require('path');

const MARK = 'codex-exhausted';

function deny(reason) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: reason },
  }));
}

let input;
try {
  input = JSON.parse(fs.readFileSync(0, 'utf8'));
} catch {
  process.exit(0);
}
const toolInput = input.tool_input || {};
if (!['Agent', 'Task'].includes(input.tool_name) || toolInput.subagent_type !== 'be-worker') process.exit(0);

const cwd = input.cwd || process.cwd();
const dirs = [...String(toolInput.prompt || '').matchAll(/([^\s"'`()<>]*build[\\/]orchestrate[\\/][^\\/\s"'`()<>]+)[\\/]/g)].map((m) => m[1]);
const found = dirs.some((d) => [path.resolve(cwd, d), path.resolve(cwd, 'backend', d)].some((p) => fs.existsSync(path.join(p, MARK))));
if (found) process.exit(0);

deny(
  'be-worker 서브에이전트는 Codex 사용량이 소진됐거나 Codex가 실패했을 때만 부른다. ' +
  '먼저 orchestrator.md "워커 보내기" 1~2번대로 `orca.cmd agent launch --agent codex`로 Orca 에이전트 탭에 Codex를 띄운다. ' +
  `화면에서 소진·실패를 확인했으면 3번대로 이슈 폴더(build/orchestrate/<NNN>/)에 ${MARK} 파일(한 줄 이유)을 쓰고, ` +
  '프롬프트에 그 폴더의 브리프 경로를 넣어 다시 부른다.' +
  (dirs.length ? ` 확인한 폴더: ${dirs.join(', ')}` : ' 프롬프트에 브리프 경로(build/orchestrate/<NNN>/...)가 없다.'),
);
