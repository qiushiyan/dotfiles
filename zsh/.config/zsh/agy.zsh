# ~/.config/zsh/agy.zsh
# Antigravity CLI (agy): trust every folder it starts in.
#
# agy asks "Do you trust the contents of this project?" in each folder it
# starts in. It records trust per exact folder in
# ~/.gemini/antigravity-cli/settings.json (trustedWorkspaces): a parent's
# entry covers nothing below it, no pattern matches, and no setting or flag
# trusts every folder, --dangerously-skip-permissions included (checked on
# agy 1.5.10). So this wrapper trusts the launch folder for that session
# alone, through --settings, which agy never saves: nothing piles up in the
# file. A headless run (-p) is never asked, so envoy needs none of this.
#
# Everything else agy runs with is its settings.json, whose keys come from
# ~/.config/twin/agy through `twin dotfiles apply` (docs/twin.md). A command
# line that brings its own --settings goes through untouched.
agy() {
  emulate -L zsh
  if (( ${argv[(I)--settings(|=*)]} )); then
    command agy "$@"
    return
  fi
  local dir=${PWD:A}
  dir=${dir//\\/\\\\}
  dir=${dir//\"/\\\"}
  command agy --settings "{\"trustedWorkspaces\":[\"$dir\"]}" "$@"
}
