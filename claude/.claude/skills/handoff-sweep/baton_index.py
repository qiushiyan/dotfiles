# /// script
# requires-python = ">=3.11"
# dependencies = ["rich"]
# ///
"""Index this project's handoff batons, grouped by cluster.

One view of ~/dev/.handoffs/<project>/ — each baton's declared fields joined
against live git state, plus the folder's own health: clusters nobody defined,
ordering entries pointing at batons that no longer exist, batons nobody ordered.
Those three are what tells you a sweep is owed, instead of you remembering.

The folder comes from the handoff skill's path helper rather than being
recomputed here: that scheme handles worktrees, submodules and symlinked dev
roots, and two copies of it would drift.

Styling goes through rich, which strips itself when stdout is not a terminal —
so an agent reading this gets clean text and a human gets the colours.
"""

from __future__ import annotations

import argparse, json, os, re, subprocess, sys
from dataclasses import dataclass, field, asdict
from pathlib import Path

HELPER = Path.home() / ".claude/skills/handoff/handoff-path.sh"
HEAD_LINES = 12          # the head block's window; prose starts below it
FIELD_SEP = " · "        # a field's machine-readable token ends here


def run(*cmd: str, cwd: Path | None = None) -> str:
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
        return p.stdout.strip() if p.returncode == 0 else ""
    except Exception:
        return ""


@dataclass
class Baton:
    slug: str
    path: str
    topic: str = ""
    goal: str = ""
    cluster: str = ""
    date: str = ""
    sha: str = ""
    blocked_by: str = ""
    collides_with: str = ""
    drift: int | None = None
    state: str = "unstarted"
    warnings: list[str] = field(default_factory=list)


def token(value: str) -> str:
    """A field's machine-readable half — everything before the separator."""
    return value.split(FIELD_SEP)[0].strip()


def is_empty(value: str) -> bool:
    """`none` means no gate. `none — but <a real gate>` does not: the old parser
    read any none-prefix as empty and silently dropped real blockers."""
    return re.fullmatch(r"none( known)?[.]?", token(value), re.I) is not None


def parse_baton(path: Path, folder: Path) -> Baton | None:
    try:
        lines = path.read_text(errors="replace").splitlines()
    except OSError:
        return None
    if not lines or not lines[0].startswith("/"):
        return None          # a note the folder happens to hold, not a baton

    b = Baton(slug=str(path.relative_to(folder)).removesuffix(".md"), path=str(path))

    # Line 1 is `/<skill> <route> — <goal>`. The route scopes the next session's
    # reads; the goal is the only thing a cold reader sees before opening
    # anything, so a line 1 without one is worth saying out loud.
    if m := re.match(r"^/(\S+)\s*(.*)$", lines[0]):
        rest = m.group(2).strip()
        route, sep, goal = rest.partition("—")
        b.topic = route.strip()
        b.goal = goal.strip()
        if not sep or not b.goal:
            b.warnings.append("line 1 carries no goal — the paste says only the route")

    head = "\n".join(lines[:HEAD_LINES])
    if m := re.search(r"^anchor:(.*)$", head, re.M | re.I):
        anchor = m.group(1)
        if d := re.search(r"\d{4}-\d{2}-\d{2}", anchor):
            b.date = d.group(0)
        if s := re.search(r"`([0-9a-f]{7,12})`", anchor):
            b.sha = s.group(1)
        elif bare := re.search(r"\b([0-9a-f]{10,12})\b", anchor):
            b.sha = bare.group(1)
            b.warnings.append("anchor sha is not in backticks")
    if m := re.search(r"cluster[`: ]+([a-z0-9][a-z0-9-]*)", head, re.I):
        b.cluster = m.group(1)
    for name, attr in (("blocked-by", "blocked_by"), ("collides-with", "collides_with")):
        if m := re.search(rf"^{name}:(.*)$", head, re.M | re.I):
            v = m.group(1).strip()
            if not is_empty(v):
                setattr(b, attr, v)
    if not b.cluster:
        b.warnings.append("no cluster")
    return b


def git_state(batons: list[Baton], repo: Path) -> None:
    default = run("git", "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD", cwd=repo)
    default = default.removeprefix("origin/")
    if not default:
        for c in ("develop", "main", "master", "trunk"):
            if run("git", "rev-parse", "--verify", "--quiet", c, cwd=repo):
                default = c
                break
    prs: dict[str, str] = {}
    raw = run("gh", "pr", "list", "--state", "all", "--limit", "200",
              "--json", "number,state,headRefName", cwd=repo)
    if raw:
        try:
            for pr in json.loads(raw):
                prs.setdefault(pr["headRefName"], f"#{pr['number']} {pr['state'].lower()}")
        except json.JSONDecodeError:
            pass

    for b in batons:
        # A review-posture baton names no new branch; its subject is the slug
        # with the prefix stripped, so look THAT up or every review reads unstarted.
        subject = b.slug.removeprefix("review-") if b.slug.startswith("review-") else b.slug
        if b.sha and run("git", "cat-file", "-e", f"{b.sha}^{{commit}}", cwd=repo) == "":
            n = run("git", "rev-list", "--count", f"{b.sha}..{default}", cwd=repo)
            b.drift = int(n) if n.isdigit() else None
        if subject in prs:
            b.state = prs[subject]
        elif run("git", "rev-parse", "--verify", "--quiet", subject, cwd=repo) or \
             run("git", "rev-parse", "--verify", "--quiet", f"origin/{subject}", cwd=repo):
            b.state = "branch, no PR"
        if b.slug.startswith("review-"):
            b.state = f"review of {subject}: {b.state}"
    return default


def read_clusters(folder: Path) -> tuple[dict[str, str], set[str]]:
    """Definitions (name -> its meaning line) and every slug the order section names."""
    f = folder / "_clusters.md"
    if not f.exists():
        return {}, set()
    text = f.read_text(errors="replace")
    defs = {m.group(1): " ".join(m.group(2).split())[:64] + "…"
            for m in re.finditer(r"^- \*\*`([a-z0-9-]+)`\*\*\s*—\s*(.+?)(?=^- \*\*`|\Z)",
                                 text, re.M | re.S)}
    # A baton slug, not any backticked path: one optional prefix segment, kebab,
    # never a dotted filename — `docs/loopy/infra/wiki-writes.md` is a doc the
    # ordering prose cites, not a baton it orders.
    slug_re = r"`((?:[a-z]+/)?[a-z][a-z0-9-]{3,})`"
    ordered = {m for m in re.findall(slug_re, text) if "." not in m}
    return defs, ordered


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true", help="machine-readable, no styling")
    ap.add_argument("--resolve", metavar="FRAGMENT",
                    help="print `slug<TAB>path<TAB>goal` for the one baton whose slug "
                         "contains FRAGMENT; list the candidates and exit 2 if several")
    args = ap.parse_args()

    probe = run("bash", str(HELPER), "_probe_")
    if not probe:
        print("baton-index: not inside a git repository — cd to the project first", file=sys.stderr)
        return 1
    folder = Path(probe).parent
    if not folder.is_dir():
        print(f"baton-index: no baton folder at {folder}", file=sys.stderr)
        return 1
    repo = Path.cwd()

    batons = sorted(
        (b for p in sorted(folder.rglob("*.md")) if (b := parse_baton(p, folder))),
        key=lambda b: (b.cluster or "~", b.slug),
    )
    default = git_state(batons, repo)
    defs, ordered = read_clusters(folder)

    undefined = sorted({b.cluster for b in batons if b.cluster and b.cluster not in defs})
    unordered = sorted(b.slug for b in batons if b.slug not in ordered)
    dangling = sorted(s for s in ordered
                      if "/" in s and s not in {b.slug for b in batons}
                      and not (folder / f"{s}.md.done").exists())

    if args.resolve:
        frag = args.resolve.lower()
        hits = [b for b in batons if frag in b.slug.lower()]
        if not hits:
            print(f"no baton matching {args.resolve!r}", file=sys.stderr)
            return 1
        if len(hits) > 1:
            print(f"{args.resolve!r} matches {len(hits)}:", file=sys.stderr)
            for b in hits:
                print(f"  {b.slug}", file=sys.stderr)
            return 2
        b = hits[0]
        print(f"{b.slug}\t{b.path}\t{b.goal}")
        return 0

    if args.json:
        print(json.dumps({
            "project": folder.name, "default_branch": default,
            "batons": [asdict(b) for b in batons],
            "folder": {"undefined_clusters": undefined, "unordered": unordered,
                       "dangling_order_entries": dangling},
        }, indent=2))
        return 0

    from rich.console import Console
    from rich.text import Text

    c = Console()
    head = run("git", "log", "-1", "--format=%h", default, cwd=repo) or "?"
    c.print(Text.assemble((folder.name, "bold"), ("  ·  ", "dim"),
                          (f"{default} @ {head}", "cyan"), ("  ·  ", "dim"),
                          (f"{len(batons)} briefs", "dim")))

    current = object()
    for b in batons:
        if b.cluster != current:
            current = b.cluster
            c.print()
            meaning = defs.get(b.cluster, "")
            c.print(Text.assemble((b.cluster or "(none)", "bold magenta"),
                                  (f"  {meaning}" if meaning else "", "dim italic")))
        drift = "—" if b.drift is None else f"{b.drift} behind"
        state_style = ("green" if b.state.startswith("#") else
                       "yellow" if "branch" in b.state else "dim")
        c.print(Text.assemble(("  ", ""), (b.slug, "bold cyan"),
                              (f"   {b.date or 'no anchor'}", "dim"),
                              (f"   {drift}", "dim" if b.drift is None or b.drift < 100 else "yellow"),
                              (f"   {b.state}", state_style)))
        if b.goal:
            c.print(Text("      " + b.goal[:150] + ("…" if len(b.goal) > 150 else ""), style="white"))
        if b.blocked_by:
            c.print(Text.assemble(("      blocked-by  ", "red"), (token(b.blocked_by)[:110], "")))
        if b.collides_with:
            c.print(Text.assemble(("      collides    ", "yellow"), (token(b.collides_with)[:110], "")))
        for w in b.warnings:
            c.print(Text("      ⚠ " + w, style="yellow"))

    if undefined or unordered or dangling:
        c.print()
        c.print(Text("the folder owes a sweep", style="bold yellow"))
        for x in undefined:
            c.print(Text(f"  cluster {x!r} is used by a brief but defined nowhere in _clusters.md", style="yellow"))
        for x in dangling:
            c.print(Text(f"  _clusters.md orders {x!r}, which no longer exists", style="yellow"))
        if unordered:
            c.print(Text(f"  not placed in _clusters.md's order: {', '.join(unordered)}", style="dim yellow"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
