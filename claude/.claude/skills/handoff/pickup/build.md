## Pickup gate — build

This brief carries an already-reviewed approach. Use the first turn to
inspect and verify the current state, with the worktree left unchanged, and
return the sections below.

1. **Problem in plain terms** — who is affected, what fails, and why the
   reviewed approach should remove that failure. Derive this from current
   code and evidence, for a reader who no longer remembers this brief.

2. **Premises checked**
   - Name the single premise that must be true for the approach to solve
     the stated problem, whether or not the brief listed it. Test it with
     the cheapest decisive evidence.
   - Check each claim under `## At pickup` at its named source.
   - Report each as `Held — <evidence>`, `Falsified — <what is true
     instead>`, or `Unverified — <what evidence is missing>`.
   - Use production evidence for production claims. When obtaining it
     would become a separate investigation, report it as unverified.

3. **Verdict** — one line:
   - `Build framing holds — <why>` when the load-bearing premise and the
     necessary claims held.
   - `Reframe required — <what changed, failed, or remains unverified>`
     otherwise.

If the verdict is `Reframe required`, state the smallest consequence for
the work and route it to a design pass in a later turn. If verification
exposed a product decision that changes the direction, append **Decision
needed** with why it matters, the user-visible options, and your
recommendation; otherwise omit it.

Stop after this response. Implementation begins only after the user's next
message.
