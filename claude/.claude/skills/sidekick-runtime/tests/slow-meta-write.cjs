'use strict';

// Test-only fault injection: make a direct write to the authoritative metadata
// observably non-atomic. Production atomic writes target a sibling temp file and
// rename it, so they are deliberately unaffected by this shim.
const fs = require('node:fs');
const path = require('node:path');

const originalWriteFileSync = fs.writeFileSync;
const pause = new Int32Array(new SharedArrayBuffer(4));

fs.writeFileSync = function writeFileSync(file, data, options) {
  if (process.env.SIDEKICK_TEST_SLOW_META_WRITE === '1' && path.basename(String(file)) === 'meta.json') {
    const buffer = Buffer.isBuffer(data) ? data : Buffer.from(String(data), options?.encoding);
    const split = Math.max(1, Math.floor(buffer.length / 2));
    const fd = fs.openSync(file, 'w');
    try {
      fs.writeSync(fd, buffer, 0, split);
      Atomics.wait(pause, 0, 0, 75);
      fs.writeSync(fd, buffer, split, buffer.length - split);
    } finally {
      fs.closeSync(fd);
    }
    return;
  }
  return originalWriteFileSync.call(this, file, data, options);
};
