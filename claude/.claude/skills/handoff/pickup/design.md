## Pickup gate — design

This brief carries a proposed approach that is still open. Use the first
turn to produce a read-only attack packet for the user and for `/consult`,
with the worktree left unchanged, and return the sections below.

1. **Problem in plain terms** — who is affected, what fails, and the goal
   beneath the brief's framing. Derive this from current code and evidence;
   the reader last saw this brief a week ago.

2. **Premises checked**
   - Name and test the load-bearing premise behind the problem or the
     proposed approach, whether or not the brief listed it.
   - Check each claim under `## At pickup` at its named source.
   - Report each as `Held`, `Falsified`, or `Unverified`, with the decisive
     evidence or the evidence still missing.

3. **Pressure test** — the proposed approach under `## At pickup`, from
   each perspective in turn:
   - **User:** the strongest objection from what the user sees, waits for,
     or must understand; otherwise `None found`.
   - **Performance:** the strongest objection on a hot path or at real
     operating sizes; otherwise `None found`. Mark an unevidenced scale
     claim unverified.
   - **Code:** trace how the change joins the current structure — absorbed,
     accreted, or blocked by it — and cost any preparatory reshape. End
     with the strongest objection or `None found`.

4. **Countershape, trade-off, and hybrid**
   - When an objection could change the choice, sketch one genuinely
     different countershape that answers it. Otherwise say the proposal
     survived this attack and omit a countershape.
   - Compare the proposal and the countershape on the root problem and on
     their user, performance, and code costs.
   - Say whether a hybrid removes the strongest objection; reject it when
     it merely combines both costs.
   - Give a provisional recommendation and name the trade-off it accepts.

5. **Decisions and parked unknowns**
   - Include **Decision needed** only for product intent, scope, priority,
     or user-visible forks that change the direction. Give options,
     consequences, and a recommendation in plain terms the user can decide
     from without the code.
   - Include **Open technical questions — parked** only for unresolved
     facts that do not change the direction, each with a working answer.

End by offering `/consult` with sections 1–4 as its input: the consult
performs the independent multi-approach exploration and settles the
direction. Stop after this response. Implementation begins once that
direction is accepted.
