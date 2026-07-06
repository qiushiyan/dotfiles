#!/usr/bin/env node
// collect.mjs — print one turn.mjs job as a single scannable block: the meta
// summary, the git delta since the recorded baseline, and result.md in full.
// Companion to turn.mjs; reads only what turn.mjs wrote. Node builtins only.
//
// usage: node collect.mjs [out-dir]
//   out-dir omitted → the newest job dir under <git-root>/.sidekick
//   (or ~/.local/state/sidekick/<cwd-basename> outside a git repo).
//
// Safe on a still-running turn: says so and shows what exists so far.

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';

function fail(msg) {
  process.stderr.write(`collect error: ${msg}\n`);
  process.exit(3);
}

function gitRoot(cwd) {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], { cwd, stdio: ['ignore', 'pipe', 'ignore'] })
      .toString().trim();
  } catch {
    return undefined;
  }
}

function latestJobDir() {
  const root = gitRoot(process.cwd());
  const base = root
    ? path.join(root, '.sidekick')
    : path.join(os.homedir(), '.local', 'state', 'sidekick', path.basename(process.cwd()));
  if (!fs.existsSync(base)) fail(`no job dirs under ${base}; pass an out-dir explicitly`);
  const dirs = fs.readdirSync(base)
    .filter((n) => fs.existsSync(path.join(base, n, 'prompt.md')))
    .sort(); // dir names lead with a YYYYMMDD-HHMMSS stamp, so lexical = chronological
  if (!dirs.length) fail(`no job dirs under ${base}; pass an out-dir explicitly`);
  return path.join(base, dirs[dirs.length - 1]);
}

function git(args, cwd) {
  try {
    return execFileSync('git', args, { cwd, stdio: ['ignore', 'pipe', 'pipe'] }).toString().trimEnd();
  } catch (err) {
    return `(git ${args.join(' ')} failed: ${err.stderr?.toString().trim() || err.message})`;
  }
}

const outDir = path.resolve(process.argv[2] ?? latestJobDir());
const metaPath = path.join(outDir, 'meta.json');
const resultPath = path.join(outDir, 'result.md');
if (!fs.existsSync(metaPath)) {
  fail(`${metaPath} not found — not a turn.mjs job dir, or the turn predates early meta writes (read ${path.join(outDir, 'raw.log')})`);
}
const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));

const fmtTokens = (t) => (t ? Object.entries(t).map(([k, v]) => `${k} ${Number(v).toLocaleString('en-US')}`).join(' · ') : 'n/a');

console.log(`job: ${outDir}`);
console.log(`status: ${meta.status}${meta.status === 'running' ? ' (still live — result.md is not final)' : ''}`);
console.log(`provider: ${meta.provider} · model ${meta.model ?? '(provider default)'} · effort ${meta.effort ?? '(provider default)'}${meta.label ? ` · label ${meta.label}` : ''}`);
if (meta.durationMs != null) console.log(`duration: ${Math.round(meta.durationMs / 60000)}m${meta.costUsd != null ? ` · cost $${meta.costUsd}` : ''}`);
console.log(`tokens: ${fmtTokens(meta.tokens)}`);
if (meta.sessionId) {
  console.log(`session: ${meta.sessionId}`);
  console.log(`resume: --resume ${meta.sessionId}`);
  console.log(`takeover: ${meta.takeoverCommand}`);
}
if (meta.error) console.log(`error: ${meta.error}`);

if (meta.gitBaseline) {
  console.log(`\n--- git since baseline ${meta.gitBaseline} (in ${meta.cwd}) ---`);
  console.log(git(['log', `${meta.gitBaseline}..HEAD`, '--oneline'], meta.cwd) || '(no commits)');
  console.log(git(['diff', meta.gitBaseline, '--stat'], meta.cwd) || '(no diff)');
  const dirty = git(['status', '--short'], meta.cwd);
  console.log(dirty ? `dirty:\n${dirty}` : 'tree clean');
}

console.log('\n--- result.md ---');
console.log(fs.existsSync(resultPath) ? fs.readFileSync(resultPath, 'utf8') : '(no result.md yet)');
