#!/usr/bin/env python3
"""spec-stats.py <spec.md> [--against <rev>] — approximate prose statistics for a
spec, with code, indented blocks and table rows excluded: words per section,
sentence and paragraph lengths, and the summary block's labelled lines and
groups. The size line counts every word outside code blocks, tables and
indented lines included, which is what SPEC-BAR's size means. With --against, each section's words are compared with the spec at that
git revision (the commit of step 3, say), so growth through the checks shows by
section. Run before the final reread."""
import re, subprocess, sys
from pathlib import Path

def prose(text):
    text = re.sub(r"^---\n.*?\n---\n", "", text, count=1, flags=re.S)   # front matter
    body = re.sub(r"```.*?```", "", text, flags=re.S)                    # code blocks
    body = re.sub(r"^(?: {4,}|\t).*$", "", body, flags=re.M)             # indented blocks
    tables = len(re.findall(r"^\s*\|\s*-{3,}", body, flags=re.M))         # header separators
    body = re.sub(r"^\s*\|.*$", "", body, flags=re.M)                     # table rows
    return text, body, tables

def sections(body):
    out, sec = {}, "(before the first heading)"
    out[sec] = 0
    for line in body.splitlines():
        if line.startswith("## "):
            sec = line[3:]; out[sec] = 0
        else:
            out[sec] += len(line.split())
    return out

def at_revision(path, rev):
    p = Path(path).resolve()
    root = subprocess.run(["git", "-C", str(p.parent), "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True).stdout.strip()
    r = subprocess.run(["git", "-C", root, "show", f"{rev}:{p.relative_to(root)}"],
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"spec-stats: the spec is not at {rev}: {r.stderr.strip()}")
    return r.stdout

def main(path, against=None):
    text, body, tables = prose(open(path, encoding="utf-8").read())

    print(f"size {len(re.sub(r'```.*?```', '', text, flags=re.S).split())} words outside code blocks")
    now = sections(body)
    if against:
        before = sections(prose(at_revision(path, against))[1])
        print(f"words per section, now against {against}")
        for sec in list(before) + [s for s in now if s not in before]:
            a, b = before.get(sec, 0), now.get(sec, 0)
            print(f"  {b:6}  {b - a:+6}  {sec}{'' if sec in now else '  (gone)'}")
        ta, tb = sum(before.values()), sum(now.values())
        print(f"  {tb:6}  {tb - ta:+6}  total ({100 * (tb - ta) / ta if ta else 0:+.0f}%)")
    else:
        print("words per section")
        for sec, n in now.items():
            print(f"  {n:6}  {sec}")

    # sentences
    sents = []
    for para in re.split(r"\n\s*\n", body):
        for bullet in re.split(r"\n(?=\s*[-*] |\s*\d+\. )", para):
            flat = re.sub(r"\s+", " ", bullet).strip()
            for s in re.split(r"(?<=[.!?])\s+(?=[A-Z*`(\[])", flat):
                w = len(s.split())
                if w >= 3: sents.append((w, s))
    words = len(body.split()); ns = len(sents)
    over40 = sum(1 for w, _ in sents if w > 40)
    longest = max(sents, key=lambda x: x[0]) if sents else (0, "")
    print(f"\nwords {words}   sentences {ns}   mean {words/ns if ns else 0:.1f} words/sentence   over 40 words {over40} ({100*over40/ns if ns else 0:.0f}%)")
    print(f"longest sentence, {longest[0]} words: {longest[1][:160]}…")
    print(f"tables {tables} (their rows are left out of the counts above)")

    # longest paragraph (a bullet counts as its own paragraph)
    paras = [re.sub(r"\s+", " ", b).strip() for p in re.split(r"\n\s*\n", body)
             for b in re.split(r"\n(?=\s*[-*] |\s*\d+\. )", p)]
    lp = max(paras, key=lambda p: len(p.split())) if paras else ""
    print(f"longest paragraph, {len(lp.split())} words: {lp[:160]}…")

    # summary block: labelled lines, complete sentences, grouped
    m = re.search(r"^## Summary\s*\n(.*?)(?=^## )", text, flags=re.S | re.M)
    block = m.group(1) if m else text.split("\n## ", 1)[0]
    lines = [l for l in block.splitlines() if l.strip()]
    labelled = [l for l in lines if re.match(r"^[A-Z][A-Za-z]*(?:, [a-z ]+)?: ", l)]
    groups = len([g for g in re.split(r"\n\s*\n", block.strip()) if g.strip()])
    print(f"\nsummary: {len(labelled)} labelled lines of {len(lines)}, {groups} groups, {len(block.split())} words")
    if len(labelled) < len(lines) * 0.8:
        print("  the summary is not a labelled block; SPEC-BAR § Summary, first")

if __name__ == "__main__":
    args = sys.argv[1:]
    if not args or args[0].startswith("-") or (len(args) not in (1, 3)) or (len(args) == 3 and args[1] != "--against"):
        sys.exit("usage: spec-stats.py <spec.md> [--against <rev>]")
    main(args[0], args[2] if len(args) == 3 else None)
