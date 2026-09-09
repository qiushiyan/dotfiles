# Tailwind skill maintenance

## Preserve the workflow adaptation

**The local SKILL.md is the maintained skill; the purchased rules are its
upstream reference.** The owner confirmed on 2026-09-09 that this version is
optimized for their workflows and should use the same manual-upgrade pattern
as obelisk. Keep its structure and invocation policy when reviewing upstream
changes; incorporate only changes that improve the adapted skill.

The upstream pin is in `.upstream/PINNED.txt`. The original source is a plain
rules document, so keep it as reference material rather than adding a second
invokable skill. Its full contents and candidate downloads remain gitignored.

The initial pin changes neither the skill body nor its invocation metadata.
Future upgrade reviews record the upstream delta and adoption decisions here.
