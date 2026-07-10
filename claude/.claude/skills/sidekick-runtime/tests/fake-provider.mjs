#!/usr/bin/env node

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const provider = process.argv[2];
const providerArgs = process.argv.slice(3);
const scenario = process.env.SIDEKICK_FAKE_SCENARIO ?? 'success';
const sessionId = process.env.SIDEKICK_FAKE_SESSION_ID ?? 'fake-session-id';
const finalText = process.env.SIDEKICK_FAKE_FINAL_TEXT ?? 'fake provider result';

if (!['codex', 'claude'].includes(provider)) {
  process.stderr.write(`unknown fake provider: ${provider}\n`);
  process.exit(64);
}

if (process.env.SIDEKICK_FAKE_PROVIDER_PID_FILE) {
  fs.writeFileSync(process.env.SIDEKICK_FAKE_PROVIDER_PID_FILE, `${process.pid}\n`);
}
if (process.env.SIDEKICK_FAKE_ARGV_FILE) {
  fs.writeFileSync(process.env.SIDEKICK_FAKE_ARGV_FILE, JSON.stringify(providerArgs));
}

if (scenario === 'exit-before-stdin') {
  process.stderr.write('fake provider exited before reading its prompt\n');
  process.exit(23);
}

// Match the real CLIs: consume the complete prompt and observe EOF before a
// turn starts. This catches regressions where turn.mjs forgets to close stdin.
let prompt = '';
for await (const chunk of process.stdin) prompt += chunk;
if (process.env.SIDEKICK_FAKE_PROMPT_FILE) {
  fs.writeFileSync(process.env.SIDEKICK_FAKE_PROMPT_FILE, prompt);
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const emit = (event) => process.stdout.write(`${JSON.stringify(event)}\n`);

function outputPath() {
  const index = providerArgs.indexOf('-o');
  return index >= 0 ? providerArgs[index + 1] : undefined;
}

function emitCodexStart() {
  emit({ type: 'thread.started', thread_id: sessionId });
}

function emitCodexResult() {
  emit({ type: 'item.completed', item: { type: 'agent_message', text: finalText } });
  emit({
    type: 'turn.completed',
    usage: {
      input_tokens: 13,
      cached_input_tokens: 5,
      output_tokens: 8,
      reasoning_output_tokens: 3,
    },
  });
  const lastMessage = outputPath();
  if (lastMessage) {
    fs.mkdirSync(path.dirname(lastMessage), { recursive: true });
    fs.writeFileSync(lastMessage, finalText);
  }
}

function startGrandchild({ ignoreSigterm = false } = {}) {
  const readyFile = process.env.SIDEKICK_FAKE_GRANDCHILD_READY_FILE;
  const grandchildProgram = [
    ignoreSigterm ? "process.on('SIGTERM', () => {});" : '',
    readyFile ? `require('node:fs').writeFileSync(${JSON.stringify(readyFile)}, 'ready\\n');` : '',
    'setInterval(() => {}, 60_000);',
  ].join(' ');
  const grandchild = spawn(process.execPath, [
    '-e',
    grandchildProgram,
  ], { stdio: 'inherit' });
  grandchild.unref();
  if (!process.env.SIDEKICK_FAKE_GRANDCHILD_PID_FILE) {
    throw new Error('SIDEKICK_FAKE_GRANDCHILD_PID_FILE is required for a tree scenario');
  }
  fs.writeFileSync(process.env.SIDEKICK_FAKE_GRANDCHILD_PID_FILE, `${grandchild.pid}\n`);
  return grandchild;
}

if (provider === 'claude') {
  if (scenario !== 'success') {
    process.stderr.write(`unsupported fake claude scenario: ${scenario}\n`);
    process.exit(64);
  }
  process.stdout.write(JSON.stringify({
    type: 'result',
    subtype: 'success',
    is_error: false,
    session_id: sessionId,
    result: finalText,
    total_cost_usd: 0.01,
    usage: {
      input_tokens: 11,
      cache_read_input_tokens: 4,
      cache_creation_input_tokens: 2,
      output_tokens: 7,
    },
  }));
} else if (scenario === 'success') {
  emitCodexStart();
  emitCodexResult();
} else if (scenario === 'nonzero-final') {
  emitCodexStart();
  emitCodexResult();
  process.exitCode = 7;
} else if (scenario === 'delayed-success') {
  await sleep(Number(process.env.SIDEKICK_FAKE_START_DELAY_MS ?? 0));
  emitCodexStart();
  await sleep(Number(process.env.SIDEKICK_FAKE_DELAY_MS ?? 500));
  emitCodexResult();
} else if (scenario === 'success-with-stubborn-grandchild') {
  emitCodexStart();
  emitCodexResult();
  startGrandchild({ ignoreSigterm: true });
  const readyFile = process.env.SIDEKICK_FAKE_GRANDCHILD_READY_FILE;
  if (readyFile) {
    while (!fs.existsSync(readyFile)) await sleep(5);
  }
} else if (scenario === 'hang-with-grandchild') {
  emitCodexStart();
  startGrandchild();
  setInterval(() => {}, 60_000);
} else if (scenario === 'hang-with-stubborn-grandchild-only') {
  emitCodexStart();
  startGrandchild({ ignoreSigterm: true });
  setInterval(() => {}, 60_000);
} else if (scenario === 'hang-with-stubborn-grandchild') {
  process.on('SIGTERM', () => {});
  emitCodexStart();
  startGrandchild({ ignoreSigterm: true });
  setInterval(() => {}, 60_000);
} else {
  process.stderr.write(`unsupported fake codex scenario: ${scenario}\n`);
  process.exit(64);
}
