#!/usr/bin/env bash
# tmux-resurrect-save.sh — resurrect's save, with floats normalised first.
#
# A snapshot taken while a pane is floated is UNRECOVERABLE. It records the
# source window missing that pane, plus a `_float_*` holder session containing
# it, and resurrect's format (session name, window index, layout, pane index)
# carries no pane user options — so the metadata that links the two halves is
# not in the file. After a restart the pane ids are freshly allocated too, so
# nothing can reconnect them. Continuum saves every 15 minutes by default, so
# any float that outlives a tick is exposed.
#
# There is no pre-save hook to fix this from: resurrect only fires
# `post-save-layout` and `post-save-all`, both too late. But continuum does not
# call resurrect directly — it reads the save script path from the
# @resurrect-save-script-path option and executes that (continuum_save.sh:30).
# Pointing that option here therefore covers the automatic timer as well as the
# manual key, which is rebound to this script in tmux.conf (resurrect binds
# prefix C-s straight to its own save.sh, bypassing the option).
#
# Args are passed through untouched — continuum calls with "quiet".

set -uo pipefail

FLOAT="$HOME/.config/tmux/scripts/tmux-float-pane.sh"
# Overridable so the test suite can prove the abort path without running the
# real save; production never sets it.
REAL="${RESURRECT_SAVE:-$HOME/.config/tmux/plugins/tmux-resurrect/scripts/save.sh}"

# FAIL CLOSED. If a float cannot be normalised, do NOT save: resurrect
# overwrites the previous snapshot, so saving now would trade a good save for
# one that records the floated pane and its window as unrelated things. Skipping
# keeps the last good save, and prepare-save has already told the user why.
if [ -f "$FLOAT" ]; then
    if ! bash "$FLOAT" prepare-save; then
        exit 1
    fi
fi

exec "$REAL" "$@"
