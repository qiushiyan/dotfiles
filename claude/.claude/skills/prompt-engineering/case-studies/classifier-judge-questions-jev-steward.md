# Case study: classifier and judge questions — the steward's Jev judgments

Read this when you write or revise a question that a classifier-style
model answers and code acts on: a yes/no gate, a rubric grader, a closed
judgment over a document. It records one pass, on planlab's steward, where
two such questions were rebuilt and measured, and what that pass taught
beyond the rulebook's body. A reasoning agent that plans and acts is not
this reader; its prompts follow the body alone.

## The setting

The steward (planlab `services/steward/`) drives unattended Claude Code
sessions through a build — design, implement, review, verify, PR — and
posts each session's final message into a task's thread, where the
engineer who owns the task reads it. Two judgments about that work are
made by **Jev** (TypeSafe's `jev-1.13`, through OpenRouter): a model that
answers closed questions over a JSON **state** with a probability each,
does no visible reasoning, and caps the state plus its longest question at
32k tokens. Code turns each probability into a band (yes, unsure, no) and
acts; nothing in a session sees the answer.

- **The reply badge.** Over every reply a session posts: does it hand the
  engineer something to decide? The card marks the reply; a reply that
  asks while the pipeline is waiting on no one is the defect the badge
  exists to catch, since the next step then makes that choice silently.
- **The residue.** Over each changed file the build's path rules cannot
  place: does the change alter text a model reads (which earns a prompt
  revision pass), and does it alter the chat screen a person uses (which
  earns a browser check)? A confident "no" on every file skips that
  follow-up; anything else runs it.

The files: `services/steward/src/loopy/decisions/` — `questions.ts` (the
questions, the situation lines, the bands and the version digest),
`project.ts` (the state under the cap), `evidence.ts` (what each file's
change did to text), `rule.ts` (bands to decisions), `decisions.eval.ts`
(the live eval). The record with the numbers is
`docs/steward/specs/2026-09-28-judgments-with-their-evidence.md`; the
vendor's own guidance is the `typesafe-ai` skill.

## What was wrong, seen from the model's side

Both questions had been written from the pipeline's point of view, passed
a review against this rulebook, and were wrong in ways no reading caught.

**The badge asked about control flow the reply does not show.** The
original question was "does `reply` say the work cannot continue until
the reader decides or provides something?" That is the pipeline's
concern, and the reply can only hint at it: whether the work continues is
decided by the host, which already knows (a session's hold, a park). A
reply that handed the engineer an optional decision — "whether this test
goes in the PR is yours" — while the next step ran on, read "no" at
0.05–0.19, correctly under the question's own definition. It was exactly
the case the badge was built for. An ablation over 60 real calls named
the mechanism: the model read "no hold" as "no decision".

**The residue judged the implementer's account, not the change.** Each
file was asked about by its path and the implementer's one-line
description. A description says what the change was for, rarely which
words moved. Over a 40-file draft of the labelled set, three of the five
files whose change altered model-facing text read under the skip band,
and would have skipped the prompt pass; asked over the change's own text,
they read 0.33, 0.83 and 0.89.

## What changed

### The frame: a scene the model knows, a question its input settles

The badge's state now opens with one sentence of situation — "An
unattended coding session posted `reply` at the end of one step of its
work, to the engineer who supervises it" — and asks what the text does:
"Does `reply` leave its reader something to decide or to provide … whether
or not the work waits for it?" The scene is stylised: there is no
steward, no Bench, no drain, and some readers are triaging a customer's
report rather than supervising code. It is kept because the right answer
under it is the right answer in fact, and because it is a scene the model
already has priors for: "unattended" is what makes an unanswered question
matter. The wait fact the old question tried to infer is joined in code
(`asks && !hostWaits`), with one exemption in code too: the step whose
purpose is to ask the engineer questions is never flagged.

The two re-read replies moved from 0.07 to 0.87 and from 0.16 to 0.92.

The judge is told nothing of what its verdict triggers. A consequence
("a yes pauses the build") is a reason for an agent that acts, and for a
judge it is a second, competing criterion: the answer starts to weigh the
cost of the action instead of reading the text.

### The evidence: a projection built for the question, never the raw material

Every word in the state is evidence to a classifier, and its accuracy
falls with material the question does not need; the cap is also real. So
code builds the state the criteria name. For the residue that is, per
file: the texts the change added and removed (every string, template and
JSX text in the file before and after, compared as texts through the
TypeScript parser, so a moved sentence is no change), a bounded slice of
the changed code lines for what text alone cannot show, and the
implementer's line beside them — never the diff. Over the cap, the state
gives way in a fixed order: the narrative, then the code slices, then the
text, then the lines.

The cut is part of the decision, not only of the request. A file whose
text or line was cut, whose source did not parse, or that git could not
show is **incomplete**, and an incomplete file never carries a skip,
whatever the model answers: a verdict over half the change cannot license
skipping work. A state that cannot fit even after every cut is not sent.
Completeness is recorded on the row, so a later reader can tell a
confident "no" from a "no" over missing evidence.

### The criteria: what the text shows, including what does not count

Each question carries criteria for both answers in observable terms. The
badge's "no" names the near-misses explicitly: a report of what was done,
later work listed as owed, a recommendation, an invitation to read
something. Those were where the errors lived. State fields are named in
backticks in the question (`reply`, `changed_text`) so the model reads the
part the question means. The residue asks one absolute question per file
per operation, never one question over the whole change, and a service
file is asked only the question that can concern it.

The judged text argues its own verdict: session replies say "nothing here
needs your decision". The criteria describe the ask and never defer to
the reply's account of itself; the eval still found the pull is not zero
(below).

### Calibration: labels, not reading

Wording was judged only on labelled data, and the labels needed as much
design as the questions:

- **Real inputs, and edited copies of them.** A committed set of one
  card's 18 replies, plus 40 cases edited from them: an explicit ask added
  as a block and as a bullet, an optional offer added, a self-declaration
  ("nothing needs your decision") added, an ask deleted. Edited pairs
  isolate one cause; they found the self-declaration effect that the real
  set could not show.
- **A labelling rule written before labelling, then corrected by the
  owner.** Two independent model raters labelled 122 real replies
  against one rubric; the owner settled every positive and every
  disagreement. The rule that came out of the owner's calls is about
  address, not optionality: a reply asks when it puts a choice to the
  reader, optional or not ("you may want the case added to the suite");
  optional work listed as owed, with no choice put to anyone, does not.
  A first reading of the owner's call had written it down as "an optional
  'if you want' does not", which contradicted the edited offer cases; the
  label behind a rule is worth re-reading before the rule is recorded.
- **An eval at the production bands.** `decisions.eval.ts` asks every case
  live and asserts what the production rule would do: no reply read
  against its label, explicit asks in the yes band, a deleted ask lowering
  the reading by 0.3 or more, every residue file complete and no wrong
  skip. An earlier version passed at looser bands than production used;
  a review found it.
- **Bands by cost.** The badge's yes is 0.6 and no 0.3; the residue's skip
  bands are per operation (0.25 for the prompt pass, 0.2 for the browser
  check), set against labelled files. A wrong skip costs more than a
  session spent.
- **The wording is the model.** The situation line, the questions, the
  criteria, the projection and the bands are hashed into one version on
  every stored row, so an edit to any of them is a new population, and a
  row asked under an old version keeps that version's questions wherever
  it is read.

What it measured: of 76 asking replies, 47 read yes, 23 unsure and 6 no;
of 46 non-asking, none read yes. The residue made no wrong skip over 34
labelled files, all with complete evidence.

## What stays open

- **A self-declaration still pulls.** An asking reply with "nothing needs
  your decision" added read about 0.2 lower, once under the no band. The
  criteria cannot fully neutralise text that argues its own verdict; the
  edited cases are how you see it.
- **The unsure band is wide** on replies whose questions are invitations
  (a diagnosis listing what a person could answer, a review round
  reporting fixes). Only real grades from the engineer can narrow it, so
  every badged reply keeps a grade control.
- **Optional offers straddle the yes band** (0.57–0.88 across runs); the
  eval asserts only that they never read as no.

## What transfers

- **To any closed-question judge:** pose the question in a scene the
  model knows and let code join what the input cannot show; build the
  state for the question and treat a cut as incomplete evidence; write
  criteria for the near-misses; give the judge no consequence; label real
  inputs plus edited pairs, write the label rule down, and eval at the
  production thresholds; version the wording with its thresholds.
- **Not to a reasoning agent:** an agent gets the consequence of its
  action as its reason, and its frame may leave things out but never
  invent them, since it acts on the real system (the body's *reader's
  world*). The steward's own session prompts in the same pass followed the
  body alone.
- **Jev-specific:** the noul primitive has no confidence, only a
  probability; questions in one request are answered independently, so a
  question that depends on another's answer is a second request; the cap
  covers the state plus the longest question. The `typesafe-ai` skill
  owns these.
