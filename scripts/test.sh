#!/bin/zsh -f
# scripts/test.sh — every suite in this repository, from one command.
#
#   scripts/test.sh               every suite, six at a time
#   scripts/test.sh zsh rex       the suites whose path holds one of the words
#   scripts/test.sh -j 1 cout     one at a time
#   scripts/test.sh -l            list what would run
#   make test [T="zsh rex"]       the same
#
# A suite is a tracked file named *.test.zsh, test-*.sh, test_*.py or
# test-*.py, so a new one is picked up by its name and there is no list to
# keep. Each runs as docs/testing.md says to run it by hand, whole, in an
# empty directory of its own under a temporary one: never in this checkout,
# where an empty path read from test state resolves to `.` (CLAUDE.md, red
# line 3). A suite that needs a tool this machine lacks skips or fails as it
# does by hand.
#
# One line per suite as it finishes (ok or FAIL, its seconds, its last line),
# then the count and the wall time. A failed suite's output is kept and its
# path printed; the exit status is 1 when any failed.

emulate -L zsh
setopt pipe_fail no_unset
zmodload zsh/datetime

REPO=${0:A:h:h}

# Suites `scripts/test.sh` cannot run whole, each with its reason.
typeset -A SKIP=(
  tmux/.config/tmux/scripts/tests/test-popup-overlay.py 'takes two tmux binaries: --stock and --candidate (docs/tmux-popup-patch.md)'
)

# --one ROOT N SUITE: run one suite and leave its result in ROOT/N.{log,rc,s}.
if [[ ${1-} == --one ]]; then
  root=$2 n=$3 suite=$4
  case $suite in
    *.zsh) run=(zsh) ;;
    *.sh)  run=(bash) ;;
    *.py)  run=(python3) ;;
  esac
  mkdir -p $root/$n.cwd && cd -q $root/$n.cwd || exit 1
  t0=$EPOCHREALTIME
  $run $REPO/$suite >$root/$n.log 2>&1 </dev/null
  rc=$?
  printf '%.1f' $(( EPOCHREALTIME - t0 )) >$root/$n.s
  print -r -- $rc >$root/$n.rc
  lines=("${(@f)$(<$root/$n.log)}")
  last=${lines[-1]-}
  # One print, so lines from suites finishing together do not interleave.
  if (( rc )); then
    print -r -- "FAIL $(<$root/$n.s)s  $suite  | ${last[1,90]}"
  else
    print -r -- "ok   $(<$root/$n.s)s  $suite  | ${last[1,90]}"
  fi
  exit 0
fi

jobs=6 list=0
while (( $# )); do
  case $1 in
    -j) jobs=${2:?-j takes a number}; shift 2 ;;
    -l) list=1; shift ;;
    -h|--help) sed -n '2,/^$/{s/^# \{0,1\}//p;}' $0; exit 0 ;;
    -*) print -u2 "test.sh: unknown option $1 (see scripts/test.sh --help)"; exit 2 ;;
    *) break ;;
  esac
done

all=(${(f)"$(git -C $REPO ls-files | grep -E '(^|/)(test[-_][^/]*\.(sh|py)|[^/]*\.test\.zsh)$')"})
suites=() skipped=()
for s in $all; do
  if (( $# )); then
    hit=0
    for w in "$@"; do [[ $s == *$w* ]] && hit=1; done
    (( hit )) || continue
  fi
  if (( ${+SKIP[$s]} )); then skipped+=($s); else suites+=($s); fi
done
(( $#suites )) || { print -u2 "test.sh: no suite matches: $*"; exit 2 }
if (( list )); then
  print -rl -- $suites
  for s in $skipped; do print -r -- "$s  (not run: $SKIP[$s])"; done
  exit 0
fi

root=$(mktemp -d ${${TMPDIR:-/tmp}%/}/dotfiles-test.XXXXXX) || exit 1
t0=$EPOCHREALTIME
n=0
for s in $suites; do print -r -- "$root $(( ++n )) $s"; done |
  xargs -P $jobs -L 1 $0 --one

failed=()
for (( i = 1; i <= $#suites; i++ )); do
  [[ $(<$root/$i.rc) == 0 ]] 2>/dev/null || failed+=("$suites[i]  $root/$i.log")
done
for s in $skipped; do print -r -- "skip        $s  | $SKIP[$s]"; done
printf '%d suites, %d failed, %.0fs\n' $#suites $#failed $(( EPOCHREALTIME - t0 ))
if (( $#failed )); then
  print -r -- "failed (output kept):"
  print -rl -- "  "$^failed
  exit 1
fi
[[ $root == */dotfiles-test.* ]] && rm -rf $root
exit 0
