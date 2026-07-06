#!/usr/bin/env node
// turn.mjs — run ONE headless AI-session turn (claude | codex) and return it as data.
// Shared engine for the /consult and /delegate skills. Node builtins only.
//
// Invocation patterns adapted from duet (~/dev/duet/src/providers/claude.ts,
// codex.ts) and the official codex plugin's companion script. Verified against
// claude v2.1.x and codex v0.142.x — on a CLI upgrade, re-check the argv facts
// in ENGINE.md before trusting a weird failure.
//
// Contract (full reference: ENGINE.md next to this file):
//   - stdout: `session:` line as soon as the id is known, a heartbeat line
//     every 30s, then a final scannable block (status/result/meta/session).
//   - files (authoritative): <out-dir>/{prompt.md,result.md,meta.json,raw.log}
//   - exit codes: 0 ok · 1 provider-reported failure · 2 infra · 3 usage · 4 timeout

import { spawn, execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';

const EFFORT = {
  claude: ['low', 'medium', 'high', 'xhigh', 'max'],
  codex: ['none', 'minimal', 'low', 'medium', 'high', 'xhigh'],
};

const HEARTBEAT_MS = 30_000;
const TIMEOUT_POLL_MS = 5_000;
const SIGKILL_AFTER_MS = 10_000;

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
    if (opts.provider === 'codex' && opts.effort === 'max') hint = " (codex has no 'max'; its highest is 'xhigh')";
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
// instead of silently interleaving. Stale locks (dead pid) are taken over.

function lockPath(sessionId) {
  const dir = path.join(os.homedir(), '.local', 'state', 'sidekick', 'locks');
  fs.mkdirSync(dir, { recursive: true });
  return path.join(dir, `${sessionId.replace(/[^a-zA-Z0-9._-]+/g, '-')}.lock`);
}

function pidAlive(pid) {
  try { process.kill(pid, 0); return true; }
  catch (err) { return err.code === 'EPERM'; }
}

function acquireSessionLock(sessionId, outDir, { soft = false } = {}) {
  const p = lockPath(sessionId);
  const payload = JSON.stringify({ pid: process.pid, outDir, startedAt: new Date().toISOString() }) + '\n';
  try {
    fs.writeFileSync(p, payload, { flag: 'wx' });
    return p;
  } catch (err) {
    if (err.code !== 'EEXIST') throw err;
    let held;
    try { held = JSON.parse(fs.readFileSync(p, 'utf8')); } catch { held = undefined; }
    if (held && pidAlive(held.pid)) {
      const msg = `session ${sessionId} already has a live turn (pid ${held.pid}, started ${held.startedAt}, out-dir ${held.outDir}). One turn per session: wait for it, or watch it with: tail -f ${path.join(held.outDir ?? '', 'raw.log')}`;
      if (soft) { console.log(`lock warning: ${msg}`); return undefined; }
      process.stderr.write(`lock error: ${msg}\n`);
      process.exit(3);
    }
    fs.writeFileSync(p, payload); // stale lock from a dead process — take it over
    return p;
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
  const args = ['-p', '--output-format', 'json'];
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

// ---------- claude envelope parsing (adapted from duet's parseClaudeTurn) ----------

function parseClaudeStdout(stdout) {
  let parsed;
  try {
    parsed = JSON.parse(stdout);
  } catch {
    return { kind: 'unparseable' };
  }
  const messages = Array.isArray(parsed) ? parsed : [parsed];
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
    const errorText = typeof envelope.result === 'string' ? envelope.result : `turn failed (${envelope.subtype})`;
    // Recover real partial work; exclude the trailing assistant block that just
    // echoes the error itself.
    return { kind: 'failed', ...base, errorText, partial: assistantText(messages, errorText) };
  }
  return { kind: 'ok', ...base, text: envelope.result ?? '' };
}

function assistantText(messages, excludeText) {
  const exclude = excludeText.trim();
  const parts = [];
  for (const m of messages) {
    if (!m || m.type !== 'assistant' || !Array.isArray(m.message?.content)) continue;
    for (const block of m.message.content) {
      if (block?.type === 'text' && typeof block.text === 'string' && block.text.trim() && block.text.trim() !== exclude) {
        parts.push(block.text);
      }
    }
  }
  return parts.join('');
}

// ---------- main ----------

const opts = parseArgs(process.argv.slice(2));
const outDir = resolveOutDir(opts);
const promptText = fs.readFileSync(opts.promptFile, 'utf8');
fs.copyFileSync(opts.promptFile, path.join(outDir, 'prompt.md'));
const rawLog = path.join(outDir, 'raw.log');
const lastMessagePath = path.join(outDir, 'last-message.txt');
const startedAt = new Date();

// claude knows its session id before spawn (minted or resumed); codex learns a
// fresh thread's id from the first thread.started event.
let sessionId = opts.provider === 'claude' ? (opts.resume ?? randomUUID()) : opts.resume;

// The review anchor: explicit --baseline wins; a write turn defaults to HEAD so
// collect.mjs can always diff the delegate's work.
const baseline = opts.baseline ?? (opts.allowWrite ? gitHead(opts.cwd) : undefined);
let sessionLock = sessionId ? acquireSessionLock(sessionId, outDir) : undefined;

const takeoverFor = (id) => (opts.provider === 'claude' ? `claude --resume ${id}` : `codex resume ${id}`);

// meta.json exists from turn start (status "running") so a killed or crashed job
// still leaves its coordinates on disk; finish() overwrites with the final record.
function writeMeta(extra) {
  const meta = {
    status: 'running',
    provider: opts.provider,
    model: opts.model ?? null, // null = the provider's own configured default
    effort: opts.effort ?? null,
    cwd: opts.cwd,
    allowWrite: opts.allowWrite,
    gitBaseline: baseline ?? null,
    sessionId: sessionId ?? null,
    resumeFlag: sessionId ? `--resume ${sessionId}` : null,
    takeoverCommand: sessionId ? takeoverFor(sessionId) : null,
    startedAt: startedAt.toISOString(),
    endedAt: null,
    durationMs: null,
    timeoutMin: opts.timeoutMin,
    label: opts.label ?? null,
    promptFile: path.resolve(opts.promptFile),
    outDir,
    tokens: null,
    costUsd: null,
    error: null,
    ...extra,
  };
  fs.writeFileSync(path.join(outDir, 'meta.json'), JSON.stringify(meta, null, 2) + '\n');
}

const argv = opts.provider === 'claude' ? claudeArgs(opts, sessionId) : codexArgs(opts, lastMessagePath);
const env = opts.provider === 'claude'
  ? { ...process.env, API_FORCE_IDLE_TIMEOUT: '1' } // claude's native stall watchdog; a Claude API knob, never set on codex
  : { ...process.env };

fs.appendFileSync(rawLog, `# ${opts.provider} ${argv.join(' ')}\n# cwd: ${opts.cwd}\n# started: ${startedAt.toISOString()}\n`);
console.log(`out-dir: ${outDir}`);
console.log(`watch: tail -f ${rawLog}`);
if (baseline) console.log(`baseline: ${baseline}`);
if (sessionId) {
  console.log(`session: ${sessionId}`);
  console.log(`takeover: ${takeoverFor(sessionId)}`);
}
writeMeta({ status: 'running' });

const child = spawn(opts.provider, argv, { cwd: opts.cwd, env, stdio: ['pipe', 'pipe', 'pipe'] });
child.stdin.write(promptText);
child.stdin.end(); // codex exec blocks forever on an open stdin pipe

let claudeStdout = '';
let codex = { finalText: undefined, errorText: undefined, tokens: undefined, threadStarted: false };
let lineBuffer = '';

function handleCodexLine(line) {
  if (!line.trim()) return;
  let event;
  try {
    event = JSON.parse(line);
  } catch {
    return; // JSONL can carry non-JSON noise; it's in raw.log if it matters
  }
  if (event.type === 'thread.started' && typeof event.thread_id === 'string') {
    codex.threadStarted = true;
    if (!sessionId) {
      sessionId = event.thread_id;
      console.log(`session: ${sessionId}`);
      console.log(`takeover: ${takeoverFor(sessionId)}`);
      // soft: a fresh thread id can't be mid-race; never kill a running turn over it
      sessionLock = sessionLock ?? acquireSessionLock(sessionId, outDir, { soft: true });
      writeMeta({ status: 'running' });
    }
  } else if (event.type === 'item.completed' && event.item?.type === 'agent_message') {
    codex.finalText = event.item.text;
  } else if (event.type === 'turn.completed' && event.usage) {
    codex.tokens = {
      input: event.usage.input_tokens ?? 0,
      cachedInput: event.usage.cached_input_tokens ?? 0,
      output: event.usage.output_tokens ?? 0,
      reasoningOutput: event.usage.reasoning_output_tokens ?? 0,
    };
  } else if (event.type === 'turn.failed') {
    codex.errorText = event.error?.message ?? 'turn failed';
  } else if (event.type === 'error') {
    codex.errorText = event.message ?? codex.errorText;
  }
}

child.stdout.on('data', (chunk) => {
  fs.appendFileSync(rawLog, chunk);
  if (opts.provider === 'claude') {
    claudeStdout += chunk;
  } else {
    lineBuffer += chunk;
    const lines = lineBuffer.split('\n');
    lineBuffer = lines.pop() ?? '';
    for (const line of lines) handleCodexLine(line);
  }
});
let stderrTail = '';
child.stderr.on('data', (chunk) => {
  fs.appendFileSync(rawLog, chunk);
  stderrTail = (stderrTail + chunk).slice(-2000);
});

const heartbeat = setInterval(() => {
  const mins = Math.round((Date.now() - startedAt.getTime()) / 60_000);
  console.log(`elapsed ${mins}m — session ${sessionId ?? 'pending'}`);
}, HEARTBEAT_MS);

// Wall-clock deadline (a Date comparison, not a monotonic timer): a laptop
// sleep freezes monotonic timers, so the first post-wake poll catches the
// overrun instead of letting the cap stretch to many real hours (duet's lesson).
let timedOut = false;
const deadline = opts.timeoutMin > 0 ? startedAt.getTime() + opts.timeoutMin * 60_000 : undefined;
const timeoutPoll = deadline
  ? setInterval(() => {
      if (Date.now() < deadline) return;
      timedOut = true;
      child.kill('SIGTERM');
      setTimeout(() => { try { child.kill('SIGKILL'); } catch {} }, SIGKILL_AFTER_MS).unref();
    }, TIMEOUT_POLL_MS)
  : undefined;

child.on('error', (err) => {
  clearInterval(heartbeat);
  if (timeoutPoll) clearInterval(timeoutPoll);
  finish({ status: 'infra', errorText: `failed to spawn ${opts.provider}: ${err.message}` });
});

// Normal completion waits for 'close' (streams flushed). A timeout kill can
// leave grandchild processes holding the stdio pipes so 'close' never fires;
// 'exit' + a short grace period is the fallback that keeps the cap honest.
let childDone = false;
child.on('close', (code) => onChildDone(code));
child.on('exit', (code) => {
  if (!timedOut) return;
  setTimeout(() => onChildDone(code ?? 0), 2000);
});

function onChildDone(code) {
  if (childDone) return;
  childDone = true;
  clearInterval(heartbeat);
  if (timeoutPoll) clearInterval(timeoutPoll);
  if (lineBuffer && opts.provider === 'codex') handleCodexLine(lineBuffer);

  if (timedOut) {
    const accepted = opts.provider === 'codex' ? codex.threadStarted : Boolean(sessionId);
    finish({
      status: 'timeout',
      errorText: `killed at the ${opts.timeoutMin}-minute cap.` + (accepted && sessionId
        ? ` The session accepted the prompt and may hold partial work — inspect it and RESUME (--resume ${sessionId}) rather than re-sending the same prompt.`
        : ' The prompt was never accepted; re-dispatching the identical turn is safe.'),
      partial: codex.finalText,
    });
    return;
  }

  if (opts.provider === 'codex') {
    if (codex.errorText) {
      finish({ status: 'failed', errorText: codex.errorText, partial: codex.finalText, tokens: codex.tokens });
    } else if (codex.finalText !== undefined || fs.existsSync(lastMessagePath)) {
      const text = codex.finalText ?? fs.readFileSync(lastMessagePath, 'utf8');
      finish({ status: code === 0 ? 'ok' : 'failed', text, tokens: codex.tokens, errorText: code === 0 ? undefined : `codex exited ${code}` });
    } else {
      finish({ status: 'infra', errorText: `codex exited ${code} with no result. stderr tail: ${stderrTail.trim() || '(empty)'}` });
    }
    return;
  }

  const parsed = parseClaudeStdout(claudeStdout);
  if (parsed.kind === 'unparseable') {
    finish({ status: 'infra', errorText: `claude exited ${code} with no parseable result envelope. stderr tail: ${stderrTail.trim() || '(empty)'}` });
    return;
  }
  if (parsed.sessionId) sessionId = parsed.sessionId;
  if (parsed.kind === 'ok') {
    finish({ status: 'ok', text: parsed.text, tokens: parsed.tokens, costUsd: parsed.costUsd });
  } else if (parsed.kind === 'budget') {
    finish({
      status: 'failed',
      errorText: `budget cap hit (--max-budget-usd ${opts.maxBudgetUsd}). Committed work may be on disk; raise the cap and RESUME (--resume ${sessionId}) for the remainder.`,
      partial: parsed.partial, tokens: parsed.tokens, costUsd: parsed.costUsd,
    });
  } else {
    finish({ status: 'failed', errorText: parsed.errorText, partial: parsed.partial, tokens: parsed.tokens, costUsd: parsed.costUsd });
  }
}

function finish({ status, text, errorText, partial, tokens, costUsd }) {
  const endedAt = new Date();
  let resultBody;
  if (status === 'ok') {
    resultBody = text ?? '';
  } else {
    resultBody = `# Turn ${status}\n\n${errorText ?? ''}\n`;
    if (partial && partial.trim()) resultBody += `\n## Partial output recovered before the failure\n\n${partial}\n`;
  }
  const resultPath = path.join(outDir, 'result.md');
  fs.writeFileSync(resultPath, resultBody);

  writeMeta({
    status,
    endedAt: endedAt.toISOString(),
    durationMs: endedAt.getTime() - startedAt.getTime(),
    tokens: tokens ?? null,
    costUsd: costUsd ?? null,
    error: status === 'ok' ? null : (errorText ?? null),
  });
  if (sessionLock) { try { fs.unlinkSync(sessionLock); } catch {} }

  console.log('');
  console.log(`status: ${status}`);
  console.log(`result: ${resultPath}`);
  console.log(`meta: ${path.join(outDir, 'meta.json')}`);
  console.log(`session: ${sessionId ?? '(none)'}`);
  if (sessionId) console.log(`takeover: ${takeoverFor(sessionId)}`);

  process.exit(status === 'ok' ? 0 : status === 'failed' ? 1 : status === 'timeout' ? 4 : 2);
}
