// 오케스트레이션 세션 기록(~/.claude/projects/<폴더>/<세션>.jsonl 과 <세션>/subagents/)에서 시간을 잰다.
// 쓰기: node timeline.mjs <세션 기록 폴더> [--session <세션 id 앞부분>] [--since <ISO 시각>] [--until <ISO 시각>]
// 출력: 세션마다 /orchestrate·push 시각(--since·--until 에 그대로 넣는 ISO), 사용자 메시지, 워커 표, 종류별 합계, 동시 워커 수, 백그라운드 명령, 본 세션이 멈춘 곳, 훅 오류 수. 시각은 이 기기 시간대(KST)
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const dir = args[0];
const opt = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : undefined; };
const usage = '쓰기: node timeline.mjs <세션 기록 폴더> [--session <세션 id 앞부분>] [--since <ISO 시각>] [--until <ISO 시각>]';
function time(name, fallback) {
	const v = opt(name);
	if (v === undefined) return fallback;
	const t = Date.parse(v);
	if (Number.isNaN(t)) { console.error(`${name} 는 ISO 시각이어야 한다 (예: 2026-10-28T13:02:00+09:00): ${v}`); process.exit(1); }
	return t;
}
const since = time('--since', 0);
const until = time('--until', Infinity);
const only = opt('--session');
if (!dir || !fs.existsSync(dir)) { console.error(usage); process.exit(1); }

// 단계 경계를 0.1분까지 맞추려고 초까지 낸다
const hhmm = (t) => new Date(t).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
// 이 기기 시간대의 초 단위 ISO. --since 에 넣을 것은 내리고(up=false), --until 에 넣을 것은 올려 그 줄이 빠지지 않게 한다
function iso(t, up) {
	const s = (up ? Math.ceil(t / 1000) : Math.floor(t / 1000)) * 1000;
	const off = -new Date(s).getTimezoneOffset();
	const sign = off >= 0 ? '+' : '-', pad = (n) => String(Math.floor(Math.abs(n))).padStart(2, '0');
	return `${new Date(s + off * 60000).toISOString().slice(0, 19)}${sign}${pad(off / 60)}:${pad(off % 60)}`;
}
const min = (ms) => (ms / 60000).toFixed(1);
const oneLine = (s, n) => String(s).replace(/\s+/g, ' ').trim().slice(0, n);

// heredoc 본문을 떼고, 명령 자리(줄 처음, &&, ;, ||, 괄호 뒤, timeout N 뒤)에서 부른 gradlew 만 gradle 실행으로 본다
const withoutHeredoc = (cmd) => String(cmd).replace(/<<-?\s*['"]?(\w+)['"]?[^\n]*\n[\s\S]*?\n\s*\1\s*(\n|$)/g, '\n');
const GRADLE = /(^|&&|;|\|\||\(|\n)\s*(timeout\s+\S+\s+)?(\.\/)?gradlew\b/;
const runsGradle = (cmd) => GRADLE.test(withoutHeredoc(cmd));
// 명령 앞의 `cd <경로> &&`·`X=<경로>;` 를 떼고, gradle 이면 ./gradlew 부터 보여 준다
function short(cmd) {
	const s = withoutHeredoc(cmd);
	if (GRADLE.test(s)) return oneLine(s.slice(s.search(/(\.\/)?gradlew\b/)), 70);
	return oneLine(s, 400).replace(/^(\s*(cd\s+("[^"]*"|\S+)|[A-Z_]+=("[^"]*"|\S+))\s*(&&|;)\s*)+/, '').slice(0, 70);
}

function readLines(file) {
	return fs.readFileSync(file, 'utf8').split('\n').filter(Boolean).flatMap((l) => {
		try { return [JSON.parse(l)]; } catch { return []; }
	}).filter((o) => { const t = o.timestamp && Date.parse(o.timestamp); return t && t >= since && t <= until; });
}

const blocks = (o) => (o.message && Array.isArray(o.message.content) ? o.message.content : []);
const userText = (o) => (o.type === 'user' && o.message && typeof o.message.content === 'string' ? o.message.content : null);
const resultText = (b) => (typeof b.content === 'string' ? b.content : Array.isArray(b.content) ? b.content.map((x) => x.text || '').join(' ') : '');
const notice = (o) => (o.type === 'queue-operation' && o.operation === 'enqueue' && typeof o.content === 'string' ? o.content : null);

// 겹치는 구간을 합친다
function merge(intervals) {
	const out = [];
	for (const [a, b] of [...intervals].sort((x, y) => x[0] - y[0])) {
		if (out.length && a <= out[out.length - 1][1]) out[out.length - 1][1] = Math.max(out[out.length - 1][1], b);
		else out.push([a, b]);
	}
	return out;
}

// 기록 하나를 잰다. 백그라운드 명령(run_in_background 이거나 2분을 넘겨 자동으로 넘어간 것)의 끝은 본 세션의 완료 알림(ends)에서 찾는다.
// 승인 대기: 사용자가 권한을 허락한 도구 호출(permissionDecision.source 가 user_…)과 AskUserQuestion. 도구 분에서 뺀다
function measure(lines, ends) {
	const pending = new Map();
	const background = [];
	const ids = new Set();
	const toolSpans = [], waitSpans = [];
	let gradle = 0, gradleMs = 0, longest = { ms: 0, what: '' };
	for (const o of lines) {
		const t = Date.parse(o.timestamp);
		if (o.type === 'assistant' && o.message && o.message.id) ids.add(o.message.id);
		for (const b of blocks(o)) {
			if (b.type === 'tool_use') {
				const input = b.input || {};
				const cmd = input.command || input.description || input.prompt || input.file_path || '';
				const p = { id: b.id, t, what: `${b.name}: ${short(cmd)}`, gradle: b.name === 'Bash' && runsGradle(cmd), ask: b.name === 'AskUserQuestion' };
				// 백그라운드 워커(Agent)는 워커 표에 따로 나오니 Bash 만 센다
				if (input.run_in_background && b.name === 'Bash') background.push({ ...p, start: t });
				else pending.set(b.id, p);
			}
			else if (b.type === 'tool_result' && pending.has(b.tool_use_id)) {
				const p = pending.get(b.tool_use_id);
				pending.delete(b.tool_use_id);
				const ms = t - p.t;
				const approved = o.permissionDecision && String(o.permissionDecision.source || '').startsWith('user');
				if (approved || p.ask) { waitSpans.push([p.t, t]); continue; }
				toolSpans.push([p.t, t]);
				if (ms > longest.ms) longest = { ms, what: p.what };
				if (/^Command running in background with ID/.test(resultText(b))) background.push({ ...p, start: p.t });
				else if (p.gradle) { gradle++; gradleMs += ms; }
			}
		}
	}
	for (const bg of background) {
		const end = ends.get(bg.id);
		bg.end = end ? end.t : null;
		bg.status = end ? end.status : '';
		if (bg.gradle && bg.end) { gradle++; gradleMs += bg.end - bg.start; }
	}
	const start = Date.parse(lines[0].timestamp);
	const end = Date.parse(lines[lines.length - 1].timestamp);
	const waits = merge(waitSpans);
	const waitMs = waits.reduce((s, [a, b]) => s + b - a, 0);
	const tools = merge(toolSpans);
	const toolMs = tools.reduce((s, [a, b]) => s + b - a, 0);
	let modelGap = 0, cursor = start;
	for (const [a, b] of merge([...toolSpans, ...waitSpans])) { modelGap = Math.max(modelGap, a - cursor); cursor = Math.max(cursor, b); }
	modelGap = Math.max(modelGap, end - cursor);
	return { start, end, turns: ids.size, toolMs, waitMs, modelMs: Math.max(0, end - start - toolMs - waitMs), modelGap, gradle, gradleMs, longest, background };
}

// 본 세션이 다음에 움직이기까지 3분 넘게 빈 곳. 본 세션 자기 말·도구와, 본 세션이 띄운 것의 완료 알림만 본다
// (워커가 띄운 백그라운드 명령의 알림은 본 세션을 깨우지 않으니 건너뛴다)
function gaps(lines, ownIds) {
	const moves = lines.filter((o) => o.type === 'assistant' || o.type === 'user'
		|| (notice(o) && ownIds.has((notice(o).match(/<tool-use-id>([^<]+)</) || [])[1])));
	const out = [];
	let last = '';
	for (let i = 0; i < moves.length; i++) {
		if (i > 0) {
			const a = Date.parse(moves[i - 1].timestamp), b = Date.parse(moves[i].timestamp);
			if (b - a > 3 * 60000) {
				const o = moves[i];
				let after = o.type;
				if (notice(o)) after = `알림 ${oneLine((notice(o).match(/<summary>([^<]*)</) || [])[1] || '', 60)}`;
				else if (userText(o) !== null) after = `사용자: ${oneLine(userText(o), 60)}`;
				else if (o.type === 'user') after = '도구 결과';
				out.push({ a, b, before: last, after });
			}
		}
		if (moves[i].type === 'assistant') {
			for (const x of blocks(moves[i])) {
				if (x.type === 'text' && x.text.trim()) last = oneLine(x.text, 80);
				if (x.type === 'tool_use') last = `${x.name}: ${short((x.input && (x.input.description || x.input.command)) || '')}`;
			}
		}
	}
	return out;
}

// 첫 /orchestrate 메시지와 실제로 main 에 올라간 push. orchestrate 스킬 본문에도 `git push origin HEAD:main` 글자가 있어
// 글자만으로는 못 가르니, 그 명령을 부른 Bash 의 결과에 `<a>..<b>  HEAD -> main`이 나온 것만 push 로 본다
function marks(lines) {
	let start = null;
	const calls = new Map(), pushes = [];
	for (const o of lines) {
		const s = userText(o);
		if (start === null && s !== null && /\/orchestrate\b/.test(s)) start = Date.parse(o.timestamp);
		for (const b of blocks(o)) {
			if (b.type === 'tool_use' && b.name === 'Bash' && /git push origin HEAD:main/.test((b.input && b.input.command) || '')) calls.set(b.id, true);
			else if (b.type === 'tool_result' && calls.has(b.tool_use_id)) {
				const m = resultText(b).match(/([0-9a-f]{7,}\.\.[0-9a-f]{7,})\s+HEAD -> main/);
				if (m) pushes.push({ t: Date.parse(o.timestamp), range: m[1] });
			}
		}
	}
	return { start, pushes };
}

const countHookErrors =(file) => fs.readFileSync(file, 'utf8').split('"hook_non_blocking_error"').length - 1;

const sessions = fs.readdirSync(dir).filter((f) => f.endsWith('.jsonl') && (!only || f.startsWith(only))).map((f) => path.join(dir, f));
for (const file of sessions) {
	const lines = readLines(file);
	if (lines.length < 50) continue;
	const ends = new Map();
	for (const o of lines) {
		const n = notice(o);
		const id = n && (n.match(/<tool-use-id>([^<]+)</) || [])[1];
		if (id && !ends.has(id)) ends.set(id, { t: Date.parse(o.timestamp), status: (n.match(/<status>([^<]+)</) || [])[1] || '' });
	}
	const ownIds = new Set(lines.flatMap((o) => (o.type === 'assistant' ? blocks(o).filter((b) => b.type === 'tool_use').map((b) => b.id) : [])));
	const main = measure(lines, ends);
	const subDir = path.join(file.replace(/\.jsonl$/, ''), 'subagents');
	console.log(`## 세션 ${path.basename(file, '.jsonl')}`);
	console.log(`- 본 세션 ${hhmm(main.start)}~${hhmm(main.end)} (${min(main.end - main.start)}분), 응답 ${main.turns}, 승인·질문 대기 ${min(main.waitMs)}분, gradle(백그라운드 포함) ${main.gradle}회 ${min(main.gradleMs)}분`);
	const mk = marks(lines);
	console.log(`- 첫 /orchestrate: ${mk.start ? iso(mk.start, false) : '없음'}`);
	console.log(`- push: ${mk.pushes.length ? mk.pushes.map((p) => `${iso(p.t, true)} ${p.range}`).join(', ') : '없음'}`);
	console.log('\n사용자 메시지 (세션 고르기·사용자 개입):');
	for (const o of lines) {
		const s = userText(o);
		if (s === null || !s.trim()) continue;
		if (s.includes('<command-name>')) console.log(`- ${hhmm(Date.parse(o.timestamp))} ${oneLine(`${(s.match(/<command-name>([^<]*)</) || [])[1]} ${(s.match(/<command-args>([^<]*)</) || [])[1] || ''}`, 80)}`);
		else if (!s.startsWith('<')) console.log(`- ${hhmm(Date.parse(o.timestamp))} ${oneLine(s, 80)}`);
	}

	const rows = [];
	let hookErrors = countHookErrors(file);
	if (fs.existsSync(subDir)) {
		for (const f of fs.readdirSync(subDir).filter((x) => x.endsWith('.jsonl'))) {
			hookErrors += countHookErrors(path.join(subDir, f));
			const sub = readLines(path.join(subDir, f));
			if (sub.length === 0) continue;
			let meta = {};
			try { meta = JSON.parse(fs.readFileSync(path.join(subDir, f.replace(/\.jsonl$/, '.meta.json')), 'utf8')); } catch { /* 메타 없음 */ }
			rows.push({ ...measure(sub, ends), type: meta.agentType || '?', desc: meta.description || '', finished: meta.finished !== false });
		}
	}
	rows.sort((x, y) => x.start - y.start);
	if (rows.length) {
		console.log('\n| 시작 | 끝 | 분 | 종류 | 설명 | 응답 | 도구 분 | 모델 분 | 승인 대기 | 가장 긴 모델 공백 | gradle 회·분 | 가장 긴 도구 호출 | 끝남 |');
		console.log('|---|---|---|---|---|---|---|---|---|---|---|---|---|');
		for (const r of rows) {
			console.log(`| ${hhmm(r.start)} | ${hhmm(r.end)} | ${min(r.end - r.start)} | ${r.type} | ${r.desc.slice(0, 40)} | ${r.turns} | ${min(r.toolMs)} | ${min(r.modelMs)} | ${min(r.waitMs)} | ${min(r.modelGap)} | ${r.gradle}·${min(r.gradleMs)} | ${min(r.longest.ms)} ${r.longest.what.replace(/\|/g, '/')} | ${r.finished ? '예' : '아니오'} |`);
		}

		const byType = {};
		for (const r of rows) {
			const t = (byType[r.type] ||= { n: 0, ms: 0, max: 0, toolMs: 0, modelMs: 0, waitMs: 0, gradleMs: 0 });
			t.n++; t.ms += r.end - r.start; t.max = Math.max(t.max, r.end - r.start);
			t.toolMs += r.toolMs; t.modelMs += r.modelMs; t.waitMs += r.waitMs; t.gradleMs += r.gradleMs;
		}
		console.log('\n| 종류 | 수 | 평균 분 | 최대 분 | 합계 분 | 도구 합계 | 모델 합계 | 승인 대기 합계 | gradle 합계 |');
		console.log('|---|---|---|---|---|---|---|---|---|');
		for (const [k, t] of Object.entries(byType)) {
			console.log(`| ${k} | ${t.n} | ${min(t.ms / t.n)} | ${min(t.max)} | ${min(t.ms)} | ${min(t.toolMs)} | ${min(t.modelMs)} | ${min(t.waitMs)} | ${min(t.gradleMs)} |`);
		}

		// 동시에 돈 워커 수가 바뀐 시각 (같은 초 안에서는 그 초의 최대값)
		const events = rows.flatMap((r) => [[r.start, 1, r.type], [r.end, -1, r.type]]).sort((x, y) => x[0] - y[0] || x[1] - y[1]);
		let now = 0, be = 0, bePeak = 0, peak = { n: 0, t: 0 };
		const perSecond = new Map();
		for (const [t, d, type] of events) {
			now += d;
			if (type === 'be-worker') { be += d; bePeak = Math.max(bePeak, be); }
			if (now > peak.n) peak = { n: now, t };
			perSecond.set(hhmm(t), Math.max(perSecond.get(hhmm(t)) ?? 0, now));
		}
		let prev = -1;
		const changes = [];
		for (const [k, n] of perSecond) { if (n !== prev) changes.push(`${k} ${n}`); prev = n; }
		console.log(`\n동시 워커: 최대 ${peak.n} (${hhmm(peak.t)}), be-worker 최대 ${bePeak}`);
		console.log(`변화: ${changes.join(' | ')}`);
	}

	const bgRows = [...main.background.map((b) => ({ ...b, owner: '본 세션' })),
		...rows.flatMap((r) => r.background.map((b) => ({ ...b, owner: r.desc.slice(0, 30) })))].sort((x, y) => x.start - y.start);
	if (bgRows.length) {
		console.log('\n| 백그라운드 시작 | 끝 | 분 | 결과 | 누가 | 명령 |');
		console.log('|---|---|---|---|---|---|');
		for (const b of bgRows) {
			console.log(`| ${hhmm(b.start)} | ${b.end ? hhmm(b.end) : '-'} | ${b.end ? min(b.end - b.start) : '끝 알림 없음'} | ${b.status} | ${b.owner} | ${b.what.replace(/^Bash: /, '').replace(/\|/g, '/')} |`);
		}
	}

	const g = gaps(lines, ownIds);
	if (g.length) {
		console.log('\n본 세션이 3분 넘게 멈춘 곳 (3분 안쪽의 기다림은 잡히지 않는다):');
		for (const x of g) console.log(`- ${hhmm(x.a)}~${hhmm(x.b)} (${min(x.b - x.a)}분) 앞: ${x.before} / 뒤: ${x.after}`);
	}
	console.log(`\n훅 오류(hook_non_blocking_error): ${hookErrors}건 (본 세션과 서브에이전트, 시간 범위와 무관하게 파일 전체)`);
	console.log();
}
