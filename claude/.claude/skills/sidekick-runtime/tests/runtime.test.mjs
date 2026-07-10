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

test('Claude JSON envelope still uses the injected provider executable', async (t) => {
  const f = fixture(t);
  const result = await runTurn(f, 'success', {
    provider: 'claude',
    env: { SIDEKICK_FAKE_FINAL_TEXT: 'claude completed the delegated task' },
  });

  assert.equal(result.code, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8'), 'claude completed the delegated task');
  const meta = readMeta(f.outDir);
  assert.equal(meta.provider, 'claude');
  assert.equal(meta.status, 'ok');
  assert.equal(meta.sessionId, 'fake-session-id');
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

test('successful provider result stays ok while a residual process group is reaped', { timeout: 10_000 }, async (t) => {
  const f = fixture(t);
  const grandchildPidFile = path.join(f.root, 'grandchild.pid');
  const grandchildReadyFile = path.join(f.root, 'grandchild.ready');
  const result = await runTurn(f, 'success-with-stubborn-grandchild', {
    env: {
      SIDEKICK_FAKE_FINAL_TEXT: 'complete result before residual cleanup',
      SIDEKICK_FAKE_GRANDCHILD_PID_FILE: grandchildPidFile,
      SIDEKICK_FAKE_GRANDCHILD_READY_FILE: grandchildReadyFile,
      SIDEKICK_SIGKILL_AFTER_MS: '150',
      SIDEKICK_CLOSE_GRACE_MS: '30',
    },
  });

  assert.equal(result.code, 0, result.stderr);
  const meta = readMeta(f.outDir);
  assert.equal(meta.status, 'ok');
  assert.equal(fs.readFileSync(path.join(f.outDir, 'result.md'), 'utf8'), 'complete result before residual cleanup');
  await assertProcessStops(readPid(grandchildPidFile), 'successful provider residual grandchild to stop');
});

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
  assert.match(body, /resume/i);
  assert.match(body, /fake-session-id/);
  await assertProcessStops(providerPid, 'timed-out provider to stop');
  await assertProcessStops(grandchildPid, 'timed-out provider grandchild to stop');
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
  assert.match(body, /resume/i);
  assert.match(body, /fake-session-id/);
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
  const meta = readMeta(f.outDir);
  assert.equal(meta.status, 'abandoned');
  assert.match(meta.reconciledAt, /^\d{4}-\d{2}-\d{2}T/);
  assert.match(meta.collectedAt, /^\d{4}-\d{2}-\d{2}T/);
  assert.equal(meta.nextAction, meta.recoveryAction);
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
  assert.match(listed.stdout, /Do not resume or redispatch/i);
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
