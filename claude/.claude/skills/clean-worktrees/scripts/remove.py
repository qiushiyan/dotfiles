#!/usr/bin/env python3
"""Archive ignored files, then remove an audited selection with gwt remove."""

import argparse
import concurrent.futures
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import time


# Only disposable dependency/cache directories. Archive everything else ignored.
DISCARD = {"node_modules", ".next", ".turbo", "__pycache__"}


def command(args, cwd=None):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, check=True,
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
    """Archive, then gwt removes the checkout and keeps its branch. gwt refuses
    main, current, locked, nesting and dirty checkouts (index-hidden edits too)
    and a HEAD that moved since the audit, and keeps a detached HEAD as a
    recovery ref."""
    result = {**item, "status": "skipped"}
    slot = hashlib.sha256(item["path"].encode()).hexdigest()[:20]
    archive = output / (slot + ".tar.gz")
    try:
        path = Path(item["path"]).expanduser().absolute()
        # A symlink alias handed to Git once deleted the real checkout.
        if path != path.resolve() or path == root or not within(path, root):
            raise ValueError("path must be a real directory strictly inside the selected root")
        if cwd_in_use(path):
            raise ValueError("a process has its working directory here")
        anchor = Path(records(path)[0]["worktree"])
        result.update(repo=str(anchor), archive=str(archive))
        result["saved_files"] = backup(path, archive)
        result["status"] = "removing"
        write_json(output / (slot + ".json"), result)
        gwt = subprocess.run(["gwt", "remove", "--keep-branch", "--expect-head", item["head"],
                              "--json", str(path)], cwd=anchor, capture_output=True, text=True)
        outcome = json.loads(gwt.stdout)
        result.update(branch=outcome.get("branch") or None, recovery_ref=outcome.get("recovery_ref"))
        if not outcome["ok"]:
            result["status"] = "failed" if outcome["worktree_removed"] else "skipped"
            result["detail"] = outcome["error"]
        else:
            result["status"] = "removed"
    except (OSError, ValueError, KeyError, IndexError, tarfile.TarError,
            subprocess.CalledProcessError) as error:
        result["status"] = "failed" if result["status"] == "removing" else "skipped"
        result["detail"] = (error.stderr.strip() if isinstance(error, subprocess.CalledProcessError)
                            else str(error))
    if result["status"] == "skipped" and archive.exists():
        archive.unlink()  # the checkout stays, so its files need no copy
        result.pop("archive", None)
    write_json(output / (slot + ".json"), result)
    return result


def expire(backup_root, keep):
    """Drop report directories older than gwt's recovery.keep (0 keeps them):
    archives otherwise grow without bound. Runs before 2026-10 also pinned
    refs/clean-worktrees/<directory>/…; those go with their directory."""
    if keep <= 0 or not backup_root.is_dir():
        return
    for directory in backup_root.iterdir():
        if not directory.is_dir() or time.time() - directory.stat().st_mtime <= keep:
            continue
        repos = set()
        for record in directory.glob("*.json"):
            try:
                repos.add(json.loads(record.read_text()).get("repo"))
            except (OSError, ValueError, AttributeError):
                pass
        for repo in repos - {None}:
            try:
                for ref in git(repo, "for-each-ref", "--format=%(refname)",
                               "refs/clean-worktrees/" + directory.name).split():
                    git(repo, "update-ref", "-d", ref)
            except (OSError, subprocess.CalledProcessError):
                pass  # a vanished repository leaves no refs to drop
        shutil.rmtree(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__, epilog=(
        'Plan JSON: {"root":"/absolute/root", "candidates":['
        '{"path":"/absolute/root/checkout", "head":"full commit SHA", '
        '"reason":"audit evidence"}]}. Optional "kept" records are copied into the report. '
        "Branches are kept. Report directories, with their archives, expire after gwt's "
        "recovery.keep (gwt config show)."))
    parser.add_argument("plan", type=Path)
    parser.add_argument("--apply", action="store_true", required=True,
                        help="archive and remove; there is no preview, since gwt checks each candidate as it removes it")
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
    try:
        keep = json.loads(command(["gwt", "config", "show", "--json"]).stdout)["recovery"]["keep"]
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        parser.error("cannot read gwt's recovery.keep: " + str(error) + "; install gwt with make -C ~/dev/gwt install")
    backup_root = (args.backup_root or root.parent / "worktree-cleanup-backups").expanduser().resolve()
    if within(backup_root, root):
        parser.error("backup root must be outside the cleanup root")
    expire(backup_root, keep)
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
