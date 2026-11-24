# The main app

A merge does not release the app. Release it with `pl-deploy-main-app-prod`,
following its pre-flight, unless a release already running or started since
the merge carries this merge commit; one built from an earlier develop does
not. That release also promotes the Loopy master when one is owed. Rerun the
check to confirm it serves.

A migration gate the release flags: read what it flags. One that drops or
rewrites customer data, installs something that writes it, or that the
release skill calls breaking (one the serving release cannot run against)
stops the closeout with what the gate protects and your recommendation.
Override any other with the acknowledgement it suggests, and say so in the
report.

A fix someone reported through a support ticket owes them a reply: draft it
with `pl-taodesk-tickets` and leave it for the user's word.
