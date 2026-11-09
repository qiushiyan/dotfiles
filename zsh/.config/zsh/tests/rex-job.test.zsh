#!/usr/bin/env zsh
# What a shell in a Rex pane reports about its commands (rex.zsh, OSC 7501
# id=shell): a command shows as working while it runs, and one that ran
# REX_JOB_MIN seconds or more stays done or error. Rex discards a whole
# report whose title or msg is not base64 of one line of UTF-8 within its
# limits, so a multi-line, pasted or very long command would lose its badge.
#
#   zsh ~/.config/zsh/tests/rex-job.test.zsh
#
# What this pins: the in-shell base64 is base64(1)'s, byte for byte (J1); a
# command reports working with the directory as its title (J2); a multi-line
# command, control characters and C1 controls arrive as one valid line (J3,
# J4); long text is cut to fit (J5); a long run that failed reads error with
# its time and exit status, its command on one line (J6); an editor reports
# nothing (J7). A prompt in a pane that still wears a Claude status chip
# clears it, and one in a pane that wears none starts nothing (J8).
#
# ISOLATION. A real interactive zsh sources the working tree's rex.zsh alone,
# under a throwaway HOME, with a PATH that holds no rexd (so no watcher
# starts) and REX_BLOCK naming no live block; the hooks' output is captured
# from stdout, never sent to a terminal. J8's rex-chip is a stub that logs
# its arguments, on a PATH of its own, and the chip's state is the sandbox's.

emulate -L zsh
setopt pipe_fail no_unset

MOD="${0:A:h:h}/rex.zsh"
typeset -i PASS=0 FAIL=0
[[ -f $MOD ]] || { print -u2 "rex-job.test: no rex.zsh at $MOD"; exit 1 }

SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/rex-job-test.XXXXXX")
[[ $SB == */rex-job-test.?* ]] || { print -u2 "bad sandbox $SB"; exit 1 }
mkdir -p "$SB/home/work dir"
trap 'rm -rf -- "$SB"' EXIT

ok() {  # ok <name> <expected> <actual>
  if [[ $2 == $3 ]]; then (( PASS++ )); print -r -- "PASS $1"
  else (( FAIL++ )); print -r -- "FAIL $1"; print -r -- "    expected: ${(qqq)2}"; print -r -- "    actual:   ${(qqq)3}"; fi
}

# shell SCRIPT: run SCRIPT in an interactive zsh that sourced rex.zsh in a
# Rex pane, from "~/work dir"; prints what it wrote.
shell() {
  command env -i HOME="$SB/home" PATH=/usr/bin:/bin LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    REX_BLOCK=block:rex-job-test TERM=xterm-256color \
    zsh -f -i -c "cd '$SB/home/work dir'; source '$MOD'; $1" 2>/dev/null
}

# decode: the first OSC 7501 report on stdin as state|title|msg, text decoded
# (the shell's exit adds a clear after it).
decode() {
  /usr/bin/python3 -c '
import base64, re, sys
for body in re.findall(r"\x1b\]7501;([^\x1b\x07]*)", sys.stdin.buffer.read().decode("utf-8", "replace"))[:1]:
    f = dict(p.split("=", 1) for p in body.split(":") if "=" in p)
    text = lambda k: base64.b64decode(f[k]).decode("utf-8") if k in f else ""
    print(f["state"], text("title"), text("msg"), sep="|")'
}

# J1: the in-shell base64 against base64(1), on fixed texts and random bytes.
mismatch=$(shell '
  local s ref; local -a texts=("" a ab abc abcd "naïve café 日本語 🚀" "C:\\temp" "x·y")
  for s in $texts; do _rex_job_b64 "$s"; ref=$(print -rn -- "$s" | base64 | tr -d "\n")
    [[ $REPLY == $ref ]] || print -r -- "mismatch: ${(q)s}"; done
  for k in {1..100}; do s=$(head -c $(( RANDOM % 90 + 1 )) /dev/urandom | LC_ALL=C tr -d "\0")
    _rex_job_b64 "$s"; ref=$(print -rn -- "$s" | base64 | tr -d "\n")
    [[ $REPLY == $ref ]] || { print -r -- "mismatch: random $k"; break }; done')
ok "J1 the in-shell base64 is base64(1)'s" "" "$mismatch"

ok "J2 a command reports working, titled by its directory" \
  "working|work dir|make test" "$(shell '_rex_job_preexec "make test"' | decode)"

ok "J3 a multi-line command reports on one line" \
  "working|work dir|for f in *; do   echo \$f done" \
  "$(shell '_rex_job_preexec $'"'"'for f in *; do\n  echo $f\ndone'"'"'' | decode)"

ok "J4 control characters and C1 controls become spaces" \
  "working|work dir|a b c d e" \
  "$(shell '_rex_job_preexec "a"$'"'"'\r'"'"'"b"$'"'"'\e'"'"'"c"$'"'"'\u0085'"'"'"d"$'"'"'\x7f'"'"'"e"' | decode)"

ok "J5 a long command is cut to 200 characters" \
  "working|work dir|$(printf 'é%.0s' {1..200})" \
  "$(shell '_rex_job_preexec "${(l:300::é:)}"' | decode)"

ok "J6 a long run that failed reads error, with its time and status, on one line" \
  "error|work dir|sleep 1 &&   false · 20s · exit 3" \
  "$(shell '_rex_job_preexec $'"'"'sleep 1 &&\n  false'"'"' >/dev/null
    _rex_job_start=$(( EPOCHSECONDS - 20 )); three() { return 3 }; three; _rex_job_precmd' | decode)"

ok "J7 an editor reports nothing" "" "$(shell '_rex_job_preexec "nvim notes.md"' | decode)"

# J8: the prompt sweep. The stub stands where the stowed rex-chip would.
mkdir -p "$SB/bin" "$SB/home/.local/state/rex-lab/chip"
print -r -- '#!/bin/sh
echo "$*" >> "'$SB'/chip.log"' > "$SB/bin/rex-chip"; chmod +x "$SB/bin/rex-chip"
chipshell() {
  command env -i HOME="$SB/home" PATH="$SB/bin:/usr/bin:/bin" LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    REX_BLOCK=block:rex-job-test TERM=xterm-256color \
    zsh -f -i -c "source '$MOD'; _rex_chip_precmd; sleep 0.5" >/dev/null 2>&1
}
: > "$SB/chip.log"
chipshell
ok "J8 a prompt in a pane that wears no chip starts nothing" "" "$(<$SB/chip.log)"
: > "$SB/home/.local/state/rex-lab/chip/block_rex-job-test.chip"
chipshell
ok "J8 a prompt in a pane that still wears a chip clears it" "clear block:rex-job-test" "$(<$SB/chip.log)"

print -r -- "rex-job: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
