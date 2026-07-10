#!/usr/bin/env node
// collect.mjs — recover or print one turn.mjs job as a single scannable block.
//
// usage:
//   node collect.mjs [out-dir]
//   node collect.mjs --pending [--base DIR]
//
// Explicit collection prints meta, the git delta, and result.md, then stamps a
// terminal job with collectedAt. --pending is discovery-only: it lists new
// terminal results plus running jobs whose recorded process state needs review.

import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';

function fail(msg) {
  process.stderr.write(`collect error: ${msg}\n`);
  process.exit(3);
}

function usage() {
  console.log('usage: node collect.mjs [out-dir]');
  console.log('       node collect.mjs --pending [--base DIR]');
}

function parseArgs(argv) {
  let pending = false;
  let base;
  let outDir;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--pending') {
      pending = true;
    } else if (arg === '--base') {
      if (i + 1 >= argv.length) fail('--base needs a directory');
      base = path.resolve(argv[++i]);
    } else if (arg === '--help' || arg === '-h') {
      usage();
      process.exit(0);
    } else if (arg.startsWith('-')) {
      fail(`unknown flag ${arg}`);
    } else if (outDir) {
      fail('pass at most one out-dir');
    } else {
      outDir = path.resolve(arg);
    }
  }
  if (pending && outDir) fail('--pending does not take an out-dir; use --base to choose the job root');
  if (!pending && base) fail('--base is only valid with --pending');
  return { pending, base, outDir };
}

function gitRoot(cwd) {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], { cwd, stdio: ['ignore', 'pipe', 'ignore'] })
      .toString().trim();
  } catch {
    return undefined;
  }
}

function defaultBase(cwd) {
  const root = gitRoot(cwd);
  return root
    ? path.join(root, '.sidekick')
    : path.join(os.homedir(), '.local', 'state', 'sidekick', path.basename(cwd));
}

function jobDirs(base) {
  if (!fs.existsSync(base)) return [];
  return fs.readdirSync(base)
    .map((name) => path.join(base, name))
    .filter((dir) => fs.existsSync(path.join(dir, 'prompt.md')))
    .sort(); // stamped names make lexical order chronological
}

function latestJobDir(base) {
  const dirs = jobDirs(base);
  if (!dirs.length) fail(`no job dirs under ${base}; pass an out-dir explicitly`);
  return dirs[dirs.length - 1];
}

function git(args, cwd) {
  try {
    return execFileSync('git', args, { cwd, stdio: ['ignore', 'pipe', 'pipe'] }).toString().trimEnd();
  } catch (err) {
    return `(git ${args.join(' ')} failed: ${err.stderr?.toString().trim() || err.message})`;
  }
}

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

function readMeta(metaPath) {
  try {
    return { meta: JSON.parse(fs.readFileSync(metaPath, 'utf8')) };
  } catch (error) {
    return { error };
  }
}

function pidAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return null;
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    if (err.code === 'EPERM') return true;
    if (err.code === 'ESRCH') return false;
    return null;
  }
}

function processGroupAlive(pgid) {
  if (process.platform === 'win32' || !Number.isInteger(pgid) || pgid <= 0) return null;
  try {
    process.kill(-pgid, 0);
    return true;
  } catch (err) {
    if (err.code === 'EPERM') return true;
    if (err.code === 'ESRCH') return false;
    return null;
  }
}

function legacyRunnerPid(meta) {
  if (!meta.sessionId) return null;
  const lockDir = path.join(os.homedir(), '.local', 'state', 'sidekick', 'locks');
  const lockName = `${String(meta.sessionId).replace(/[^a-zA-Z0-9._-]+/g, '-')}.lock`;
  try {
    const lock = JSON.parse(fs.readFileSync(path.join(lockDir, lockName), 'utf8'));
    return Number.isInteger(lock.pid) ? lock.pid : null;
  } catch {
    return null;
  }
}

function runningState(meta) {
  if (meta.status !== 'running') return { kind: 'terminal' };
  const runnerPid = Number.isInteger(meta.runnerPid) ? meta.runnerPid : legacyRunnerPid(meta);
  const runnerAlive = pidAlive(runnerPid);
  const groupAlive = processGroupAlive(meta.providerPgid);
  const providerAlive = pidAlive(meta.providerPid);

  if (runnerAlive === true) {
    return {
      kind: 'live',
      detail: `a process with recorded runner PID ${runnerPid} is alive`,
    };
  }
  if (groupAlive === true || providerAlive === true) {
    const id = meta.providerPgid ?? meta.providerPid;
    return {
      kind: 'orphaned',
      detail: `the runner is gone, but a process in the recorded provider group ${id} is still alive`,
    };
  }
  if (runnerAlive === false && (groupAlive === false || (meta.providerPgid == null && providerAlive === false))) {
    return {
      kind: 'abandoned',
      detail: 'the recorded runner and provider process group are no longer alive',
    };
  }
  return {
    kind: 'unknown',
    detail: 'the job predates complete PID tracking, so provider liveness cannot be established safely',
  };
}

function recoveryForStale(meta, state) {
  if (state.kind === 'orphaned') {
    return 'Do not resume or redispatch: another provider process may still be changing the tree. Stop or wait for that process first, then inspect raw.log and the working tree.';
  }
  if (state.kind === 'abandoned') {
    if (meta.promptState === 'accepted' && meta.sessionId) {
      return `Inspect raw.log and the working tree, then continue the same session with --resume ${meta.sessionId}; re-sending the original prompt could duplicate work.`;
    }
    if (meta.promptState === 'not_started') {
      return 'The prompt was not started. Redispatch the identical call once.';
    }
    return `Inspect raw.log and the working tree first. Redispatch only if neither shows partial work${meta.sessionId ? `; otherwise continue with --resume ${meta.sessionId}` : ''}.`;
  }
  return 'Inspect raw.log, the provider process list, and the working tree before resuming or redispatching; liveness is unknown.';
}

function pendingJobs(base) {
  const pending = [];
  for (const dir of jobDirs(base)) {
    const metaPath = path.join(dir, 'meta.json');
    if (!fs.existsSync(metaPath)) continue;
    const read = readMeta(metaPath);
    if (read.error) {
      pending.push({ kind: 'corrupt', dir, detail: `meta.json is unreadable: ${read.error.message}` });
      continue;
    }
    const { meta } = read;
    if (meta.status === 'running') {
      const state = runningState(meta);
      if (state.kind !== 'live') pending.push({ ...state, dir, meta });
      continue;
    }
    // Missing collectedAt means a legacy job, not a newly missed notification.
    if (Object.hasOwn(meta, 'collectedAt') && meta.collectedAt === null) {
      pending.push({ kind: 'terminal', dir, meta, detail: `terminal status ${meta.status} has not been collected` });
    }
  }
  return pending;
}

function printPending(base) {
  const pending = pendingJobs(base);
  console.log(`pending jobs: ${pending.length} (under ${base})`);
  if (!pending.length) {
    console.log('next: no recovery action is needed');
    return;
  }
  for (const item of pending) {
    console.log(`\n[${item.kind}${item.meta?.status && item.kind === 'terminal' ? `:${item.meta.status}` : ''}] ${item.dir}`);
    console.log(`why: ${item.detail}`);
    if (item.kind === 'terminal') {
      console.log(`next: node ${shellQuote(process.argv[1])} ${shellQuote(item.dir)}`);
    } else if (item.kind === 'corrupt') {
      console.log(`next: inspect ${path.join(item.dir, 'raw.log')} and the working tree; do not infer completion from the damaged metadata`);
    } else {
      console.log(`next: ${recoveryForStale(item.meta, item)}`);
    }
  }
}

function reconcileAbandoned(outDir, meta, state) {
  if (state.kind !== 'abandoned') return meta;
  const error = `The sidekick runner ended without publishing a terminal result; ${state.detail}.`;
  const nextAction = recoveryForStale(meta, state);
  const reconciled = {
    ...meta,
    status: 'abandoned',
    reconciledAt: new Date().toISOString(),
    error,
    nextAction: `Collect and inspect this reconciled job: node ${shellQuote(process.argv[1])} ${shellQuote(outDir)}.`,
    recoveryAction: nextAction,
    collectedAt: meta.collectedAt ?? null,
  };
  const resultPath = path.join(outDir, 'result.md');
  if (!fs.existsSync(resultPath)) {
    writeFileAtomic(resultPath, `# Turn abandoned\n\n${error}\n\n**After collecting:** ${nextAction}\n`);
  }
  writeFileAtomic(path.join(outDir, 'meta.json'), JSON.stringify(reconciled, null, 2) + '\n');
  return reconciled;
}

function collect(outDir) {
  const metaPath = path.join(outDir, 'meta.json');
  const resultPath = path.join(outDir, 'result.md');
  if (!fs.existsSync(metaPath)) {
    fail(`${metaPath} not found — inspect ${path.join(outDir, 'raw.log')} before deciding whether to retry`);
  }
  const read = readMeta(metaPath);
  if (read.error) {
    fail(`${metaPath} is not valid JSON (${read.error.message}). Inspect raw.log and the working tree; do not assume the job finished or retry it blindly.`);
  }
  let { meta } = read;
  let state = runningState(meta);
  meta = reconcileAbandoned(outDir, meta, state);
  state = runningState(meta);

  const fmtTokens = (tokens) => (tokens
    ? Object.entries(tokens).map(([key, value]) => `${key} ${Number(value).toLocaleString('en-US')}`).join(' · ')
    : 'n/a');

  console.log(`job: ${outDir}`);
  if (meta.status === 'running') console.log(`status: running (${state.kind} — ${state.detail}; result.md is not final)`);
  else console.log(`status: ${meta.status}`);
  console.log(`provider: ${meta.provider} · model ${meta.model ?? '(provider default)'} · effort ${meta.effort ?? '(provider default)'}${meta.label ? ` · label ${meta.label}` : ''}`);
  if (meta.durationMs != null) console.log(`duration: ${Math.round(meta.durationMs / 60000)}m${meta.costUsd != null ? ` · cost $${meta.costUsd}` : ''}`);
  console.log(`tokens: ${fmtTokens(meta.tokens)}`);
  console.log(`prompt: ${meta.promptState ?? 'unknown'}`);
  if (meta.sessionId) {
    console.log(`session: ${meta.sessionId}`);
    console.log(`resume: --resume ${meta.sessionId}`);
    console.log(`takeover: ${meta.takeoverCommand}`);
  }
  if (meta.error) console.log(`error: ${meta.error}`);
  if (meta.collectedAt) console.log(`collected: ${meta.collectedAt}`);

  if (meta.gitBaseline) {
    console.log(`\n--- git since baseline ${meta.gitBaseline} (in ${meta.cwd}) ---`);
    console.log(git(['log', `${meta.gitBaseline}..HEAD`, '--oneline'], meta.cwd) || '(no commits)');
    console.log(git(['diff', meta.gitBaseline, '--stat'], meta.cwd) || '(no diff)');
    const dirty = git(['status', '--short'], meta.cwd);
    console.log(dirty ? `dirty:\n${dirty}` : 'tree clean');
  }

  console.log('\n--- result.md ---');
  console.log(fs.existsSync(resultPath) ? fs.readFileSync(resultPath, 'utf8') : '(no result.md yet)');

  if (meta.status === 'running') {
    console.log(`\nnext: ${state.kind === 'live'
      ? 'Wait for Claude Code\'s native background-task notification; polling is unnecessary.'
      : recoveryForStale(meta, state)}`);
    return;
  }

  const now = new Date().toISOString();
  const postCollectionAction = meta.status === 'ok'
    ? 'Use this result in the invoking skill\'s verification, judgment, or synthesis step.'
    : (meta.recoveryAction ?? meta.nextAction);
  if (!meta.collectedAt) {
    meta = { ...meta, collectedAt: now, nextAction: postCollectionAction };
    writeFileAtomic(metaPath, JSON.stringify(meta, null, 2) + '\n');
  }
  console.log(`\nnext: ${postCollectionAction}`);
}

const args = parseArgs(process.argv.slice(2));
if (args.pending) {
  printPending(args.base ?? defaultBase(process.cwd()));
} else {
  const outDir = args.outDir ?? latestJobDir(defaultBase(process.cwd()));
  collect(outDir);
}
