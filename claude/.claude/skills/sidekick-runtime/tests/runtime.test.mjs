import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const TEST_DIR = path.dirname(fileURLToPath(import.meta.url));
const RUNTIME_DIR = path.dirname(TEST_DIR);
const SKILLS_DIR = path.dirname(RUNTIME_DIR);
const TURN = path.join(RUNTIME_DIR, 'turn.mjs');
const COLLECT = path.join(RUNTIME_DIR, 'collect.mjs');
const FAKE_BIN = path.join(TEST_DIR, 'fake-bin');
const SLOW_META_PRELOAD = path.join(TEST_DIR, 'slow-meta-write.cjs');

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'sidekick-runtime-test-'));
  const cwd = path.join(root, 'worktree');
  const home = path.join(root, 'home');
  const outDir = path.join(root, 'job');
  const promptFile = path.join(root, 'prompt.md');
  fs.mkdirSync(cwd, { recursive: true });
  fs.mkdirSync(home, { recursive: true });
  fs.writeFileSync(promptFile, 'Do the deterministic fake task.\n');
  const runnerPids = new Set();
  t.after(() => {
    for (const pid of runnerPids) {
      try { process.kill(pid, 'SIGKILL'); } catch {}
    }
    if (fs.existsSync(root)) {
      for (const name of fs.readdirSync(root).filter((entry) => entry.endsWith('.pid'))) {
        forceStopFromPidFile(path.join(root, name));
      }
    }
    fs.rmSync(root, { recursive: true, force: true });
  });
  return { root, cwd, home, outDir, promptFile, runnerPids };
}

function testEnv(f, scenario, extra = {}) {
  return {
    ...process.env,
    HOME: f.home,
    PATH: `${FAKE_BIN}${path.delimiter}${process.env.PATH ?? ''}`,
    SIDEKICK_FAKE_SCENARIO: scenario,
    SIDEKICK_FAKE_PROVIDER_PID_FILE: path.join(f.root, 'default-provider.pid'),
    ...extra,
  };
}

function turnArgs(f, provider = 'codex', extra = []) {
  return [
    TURN,
    '--provider', provider,
    '--prompt-file', f.promptFile,
    '--cwd', f.cwd,
    '--out-dir', f.outDir,
    '--timeout-min', '0',
    ...extra,
  ];
}

function capture(child) {
  let stdout = '';
  let stderr = '';
  child.stdout?.on('data', (chunk) => { stdout += chunk; });
  child.stderr?.on('data', (chunk) => { stderr += chunk; });
  const completion = new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('close', (code, signal) => resolve({ code, signal, stdout, stderr }));
  });
  return { child, completion };
}

function startTurn(f, scenario, { provider = 'codex', args = [], env = {} } = {}) {
  const child = spawn(process.execPath, turnArgs(f, provider, args), {
    cwd: f.cwd,
    env: testEnv(f, scenario, env),
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  f.runnerPids.add(child.pid);
  child.once('close', () => f.runnerPids.delete(child.pid));
  return capture(child);
}

async function runTurn(f, scenario, options) {
  return startTurn(f, scenario, options).completion;
}

async function waitFor(description, predicate, timeoutMs = 5_000) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const value = predicate();
      if (value) return value;
    } catch (error) {
      lastError = error;
    }
    await delay(10);
  }
  const suffix = lastError ? ` (${lastError.message})` : '';
  throw new Error(`timed out waiting for ${description}${suffix}`);
}

function readMeta(outDir) {
  return JSON.parse(fs.readFileSync(path.join(outDir, 'meta.json'), 'utf8'));
}

function readRawEvents(outDir) {
  return fs.readFileSync(path.join(outDir, 'raw.log'), 'utf8')
    .split(/\r?\n/)
    .filter((line) => line.trim())
    .map((line) => JSON.parse(line));
}

function readPid(file) {
  return Number(fs.readFileSync(file, 'utf8').trim());
}

function processIsRunning(pid) {
  try {
    process.kill(pid, 0);
  } catch (error) {
    return error.code === 'EPERM';
  }
  try {
    const state = execFileSync('ps', ['-p', String(pid), '-o', 'stat='], {
      stdio: ['ignore', 'pipe', 'ignore'],
    }).toString().trim();
    return state.length > 0 && !state.startsWith('Z');
  } catch {
    return false;
  }
}

async function assertProcessStops(pid, message, timeoutMs = 1_000) {
  await waitFor(message, () => !processIsRunning(pid), timeoutMs);
}

function forceStopFromPidFile(file) {
  if (!fs.existsSync(file)) return;
  const pid = readPid(file);
  if (!Number.isInteger(pid) || pid <= 0 || !processIsRunning(pid)) return;
  try { process.kill(pid, 'SIGKILL'); } catch {}
}

function writeJob(dir, overrides = {}, result) {
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'prompt.md'), 'pending collection fixture\n');
  const meta = {
    status: 'ok',
    provider: 'codex',
    model: null,
    effort: null,
    cwd: path.dirname(path.dirname(dir)),
    allowWrite: false,
    gitBaseline: null,
    runnerPid: 99_999_999,
    runnerInstanceId: 'fixture-runner',
    providerPid: null,
    providerPgid: null,
    promptState: 'accepted',
    sessionId: 'fixture-session',
    resumeFlag: '--resume fixture-session',
    takeoverCommand: 'codex resume fixture-session',
    startedAt: '2026-01-01T00:00:00.000Z',
    endedAt: '2026-01-01T00:01:00.000Z',
    durationMs: 60_000,
    timeoutMin: 30,
    label: null,
    promptFile: path.join(dir, 'prompt.md'),
    outDir: dir,
    tokens: null,
    costUsd: null,
    error: null,
    collectedAt: null,
    ...overrides,
  };
  fs.writeFileSync(path.join(dir, 'meta.json'), `${JSON.stringify(meta, null, 2)}\n`);
  if (result !== undefined) fs.writeFileSync(path.join(dir, 'result.md'), result);
}

test('caller skill contracts scale hard caps and preserve them on resumed turns', () => {
  const policies = { consult: 30, review: 60, delegate: 180 };
  for (const [skill, cap] of Object.entries(policies)) {
    const body = fs.readFileSync(path.join(SKILLS_DIR, skill, 'SKILL.md'), 'utf8');
    const capMentions = [...body.matchAll(new RegExp(`--timeout-min ${cap}`, 'g'))];
    assert.ok(capMentions.length >= 2, `${skill} should use ${cap} minutes on initial and resumed turns`);
    assert.match(body, /hard wall-clock safety cap for \*\*every .* turn\*\*/i);
    assert.match(body, /takeover-after-terminal:/);
    assert.match(body, /optional observation, never a completion signal/i);
  }
});

test('Codex JSONL success becomes authoritative result and metadata', async (t) => {
  const f = fixture(t);
  const argvFile = path.join(f.root, 'argv.json');
  const result = await runTurn(f, 'success', {
    args: ['--effort', 'ultra'],
    env: {
      SIDEKICK_FAKE_ARGV_FILE: argvFile,
      SIDEKICK_FAKE_FINAL_TEXT: 'codex completed the delegated task',
    },
  });

  assert.equal(result.code, 0, result.stderr);
  assert.match(result.stdout, /status: ok/);
  assert.equal(fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8'), 'codex completed the delegated task');
  const meta = readMeta(f.outDir);
  assert.equal(meta.status, 'ok');
  assert.equal(meta.sessionId, 'fake-session-id');
  assert.equal(meta.effort, 'ultra');
  assert.deepEqual(meta.tokens, { input: 13, cachedInput: 5, output: 8, reasoningOutput: 3 });
  assert.ok(JSON.parse(fs.readFileSync(argvFile, 'utf8')).includes('model_reasoning_effort=ultra'));
});

test('Claude stream-json success is parsed incrementally and preserves the final envelope', async (t) => {
  const f = fixture(t);
  const argvFile = path.join(f.root, 'argv.json');
  const result = await runTurn(f, 'success', {
    provider: 'claude',
    env: {
      SIDEKICK_FAKE_ARGV_FILE: argvFile,
      SIDEKICK_FAKE_FINAL_TEXT: 'claude completed the delegated task',
      SIDEKICK_FAKE_STDERR: 'claude diagnostic on stderr\n',
    },
  });

  assert.equal(result.code, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8'), 'claude completed the delegated task');
  const meta = readMeta(f.outDir);
  const argv = JSON.parse(fs.readFileSync(argvFile, 'utf8'));
  assert.equal(meta.provider, 'claude');
  assert.equal(meta.status, 'ok');
  assert.equal(meta.sessionId, 'fake-session-id');
  assert.equal(meta.promptState, 'accepted');
  assert.equal(meta.resultKind, 'final');
  assert.equal(meta.resumeFlag, `--resume ${meta.sessionId}`);
  assert.equal(meta.resumeArgs, `--resume ${meta.sessionId} --timeout-min 0`);
  assert.ok(argv.includes('stream-json'));
  assert.ok(argv.includes('--verbose'));
  assert.ok(!argv.includes('--include-partial-messages'));
  assert.match(result.stdout, /^provider: claude .* hard cap off$/m);
  assert.match(result.stdout, /^watch: .*progress\.log.*raw\.log.*$/m);
  assert.match(result.stdout, /^takeover-after-terminal: claude --resume /m);
  assert.match(result.stdout, /^next: return now; wait for the native background-task notification/m);
  assert.deepEqual(readRawEvents(f.outDir).map((event) => event.type), ['system', 'assistant', 'result']);
  assert.equal(fs.readFileSync(path.join(f.outDir, 'stderr.log'), 'utf8'), 'claude diagnostic on stderr\n');
  assert.match(meta.watchCommand, /progress\.log.*raw\.log/);
});

test('Claude stream parsing survives fragmented JSON and a split UTF-8 code point', async (t) => {
  const f = fixture(t);
  const result = await runTurn(f, 'fragmented-success', {
    provider: 'claude',
    env: { SIDEKICK_FAKE_FINAL_TEXT: 'fragmented claude result' },
  });

  assert.equal(result.code, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8'), 'fragmented claude result');
  const events = readRawEvents(f.outDir);
  assert.match(events.find((event) => event.type === 'assistant').message.content[0].text, /🧭/);
  assert.equal(events.at(-1).type, 'result');
});

test('Claude progress is observable before the final result without polluting raw JSONL', async (t) => {
  const f = fixture(t);
  const running = startTurn(f, 'delayed-success', {
    provider: 'claude',
    env: {
      SIDEKICK_FAKE_START_DELAY_MS: '150',
      SIDEKICK_FAKE_DELAY_MS: '350',
      SIDEKICK_HEARTBEAT_MS: '20',
      SIDEKICK_FAKE_FINAL_TEXT: 'delayed claude result',
    },
  });

  const heartbeatMeta = await waitFor('heartbeat while Claude is initialized but semantically quiet', () => {
    if (!fs.existsSync(path.join(f.outDir, 'meta.json'))) return undefined;
    const meta = readMeta(f.outDir);
    return meta.lastHeartbeatAt && meta.promptState === 'unknown' ? meta : undefined;
  });
  assert.equal(running.child.exitCode, null);
  assert.match(heartbeatMeta.lastHeartbeatAt, /^\d{4}-\d{2}-\d{2}T/);
  assert.match(fs.readFileSync(path.join(f.outDir, 'progress.log'), 'utf8'), /state=running elapsed=.*provider_process=.*prompt=unknown.*events=/);

  const accepted = await waitFor('accepted Claude stream before completion', () => {
    if (!fs.existsSync(path.join(f.outDir, 'meta.json'))) return undefined;
    const meta = readMeta(f.outDir);
    return meta.promptState === 'accepted' ? meta : undefined;
  });
  assert.equal(running.child.exitCode, null);
  assert.match(accepted.promptStateEvidence, /claude assistant/);
  assert.match(fs.readFileSync(path.join(f.outDir, 'progress.log'), 'utf8'), /state=(?:accepted|running)/);
  assert.deepEqual(readRawEvents(f.outDir).map((event) => event.type), ['system', 'assistant']);

  const result = await running.completion;
  assert.equal(result.code, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8'), 'delayed claude result');
  assert.match(fs.readFileSync(path.join(f.outDir, 'progress.log'), 'utf8'), /state=running elapsed=.*provider_process=.*prompt=.*events=/);
  assert.doesNotMatch(fs.readFileSync(path.join(f.outDir, 'raw.log'), 'utf8'), /state=running|provider_process=/);
  assert.doesNotMatch(result.stdout, /^elapsed /m);
});

test('Claude provider failure keeps real partial work and excludes its error echo', async (t) => {
  const f = fixture(t);
  const result = await runTurn(f, 'partial-failure', { provider: 'claude' });

  assert.equal(result.code, 1, result.stderr);
  const meta = readMeta(f.outDir);
  const body = fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8');
  assert.equal(meta.promptState, 'accepted');
  assert.equal(meta.resultKind, 'partial');
  assert.match(meta.error, /synthetic provider failure/);
  assert.match(meta.recoveryAction, /--resume/);
  assert.match(body, /useful claude work before failure/);
  assert.equal((body.match(/synthetic provider failure/g) ?? []).length, 1);
  assert.doesNotMatch(body, /After collecting/);
});

test('a nonzero Codex exit preserves its final message as recovered partial output', async (t) => {
  const f = fixture(t);
  const result = await runTurn(f, 'nonzero-final', {
    env: { SIDEKICK_FAKE_FINAL_TEXT: 'useful work completed before exit' },
  });

  assert.equal(result.code, 1, result.stderr);
  const meta = readMeta(f.outDir);
  const body = fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8');
  assert.equal(meta.status, 'failed');
  assert.match(meta.error, /codex exited (?:with code )?7/i);
  assert.match(body, /Partial output recovered before the failure/i);
  assert.match(body, /useful work completed before exit/);
});

test('provider exit while stdin is being written finalizes once instead of crashing on EPIPE', async (t) => {
  const f = fixture(t);
  fs.writeFileSync(f.promptFile, Buffer.alloc(8 * 1024 * 1024, 'x'));
  const result = await runTurn(f, 'exit-before-stdin');

  assert.equal(result.code, 2, result.stderr);
  assert.equal((result.stdout.match(/^status:/gm) ?? []).length, 1);
  const meta = readMeta(f.outDir);
  const body = fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8');
  assert.equal(meta.status, 'infra');
  assert.match(`${meta.error}\n${body}`, /stdin|prompt|exited 23|no result/i);
});

test('spawn ENOENT produces one finalized infra record', async (t) => {
  const f = fixture(t);
  const emptyBin = path.join(f.root, 'empty-bin');
  fs.mkdirSync(emptyBin);
  const child = spawn(process.execPath, turnArgs(f), {
    cwd: f.cwd,
    env: { ...testEnv(f, 'success'), PATH: emptyBin },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  f.runnerPids.add(child.pid);
  child.once('close', () => f.runnerPids.delete(child.pid));
  const result = await capture(child).completion;

  assert.equal(result.code, 2, result.stderr);
  assert.equal((result.stdout.match(/^status:/gm) ?? []).length, 1);
  const meta = readMeta(f.outDir);
  assert.equal(meta.status, 'infra');
  assert.equal(meta.promptState, 'not_started');
  assert.match(meta.error, /failed to spawn codex|ENOENT/i);
  assert.match(meta.nextAction, /collect\.mjs/);
  assert.match(meta.recoveryAction, /prompt was not accepted|retry the identical dispatch/i);
  assert.ok(fs.existsSync(path.join(f.outDir, 'result.md')));
});

test('explicit collection prints failed-job recovery after the result and stamps metadata', async (t) => {
  const f = fixture(t);
  const turn = await runTurn(f, 'nonzero-final', {
    env: { SIDEKICK_FAKE_FINAL_TEXT: 'partial implementation for the host to inspect' },
  });
  assert.equal(turn.code, 1, turn.stderr);
  const before = readMeta(f.outDir);
  assert.equal(before.collectedAt, null);
  assert.match(before.nextAction, /collect\.mjs/);
  assert.match(before.recoveryAction, /inspect|continue/i);

  const explicit = capture(spawn(process.execPath, [COLLECT, f.outDir], {
    cwd: f.cwd,
    env: testEnv(f, 'success'),
    stdio: ['ignore', 'pipe', 'pipe'],
  }));
  const collected = await explicit.completion;

  assert.equal(collected.code, 0, collected.stderr);
  const resultIndex = collected.stdout.indexOf('--- result.md ---');
  const recoveryIndex = collected.stdout.lastIndexOf('\nnext: ');
  assert.ok(resultIndex >= 0, 'collect output should contain the result section');
  assert.ok(recoveryIndex > resultIndex, 'host recovery guidance should follow the result section');
  assert.match(collected.stdout, /resume: --resume fake-session-id --timeout-min 0/);
  assert.match(collected.stdout.slice(recoveryIndex), /inspect|continue/i);
  const after = readMeta(f.outDir);
  assert.match(after.collectedAt, /^\d{4}-\d{2}-\d{2}T/);
  assert.equal(after.nextAction, after.recoveryAction);
});

test('metadata remains parseable while running and records the runner PID', async (t) => {
  const f = fixture(t);
  const running = startTurn(f, 'delayed-success', {
    env: {
      NODE_OPTIONS: `${process.env.NODE_OPTIONS ?? ''} --require=${SLOW_META_PRELOAD}`.trim(),
      SIDEKICK_FAKE_START_DELAY_MS: '150',
      SIDEKICK_FAKE_DELAY_MS: '500',
      SIDEKICK_TEST_SLOW_META_WRITE: '1',
    },
  });
  const metaPath = path.join(f.outDir, 'meta.json');

  const initial = await waitFor('initial running metadata', () => {
    if (!fs.existsSync(metaPath)) return undefined;
    const value = readMeta(f.outDir);
    return value.status === 'running' ? value : undefined;
  });
  assert.equal(initial.runnerPid, running.child.pid);

  let reads = 0;
  while (running.child.exitCode === null && running.child.signalCode === null) {
    const meta = readMeta(f.outDir);
    assert.equal(meta.runnerPid, running.child.pid);
    reads += 1;
    await delay(1);
  }
  const result = await running.completion;
  assert.equal(result.code, 0, result.stderr);
  assert.ok(reads >= 10, `expected repeated concurrent reads, got ${reads}`);
  assert.equal(readMeta(f.outDir).runnerPid, running.child.pid);
});

test('a racing resume is refused before it can truncate the live job artifacts', { timeout: 10_000 }, async (t) => {
  const f = fixture(t);
  const running = startTurn(f, 'init-only-hang', { provider: 'claude' });
  const meta = await waitFor('Claude session initialization', () => {
    const rawPath = path.join(f.outDir, 'raw.log');
    if (!fs.existsSync(rawPath) || !fs.existsSync(path.join(f.outDir, 'meta.json'))) return undefined;
    const value = readMeta(f.outDir);
    return fs.readFileSync(rawPath, 'utf8').includes('"subtype":"init"') ? value : undefined;
  });
  const rawBefore = fs.readFileSync(path.join(f.outDir, 'raw.log'), 'utf8');
  const progressBefore = fs.readFileSync(path.join(f.outDir, 'progress.log'), 'utf8');

  const racerChild = spawn(process.execPath, turnArgs(f, 'claude', ['--resume', meta.sessionId]), {
    cwd: f.cwd,
    env: testEnv(f, 'success'),
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  f.runnerPids.add(racerChild.pid);
  racerChild.once('close', () => f.runnerPids.delete(racerChild.pid));
  const refused = await capture(racerChild).completion;

  assert.equal(refused.code, 3, refused.stderr);
  assert.match(refused.stderr, /already has a live turn/i);
  assert.equal(fs.readFileSync(path.join(f.outDir, 'raw.log'), 'utf8'), rawBefore);
  assert.equal(fs.readFileSync(path.join(f.outDir, 'progress.log'), 'utf8'), progressBefore);

  running.child.kill('SIGTERM');
  const stopped = await running.completion;
  assert.equal(stopped.code, 5, stopped.stderr);
});

test('a dead-owner session lock is never reclaimed before orphan inspection', async (t) => {
  const f = fixture(t);
  const sessionId = 'stale-lock-session';
  const lockDir = path.join(f.home, '.local', 'state', 'sidekick', 'locks');
  const heldOutDir = path.join(f.root, 'prior-job');
  fs.mkdirSync(lockDir, { recursive: true });
  fs.mkdirSync(heldOutDir, { recursive: true });
  fs.writeFileSync(path.join(lockDir, `${sessionId}.lock`), `${JSON.stringify({
    pid: 2_147_483_647,
    runnerInstanceId: 'dead-runner',
    outDir: heldOutDir,
    startedAt: '2020-01-01T00:00:00.000Z',
  })}\n`);

  const result = await runTurn(f, 'success', {
    provider: 'claude',
    args: ['--resume', sessionId],
  });

  assert.equal(result.code, 3, result.stderr);
  assert.match(result.stderr, /automatic takeover is refused/i);
  assert.match(result.stderr, /provider may still be running/i);
  assert.match(result.stderr, /collect\.mjs/);
  assert.ok(!fs.existsSync(path.join(f.outDir, 'raw.log')), 'refused resume must not create or truncate job logs');
  assert.ok(!fs.existsSync(path.join(f.root, 'default-provider.pid')), 'refused resume must not spawn a provider');
});

test('a fresh Codex session-id collision stops instead of continuing without a lock', { timeout: 10_000 }, async (t) => {
  const f = fixture(t);
  const sessionId = 'fake-session-id';
  const lockDir = path.join(f.home, '.local', 'state', 'sidekick', 'locks');
  const lockPath = path.join(lockDir, `${sessionId}.lock`);
  const held = {
    pid: process.pid,
    runnerInstanceId: 'existing-live-runner',
    outDir: path.join(f.root, 'existing-live-job'),
    startedAt: new Date().toISOString(),
  };
  fs.mkdirSync(lockDir, { recursive: true });
  fs.writeFileSync(lockPath, `${JSON.stringify(held)}\n`);

  const result = await runTurn(f, 'delayed-success', {
    env: {
      SIDEKICK_FAKE_DELAY_MS: '500',
      SIDEKICK_SIGKILL_AFTER_MS: '50',
      SIDEKICK_CLOSE_GRACE_MS: '20',
    },
  });

  const meta = readMeta(f.outDir);
  assert.equal(result.code, 2, `${result.stderr}\n${JSON.stringify(meta)}`);
  assert.equal(meta.status, 'infra');
  assert.equal(meta.promptState, 'accepted');
  assert.match(meta.error, /session id that is already locked/i);
  assert.match(meta.recoveryAction, /do not resume or redispatch/i);
  assert.match(meta.sessionLockConflict, /already has a live turn/i);
  assert.equal(meta.resumeFlag, null);
  assert.equal(meta.resumeArgs, null);
  assert.equal(meta.takeoverCommand, null);
  assert.doesNotMatch(result.stdout, /^takeover(?:-after-terminal)?:/m);
  assert.equal(JSON.parse(fs.readFileSync(lockPath, 'utf8')).runnerInstanceId, held.runnerInstanceId);
  await assertProcessStops(readPid(path.join(f.root, 'default-provider.pid')), 'colliding Codex provider to stop');

  const collected = await capture(spawn(process.execPath, [COLLECT, f.outDir], {
    cwd: f.cwd,
    env: testEnv(f, 'success'),
    stdio: ['ignore', 'pipe', 'pipe'],
  })).completion;
  assert.equal(collected.code, 0, collected.stderr);
  assert.match(collected.stdout, /^session: fake-session-id$/m);
  assert.doesNotMatch(collected.stdout, /^resume:|^takeover:/m);
  assert.match(collected.stdout, /do not resume or redispatch/i);
});

test('a Codex lock collision overrides an earlier timeout recovery path', { timeout: 10_000 }, async (t) => {
  const f = fixture(t);
  const sessionId = 'fake-session-id';
  const lockDir = path.join(f.home, '.local', 'state', 'sidekick', 'locks');
  fs.mkdirSync(lockDir, { recursive: true });
  fs.writeFileSync(path.join(lockDir, `${sessionId}.lock`), `${JSON.stringify({
    pid: process.pid,
    runnerInstanceId: 'existing-live-runner',
    outDir: path.join(f.root, 'existing-live-job'),
    startedAt: new Date().toISOString(),
  })}\n`);

  const result = await runTurn(f, 'delayed-thread-start-ignore-sigterm', {
    args: ['--timeout-min', '0.001'],
    env: {
      SIDEKICK_FAKE_START_DELAY_MS: '100',
      SIDEKICK_TIMEOUT_POLL_MS: '5',
      SIDEKICK_SIGKILL_AFTER_MS: '200',
      SIDEKICK_CLOSE_GRACE_MS: '20',
    },
  });

  const meta = readMeta(f.outDir);
  assert.equal(result.code, 2, `${result.stderr}\n${JSON.stringify(meta)}`);
  assert.equal(meta.status, 'infra');
  assert.ok(meta.terminationRequestedAt, 'timeout should have requested termination before thread.started');
  assert.match(meta.error, /session id that is already locked/i);
  assert.doesNotMatch(meta.error, /hard wall-clock cap ended/i);
  assert.equal(meta.resumeFlag, null);
  assert.equal(meta.resumeArgs, null);
  assert.equal(meta.takeoverCommand, null);
  assert.doesNotMatch(result.stdout, /^takeover(?:-after-terminal)?:/m);
  await assertProcessStops(readPid(path.join(f.root, 'default-provider.pid')), 'timeout-before-collision provider to stop');
});

test('successful provider result stays ok while a residual process group is reaped', { timeout: 10_000 }, async (t) => {
  const f = fixture(t);
  const grandchildPidFile = path.join(f.root, 'grandchild.pid');
  const grandchildReadyFile = path.join(f.root, 'grandchild.ready');
  const result = await runTurn(f, 'success-with-stubborn-grandchild', {
    args: ['--timeout-min', '0.006'],
    env: {
      SIDEKICK_FAKE_FINAL_TEXT: 'complete result before residual cleanup',
      SIDEKICK_FAKE_GRANDCHILD_PID_FILE: grandchildPidFile,
      SIDEKICK_FAKE_GRANDCHILD_READY_FILE: grandchildReadyFile,
      SIDEKICK_TIMEOUT_POLL_MS: '5',
      SIDEKICK_SIGKILL_AFTER_MS: '600',
      SIDEKICK_CLOSE_GRACE_MS: '30',
    },
  });

  const meta = readMeta(f.outDir);
  assert.equal(result.code, 0, `${result.stderr}\n${JSON.stringify(meta)}`);
  assert.equal(meta.status, 'ok');
  assert.match(meta.providerTerminalEventType, /codex turn\.completed/);
  assert.ok(meta.terminationRequestedAt, 'hard cap should fire during residual cleanup');
  assert.equal(fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8'), 'complete result before residual cleanup');
  await assertProcessStops(readPid(grandchildPidFile), 'successful provider residual grandchild to stop');
});

test('a complete Claude result stays ok when residual cleanup crosses the hard cap', { timeout: 10_000 }, async (t) => {
  const f = fixture(t);
  const grandchildPidFile = path.join(f.root, 'grandchild.pid');
  const grandchildReadyFile = path.join(f.root, 'grandchild.ready');
  const result = await runTurn(f, 'success-with-stubborn-grandchild', {
    provider: 'claude',
    args: ['--timeout-min', '0.006'],
    env: {
      SIDEKICK_FAKE_FINAL_TEXT: 'complete Claude result before residual cleanup',
      SIDEKICK_FAKE_GRANDCHILD_PID_FILE: grandchildPidFile,
      SIDEKICK_FAKE_GRANDCHILD_READY_FILE: grandchildReadyFile,
      SIDEKICK_TIMEOUT_POLL_MS: '5',
      SIDEKICK_SIGKILL_AFTER_MS: '600',
      SIDEKICK_CLOSE_GRACE_MS: '30',
    },
  });

  const meta = readMeta(f.outDir);
  assert.equal(result.code, 0, `${result.stderr}\n${JSON.stringify(meta)}`);
  assert.equal(meta.status, 'ok');
  assert.match(meta.providerTerminalEventType, /claude success/);
  assert.ok(meta.terminationRequestedAt, 'hard cap should fire during residual cleanup');
  assert.equal(fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8'), 'complete Claude result before residual cleanup');
  await assertProcessStops(readPid(grandchildPidFile), 'successful Claude residual grandchild to stop');
});

for (const provider of ['codex', 'claude']) {
  test(`an authoritative ${provider} result stays ok when the provider itself crosses the hard cap`, { timeout: 10_000 }, async (t) => {
    const f = fixture(t);
    const finalText = `complete ${provider} result before CLI stall`;
    const result = await runTurn(f, 'terminal-success-then-hang', {
      provider,
      args: ['--timeout-min', '0.004'],
      env: {
        SIDEKICK_FAKE_FINAL_TEXT: finalText,
        SIDEKICK_TIMEOUT_POLL_MS: '5',
        SIDEKICK_SIGKILL_AFTER_MS: '50',
        SIDEKICK_CLOSE_GRACE_MS: '20',
      },
    });

    const meta = readMeta(f.outDir);
    assert.equal(result.code, 0, `${result.stderr}\n${JSON.stringify(meta)}`);
    assert.equal(meta.status, 'ok');
    assert.ok(meta.providerTerminalAt);
    assert.ok(meta.terminationRequestedAt, 'hard cap should stop the stalled provider after its terminal event');
    assert.equal(fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8'), finalText);
  });
}

test('timeout kills the provider process tree and tells the host to resume an accepted turn', { timeout: 15_000 }, async (t) => {
  const f = fixture(t);
  const providerPidFile = path.join(f.root, 'provider.pid');
  const grandchildPidFile = path.join(f.root, 'grandchild.pid');
  const grandchildReadyFile = path.join(f.root, 'grandchild.ready');
  const running = startTurn(f, 'hang-with-stubborn-grandchild-only', {
    args: ['--timeout-min', '0.005'],
    env: {
      SIDEKICK_FAKE_PROVIDER_PID_FILE: providerPidFile,
      SIDEKICK_FAKE_GRANDCHILD_PID_FILE: grandchildPidFile,
      SIDEKICK_FAKE_GRANDCHILD_READY_FILE: grandchildReadyFile,
      SIDEKICK_TIMEOUT_POLL_MS: '10',
      SIDEKICK_SIGKILL_AFTER_MS: '150',
      SIDEKICK_CLOSE_GRACE_MS: '30',
    },
  });
  await waitFor('provider and initialized grandchild', () => (
    fs.existsSync(providerPidFile) && fs.existsSync(grandchildPidFile) && fs.existsSync(grandchildReadyFile)
  ));
  const providerPid = readPid(providerPidFile);
  const grandchildPid = readPid(grandchildPidFile);
  const result = await running.completion;

  assert.equal(result.code, 4, result.stderr);
  const meta = readMeta(f.outDir);
  const body = fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8');
  assert.equal(meta.status, 'timeout');
  assert.equal(meta.promptState, 'accepted');
  assert.equal(meta.providerPid, providerPid);
  assert.equal(meta.providerPgid, providerPid);
  assert.match(meta.recoveryAction, /resume/i);
  assert.match(meta.recoveryAction, /fake-session-id/);
  assert.doesNotMatch(body, /After collecting/i);
  await assertProcessStops(providerPid, 'timed-out provider to stop');
  await assertProcessStops(grandchildPid, 'timed-out provider grandchild to stop');
});

test('accepted Claude timeout recovers partial output, prescribes resume, and kills the process tree', { timeout: 15_000 }, async (t) => {
  const f = fixture(t);
  const providerPidFile = path.join(f.root, 'provider.pid');
  const grandchildPidFile = path.join(f.root, 'grandchild.pid');
  const grandchildReadyFile = path.join(f.root, 'grandchild.ready');
  const running = startTurn(f, 'hang-with-stubborn-grandchild-only', {
    provider: 'claude',
    args: ['--timeout-min', '0.005'],
    env: {
      SIDEKICK_FAKE_PROVIDER_PID_FILE: providerPidFile,
      SIDEKICK_FAKE_GRANDCHILD_PID_FILE: grandchildPidFile,
      SIDEKICK_FAKE_GRANDCHILD_READY_FILE: grandchildReadyFile,
      SIDEKICK_TIMEOUT_POLL_MS: '10',
      SIDEKICK_SIGKILL_AFTER_MS: '150',
      SIDEKICK_CLOSE_GRACE_MS: '30',
      SIDEKICK_HEARTBEAT_MS: '20',
    },
  });
  await waitFor('Claude provider and initialized grandchild', () => (
    fs.existsSync(providerPidFile) && fs.existsSync(grandchildPidFile) && fs.existsSync(grandchildReadyFile)
  ));
  const providerPid = readPid(providerPidFile);
  const grandchildPid = readPid(grandchildPidFile);
  const result = await running.completion;

  assert.equal(result.code, 4, result.stderr);
  const meta = readMeta(f.outDir);
  const body = fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8');
  assert.equal(meta.status, 'timeout');
  assert.equal(meta.promptState, 'accepted');
  assert.match(meta.promptStateEvidence, /claude assistant/);
  assert.equal(meta.resultKind, 'partial');
  assert.equal(meta.resumeFlag, `--resume ${meta.sessionId}`);
  assert.equal(meta.resumeArgs, `--resume ${meta.sessionId} --timeout-min 0.005`);
  assert.match(meta.recoveryAction, /--resume/);
  assert.match(meta.recoveryAction, /--timeout-min 0\.005/);
  assert.match(meta.recoveryAction, new RegExp(meta.sessionId));
  assert.match(meta.recoveryAction, /not evidence.*hung|do not redispatch/is);
  assert.match(body, /useful claude work before timeout/);
  assert.match(fs.readFileSync(path.join(f.outDir, 'progress.log'), 'utf8'), /state=terminal status=timeout/);
  assert.deepEqual(readRawEvents(f.outDir).map((event) => event.type), ['system', 'assistant']);
  await assertProcessStops(providerPid, 'timed-out Claude provider to stop');
  await assertProcessStops(grandchildPid, 'timed-out Claude provider grandchild to stop');
});

test('Claude timeout before semantic activity keeps acceptance unknown', { timeout: 10_000 }, async (t) => {
  const f = fixture(t);
  const result = await runTurn(f, 'init-only-hang', {
    provider: 'claude',
    args: ['--timeout-min', '0.002'],
    env: {
      SIDEKICK_TIMEOUT_POLL_MS: '10',
      SIDEKICK_SIGKILL_AFTER_MS: '50',
      SIDEKICK_CLOSE_GRACE_MS: '20',
    },
  });

  assert.equal(result.code, 4, result.stderr);
  const meta = readMeta(f.outDir);
  assert.equal(meta.promptState, 'unknown');
  assert.equal(meta.resultKind, 'none');
  assert.match(meta.recoveryAction, /acceptance is unconfirmed|positively establish/i);
  assert.match(meta.recoveryAction, /progress\.log.*raw\.log.*stderr\.log/i);
});

test('Claude timeout falls back to same-turn transcript evidence and recovers partial work', { timeout: 10_000 }, async (t) => {
  const f = fixture(t);
  const result = await runTurn(f, 'transcript-only-hang', {
    provider: 'claude',
    args: ['--timeout-min', '0.002'],
    env: {
      SIDEKICK_TIMEOUT_POLL_MS: '10',
      SIDEKICK_SIGKILL_AFTER_MS: '50',
      SIDEKICK_CLOSE_GRACE_MS: '20',
    },
  });

  assert.equal(result.code, 4, result.stderr);
  const meta = readMeta(f.outDir);
  const body = fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8');
  assert.equal(meta.promptState, 'accepted');
  assert.equal(meta.promptStateEvidence, 'claude session transcript');
  assert.equal(meta.resultKind, 'partial');
  assert.match(meta.recoveryAction, new RegExp(meta.sessionId));
  assert.match(body, /partial work from the Claude transcript/);
});

test('Claude transcript fallback rejects records from before the resumed turn', { timeout: 10_000 }, async (t) => {
  const f = fixture(t);
  const sessionId = 'prior-session-id';
  const transcriptDir = path.join(f.home, '.claude', 'projects', 'prior-project');
  fs.mkdirSync(transcriptDir, { recursive: true });
  fs.writeFileSync(path.join(transcriptDir, `${sessionId}.jsonl`), `${JSON.stringify({
    type: 'assistant',
    timestamp: '2020-01-01T00:00:00.000Z',
    message: { role: 'assistant', content: [{ type: 'text', text: 'old work must not count' }] },
  })}\n`);

  const result = await runTurn(f, 'hang-before-acceptance', {
    provider: 'claude',
    args: ['--resume', sessionId, '--timeout-min', '0.002'],
    env: {
      SIDEKICK_TIMEOUT_POLL_MS: '10',
      SIDEKICK_SIGKILL_AFTER_MS: '50',
      SIDEKICK_CLOSE_GRACE_MS: '20',
    },
  });

  assert.equal(result.code, 4, result.stderr);
  const meta = readMeta(f.outDir);
  assert.equal(meta.promptState, 'unknown');
  assert.equal(meta.resultKind, 'none');
});

test('SIGTERM interruption kills the provider process tree and finalizes actionable state', { timeout: 10_000 }, async (t) => {
  const f = fixture(t);
  const providerPidFile = path.join(f.root, 'provider.pid');
  const grandchildPidFile = path.join(f.root, 'grandchild.pid');
  const grandchildReadyFile = path.join(f.root, 'grandchild.ready');
  const running = startTurn(f, 'hang-with-stubborn-grandchild-only', {
    env: {
      SIDEKICK_FAKE_PROVIDER_PID_FILE: providerPidFile,
      SIDEKICK_FAKE_GRANDCHILD_PID_FILE: grandchildPidFile,
      SIDEKICK_FAKE_GRANDCHILD_READY_FILE: grandchildReadyFile,
      SIDEKICK_SIGKILL_AFTER_MS: '150',
      SIDEKICK_CLOSE_GRACE_MS: '30',
    },
  });
  await waitFor('accepted running turn', () => {
    if (!fs.existsSync(grandchildPidFile) || !fs.existsSync(grandchildReadyFile)) return false;
    if (!fs.existsSync(path.join(f.outDir, 'meta.json'))) return false;
    return readMeta(f.outDir).sessionId === 'fake-session-id';
  });
  const providerPid = readPid(providerPidFile);
  const grandchildPid = readPid(grandchildPidFile);
  running.child.kill('SIGTERM');
  const result = await running.completion;

  assert.equal(result.code, 5, result.stderr);
  const meta = readMeta(f.outDir);
  const body = fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8');
  assert.equal(meta.status, 'interrupted');
  assert.equal(meta.promptState, 'accepted');
  assert.equal(meta.providerPid, providerPid);
  assert.equal(meta.providerPgid, providerPid);
  assert.match(meta.error, /SIGTERM|interrupt/i);
  assert.match(meta.recoveryAction, /resume/i);
  assert.match(meta.recoveryAction, /fake-session-id/);
  assert.doesNotMatch(body, /After collecting/i);
  await assertProcessStops(providerPid, 'interrupted provider to stop');
  await assertProcessStops(grandchildPid, 'interrupted provider grandchild to stop');
});

test('collect identifies a dead runner instead of calling the job live', async (t) => {
  const f = fixture(t);
  fs.mkdirSync(f.outDir, { recursive: true });
  fs.writeFileSync(path.join(f.outDir, 'prompt.md'), 'stale fixture\n');
  fs.writeFileSync(path.join(f.outDir, 'meta.json'), JSON.stringify({
    status: 'running',
    provider: 'codex',
    model: null,
    effort: null,
    cwd: f.cwd,
    label: 'stale-fixture',
    runnerPid: 2_147_483_647,
    sessionId: 'stale-session',
    takeoverCommand: 'codex resume stale-session',
    startedAt: '2020-01-01T00:00:00.000Z',
    durationMs: null,
    costUsd: null,
    tokens: null,
    error: null,
    gitBaseline: null,
  }, null, 2));

  const result = capture(spawn(process.execPath, [COLLECT, f.outDir], {
    cwd: f.cwd,
    env: testEnv(f, 'success'),
    stdio: ['ignore', 'pipe', 'pipe'],
  }));
  const collected = await result.completion;

  assert.equal(collected.code, 0, collected.stderr);
  assert.doesNotMatch(collected.stdout, /still live/i);
  assert.match(collected.stdout, /abandon|stale|runner.*dead/i);
  assert.match(collected.stdout, /inspect|raw\.log|provider process/i);
});

test('explicit collection reconciles a provably abandoned job and stamps it', async (t) => {
  const f = fixture(t);
  writeJob(f.outDir, {
    status: 'running',
    cwd: f.cwd,
    runnerPid: 99_999_999,
    providerPid: 99_999_999,
    providerPgid: 99_999_999,
    promptState: 'accepted',
    timeoutMin: 180,
    endedAt: null,
    durationMs: null,
  });

  const explicit = capture(spawn(process.execPath, [COLLECT, f.outDir], {
    cwd: f.cwd,
    env: testEnv(f, 'success'),
    stdio: ['ignore', 'pipe', 'pipe'],
  }));
  const collected = await explicit.completion;

  assert.equal(collected.code, 0, collected.stderr);
  assert.match(collected.stdout, /status: abandoned/);
  assert.match(collected.stdout, /Turn abandoned/);
  assert.match(collected.stdout, /resume: --resume fixture-session --timeout-min 180/);
  assert.match(collected.stdout, /continue the same session with --resume fixture-session --timeout-min 180/i);
  const meta = readMeta(f.outDir);
  assert.equal(meta.status, 'abandoned');
  assert.match(meta.reconciledAt, /^\d{4}-\d{2}-\d{2}T/);
  assert.match(meta.collectedAt, /^\d{4}-\d{2}-\d{2}T/);
  assert.equal(meta.nextAction, meta.recoveryAction);
});

test('abandoned collision recovery never synthesizes a null resume command', async (t) => {
  const f = fixture(t);
  writeJob(f.outDir, {
    status: 'running',
    cwd: f.cwd,
    runnerPid: 99_999_999,
    providerPid: 99_999_999,
    providerPgid: 99_999_999,
    promptState: 'accepted',
    sessionLockConflict: 'session fixture-session is locked by another live turn',
    resumeFlag: null,
    resumeArgs: null,
    takeoverCommand: null,
    endedAt: null,
    durationMs: null,
  });

  const collected = await capture(spawn(process.execPath, [COLLECT, f.outDir], {
    cwd: f.cwd,
    env: testEnv(f, 'success'),
    stdio: ['ignore', 'pipe', 'pipe'],
  })).completion;

  assert.equal(collected.code, 0, collected.stderr);
  assert.match(collected.stdout, /status: abandoned/);
  assert.match(collected.stdout, /session-lock collision/i);
  assert.match(collected.stdout, /do not resume or redispatch/i);
  assert.doesNotMatch(collected.stdout, /with null|^resume:|^takeover:/m);
  const meta = readMeta(f.outDir);
  assert.equal(meta.status, 'abandoned');
  assert.match(meta.recoveryAction, /do not resume or redispatch/i);
});

test('pending marks a dead-runner/live-provider job orphaned and forbids resume or redispatch', async (t) => {
  const f = fixture(t);
  const base = path.join(f.root, 'pending');
  const orphanedDir = path.join(base, '20260101-000000-orphaned');
  writeJob(orphanedDir, {
    status: 'running',
    cwd: f.cwd,
    runnerPid: 99_999_999,
    providerPid: process.pid,
    providerPgid: null,
    endedAt: null,
    durationMs: null,
  });

  const pending = capture(spawn(process.execPath, [COLLECT, '--pending', '--base', base], {
    cwd: f.cwd,
    env: testEnv(f, 'success'),
    stdio: ['ignore', 'pipe', 'pipe'],
  }));
  const listed = await pending.completion;

  assert.equal(listed.code, 0, listed.stderr);
  assert.match(listed.stdout, /\[orphaned\].*20260101-000000-orphaned/);
  assert.match(listed.stdout, /Resume or redispatch only after the process is gone/i);
  assert.equal(readMeta(orphanedDir).collectedAt, null);
});

test('collect --pending lists unseen terminal jobs for progressive recovery', async (t) => {
  const f = fixture(t);
  execFileSync('git', ['init', '-q'], { cwd: f.cwd });
  const base = path.join(f.cwd, '.sidekick');
  const seenDir = path.join(base, '20260101-000000-seen');
  const unseenDir = path.join(base, '20260101-000100-unseen');
  const liveDir = path.join(base, '20260101-000200-live');
  const abandonedDir = path.join(base, '20260101-000300-abandoned');
  writeJob(seenDir, { collectedAt: '2026-01-01T00:02:00.000Z' }, 'already collected result');
  writeJob(unseenDir, {}, 'missed completion recovered');
  writeJob(liveDir, {
    status: 'running',
    runnerPid: process.pid,
    runnerInstanceId: 'live-fixture-runner',
    endedAt: null,
    durationMs: null,
  });
  writeJob(abandonedDir, {
    status: 'running',
    runnerPid: 99_999_999,
    runnerInstanceId: 'abandoned-fixture-runner',
    providerPid: 99_999_999,
    providerPgid: 99_999_999,
    endedAt: null,
    durationMs: null,
  });

  const pending = capture(spawn(process.execPath, [COLLECT, '--pending', '--base', base], {
    cwd: f.cwd,
    env: testEnv(f, 'success'),
    stdio: ['ignore', 'pipe', 'pipe'],
  }));
  const collected = await pending.completion;

  assert.equal(collected.code, 0, collected.stderr);
  assert.match(collected.stdout, /20260101-000100-unseen/);
  assert.match(collected.stdout, /20260101-000300-abandoned/);
  assert.doesNotMatch(collected.stdout, /20260101-000200-live/);
  assert.doesNotMatch(collected.stdout, /20260101-000000-seen/);
  assert.equal(readMeta(unseenDir).collectedAt, null);
  assert.equal(readMeta(seenDir).collectedAt, '2026-01-01T00:02:00.000Z');
  assert.equal(readMeta(liveDir).collectedAt, null);

  const explicit = capture(spawn(process.execPath, [COLLECT, unseenDir], {
    cwd: f.cwd,
    env: testEnv(f, 'success'),
    stdio: ['ignore', 'pipe', 'pipe'],
  }));
  const explicitResult = await explicit.completion;
  assert.equal(explicitResult.code, 0, explicitResult.stderr);
  assert.match(explicitResult.stdout, /missed completion recovered/);
  assert.match(readMeta(unseenDir).collectedAt, /^\d{4}-\d{2}-\d{2}T/);

  const after = capture(spawn(process.execPath, [COLLECT, '--pending'], {
    cwd: f.cwd,
    env: testEnv(f, 'success'),
    stdio: ['ignore', 'pipe', 'pipe'],
  }));
  const afterResult = await after.completion;
  assert.equal(afterResult.code, 0, afterResult.stderr);
  assert.doesNotMatch(afterResult.stdout, /20260101-000100-unseen/);
});
