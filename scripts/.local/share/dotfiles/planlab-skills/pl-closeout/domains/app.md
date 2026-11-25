# The main app

A merge does not release the app. Release it with `pl-deploy-main-app-prod`
unless a release already running or started since
the merge carries this merge commit; one built from an earlier develop does
not. That release also promotes the Loopy master when one is owed. Rerun the
check to confirm it serves.

A migration gate the release flags: read what it flags. One that drops or
rewrites customer data, installs something that writes it, or that the
release skill calls breaking (one the serving release cannot run against)
stops the closeout. Any other you override: the user's standing instruction
(`~/dotfiles/docs/session-pipeline.md` § Who decides) is the person's word
the release skill asks for. Set it with the acknowledgement the gate
suggests, its reason quoting that rule, and say so in the report.

A fix someone reported through a support ticket owes them a reply: draft it
with `pl-taodesk-tickets` and leave it for the user's word.
