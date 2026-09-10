#!/usr/bin/env python3
"""Collect worktree evidence and write a draft removal plan; never remove checkouts."""

import argparse
import concurrent.futures
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import time

from remove import DISCARD, ignored, records, within, write_json


def run(path, *args):
    return subprocess.run(["git", "-C", str(path), *args], capture_output=True,
                          text=True, timeout=60,
                          env={**os.environ, "GIT_OPTIONAL_LOCKS": "0", "GIT_TERMINAL_PROMPT": "0"})


def git(path, *args):
    result = run(path, *args)
    result.check_returncode()
    return result.stdout


def problem(error):
    if isinstance(error, subprocess.CalledProcessError):
        return error.stderr.strip() or str(error)
    return str(error)


def discover(root):
    """Find checkout markers without traversing checkouts or symlink aliases."""
    found, errors = [], []
    for base, dirs, files in os.walk(root, followlinks=False,
                                     onerror=lambda error: errors.append(str(error))):
        if ".git" in dirs or ".git" in files:
            found.append(Path(base))
            dirs[:] = []
        else:
            dirs[:] = [name for name in dirs if name not in DISCARD and
                       not (Path(base) / name).is_symlink()]
    return found, errors


def repository(path, should_fetch, base):
    info = {"repo": str(path), "errors": [], "remotes": [], "verified_refs": {}}
    try:
        info["entries"] = records(path)
        info["repo"] = info["entries"][0]["worktree"]
        info["remotes"] = git(path, "remote").splitlines()
        if should_fetch:
            for remote in info["remotes"]:
                stage = "fetch " + remote
                try:
                    git(path, "fetch", "--prune", "--no-recurse-submodules", remote)
                    # A narrow fetch refspec can leave stale tracking refs intact.
                    # Match their objects to currently advertised branch heads.
                    stage = "verify remote heads for " + remote
                    advertised = {}
                    for line in git(path, "ls-remote", "--heads", remote).splitlines():
                        sha, ref = line.split("\t", 1)
                        advertised["refs/remotes/" + remote + "/" + ref.removeprefix("refs/heads/")] = sha
                    for line in git(path, "for-each-ref", "--format=%(refname)\t%(objectname)",
                                    "refs/remotes/" + remote + "/").splitlines():
                        ref, sha = line.split("\t", 1)
                        if advertised.get(ref) == sha:
                            info["verified_refs"][ref] = sha
                except (OSError, subprocess.SubprocessError) as error:
                    info["errors"].append(stage + ": " + problem(error))
        info["fresh"] = bool(should_fetch and info["remotes"] and not info["errors"])
        ref = base or "refs/remotes/origin/HEAD"
        resolved = run(path, "rev-parse", "--verify", ref + "^{commit}")
        info["base"] = ref if resolved.returncode == 0 else None
        info["base_head"] = resolved.stdout.strip() if resolved.returncode == 0 else None
        info["base_fresh"] = False
        if not info["base"]:
            info["base_note"] = "integration ref unresolved; use --base for the intended ref"
        else:
            full = git(path, "rev-parse", "--symbolic-full-name", ref).strip()
            symbolic = run(path, "symbolic-ref", "-q", full)
            full = symbolic.stdout.strip() if symbolic.returncode == 0 else full
            info["base_fresh"] = info["verified_refs"].get(full) == info["base_head"]
            if not info["base_fresh"]:
                info["base_note"] = "integration ref not verified against current remote branch heads"
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        info["errors"].append(problem(error))
        info["fresh"] = False
    return info


def activity(path, head):
    samples = [(float(git(path, "show", "-s", "--format=%ct", head)), "HEAD commit")]
    reflog = git(path, "reflog", "show", "-1", "--format=%gD", "--date=unix", "HEAD")
    match = re.search(r"@\{(\d+)\}", reflog)
    if match:
        samples.append((float(match[1]), "HEAD reflog"))
    names = git(path, "ls-files", "--cached", "--others", "--exclude-standard", "-z").split("\0")
    files = [path / name for name in names if name] + [path / ".git"]
    files.extend(ignored(path))
    for file in files:
        samples.append((file.lstat().st_mtime, str(file.relative_to(path))))
    timestamp, source = max(samples)
    return {"timestamp": timestamp, "source": source,
            "date": datetime.datetime.fromtimestamp(timestamp, datetime.timezone.utc).isoformat()}


def inspect(entry, repo, root, cutoff, cwds, process_error):
    path = Path(entry["worktree"]).absolute()
    row = {"path": str(path), "repo": repo["repo"], "head": entry.get("HEAD"),
           "branch": entry.get("branch"), "errors": list(repo["errors"]), "keep_reasons": []}
    reasons = row["keep_reasons"]
    if not path.exists():
        row["missing_checkout"] = True
        reasons.append("registration whose checkout path is missing")
        return row
    try:
        if path != path.resolve() or path == root:
            reasons.append("noncanonical path or selected root itself")
            return row
        if path == Path(repo["repo"]).resolve():
            reasons.append("main checkout")
        if "locked" in entry:
            reasons.append("locked")
        if any(within(Path(e["worktree"]).resolve(), path) and
               Path(e["worktree"]).resolve() != path for e in repo["entries"]):
            reasons.append("contains another registered worktree")
        if process_error:
            row["errors"].append("process inventory: " + process_error)
        else:
            row["in_use"] = any(within(cwd, path) for cwd in cwds)
            if row["in_use"]:
                reasons.append("process working directory inside checkout")
        status = git(path, "status", "--porcelain=v1", "--untracked-files=all")
        row["dirty"] = bool(status.strip())
        if row["dirty"]:
            reasons.append("uncommitted or untracked files")
        flags = git(path, "ls-files", "-v", "-z").split("\0")
        if any(line[:1].islower() or line.startswith("S ") for line in flags):
            reasons.append("index flags can hide local edits")
        contains = git(path, "for-each-ref", "--contains", row["head"],
                       "--format=%(refname)\t%(objectname)", "refs/remotes/").splitlines()
        row["remote_contains"] = []
        for line in contains:
            ref, sha = line.split("\t", 1)
            if repo["verified_refs"].get(ref) == sha:
                row["remote_contains"].append(ref)
        row["merged"] = None
        if repo.get("base_head"):
            check = run(path, "merge-base", "--is-ancestor", row["head"], repo["base_head"])
            if check.returncode not in (0, 1):
                check.check_returncode()
            row["merged"] = check.returncode == 0
        row["activity"] = activity(path, row["head"])
        row["inactive"] = row["activity"]["timestamp"] < cutoff
        if git(path, "rev-parse", "HEAD").strip() != row["head"]:
            row["errors"].append("HEAD changed during audit")
        if not repo["fresh"]:
            reasons.append("remote evidence not refreshed")
        merged_fresh = row["merged"] and repo.get("base_fresh")
        if not merged_fresh and not (row["inactive"] and row["remote_contains"]):
            reasons.append("unresolved merge or inactivity; review PR evidence or retain")
        if not reasons and not row["errors"]:
            row["reason"] = ("HEAD contained in refreshed " + repo["base"] if merged_fresh else
                             "inactive since " + row["activity"]["date"] + "; tip reachable from refreshed remote")
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        row["errors"].append(problem(error))
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__, epilog=(
        "The output contains evidence plus candidates/kept accepted by remove.py. "
        "Candidates use Git ancestry or inactive remote-backed tips; squash/rebase PR "
        "proof remains for agent review. Activity includes commit/reflog, .git marker, "
        "tracked/nonignored files and ignored files outside the remover's cache exclusions."))
    parser.add_argument("root", nargs="?", type=Path, default=Path.home() / "dev/.worktrees")
    parser.add_argument("--output", type=Path, required=True, help="JSON evidence and draft plan, outside cleanup root")
    parser.add_argument("--repo", type=Path, action="append", default=[],
                        help="also read this registry; repeat for repos with no surviving checkouts under root")
    parser.add_argument("--base", help="integration ref for this audit; default: origin/HEAD")
    parser.add_argument("--days", type=float, default=14)
    parser.add_argument("--jobs", type=int, choices=range(1, 9), default=4)
    parser.add_argument("--no-fetch", action="store_true", help="cached evidence only; produces no removal candidates")
    args = parser.parse_args()
    if args.days <= 0:
        parser.error("--days must be positive")
    root = args.root.expanduser().resolve(strict=True)
    output = args.output.expanduser().resolve()
    if within(output, root):
        parser.error("--output must be outside cleanup root")
    now = time.time()
    paths, errors = discover(root)
    owners = {}
    for path in paths + args.repo:
        try:
            common = git(path.expanduser(), "rev-parse", "--path-format=absolute", "--git-common-dir").strip()
            owners.setdefault(str(Path(common).resolve()), path.expanduser())
        except (OSError, subprocess.SubprocessError) as error:
            errors.append(str(path) + ": " + problem(error))
    try:
        snapshot = subprocess.run(["lsof", "-a", "-d", "cwd", "-Fn"], capture_output=True,
                                  text=True, check=True, timeout=30).stdout
        cwds = [Path(line[1:]).resolve() for line in snapshot.splitlines() if line.startswith("n/")]
        process_error = None
    except (OSError, subprocess.SubprocessError) as error:
        cwds, process_error = [], problem(error)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        repos = list(pool.map(lambda p: repository(p, not args.no_fetch, args.base), owners.values()))
        jobs = [(entry, repo) for repo in repos for entry in repo.get("entries", [])
                if within(Path(entry["worktree"]).absolute(), root)]
        rows = list(pool.map(lambda pair: inspect(*pair, root, now - args.days * 86400, cwds, process_error), jobs))
    candidates = [{"path": row["path"], "head": row["head"], "reason": row["reason"]}
                  for row in rows if row.get("reason")]
    kept = [{"path": row["path"], "reasons": row["keep_reasons"] + row["errors"]}
            for row in rows if not row.get("reason")]
    report = {"root": str(root), "audited_at": datetime.datetime.fromtimestamp(now, datetime.timezone.utc).isoformat(),
              "days": args.days, "candidates": candidates, "kept": kept, "worktrees": rows,
              "repositories": [{k: v for k, v in repo.items() if k != "entries"} for repo in repos],
              "discovery_errors": errors, "process_error": process_error}
    output.parent.mkdir(parents=True, exist_ok=True)
    write_json(output, report)
    print(json.dumps({"report": str(output), "worktrees": len(rows), "candidates": len(candidates),
                      "kept": len(kept), "discovery_errors": len(errors),
                      "repositories_with_errors": sum(bool(repo["errors"]) for repo in repos),
                      "process_error": process_error,
                      "note": "Review unresolved PR evidence and any errors before applying the draft plan."}))


if __name__ == "__main__":
    main()
