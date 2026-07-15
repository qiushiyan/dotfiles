#!/usr/bin/env node
// turn.mjs — run ONE headless AI-session turn (claude | codex) and return it as data.
// Shared engine for the /consult, /review, and /delegate skills. Node builtins only.
//
// Invocation patterns adapted from duet (~/dev/duet/src/providers/claude.ts,
// codex.ts) and the official codex plugin's companion script. Verified against
// claude v2.1.x and codex v0.142.x — on a CLI upgrade, re-check the argv facts
// in ENGINE.md before trusting a weird failure.
//
// Contract (full reference: ENGINE.md next to this file):
//   - stdout: one startup coordinate block, then one terminal coordinate block.
//   - files (authoritative): prompt/result/meta plus progress, raw stdout, stderr.
//   - exit codes: 0 ok · 1 provider failure · 2 infra · 3 usage · 4 timeout · 5 interrupted

import { spawn, execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';

const EFFORT = {
  claude: ['low', 'medium', 'high', 'xhigh', 'max'],
  codex: ['none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max', 'ultra'],
};

function durationFromEnv(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined) return fallback;
  const value = Number(raw);
  return Number.isFinite(value) && value >= 0 ? value : fallback;
}

const HEARTBEAT_MS = durationFromEnv('SIDEKICK_HEARTBEAT_MS', 30_000);
const TIMEOUT_POLL_MS = durationFromEnv('SIDEKICK_TIMEOUT_POLL_MS', 5_000);
const SIGKILL_AFTER_MS = durationFromEnv('SIDEKICK_SIGKILL_AFTER_MS', 10_000);
const CLOSE_GRACE_MS = durationFromEnv('SIDEKICK_CLOSE_GRACE_MS', 2_000);

const EXIT_CODE = {
  ok: 0,
  failed: 1,
  infra: 2,
  timeout: 4,
  interrupted: 5,
};

function writeFileAtomic(filePath, contents) {
  const tempPath = `${filePath}.${process.pid}.${randomUUID()}.tmp`;
  try {
    fs.writeFileSync(tempPath, contents);
    fs.renameSync(tempPath, filePath);
  } catch (err) {
    try { fs.unlinkSync(tempPath); } catch {}
    throw err;
  }
}

function shellQuote(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}

function formatDuration(ms) {
  if (ms < 90_000) return `${Math.max(0, Math.floor(ms / 1000))}s`;
  const totalMinutes = Math.floor(ms / 60_000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  return hours > 0 ? `${hours}h${minutes}m` : `${totalMinutes}m`;
}

function fail(msg) {
  process.stderr.write(`usage error: ${msg}\n`);
  process.exit(3);
}

// ---------- args ----------

function parseArgs(argv) {
  const opts = {
    provider: undefined,
    promptFile: undefined,
    model: undefined,
    effort: undefined,
    resume: undefined,
    baseline: undefined,
    allowWrite: false,
    cwd: process.cwd(),
    outDir: undefined,
    timeoutMin: 30,
    maxBudgetUsd: undefined,
    label: undefined,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => {
      if (i + 1 >= argv.length) fail(`${a} needs a value`);
      return argv[++i];
    };
    switch (a) {
      case '--provider': opts.provider = next(); break;
      case '--prompt-file': opts.promptFile = next(); break;
      case '--model': opts.model = next(); break;
      case '--effort': opts.effort = next(); break;
      case '--resume': opts.resume = next(); break;
      case '--baseline': opts.baseline = next(); break;
      case '--allow-write': opts.allowWrite = true; break;
      case '--cwd': opts.cwd = path.resolve(next()); break;
      case '--out-dir': opts.outDir = path.resolve(next()); break;
      case '--timeout-min': opts.timeoutMin = Number(next()); break;
      case '--max-budget-usd': opts.maxBudgetUsd = Number(next()); break;
      case '--label': opts.label = next(); break;
      default: fail(`unknown flag ${a}`);
    }
  }

  if (!opts.provider) fail('--provider <claude|codex> is required');
  if (!['claude', 'codex'].includes(opts.provider)) fail(`--provider must be claude or codex, got '${opts.provider}'`);
  if (!opts.promptFile) fail('--prompt-file <path> is required');
  if (!fs.existsSync(opts.promptFile)) fail(`prompt file not found: ${opts.promptFile}`);
  if (!fs.existsSync(opts.cwd)) fail(`cwd not found: ${opts.cwd}`);
  if (!Number.isFinite(opts.timeoutMin) || opts.timeoutMin < 0) fail('--timeout-min must be a number >= 0 (0 = no cap)');

  if (opts.effort !== undefined && !EFFORT[opts.provider].includes(opts.effort)) {
    // Validate BEFORE spawn: claude silently ignores an invalid effort (runs at
    // default), codex burns a turn-start and fails with an API 400 mid-stream.
    let hint = '';
    if (opts.provider === 'claude' && ['none', 'minimal'].includes(opts.effort)) hint = ` (claude has no '${opts.effort}'; its lowest is 'low')`;
    fail(`--effort '${opts.effort}' is not valid for ${opts.provider}. Valid: ${EFFORT[opts.provider].join(', ')}${hint}`);
  }
  if (opts.maxBudgetUsd !== undefined) {
    if (opts.provider !== 'claude') fail('--max-budget-usd exists only on claude; codex has no budget flag');
    if (!Number.isFinite(opts.maxBudgetUsd) || opts.maxBudgetUsd <= 0) fail('--max-budget-usd must be a positive number');
  }
  return opts;
}

// ---------- out-dir ----------

function gitRoot(cwd) {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], { cwd, stdio: ['ignore', 'pipe', 'ignore'] })
      .toString().trim();
  } catch {
    return undefined;
  }
}

function gitHead(cwd) {
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], { cwd, stdio: ['ignore', 'pipe', 'ignore'] })
      .toString().trim();
  } catch {
    return undefined;
  }
}

// ---------- session lock (one live turn per session id) ----------
// A concurrent second turn on the same session — including a --resume racing a
// live one — corrupts the conversation. The lock makes that race fail fast
// instead of silently interleaving. An existing lock is never reclaimed here:
// a dead runner can leave a live orphan provider, and automatic stale takeover
// cannot be made race-free with a plain lock file. Recovery must inspect first.

function lockPath(sessionId) {
  const dir = path.join(os.homedir(), '.local', 'state', 'sidekick', 'locks');
  fs.mkdirSync(dir, { recursive: true });
  return path.join(dir, `${sessionId.replace(/[^a-zA-Z0-9._-]+/g, '-')}.lock`);
}

function pidAlive(pid) {
  try { process.kill(pid, 0); return true; }
  catch (err) { return err.code === 'EPERM'; }
}

class SessionLockConflict extends Error {}

function acquireSessionLock(sessionId, outDir, runnerInstanceId, { soft = false } = {}) {
  const p = lockPath(sessionId);
  const payload = JSON.stringify({
    pid: process.pid,
    runnerInstanceId,
    outDir,
    startedAt: new Date().toISOString(),
  }) + '\n';
  try {
    fs.writeFileSync(p, payload, { flag: 'wx' });
    return p;
  } catch (err) {
    if (err.code !== 'EEXIST') throw err;
    let held;
    try { held = JSON.parse(fs.readFileSync(p, 'utf8')); } catch { held = undefined; }
    if (held && pidAlive(held.pid)) {
      const msg = `session ${sessionId} already has a live turn (pid ${held.pid}, started ${held.startedAt}, out-dir ${held.outDir}). One turn per session: wait for it, or observe it with: tail -f ${path.join(held.outDir ?? '', 'progress.log')}`;
      if (soft) throw new SessionLockConflict(msg);
      process.stderr.write(`lock error: ${msg}\n`);
      process.exit(3);
    }
    const heldOutDir = held?.outDir;
    const inspect = heldOutDir
      ? `Run node ${shellQuote(path.join(path.dirname(process.argv[1]), 'collect.mjs'))} ${shellQuote(heldOutDir)} and inspect its provider state. `
      : '';
    const msg = `session ${sessionId} has an existing lock whose runner is not provably live (${p}). Automatic takeover is refused because its provider may still be running. ${inspect}Only after the provider is gone and its work is accounted for, remove the stale lock and retry.`;
    if (soft) throw new SessionLockConflict(msg);
    process.stderr.write(`lock error: ${msg}\n`);
    process.exit(3);
  }
}

function releaseSessionLock(lockFile, runnerInstanceId) {
  if (!lockFile) return;
  try {
    const held = JSON.parse(fs.readFileSync(lockFile, 'utf8'));
    // Do not remove a lock that another runner acquired after manual cleanup or
    // PID reuse. Legacy locks have no instance id and are safe only when ours.
    if (held.runnerInstanceId && held.runnerInstanceId !== runnerInstanceId) return;
    if (!held.runnerInstanceId && held.pid !== process.pid) return;
    fs.unlinkSync(lockFile);
  } catch (err) {
    if (err.code !== 'ENOENT') console.error(`lock cleanup warning: ${err.message}`);
  }
}

function resolveOutDir(opts) {
  if (opts.outDir) {
    fs.mkdirSync(opts.outDir, { recursive: true });
    return opts.outDir;
  }
  const root = gitRoot(opts.cwd);
  const base = root
    ? path.join(root, '.sidekick')
    : path.join(os.homedir(), '.local', 'state', 'sidekick', path.basename(opts.cwd));
  fs.mkdirSync(base, { recursive: true });
  if (root) {
    // Self-ignore, never touch the repo's own .gitignore (the .duet/ pattern).
    const ignore = path.join(base, '.gitignore');
    if (!fs.existsSync(ignore)) fs.writeFileSync(ignore, '*\n');
  }
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const stamp = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
  const slug = (opts.label ?? opts.provider).toLowerCase().replace(/[^a-z0-9._-]+/g, '-').slice(0, 40);
  let dir = path.join(base, `${stamp}-${slug}`);
  if (fs.existsSync(dir)) dir = `${dir}-${randomUUID().slice(0, 4)}`;
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

// ---------- argv builders (one per provider — the per-provider surface lives here) ----------

function claudeArgs(opts, sessionId) {
  // stream-json emits completed message/tool events as they happen, while the
  // final `result` event retains the same status/usage envelope as json mode.
  // Keep partial token deltas off: event-boundary progress is useful without
  // multiplying log size with one record per generated chunk.
  const args = ['-p', '--output-format', 'stream-json', '--verbose'];
  if (opts.model) args.push('--model', opts.model);
  if (opts.effort) args.push('--effort', opts.effort);
  args.push(...(opts.resume ? ['--resume', opts.resume] : ['--session-id', sessionId]));
  // Write intent, not a sandbox: bypassPermissions lets the delegate edit/run
  // unattended. Without it the turn stays effectively read-only (unpermitted
  // tools fail; headless never prompts).
  if (opts.allowWrite) args.push('--permission-mode', 'bypassPermissions');
  if (opts.maxBudgetUsd !== undefined) args.push('--max-budget-usd', String(opts.maxBudgetUsd));
  return args;
}

function codexArgs(opts, lastMessagePath) {
  // No sandbox/permission flag EVER: ~/.codex/config.toml governs. A derived
  // read-only sandbox breaks the session's own tooling (duet, 2026-06-22).
  // `resume` takes the session id then `-` (prompt via stdin) and has no --cd;
  // cwd is set on the child process instead.
  const args = opts.resume ? ['exec', 'resume', '--json'] : ['exec', '--json'];
  if (opts.model) args.push('-m', opts.model);
  if (opts.effort) args.push('-c', `model_reasoning_effort=${opts.effort}`);
  args.push('-o', lastMessagePath);
  if (opts.resume) args.push(opts.resume);
  args.push('-');
  return args;
}

// ---------- claude stream parsing (adapted from duet's parseClaudeTurn) ----------

function parseClaudeMessages(messages) {
  const envelope = messages.find((m) => m && typeof m === 'object' && m.type === 'result');
  if (!envelope) return { kind: 'unparseable' };

  const usage = envelope.usage && typeof envelope.usage.input_tokens === 'number'
    ? {
        input: envelope.usage.input_tokens,
        cacheRead: envelope.usage.cache_read_input_tokens ?? 0,
        cacheCreation: envelope.usage.cache_creation_input_tokens ?? 0,
        output: envelope.usage.output_tokens ?? 0,
      }
    : undefined;
  const base = {
    sessionId: envelope.session_id,
    costUsd: typeof envelope.total_cost_usd === 'number' ? envelope.total_cost_usd : undefined,
    tokens: usage,
  };

  if (envelope.subtype === 'error_max_budget_usd') {
    return { kind: 'budget', ...base, partial: assistantText(messages, '') };
  }
  if (envelope.is_error || envelope.subtype !== 'success') {
    const errorText = typeof envelope.result === 'string'
      ? envelope.result
      : Array.isArray(envelope.errors) && envelope.errors.length > 0
        ? envelope.errors.join(' | ')
        : `turn failed (${envelope.subtype})`;
    // Recover real partial work; exclude the trailing assistant block that just
    // echoes the error itself.
    return { kind: 'failed', ...base, errorText, partial: assistantText(messages, errorText) };
  }
  return { kind: 'ok', ...base, text: envelope.result ?? '' };
}

function assistantText(messages, excludeText) {
  const exclude = excludeText.trim();
  const messageParts = [];
  for (const m of messages) {
    if (!m || m.type !== 'assistant' || !Array.isArray(m.message?.content)) continue;
    const blocks = [];
    for (const block of m.message.content) {
      if (block?.type === 'text' && typeof block.text === 'string' && block.text.trim() && block.text.trim() !== exclude) {
        blocks.push(block.text);
      }
    }
    if (blocks.length > 0) messageParts.push(blocks.join(''));
  }
  return messageParts.join('\n\n');
}

function claudeEventProvesAcceptance(event) {
  if (!event || typeof event !== 'object') return false;
  // `system/init` proves only that the process launched. User/assistant message
  // events and partial stream events prove that this turn reached model work.
  if (event.type === 'assistant' || event.type === 'user' || event.type === 'stream_event') return true;
  return event.type === 'result' && ['success', 'error_max_budget_usd'].includes(event.subtype);
}

// Claude persists its standard transcript while a print-mode turn runs. This
// is a timeout-only fallback for the narrow window before a stream event reaches
// stdout. Match the exact session filename and require activity from THIS turn;
// prior records in a resumed conversation are not acceptance evidence.
function claudeTranscriptEvidence(sessionId, sinceMs) {
  if (!sessionId || !/^[A-Za-z0-9._-]+$/.test(sessionId)) return undefined;
  try {
    const configDir = process.env.CLAUDE_CONFIG_DIR
      ? path.resolve(process.env.CLAUDE_CONFIG_DIR)
      : path.join(os.homedir(), '.claude');
    const projectsRoot = path.join(configDir, 'projects');
    if (!fs.existsSync(projectsRoot)) return undefined;
    const candidates = [];
    for (const entry of fs.readdirSync(projectsRoot, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const candidate = path.join(projectsRoot, entry.name, `${sessionId}.jsonl`);
      if (!fs.existsSync(candidate)) continue;
      candidates.push({ path: candidate, mtimeMs: fs.statSync(candidate).mtimeMs });
    }
    const transcript = candidates.sort((a, b) => b.mtimeMs - a.mtimeMs)[0]?.path;
    if (!transcript) return undefined;

    const size = fs.statSync(transcript).size;
    const maxBytes = 1024 * 1024;
    const start = Math.max(0, size - maxBytes);
    const fd = fs.openSync(transcript, 'r');
    let text;
    try {
      const buffer = Buffer.alloc(size - start);
      if (buffer.length > 0) fs.readSync(fd, buffer, 0, buffer.length, start);
      text = buffer.toString('utf8');
    } finally {
      fs.closeSync(fd);
    }
    if (start > 0) {
      const newline = text.indexOf('\n');
      text = newline === -1 ? '' : text.slice(newline + 1);
    }

    const messages = [];
    let accepted = false;
    let lastActivityAt;
    for (const raw of text.split('\n')) {
      if (!raw.trim().startsWith('{')) continue;
      let record;
      try { record = JSON.parse(raw); } catch { continue; }
      if (!record || !['user', 'assistant', 'result'].includes(record.type)) continue;
      const timestampMs = typeof record.timestamp === 'string' ? Date.parse(record.timestamp) : NaN;
      if (!Number.isFinite(timestampMs) || timestampMs < sinceMs) continue;
      accepted = true;
      if (!lastActivityAt || timestampMs > Date.parse(lastActivityAt)) lastActivityAt = record.timestamp;
      messages.push(record);
    }
    return {
      accepted,
      lastActivityAt: lastActivityAt ?? null,
      partial: assistantText(messages, ''),
    };
  } catch {
    return undefined; // recovery telemetry must never change the turn outcome
  }
}

// ---------- main ----------

const opts = parseArgs(process.argv.slice(2));
const outDir = resolveOutDir(opts);
const promptText = fs.readFileSync(opts.promptFile, 'utf8');
const startedAt = new Date();
const runnerInstanceId = randomUUID();

// Claude knows its session id before spawn (minted or resumed); Codex learns a
// fresh thread's id from the first thread.started event. Acquire the known-id
// lock before writing any job artifact so a rejected racing resume cannot
// truncate the live job's files when both calls name the same out-dir.
let sessionId = opts.provider === 'claude' ? (opts.resume ?? randomUUID()) : opts.resume;
let sessionLock = sessionId ? acquireSessionLock(sessionId, outDir, runnerInstanceId) : undefined;

const rawLog = path.join(outDir, 'raw.log');
const stderrLog = path.join(outDir, 'stderr.log');
const progressLog = path.join(outDir, 'progress.log');
const lastMessagePath = path.join(outDir, 'last-message.txt');
const metaPath = path.join(outDir, 'meta.json');
const deadlineAt = opts.timeoutMin > 0 ? new Date(startedAt.getTime() + opts.timeoutMin * 60_000) : undefined;
try {
  fs.copyFileSync(opts.promptFile, path.join(outDir, 'prompt.md'));
  fs.writeFileSync(rawLog, '');
  fs.writeFileSync(stderrLog, '');
  fs.writeFileSync(progressLog, '');
} catch (error) {
  releaseSessionLock(sessionLock, runnerInstanceId);
  throw error;
}

let progressWriteFailed = false;
function appendProgress(state, fields = {}) {
  try {
    const detail = Object.entries(fields)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => `${key}=${String(value).replace(/\s+/g, '_')}`)
      .join(' ');
    fs.appendFileSync(progressLog, `${new Date().toISOString()} state=${state}${detail ? ` ${detail}` : ''}\n`);
  } catch (error) {
    if (!progressWriteFailed) process.stderr.write(`progress log warning: ${error.message}\n`);
    progressWriteFailed = true;
  }
}

// The review anchor: explicit --baseline wins; a write turn defaults to HEAD so
// collect.mjs can always diff the delegate's work.
const baseline = opts.baseline ?? (opts.allowWrite ? gitHead(opts.cwd) : undefined);

const takeoverFor = (id) => (opts.provider === 'claude' ? `claude --resume ${id}` : `codex resume ${id}`);
const resumeFor = (id) => `--resume ${id} --timeout-min ${opts.timeoutMin}`;
const argv = opts.provider === 'claude' ? claudeArgs(opts, sessionId) : codexArgs(opts, lastMessagePath);
const env = opts.provider === 'claude'
  ? { ...process.env, API_FORCE_IDLE_TIMEOUT: '1' } // claude's native stall watchdog; a Claude API knob, never set on codex
  : { ...process.env };
const watchCommand = `tail -f ${shellQuote(progressLog)} ${shellQuote(rawLog)}`;

let claude = { messages: [] };
let codex = { finalText: undefined, errorText: undefined, tokens: undefined, threadStarted: false };
let lineBuffer = '';
let providerOutputBytes = 0;
let providerEventCount = 0;
let lastProviderOutputAt;
let lastProviderActivityAt;
let lastProviderEventType;
let providerTerminalAt;
let providerTerminalEventType;
let lockConflictError;

function observationFields() {
  return {
    providerOutputBytes,
    providerEventCount,
    lastProviderOutputAt: lastProviderOutputAt ?? null,
    lastProviderActivityAt: lastProviderActivityAt ?? null,
    lastProviderEventType: lastProviderEventType ?? null,
  };
}

// meta.json exists from turn start (status "running") so a killed or crashed job
// still leaves its coordinates on disk. Every update is replace-by-rename so a
// kill cannot leave a half-written JSON document.
let meta = {
  schemaVersion: 3,
  status: 'running',
  provider: opts.provider,
  model: opts.model ?? null, // null = the provider's own configured default
  effort: opts.effort ?? null,
  cwd: opts.cwd,
  allowWrite: opts.allowWrite,
  gitBaseline: baseline ?? null,
  sessionId: sessionId ?? null,
  resumeFlag: sessionId ? `--resume ${sessionId}` : null,
  resumeArgs: sessionId ? resumeFor(sessionId) : null,
  takeoverCommand: sessionId ? takeoverFor(sessionId) : null,
  sessionLockConflict: null,
  startedAt: startedAt.toISOString(),
  endedAt: null,
  durationMs: null,
  timeoutMin: opts.timeoutMin,
  deadlineAt: deadlineAt?.toISOString() ?? null,
  label: opts.label ?? null,
  promptFile: path.resolve(opts.promptFile),
  outDir,
  rawPath: rawLog,
  stderrPath: stderrLog,
  progressPath: progressLog,
  watchCommand,
  providerArgv: [opts.provider, ...argv],
  runnerPid: process.pid,
  runnerInstanceId,
  providerPid: null,
  providerPgid: null,
  childExitCode: null,
  childExitSignal: null,
  promptState: 'unknown',
  promptStateEvidence: null,
  promptAcceptedAt: null,
  terminationRequestedAt: null,
  interruptionSignal: null,
  lastHeartbeatAt: null,
  providerTerminalAt: null,
  providerTerminalEventType: null,
  ...observationFields(),
  tokens: null,
  costUsd: null,
  error: null,
  resultKind: 'none',
  nextAction: 'Return now and wait for Claude Code\'s native background-task notification. Use the watch command only for live observation; it is not a completion signal.',
  recoveryAction: null,
  collectedAt: null,
};

function writeMeta(extra = {}) {
  const sessionAvailable = Boolean(sessionId && !lockConflictError);
  meta = {
    ...meta,
    sessionId: sessionId ?? null,
    resumeFlag: sessionAvailable ? `--resume ${sessionId}` : null,
    resumeArgs: sessionAvailable ? resumeFor(sessionId) : null,
    takeoverCommand: sessionAvailable ? takeoverFor(sessionId) : null,
    sessionLockConflict: lockConflictError ?? null,
    ...observationFields(),
    ...extra,
  };
  writeFileAtomic(metaPath, JSON.stringify(meta, null, 2) + '\n');
}

console.log(`out-dir: ${outDir}`);
console.log(`provider: ${opts.provider} · model ${opts.model ?? '(provider default)'} · effort ${opts.effort ?? '(provider default)'} · hard cap ${opts.timeoutMin === 0 ? 'off' : `${opts.timeoutMin}m`}`);
console.log(`watch: ${watchCommand}`);
console.log(`raw: ${rawLog}`);
console.log(`stderr: ${stderrLog}`);
if (baseline) console.log(`baseline: ${baseline}`);
if (sessionId) {
  console.log(`session: ${sessionId}`);
  console.log(`takeover-after-terminal: ${takeoverFor(sessionId)}`);
}
console.log('next: return now; wait for the native background-task notification, then collect this job');
appendProgress('starting', {
  provider: opts.provider,
  hard_cap: opts.timeoutMin === 0 ? 'off' : `${opts.timeoutMin}m`,
  prompt: 'unknown',
});
writeMeta();

// On POSIX, a detached child leads its own process group. That lets timeout and
// cancellation stop provider grandchildren too, rather than only the CLI parent.
const child = spawn(opts.provider, argv, {
  cwd: opts.cwd,
  env,
  detached: process.platform !== 'win32',
  stdio: ['pipe', 'pipe', 'pipe'],
});
writeMeta({
  providerPid: child.pid ?? null,
  providerPgid: process.platform === 'win32' ? null : (child.pid ?? null),
});
appendProgress('running', {
  provider_process: child.pid ? 'alive' : 'unavailable',
  provider_pid: child.pid ?? 'unknown',
  prompt: meta.promptState,
});
child.stdin.on('error', (err) => {
  appendProgress('input-error', { detail: err.message });
});
child.stdin.end(promptText); // codex exec blocks forever on an open stdin pipe

function markPromptAccepted(evidence) {
  if (meta.promptState === 'accepted') return;
  const acceptedAt = new Date().toISOString();
  writeMeta({
    promptState: 'accepted',
    promptStateEvidence: evidence,
    promptAcceptedAt: acceptedAt,
  });
  appendProgress('accepted', { prompt: 'accepted', evidence, session: sessionId ?? 'pending' });
}

function recordProviderEvent(event) {
  providerEventCount += 1;
  lastProviderActivityAt = new Date().toISOString();
  lastProviderEventType = typeof event?.type === 'string' ? event.type : 'unknown';
}

function markProviderTerminal(eventType) {
  if (providerTerminalAt) return;
  providerTerminalAt = new Date().toISOString();
  providerTerminalEventType = eventType;
  writeMeta({ providerTerminalAt, providerTerminalEventType });
  appendProgress('provider-terminal', { event: eventType, prompt: meta.promptState });
}

function handleClaudeEvent(event) {
  if (Array.isArray(event)) {
    for (const item of event) handleClaudeEvent(item);
    return;
  }
  if (!event || typeof event !== 'object') return;
  claude.messages.push(event);
  recordProviderEvent(event);
  if (typeof event.session_id === 'string' && !sessionId) sessionId = event.session_id;
  if (event.type === 'system' && event.subtype === 'init') {
    appendProgress('provider-initialized', { session: event.session_id ?? sessionId ?? 'pending' });
  } else if (event.type === 'system' && event.subtype === 'api_retry') {
    appendProgress('provider-retry', {
      attempt: event.attempt,
      max_retries: event.max_retries,
      retry_delay_ms: event.retry_delay_ms,
    });
  }
  if (claudeEventProvesAcceptance(event)) markPromptAccepted(`claude ${event.type}${event.subtype ? `/${event.subtype}` : ''}`);
  if (event.type === 'result') markProviderTerminal(`claude ${event.subtype ?? 'result'}`);
}

function handleClaudeLine(line) {
  const text = line.trim();
  if (!text) return;
  try { handleClaudeEvent(JSON.parse(text)); } catch {
    // Keep foreign/malformed output in raw.log; a later valid result can still
    // complete the turn, and the raw protocol remains available for diagnosis.
  }
}

function handleCodexLine(line) {
  if (!line.trim()) return;
  let event;
  try {
    event = JSON.parse(line);
  } catch {
    return; // JSONL can carry non-JSON noise; it's in raw.log if it matters
  }
  recordProviderEvent(event);
  if (event.type === 'thread.started' && typeof event.thread_id === 'string') {
    codex.threadStarted = true;
    if (!sessionId) {
      sessionId = event.thread_id;
      console.log(`session: ${sessionId}`);
      // A fresh Codex id is learned only after spawn. A collision is improbable,
      // but once observed this turn must stop rather than continue unlocked.
      try {
        sessionLock = sessionLock ?? acquireSessionLock(sessionId, outDir, runnerInstanceId, { soft: true });
      } catch (error) {
        if (!(error instanceof SessionLockConflict)) throw error;
        lockConflictError = error.message;
        markPromptAccepted('codex thread.started with conflicting session lock');
        process.stderr.write(`lock error: ${lockConflictError}\n`);
        appendProgress('lock-conflict', { session: sessionId, action: 'stopping' });
        requestTermination('lock_conflict', 'SIGTERM');
        return;
      }
      console.log(`takeover-after-terminal: ${takeoverFor(sessionId)}`);
      markPromptAccepted('codex thread.started');
    } else {
      markPromptAccepted('codex thread.started');
    }
  } else if (event.type === 'item.completed' && event.item?.type === 'agent_message') {
    codex.finalText = event.item.text;
  } else if (event.type === 'turn.completed') {
    if (event.usage) {
      codex.tokens = {
        input: event.usage.input_tokens ?? 0,
        cachedInput: event.usage.cached_input_tokens ?? 0,
        output: event.usage.output_tokens ?? 0,
        reasoningOutput: event.usage.reasoning_output_tokens ?? 0,
      };
    }
    markProviderTerminal('codex turn.completed');
  } else if (event.type === 'turn.failed') {
    codex.errorText = event.error?.message ?? 'turn failed';
    markProviderTerminal('codex turn.failed');
  } else if (event.type === 'error') {
    codex.errorText = event.message ?? codex.errorText;
  }
}

child.stdout.setEncoding('utf8');
child.stderr.setEncoding('utf8');
child.stdout.on('data', (chunk) => {
  fs.appendFileSync(rawLog, chunk);
  providerOutputBytes += Buffer.byteLength(chunk);
  lastProviderOutputAt = new Date().toISOString();
  lineBuffer += chunk;
  const lines = lineBuffer.split('\n');
  lineBuffer = lines.pop() ?? '';
  for (const line of lines) {
    if (opts.provider === 'claude') handleClaudeLine(line);
    else handleCodexLine(line);
  }
});
let stderrTail = '';
child.stderr.on('data', (chunk) => {
  fs.appendFileSync(stderrLog, chunk);
  providerOutputBytes += Buffer.byteLength(chunk);
  lastProviderOutputAt = new Date().toISOString();
  stderrTail = (stderrTail + chunk).slice(-2000);
});

const heartbeat = HEARTBEAT_MS > 0
  ? setInterval(() => {
      if (opts.provider === 'claude' && meta.promptState !== 'accepted') {
        const transcript = claudeTranscriptEvidence(sessionId, startedAt.getTime());
        if (transcript?.accepted) markPromptAccepted('claude session transcript');
      }
      const now = new Date();
      const activityAge = lastProviderActivityAt
        ? `${formatDuration(now.getTime() - Date.parse(lastProviderActivityAt))}_ago`
        : 'none';
      const providerAlive = processGroupAlive() ? 'alive' : 'not_observed';
      writeMeta({ lastHeartbeatAt: now.toISOString() });
      appendProgress('running', {
        elapsed: formatDuration(now.getTime() - startedAt.getTime()),
        provider_process: providerAlive,
        last_provider_activity: activityAge,
        prompt: meta.promptState,
        events: providerEventCount,
      });
    }, HEARTBEAT_MS)
  : undefined;

// Wall-clock deadline (a Date comparison, not a monotonic timer): a laptop
// sleep freezes monotonic timers, so the first post-wake poll catches the
// overrun instead of letting the cap stretch to many real hours (duet's lesson).
let termination;
let forceKillTimer;
let exitFallbackTimer;
let forceFinalizeTimer;
let residualCleanupStarted = false;
let childExit = { code: null, signal: null };
let childDone = false;
let finished = false;

function signalProcessTree(signal) {
  if (!child.pid || childDone) return;
  if (process.platform !== 'win32') {
    try {
      process.kill(-child.pid, signal);
      return;
    } catch (err) {
      if (err.code === 'ESRCH') return;
    }
  }
  try { child.kill(signal); } catch {}
}

function processGroupAlive() {
  if (process.platform === 'win32' || !child.pid) return child.exitCode === null;
  try {
    process.kill(-child.pid, 0);
    return true;
  } catch (err) {
    return err.code === 'EPERM';
  }
}

function forceStopThenFinalize() {
  if (forceFinalizeTimer || childDone) return;
  signalProcessTree('SIGKILL');
  forceFinalizeTimer = setTimeout(
    () => onChildDone(childExit.code, childExit.signal),
    CLOSE_GRACE_MS,
  );
}

function cleanupResidualGroupThenFinalize() {
  if (residualCleanupStarted || childDone) return;
  residualCleanupStarted = true;
  signalProcessTree('SIGTERM');
  forceKillTimer = setTimeout(forceStopThenFinalize, SIGKILL_AFTER_MS);
}

function requestTermination(kind, signal) {
  if (finished || childDone) return;
  if (termination) {
    // A second interrupt is an explicit request to stop waiting for cleanup.
    if (kind === 'interrupted') {
      if (forceKillTimer) clearTimeout(forceKillTimer);
      forceStopThenFinalize();
    }
    return;
  }
  const requestedAt = new Date().toISOString();
  termination = { kind, signal, requestedAt };
  writeMeta({
    terminationRequestedAt: requestedAt,
    interruptionSignal: kind === 'interrupted' ? signal : null,
    nextAction: 'The provider is stopping. Wait for the terminal task notification before inspecting or resuming the job.',
  });
  appendProgress('stopping', {
    reason: kind === 'timeout' ? 'hard_cap' : signal,
    elapsed: formatDuration(Date.now() - startedAt.getTime()),
    prompt: meta.promptState,
  });
  signalProcessTree(signal === 'SIGINT' ? 'SIGINT' : 'SIGTERM');
  forceKillTimer = setTimeout(forceStopThenFinalize, SIGKILL_AFTER_MS);
}

for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) {
  process.on(signal, () => requestTermination('interrupted', signal));
}

const deadline = deadlineAt?.getTime();
const timeoutPoll = deadline
  ? setInterval(() => {
      if (Date.now() < deadline) return;
      clearInterval(timeoutPoll);
      requestTermination('timeout', 'SIGTERM');
    }, Math.max(1, TIMEOUT_POLL_MS))
  : undefined;

child.on('error', (err) => {
  finish({
    status: 'infra',
    errorText: `The sidekick runtime could not start ${opts.provider}: ${err.message}`,
    nextAction: 'The prompt was not accepted. Retry the identical dispatch once; if startup fails again, check the provider executable and report the infrastructure failure.',
    promptState: 'not_started',
    promptStateEvidence: 'provider spawn error',
  });
});

// Normal completion waits for 'close' (streams flushed). On a requested stop,
// direct-child exit is not enough: a grandchild can keep running after it. The
// runtime waits for the whole process group, escalates to SIGKILL, then gives
// streams one final drain window before publishing terminal metadata.
child.on('close', (code, signal) => {
  childExit = { code, signal };
  if (processGroupAlive()) {
    if (!termination) cleanupResidualGroupThenFinalize();
    return;
  }
  onChildDone(code, signal);
});
child.on('exit', (code, signal) => {
  childExit = { code, signal };
  if (termination) return; // TERM -> KILL -> drain owns forced completion.
  exitFallbackTimer = setTimeout(() => {
    if (processGroupAlive()) cleanupResidualGroupThenFinalize();
    else onChildDone(code, signal);
  }, CLOSE_GRACE_MS);
});

function recoveredCodexText() {
  if (codex.finalText !== undefined) return codex.finalText;
  try { return fs.readFileSync(lastMessagePath, 'utf8'); }
  catch { return undefined; }
}

function recoveryEvidence() {
  if (opts.provider === 'codex') {
    const partial = recoveredCodexText();
    return {
      accepted: codex.threadStarted || partial !== undefined,
      evidence: codex.threadStarted ? 'codex thread.started' : partial !== undefined ? 'codex recovered output' : null,
      partial,
      tokens: codex.tokens,
      costUsd: undefined,
    };
  }

  const parsed = parseClaudeMessages(claude.messages);
  const streamPartial = assistantText(claude.messages, parsed.kind === 'failed' ? parsed.errorText : '');
  const transcript = claudeTranscriptEvidence(sessionId, startedAt.getTime());
  if (meta.promptState !== 'accepted' && transcript?.accepted) markPromptAccepted('claude session transcript');
  return {
    accepted: meta.promptState === 'accepted' || transcript?.accepted === true,
    evidence: meta.promptStateEvidence ?? (transcript?.accepted ? 'claude session transcript' : null),
    partial: (parsed.kind === 'ok' ? parsed.text : parsed.kind === 'unparseable' ? undefined : parsed.partial)
      || streamPartial
      || transcript?.partial
      || undefined,
    tokens: parsed.kind === 'unparseable' ? undefined : parsed.tokens,
    costUsd: parsed.kind === 'unparseable' ? undefined : parsed.costUsd,
  };
}

function acceptanceGuidance(kind) {
  const observed = recoveryEvidence();
  const stopped = kind === 'timeout'
    ? `The ${opts.timeoutMin}-minute hard wall-clock cap ended this ${opts.provider} turn. Reaching the cap includes healthy active work and is not evidence that the provider hung.`
    : `The sidekick runtime stopped ${opts.provider} after receiving ${termination?.signal ?? 'an external signal'}.`;
  if (observed.accepted && sessionId) {
    return {
      promptState: 'accepted',
      promptStateEvidence: observed.evidence,
      errorText: `${stopped} The provider accepted the prompt, so the session or working tree may contain partial work.`,
      nextAction: `Inspect the recovered result, progress.log, stderr.log, and the working tree, then continue the same session with ${resumeFor(sessionId)}. Do not redispatch the original prompt because it could duplicate accepted work.`,
      ...observed,
    };
  }
  return {
    promptState: 'unknown',
    promptStateEvidence: null,
    errorText: `${stopped} Prompt acceptance is unconfirmed; absence of provider output is not proof that no work occurred.`,
    nextAction: `Inspect progress.log, raw.log, stderr.log, and the working tree. Redispatch only if you can positively establish that the prompt never began${sessionId ? `; otherwise continue the existing session with ${resumeFor(sessionId)}` : ''}.`,
    ...observed,
  };
}

function onChildDone(code, signal) {
  if (childDone) return;
  childDone = true;
  if (heartbeat) clearInterval(heartbeat);
  if (timeoutPoll) clearInterval(timeoutPoll);
  if (forceKillTimer) clearTimeout(forceKillTimer);
  if (exitFallbackTimer) clearTimeout(exitFallbackTimer);
  if (forceFinalizeTimer) clearTimeout(forceFinalizeTimer);
  if (lineBuffer) {
    if (opts.provider === 'claude') handleClaudeLine(lineBuffer);
    else handleCodexLine(lineBuffer);
    lineBuffer = '';
  }

  if (lockConflictError) {
    finish({
      status: 'infra',
      errorText: `Codex was stopped after reporting a session id that is already locked. ${lockConflictError}`,
      nextAction: 'Inspect or collect the job named in the lock error. Do not resume or redispatch this session until that turn and any orphan provider are terminal.',
      partial: recoveredCodexText(),
      tokens: codex.tokens,
      promptState: 'accepted',
      promptStateEvidence: 'codex thread.started with conflicting session lock',
      childExitCode: code,
      childExitSignal: signal,
    });
    return;
  }

  if (termination && !providerTerminalAt) {
    const recovery = acceptanceGuidance(termination.kind);
    finish({
      status: termination.kind === 'timeout' ? 'timeout' : 'interrupted',
      errorText: recovery.errorText,
      nextAction: recovery.nextAction,
      partial: recovery.partial,
      tokens: recovery.tokens,
      costUsd: recovery.costUsd,
      promptState: recovery.promptState,
      promptStateEvidence: recovery.promptStateEvidence,
      childExitCode: code,
      childExitSignal: signal,
    });
    return;
  }

  if (signal && !providerTerminalAt) {
    const observed = recoveryEvidence();
    const promptState = observed.accepted ? 'accepted' : 'unknown';
    finish({
      status: 'infra',
      errorText: `${opts.provider} ended unexpectedly after signal ${signal}; the sidekick runner itself was not asked to stop.`,
      nextAction: promptState === 'accepted' && sessionId
        ? `Inspect the recovered output, progress.log, stderr.log, and working tree, then continue with ${resumeFor(sessionId)}; do not redispatch the original prompt.`
        : 'Prompt acceptance is unconfirmed. Inspect progress.log, raw.log, stderr.log, the provider process state, and the working tree before choosing retry or resume.',
      partial: observed.partial,
      tokens: observed.tokens,
      costUsd: observed.costUsd,
      promptState,
      promptStateEvidence: observed.evidence,
      childExitCode: code,
      childExitSignal: signal,
    });
    return;
  }

  if (opts.provider === 'codex') {
    const recovered = recoveredCodexText();
    if (codex.errorText) {
      finish({
        status: 'failed',
        errorText: `Codex reported a provider failure: ${codex.errorText}`,
        nextAction: sessionId
          ? `Inspect the partial output and working tree. Fix the reported cause, then continue with ${resumeFor(sessionId)}; do not resend completed work.`
          : 'Inspect progress.log, raw.log, stderr.log, and the working tree before retrying; the runtime cannot prove whether the provider began work.',
        partial: recovered,
        tokens: codex.tokens,
        promptState: codex.threadStarted || recovered !== undefined ? 'accepted' : 'unknown',
        childExitCode: code,
        childExitSignal: signal,
      });
    } else if (recovered !== undefined) {
      if (code === 0 || (termination && providerTerminalEventType === 'codex turn.completed')) {
        finish({ status: 'ok', text: recovered, tokens: codex.tokens, promptState: 'accepted', childExitCode: code, childExitSignal: signal });
      } else {
        finish({
          status: 'failed',
          errorText: `Codex exited with code ${code} after producing a response.`,
          nextAction: sessionId
            ? `Read the recovered output and inspect the working tree, then continue with ${resumeFor(sessionId)} if work remains.`
            : 'Read the recovered output and inspect the working tree before deciding whether another dispatch is needed.',
          partial: recovered,
          tokens: codex.tokens,
          promptState: 'accepted',
          childExitCode: code,
          childExitSignal: signal,
        });
      }
    } else {
      const detail = stderrTail.trim().split('\n').filter(Boolean).slice(-3).join(' | ') || '(no stderr detail)';
      finish({
        status: 'infra',
        errorText: `Codex exited with code ${code} but returned no usable result. Last provider detail: ${detail}`,
        nextAction: codex.threadStarted && sessionId
          ? `The prompt was accepted. Inspect progress.log, raw.log, stderr.log, and the working tree, then continue with ${resumeFor(sessionId)}; do not redispatch the original prompt.`
          : 'Prompt acceptance is unconfirmed. Inspect progress.log, raw.log, stderr.log, and the working tree; retry unchanged only if they prove that work never began.',
        tokens: codex.tokens,
        promptState: codex.threadStarted ? 'accepted' : 'unknown',
        childExitCode: code,
        childExitSignal: signal,
      });
    }
    return;
  }

  const parsed = parseClaudeMessages(claude.messages);
  if (parsed.kind === 'unparseable') {
    const detail = stderrTail.trim().split('\n').filter(Boolean).slice(-3).join(' | ') || '(no stderr detail)';
    const observed = recoveryEvidence();
    finish({
      status: 'infra',
      errorText: `Claude exited with code ${code} but returned no parseable result envelope. Last provider detail: ${detail}`,
      nextAction: observed.accepted && sessionId
        ? `Inspect the recovered output, progress.log, stderr.log, and the working tree, then continue with ${resumeFor(sessionId)}; do not redispatch the original prompt.`
        : `Prompt acceptance is unconfirmed. Inspect progress.log, raw.log, stderr.log, and the working tree; retry unchanged only if work provably never began${sessionId ? `, otherwise continue with ${resumeFor(sessionId)}` : ''}.`,
      partial: observed.partial,
      promptState: observed.accepted ? 'accepted' : 'unknown',
      promptStateEvidence: observed.evidence,
      childExitCode: code,
      childExitSignal: signal,
    });
    return;
  }
  if (parsed.sessionId) sessionId = parsed.sessionId;
  if (parsed.kind === 'ok') {
    finish({
      status: 'ok', text: parsed.text, tokens: parsed.tokens, costUsd: parsed.costUsd,
      promptState: 'accepted', childExitCode: code, childExitSignal: signal,
    });
  } else if (parsed.kind === 'budget') {
    finish({
      status: 'failed',
      errorText: `Claude stopped at the --max-budget-usd ${opts.maxBudgetUsd} cap after accepting the prompt. Partial work may be on disk.`,
      nextAction: `Inspect the partial output and working tree, raise the budget cap, then continue with ${resumeFor(sessionId)}. Re-sending the original prompt could duplicate work.`,
      partial: parsed.partial, tokens: parsed.tokens, costUsd: parsed.costUsd,
      promptState: 'accepted', childExitCode: code, childExitSignal: signal,
    });
  } else {
    const observed = recoveryEvidence();
    finish({
      status: 'failed',
      errorText: `Claude reported a provider failure: ${parsed.errorText}`,
      nextAction: observed.accepted && sessionId
        ? `Inspect the partial output and working tree, fix the reported cause, then continue with ${resumeFor(sessionId)}.`
        : 'Prompt acceptance is unconfirmed. Inspect progress.log, raw.log, stderr.log, and the working tree before choosing retry or resume.',
      partial: parsed.partial, tokens: parsed.tokens, costUsd: parsed.costUsd,
      promptState: observed.accepted ? 'accepted' : 'unknown',
      promptStateEvidence: observed.evidence,
      childExitCode: code, childExitSignal: signal,
    });
  }
}

function finish({
  status,
  text,
  errorText,
  nextAction,
  partial,
  tokens,
  costUsd,
  promptState,
  promptStateEvidence,
  childExitCode,
  childExitSignal,
}) {
  if (finished) return;
  finished = true;
  if (heartbeat) clearInterval(heartbeat);
  if (timeoutPoll) clearInterval(timeoutPoll);
  if (forceKillTimer) clearTimeout(forceKillTimer);
  if (exitFallbackTimer) clearTimeout(exitFallbackTimer);
  if (forceFinalizeTimer) clearTimeout(forceFinalizeTimer);
  const endedAt = new Date();
  const collectScript = path.join(path.dirname(process.argv[1]), 'collect.mjs');
  const collectAction = `Collect and verify this job: node ${shellQuote(collectScript)} ${shellQuote(outDir)}.`;
  const recoveryAction = status === 'ok' ? null : (nextAction ?? 'Inspect result.md, progress.log, raw.log, and stderr.log before choosing a recovery action.');
  const hasPartial = typeof partial === 'string' && partial.trim().length > 0;
  const resultKind = status === 'ok' ? 'final' : hasPartial ? 'partial' : 'none';
  let resultBody;
  if (status === 'ok') {
    resultBody = text ?? '';
  } else {
    resultBody = `# Turn ${status}\n\n${errorText ?? ''}\n`;
    if (hasPartial) resultBody += `\n## Partial output recovered before the failure\n\n${partial}\n`;
  }
  const resultPath = path.join(outDir, 'result.md');
  writeFileAtomic(resultPath, resultBody);

  writeMeta({
    status,
    endedAt: endedAt.toISOString(),
    durationMs: endedAt.getTime() - startedAt.getTime(),
    tokens: tokens ?? null,
    costUsd: costUsd ?? null,
    error: status === 'ok' ? null : (errorText ?? null),
    nextAction: collectAction,
    recoveryAction,
    promptState: promptState ?? meta.promptState,
    ...(promptStateEvidence !== undefined ? { promptStateEvidence } : {}),
    resultKind,
    childExitCode: childExitCode ?? child.exitCode ?? null,
    childExitSignal: childExitSignal ?? child.signalCode ?? null,
  });
  appendProgress('terminal', {
    status,
    elapsed: formatDuration(endedAt.getTime() - startedAt.getTime()),
    result: resultKind,
    prompt: promptState ?? meta.promptState,
  });
  releaseSessionLock(sessionLock, runnerInstanceId);

  console.log('');
  console.log(`status: ${status}`);
  console.log(`result: ${resultPath}`);
  console.log(`meta: ${metaPath}`);
  console.log(`session: ${sessionId ?? '(none)'}`);
  if (sessionId && !lockConflictError) console.log(`takeover: ${takeoverFor(sessionId)}`);
  console.log(`next: ${collectAction}`);

  process.exit(EXIT_CODE[status] ?? EXIT_CODE.infra);
}
