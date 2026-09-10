# Validation — 10 September 2026

The concurrency spike asked whether normal Git removal of distinct linked
worktrees preserves integrity and improves median deletion time by at least
10%. Real Apple Git 2.50.1, macOS 26.5 arm64, and the local filesystem; synthetic
repository and eight checkouts with 5,000 ignored tiny files each. Configuration
and hooks were isolated. Setup and verification were outside the timed interval.

| Workers | Three trials, seconds | Median | Faster than serial |
| --- | --- | --- | --- |
| 1 | 2.3176, 2.3613, 2.3877 | 2.3613 | — |
| 2 | 1.7374, 1.8205, 1.7349 | 1.7374 | 26.4% |
| 4 | 1.3449, 1.3289, 1.3077 | 1.3289 | 43.7% |

All 72 removals succeeded. Each trial verified absent paths and registrations,
unchanged base HEAD and refs, and successful `git fsck --full`. VERIFIED for this
workload; full cleanup speed, other storage/Git versions, simultaneous writers,
submodules, and cancellation remain unmeasured. Four workers is a bounded
default, not a universal optimum.

Normal removal refused dirty, untracked, and locked checkouts (exit 128).
An ignored directory's symlink was unlinked without changing its external
target. **A symlink used as the worktree argument deleted the real checkout
(exit 0), leaving a dangling alias.** This observation earns the runner's
canonical-path guard. An initial harness assumption that `node_modules/`
ignores a symlink named `node_modules` was false; the corrected probe records
Git's refusal. No real worktrees were used or removed by the spike.

The runner's ten isolated integration tests cover previews, mixed protected
checkouts, path scope, ignored-file archives, external symlinks, detached recovery
refs, two/four workers, and a real process holding a checkout cwd. A cold review
reproduced two additional losses in the initial runner: Git hid edited files
marked `assume-unchanged` or `skip-worktree`, and name-based cache exclusions
discarded regular files. The fixes retain flagged checkouts and exclude only
actual directories; regression tests also preserve cache-named symlinks.

```bash
python3 -m unittest discover -s ~/.agents/skills/clean-worktrees/tests -v
```

All ten pass (6.97 seconds). The frontmatter validator passes with the house
guide's `argument-hint` extension checked separately; its upstream allowlist
does not recognize that extension. Both global agent paths resolve to the
same skill source.

A cold audit of twelve supplied evidence cases selected the same correct five
checkouts with and without the skill. This proves no selection-quality gain;
the runner supplies repeatable execution and the measured concurrency benefit.
The cold reader's one instruction conflict—an audit-only output versus the
runner's execution-plan schema—was removed by limiting that schema to removal.

## Audit collector and instruction revision

The follow-up cold read moved the agent/runner responsibility split to the
opening, shortened execution narration, clarified registrations with missing
checkout paths, and required renewed eligibility checks after interruption.
The skill is now 75 lines, including the new collector entry point.

`audit.py` gathers Git, process, and activity evidence and writes a draft plan
accepted by `remove.py`. Ten additional isolated CLI tests cover refreshed graph
proof, inactive remote-backed tips, recent checkout/ignored-file activity, cached
or failed probes, multiple repositories, detached checkouts, and missing paths.
PR merge judgment remains outside the collector.

Cold code review found that a narrowed fetch refspec can leave stale tracking
refs untouched. The collector now compares individual ref objects with currently
advertised remote branch heads. Two regression cases reject a deleted remote
feature tip and a stale explicit integration ref despite a successful fetch.

The combined suite passes all 20 tests in 13.00 seconds. A cached-only smoke
audit of the live worktree root found 13 checkouts with no probe errors and zero
proposed removals; it did not fetch or remove checkouts. The cold reader otherwise
confirmed the updated ownership and retry instructions were clear.
