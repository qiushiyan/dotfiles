#!/usr/bin/env python3
"""Apply an audited worktree selection; preview unless --apply is supplied."""

import argparse
import concurrent.futures
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import time


# Only disposable dependency/cache directories. Archive everything else ignored.
DISCARD = {"node_modules", ".next", ".turbo", "__pycache__"}


def command(args):
    return subprocess.run(args, capture_output=True, text=True, check=True,
                          env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})


def git(path, *args):
    return command(["git", "-C", str(path), *args]).stdout


def records(path):
    entries = []
    for block in git(path, "worktree", "list", "--porcelain", "-z").split("\0\0"):
        if block:
            entries.append(dict(line.partition(" ")[::2] for line in block.split("\0") if line))
    return entries


def within(path, parent):
    return path == parent or parent in path.parents


def cwd_in_use(path):
    # A failed process inventory is an unknown, not an empty process list.
    output = command(["lsof", "-a", "-d", "cwd", "-Fn"]).stdout
    return any(within(Path(line[1:]).resolve(), path)
               for line in output.splitlines() if line.startswith("n/"))


def inspect(item, root):
    path = Path(item["path"]).expanduser().absolute()
    if path != path.resolve() or path == root or not within(path, root):
        raise ValueError("path must be a real directory strictly inside the selected root")
    if not (path / ".git").is_file():
        raise ValueError("not a linked worktree with an existing checkout")
    entries = records(path)
    anchor = Path(entries[0]["worktree"]).resolve()
    entry = next(e for e in entries if Path(e["worktree"]).resolve() == path)
    if path == anchor or "locked" in entry:
        raise ValueError("main or locked worktree")
    if any(within(Path(e["worktree"]).resolve(), path) and
           Path(e["worktree"]).resolve() != path for e in entries):
        raise ValueError("contains another registered worktree")
    if git(path, "rev-parse", "HEAD").strip() != item["head"]:
        raise ValueError("HEAD changed since the audit")
    # Both status and normal removal can miss edits hidden by these index flags.
    flags = git(path, "ls-files", "-v", "-z").split("\0")
    if any(row[:1].islower() or row.startswith("S ") for row in flags):
        raise ValueError("assume-unchanged or skip-worktree index flags can hide local edits")
    if git(path, "status", "--porcelain=v1", "--untracked-files=all").strip():
        raise ValueError("uncommitted or untracked files")
    if cwd_in_use(path):
        raise ValueError("a process has its working directory here")
    return path, anchor, entry.get("branch")


def ignored(path):
    roots = git(path, "ls-files", "--others", "--ignored", "--exclude-standard",
                "--directory", "--no-empty-directory", "-z").split("\0")
    for name in roots:
        if not name:
            continue
        relative = Path(name)
        components = [path.joinpath(*relative.parts[:i + 1])
                      for i, part in enumerate(relative.parts) if part in DISCARD]
        if any(p.is_dir() and not p.is_symlink() for p in components):
            continue
        full = path / relative
        if full.is_symlink() or not full.is_dir():
            yield full
            continue
        for base, dirs, files in os.walk(full, followlinks=False):
            for directory in dirs[:]:
                child = Path(base) / directory
                if child.is_symlink():
                    yield child
                    dirs.remove(directory)
                elif directory in DISCARD:
                    dirs.remove(directory)
            for filename in files:
                yield Path(base) / filename


def fingerprint(path, files):
    return [(str(f.relative_to(path)), f.lstat().st_size, f.lstat().st_mtime_ns,
             os.readlink(f) if f.is_symlink() else None) for f in files]


def backup(path, destination):
    files = sorted(ignored(path))
    before = fingerprint(path, files)
    with tarfile.open(destination, "w:gz", compresslevel=1, dereference=False) as archive:
        for file in files:
            archive.add(file, arcname=str(file.relative_to(path)), recursive=False)
    # Stream the whole archive, so validation checks payloads as well as headers.
    with tarfile.open(destination, "r:gz") as archive:
        members = archive.getmembers()
        if [m.name for m in members] != [str(f.relative_to(path)) for f in files]:
            raise ValueError("backup member list mismatch")
        for member in members:
            if member.isfile():
                with archive.extractfile(member) as data:
                    while data.read(1024 * 1024):
                        pass
    if before != fingerprint(path, sorted(ignored(path))):
        raise ValueError("ignored files changed during backup; checkout retained")
    return len(files)


def write_json(path, data):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2) + "\n")
    temporary.replace(path)


def remove(item, root, output):
    result = {**item, "status": "skipped"}
    slot = hashlib.sha256(item["path"].encode()).hexdigest()[:20]
    try:
        path, anchor, branch = inspect(item, root)
        result.update(repo=str(anchor), branch=branch, archive=str(output / (slot + ".tar.gz")))
        result["saved_files"] = backup(path, Path(result["archive"]))
        # Refresh after backup and immediately before each removal, not once per batch.
        if inspect(item, root) != (path, anchor, branch):
            raise ValueError("worktree registration changed during backup")
        # Keep even detached commits reachable after the worktree's reflog disappears.
        ref = "refs/clean-worktrees/" + output.name + "/" + slot
        git(anchor, "update-ref", ref, item["head"], "")
        result["recovery_ref"] = ref
        result["status"] = "removing"
        write_json(output / (slot + ".json"), result)
        git(anchor, "worktree", "remove", str(path))
        if path.exists() or any(Path(e["worktree"]).resolve() == path for e in records(anchor)):
            raise ValueError("removal returned but path or registration remains")
        result["status"] = "removed"
    except (OSError, ValueError, KeyError, StopIteration, tarfile.TarError,
            subprocess.CalledProcessError) as error:
        result["status"] = "failed" if result["status"] == "removing" else "skipped"
        result["detail"] = (error.stderr.strip() if isinstance(error, subprocess.CalledProcessError)
                            else str(error))
    write_json(output / (slot + ".json"), result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, epilog=(
        'Plan JSON: {"root":"/absolute/root", "candidates":['
        '{"path":"/absolute/root/checkout", "head":"full commit SHA", '
        '"reason":"audit evidence"}]}. Optional "kept" records are copied into the report. '
        'Archives and recovery refs are retained; branches are never deleted.'))
    parser.add_argument("plan", type=Path)
    parser.add_argument("--apply", action="store_true", help="back up and remove the audited selection")
    parser.add_argument("--jobs", type=int, choices=range(1, 5), default=4,
                        help="maximum concurrent backup/removal workers (default: 4)")
    parser.add_argument("--backup-root", type=Path,
                        help="outside the cleanup root; default: sibling worktree-cleanup-backups")
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text())
    root = Path(plan["root"]).expanduser().resolve(strict=True)
    candidates = plan["candidates"]
    paths = [str(Path(c["path"]).expanduser().absolute()) for c in candidates]
    if len(set(paths)) != len(paths):
        parser.error("duplicate candidate paths")
    for item in candidates:
        if not item.get("reason") or not item.get("head"):
            parser.error("each candidate needs its audited HEAD and eligibility evidence")
    if not args.apply:
        for item in candidates:
            try:
                inspect(item, root)
                print(json.dumps({"path": item["path"], "status": "ready", "reason": item["reason"]}))
            except (OSError, ValueError, StopIteration, subprocess.CalledProcessError) as error:
                print(json.dumps({"path": item["path"], "status": "skipped", "detail": str(error)}))
        return
    backup_root = (args.backup_root or root.parent / "worktree-cleanup-backups").expanduser().resolve()
    if within(backup_root, root):
        parser.error("backup root must be outside the cleanup root")
    backup_root.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix=datetime.datetime.now().strftime("%Y%m%d-%H%M%S-"),
                                   dir=backup_root))
    write_json(output / "plan.json", plan)
    before = os.statvfs(root)
    started = time.monotonic()
    last_progress = started
    results = []
    print(json.dumps({"report_directory": str(output), "selected": len(candidates), "jobs": args.jobs}), flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        pending = {pool.submit(remove, item, root, output) for item in candidates}
        while pending:
            done, pending = concurrent.futures.wait(pending, timeout=30,
                                                    return_when=concurrent.futures.FIRST_COMPLETED)
            results.extend(future.result() for future in done)
            now = time.monotonic()
            if now - last_progress >= 30 or not pending:
                print(json.dumps({"finished": len(results), "total": len(candidates),
                                  "removed": sum(r["status"] == "removed" for r in results),
                                  "elapsed_seconds": round(now - started)}), flush=True)
                last_progress = now
    after = os.statvfs(root)
    summary = {"results": results, "kept": plan.get("kept", []),
               "available_bytes_change": after.f_bavail * after.f_frsize - before.f_bavail * before.f_frsize,
               "elapsed_seconds": round(time.monotonic() - started, 2)}
    write_json(output / "results.json", summary)
    print(json.dumps({"report": str(output / "results.json"),
                      "removed": sum(r["status"] == "removed" for r in results),
                      "skipped_or_failed": sum(r["status"] != "removed" for r in results)}), flush=True)


if __name__ == "__main__":
    main()
