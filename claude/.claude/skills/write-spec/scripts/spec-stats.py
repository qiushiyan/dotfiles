#!/usr/bin/env python3
"""spec-stats.py <spec.md> — the shape of a spec as a model reads it: words per
section, sentence length, the longest paragraph, and whether the summary is a
labelled block. Run before the final reread."""
import re, sys

def main(path):
    text = open(path, encoding="utf-8").read()
    text = re.sub(r"^---\n.*?\n---\n", "", text, count=1, flags=re.S)   # front matter
    body = re.sub(r"```.*?```", "", text, flags=re.S)                    # code blocks
    body = re.sub(r"^(?: {4,}|\t).*$", "", body, flags=re.M)             # indented blocks

    # words per section
    print("words per section")
    sec, n = "(before the first heading)", 0
    for line in body.splitlines():
        if line.startswith("## "):
            print(f"  {n:6}  {sec}"); sec, n = line[3:], 0
        else:
            n += len(line.split())
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
        print("  the summary is not a labelled block; SPEC-BAR § The summary, first")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else sys.exit("usage: spec-stats.py <spec.md>"))
