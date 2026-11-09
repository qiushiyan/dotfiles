"""chip-resize.py REX-CHIP BLOCK: `rex-chip draw` on a pty that is resized.

test-rex-chip.sh's K11 runs it. The pty starts 80 columns wide and becomes 55
a tenth of a second later, as the app sizes a new floating layer just after
its program starts, then 70. Prints four words:

  the paints in the first 0.9 s (1: nothing was drawn at the starting width)
  the columns the last of them was laid out for
  fast or slow: whether the second resize was painted within 0.4 s
  the columns that paint was laid out for

The caller's environment reaches the float as it is, so the state it draws is
the suite's sandbox.
"""
import fcntl
import os
import pty
import re
import select
import struct
import sys
import termios
import time

PAINT = "\x1b[2J"


def resize(fd, cols):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 2, cols, 0, 0))


def read_for(fd, seconds, until_paint=False):
    buf, end = b"", time.time() + seconds
    while time.time() < end:
        if not select.select([fd], [], [], 0.02)[0]:
            continue
        try:
            buf += os.read(fd, 4096)
        except OSError:
            break
        if until_paint and PAINT.encode() in buf:
            time.sleep(0.05)  # the line follows the clear
            if select.select([fd], [], [], 0)[0]:
                buf += os.read(fd, 4096)
            break
    return buf.decode("utf-8", "replace")


def laid_out_for(text):
    """The width of the last paint: its line and the one-column margin."""
    line = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", text.split(PAINT)[-1])
    return len(line) + 1


def main():
    pid, fd = pty.fork()
    if pid == 0:
        os.execv("/bin/bash", ["/bin/bash", sys.argv[1], "draw", sys.argv[2]])
    try:
        resize(fd, 80)
        time.sleep(0.1)
        resize(fd, 55)
        first = read_for(fd, 0.8)
        resize(fd, 70)
        second = read_for(fd, 0.4, until_paint=True)
        print(first.count(PAINT), laid_out_for(first),
              "fast" if PAINT in second else "slow", laid_out_for(second))
    finally:
        os.kill(pid, 9)
        os.waitpid(pid, 0)


if __name__ == "__main__":
    main()
