# Taodesk

A merge to develop does not deploy Taodesk. Deploy `taodesk/` with
`pl-deploy-taodesk`: its pre-deploy section, the migration step the deploy
itself does not run, then the checks it lists after a deploy. The deploy uploads a working tree, so run it
from a clean checkout of `origin/develop`, never the PR's worktree, which
lacks what else has merged.

A migration under `packages/db-schema/` belongs to the main app's database
and rides the app's release ([app.md](app.md)). When one merge changes both,
`pl-deploy-taodesk` sets the order: Taodesk goes first when the app will send
it more than the serving Taodesk accepts. A migration that drops or rewrites
ticket data stops the closeout, as app.md says for the app's.

The people a Taodesk change is for are usually the support team or a
customer on a ticket. A customer's reply is drafted with `pl-taodesk-tickets`
and waits for the user.
