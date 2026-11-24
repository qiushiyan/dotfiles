# The main app

A merge does not release the app. Release it with `pl-deploy-main-app-prod`,
following its pre-flight, unless a release already running or started since
the merge carries this merge commit; one built from an earlier develop does
not. That release also promotes the Loopy master when one is owed. In a batch
a driver runs, the release is held for one session at a time; the step that
sent this closeout holds it.

A migration gate the release flags: read what it flags. One that drops or
rewrites customer data, installs something that writes it, or that the
release skill calls breaking (one the serving release cannot run against)
stops the closeout with what the gate protects
and your recommendation. Override any other with the acknowledgement it
suggests, and say so in the report.

Confirm with `pl-check-deployed`, the merge commit as `--ref` (a squash
leaves the branch head out of develop) and `app` as `--target`.

A fix someone reported through a support ticket owes them a reply: draft it
with `pl-taodesk-tickets` and leave it for the user's word.
