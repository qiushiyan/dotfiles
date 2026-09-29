# slackkit — one personal Slack toolkit for coding agents

**Status: built 2026-09-29, except the PlanLab half, which is open as planlab-ai/main#8203.**
slackkit exists with its library, CLI, skill and manifest, slack-digest
imports it, and this repo links the skill and carries the token store to the
mini. Delete this file when the PlanLab PR merges; its surviving decisions
live in `~/dev/slackkit/DESIGN.md` and slack-digest's `DESIGN.md`. Settled 2026-09-29 from a
session-history analysis and a consult round (`consult-r1/codex-gpt-6-astra`,
job `~/.local/state/envoy/jobs/dotfiles-4f711dad/consult-r1+4`); the design
follows that voice's position where the two differed.

## Why

Agents in coding sessions keep needing Slack as Qiushi: read the thread behind
a link a colleague shared, post a reply once a fix lands, look up a channel or
member id for a config. Nothing owns that today, so each session rebuilds it.
The session index (Claude sessions, 2026-06-26 → 09-29, 174 prompts about
Slack in 93 sessions) shows three doors: PlanLab's team skill `pl-slack` and
its bash scripts, bound to a project bot's token and a repo-relative env file;
raw `curl` against the Web API for posts, identity checks and id lookups; and
`slack-digest`'s ledger commands, which reach only the threads the daily
briefing raised. The counts say which doors exist, not demand shares: they
tally mentions inside shell commands, inspections included. What decides the
matter is one observed session (2026-09-29): to post a reply in a thread the
digest did not track, the agent grepped the user token out of `tokens.env`,
ran PlanLab's script with that token in the bot's place, and built the
`chat.postMessage` payload by hand; the reply then had to move to a second
thread after the first was deleted. Every pasted permalink in the index is
from PlanLab, and threads are always referred to by link, so a permalink is
the read command's input.

The digest already holds what every door reinvents: the user-token identity
(the "Digest (Qiushi)" app, one install per workspace, reading Slack as him
with no bot to invite), a client with retry and paging, permalink parsing,
name resolution, mrkdwn rendering, credential redaction, escaped posting.
Both installed user tokens carry `search:read`, `im:write`, `files:read`,
`chat:write`, `reactions:write` and `users:read.email` today, verified live.

The official Slack plugin (`slackapi/slack-mcp-plugin`) is not the base: its
hosted MCP server needs each workspace admin's approval, its tool list is not
in the repo, nothing in it handles a permalink, and Codex installs get the
skills without the server. Borrowed from it: the search modifier syntax, its
error-handling rows (`missing_scope` names `needed`/`provided`; cursors are
never constructed; `Retry-After` is honoured), and the etiquette of reacting
instead of replying for an acknowledgement.

## Decisions

- A new Go repository `~/dev/slackkit` owns three artifacts: a library, a
  `slack` CLI, and the `slack` skill. `slack-digest` imports the library and
  keeps only what is the briefing's: collection windows, thread filtering,
  the judge, the ledger, the tape and replay.
- The skill is linked into dotfiles the way `read-email` is
  (`claude/.claude/skills/slack → ~/dev/slackkit/skills/slack`); it replaces
  `slack-followup`, whose digest flow becomes one section.
- Identity is the "Digest (Qiushi)" app's user tokens. The manifest moves to
  slackkit so anyone, a teammate included, installs their own app and speaks
  as themselves. Project bots (PlanLab's bugbot, the lab's bug-report bot, the
  `SLACK_BOT_TOKEN` in `~/.secrets`) are never a personal identity.
- PlanLab deletes `pl-slack`. Its skills refer to the personal skill by the
  name `slack`, never a path. What is PlanLab's stays in PlanLab, in a local
  guide (§ PlanLab below).
- Flags live in the CLI's `-h`; the skill carries judgment only.

## Shape

### The library

A workspace session, constructed from an explicit token and an explicit
`http.RoundTripper`, exposing domain operations with structured results:
`Thread`, `History`, `Conversations`, `People`, `Post`, `React`, `Delete`,
`Search`, `Identity`. Credential discovery is a separate composition concern,
not the session's: the CLI resolves a token from the store and constructs a
session; the digest constructs one from its own token, including its replay
sentinel, and its tape transport, and never loads the personal catalog.

A parsed message reference keeps **workspace host, channel, the selected
message's ts, and the thread root** as separate fields. Posting into a thread
uses the root; reacting to or deleting a message uses the selected ts. The
root is resolved from Slack, since `conversations.replies` given a reply's ts
returns that one message with `has_more=false` and a different `thread_ts`,
and a URL's `thread_ts` is only a claim to verify. A read presents a thread
only when it fetched it from the root to the end; a prefix is reported as one.

Messages retain the raw payload beside the projection: blocks, attachment
fallbacks, file metadata with download URLs, reactions. The digest's model
drops blocks and keeps only a file's name, which is fine for a briefing and
loses evidence for a debugging read. General reads keep bot and system
messages; the digest's `filterThread` stays in the digest.

Shared rendering covers message content: names (the token owner as "you"),
entities, links, mentions, attachment descriptions, reactions, local times.
The digest's reference labels (`m12`), "(earlier)" marks and GitHub
annotations stay in `formatMessage` there. There is no universal renderer
with digest-mode flags.

Text going out is compiled once, in the library: literal by default, with
`&<>` escaped; `mrkdwn` on request keeps intentional markup. The preview shows
the compiled text, not the pre-escape input. A write returns one of three
outcomes, accepted with its ts and permalink, rejected with Slack's error, or
unknown when the response was lost after the request left; an unknown outcome
is never retried by the library, and the caller is told what read would
settle it.

Redaction is an output policy, not a renderer feature: transcripts, search
snippets, JSON and metadata pass through it alike, and downloaded bytes are
outside any claim of redaction. `--unredacted` exists and marks its output.

The token store is `~/.config/slack/tokens.env`, lines `<key>=<token>` and
`<key>-bot=<token>`, Keychain fallback per account under service `slack`; an
empty value registers a key whose token lives in the Keychain, which is how
link-only commands can enumerate workspaces without a Keychain listing. `-bot`
accounts are excluded from workspace selection and preserved for the digest's
notifying DM. A permalink's host selects the workspace via one `auth.test` per
registered user token; two tokens answering the same host fail with both
named. No cache while there are two accounts.

### The CLI

Verbs are domain nouns and stay under ten. Every verb takes the address the
agent already holds: a permalink, `<channel> <ts>`, `#name`, `@handle`, an
email, a raw id. Reads print text meant for a model to read, `--json` for
chaining, `--out DIR --files` to stage a bundle with attachments. Writes print
the actor, the destination and the permalink of what they did, so the next
command has its input. Every `ok: false` maps to one line saying what to do
next, in the spirit of `pl-slack`'s error table, moved from prose into code.

```sh
slack read <permalink>                    # the whole thread, root to end, requested message marked
slack read <permalink> --out DIR --files  # bundle: transcript, raw json, attachments
slack read '#channel' -w planlab --since 2d   # bounded recent history; the window is stated
slack post <permalink> --text-file reply.txt        # preview: compiled text, actor, destination
slack post <permalink> --text-file reply.txt --send
slack post '@handle' -w planlab "text"     # opens the DM
slack react <permalink> :eyes:
slack delete <permalink>                  # own messages only
slack search -w planlab 'from:@thomas "AND-412" after:2026-09-01'
slack whois thomas@planlab.ai             # id · name · email
slack channel '#tech' -w planlab --members
slack whoami                              # every registered workspace: user, team, url, scopes
```

Contracts: a message target reads the complete thread; a channel or person
target reads bounded recent history and says its window and continuation. A
permalink fixes the workspace, and a `-w` given beside it must agree;
link-less addresses require `-w`, and nothing is inferred from the current
directory. `post` previews without `--send`; with it, it sends directly, so
the preview is a convenience the skill turns into a gate, not a guarantee.
Text comes from an argument, `--text-file` or stdin, so multi-line replies
need no shell reconstruction. Search hides Slack's page-based pagination,
prints candidates with workspace, channel, time, author and link, says when
more exist, and an empty result is a "nothing found", not a finding.

### The skill

Lean, in three layers: what this is and what done looks like (the reply is in
the thread and, when the digest tracked it, the item is closed); the judgment
the CLI cannot carry (send only after Qiushi says yes to the previewed text;
his voice, English, two sentences, naming the PR; "live" only when deployed;
for a target given without a link, search, read the candidate, confirm the
target before posting); and the boundaries (a PlanLab bug-report outcome is
the project CLI's bot post; a project's own Slack guide, when its instructions
name one, answers that repo's patterns). A few complete worked patterns, each
with its output shape, carry the rest. Scope tables, wire format and the
address model are the repo's documentation and the CLI's errors, not a second
agent-facing manual.

## Migrations

**slack-digest.** Import the library; delete `internal/slack`, `text.go`'s
`Names`/`Plain`/`Redact`, `token()` and the Keychain constant; `reply <id>`
becomes the library's post plus a ledger settle, reporting a posted reply
separately from a failed settle. The extraction is behaviour-preserving for
the tape: a replay of an existing record reproduces it exactly, so the
digest's read sequence and request parameters do not change. The doors test
learns the new construction site, and a new test replays a record with no
credentials and network forbidden. The digest builds against a pinned module
version; `go.work` is for development only.

**dotfiles.** Link the skill; remove `slack-followup`; add `.config/slack` to
mini-sync's carried secrets and `slack` to its binaries. mini-sync copies
symlinks as symlinks, so every project-owned skill link on the mini dangles
today (`read-email`, `explain-diff` verified 2026-09-29); the same change
makes it carry those skill directories as real directories, which fixes all
three. Secrets are copied after binaries; the digest runs once at 08:30, so
the window is harmless unless a sync straddles it, and the first sync after
the cutover is run by hand with the new store already in place.

**PlanLab.** Delete `.agents/skills/pl-slack` and its scripts. Add
`docs/loopy/slack.md`, the project's Slack guide: the three apps and their
tokens and scopes (bugbot, Taodesk, autoandy, and the eval notifier as
bugbot's channel), staged bug-report threads via `loopy evidence`, the two
`thread.json` artifacts, the server-composed outcome path, the code pointers
(`read-thread.ts`, `upload-file.ts`, `escapeSlackText`, `slackDate`), the PII
boundary, and one line saying personal reads and posts are the `slack` skill,
installed by each person with their own identity. The six skills and the
skill-map row that name `pl-slack` point at the guide for bot mechanics and at
`slack` for personal operations, never `slack` for both.

## Sequencing

The personal repositories (slackkit, slack-digest, dotfiles) take direct
commits on `main`, in that order, since slackkit has to exist before the
digest imports it. PlanLab is a team repository and takes a PR. Each commit
is a correct state on its own; the digest kept working on its old code until
its commit landed.

## Test plan the consult pinned

- A bare reply link resolves to its root; a link whose `thread_ts` disagrees
  with Slack's answer is rejected with both values; a deleted target is
  reported, not rendered empty.
- `react` and `delete` act on the selected message, `post` on the root; a
  thread whose root is the selected message does both on one ts.
- A block-only message, a bot-only thread, an attachment with only fallback
  text, an empty `replies` response, and a reaction count exceeding the
  returned user list each render without loss or crash.
- A lost response after an accepted post yields "unknown" with the recovery
  read, never "nothing posted"; a rejected post carries Slack's error.
- Literal text with `<!channel>` posts as text; the same with `--format
  mrkdwn` posts as markup; the preview equals what is sent.
- Redaction applies to transcript, search snippets and `--json` alike;
  `--unredacted` output is marked.
- Two tokens whose `auth.test` share a host fail naming both; `-w` beside a
  permalink for another workspace fails.
- The digest's replay of an existing record reproduces it byte for byte
  after the import, with no token file and no network.
- Search paginates by Slack's page fields, states truncation, and returns
  candidates with permalinks that `read` accepts.

## Tenets

- **Bind a personal action to a verified workspace and user before resolving
  its destination**, because identical-looking names across installed
  identities must never choose who speaks.
- **Share Slack facts and operations; keep the briefing's judgment in the
  briefing**, because a briefing's useful omissions are defects in an
  evidence reader.
- **The caller controls every external read**, because replay has to work
  with no credentials, no cache and no live workspace.
- **A command accepts the address already held and finishes the operation
  behind it**, because teaching agents the missing joins recreates the
  toolkit in every session.
- **Results state observed outcomes and coverage**, because a partial read or
  an uncertain write must not become a confident conclusion or a duplicate
  post.
- **A post in Qiushi's name is shown before it is sent, by the command
  itself**, because the instruction layer differs between harnesses and a
  post cannot be unsent.
- **Project workflow ownership survives personal-tool adoption**, because
  speaking as a person and completing a bot-managed business operation have
  different effects.

*Unless you know better ones.*

## Open before the build

- Whether any teammate runs `pl-slack`'s scripts is unmeasurable from here;
  the PlanLab PR says so and names the replacement.
- Slack's `search.messages` is a legacy method that works with both tokens
  today; the search verb is built as candidate discovery so a change there
  costs one operation.
- A `--mention` option that resolves a handle or email into the text waits
  for a session that needs it; until then `whois` gives the id and `--format
  mrkdwn` carries it.
