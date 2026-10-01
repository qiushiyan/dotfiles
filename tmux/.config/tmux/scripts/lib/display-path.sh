# shellcheck shell=bash disable=SC2034  # the results are read by the sourcer
# lib/display-path.sh — the compact workspace path agents show, defined once.
#
#   display_path <dir> <home> <git-dir> <git-common-dir> <toplevel>
#
# Sets DISPLAY_PATH, and DISPLAY_PATH_LINKED to 1 when <dir> is inside a
# linked worktree (else empty). Callers pass git's own
# `rev-parse --path-format=absolute --git-dir --git-common-dir --show-toplevel`
# lines (empty outside a repository) and physical paths for <dir> and <home>:
# git reports physical paths, so a symlinked spelling would not strip.
#
# A linked worktree (gwt / prefix-W put them at ~/dev/.worktrees/<repo>/<branch>)
# shows as its MAIN checkout plus any subpath: the raw path's grouping key is
# the main checkout's basename and its last segment repeats the branch, which
# the agent shows on its own. Detection is git-common-dir, not path parsing, so
# branches with slashes and worktrees made outside the convention resolve.
# Then ~/dev is implicit and the rest of home is ~, on whole path components
# only (a sibling like /Users/name2 stays as it is).
#
# Readers: the Claude statusline (statusline-command.sh) and the Codex pane
# wrapper (zsh tmux-utils.zsh). Both bash and zsh source this file, so it uses
# scalar parameter expansion only, with every pattern operand quoted.
display_path() {
    DISPLAY_PATH=$1 DISPLAY_PATH_LINKED=
    if [ -n "$4" ] && [ -n "$5" ] && [ "$3" != "$4" ]; then
        DISPLAY_PATH="${4%/.git}${1#"$5"}"
        DISPLAY_PATH_LINKED=1
    fi
    case $DISPLAY_PATH in
        "$2/dev/"*) DISPLAY_PATH=${DISPLAY_PATH#"$2/dev/"} ;;
        "$2")       DISPLAY_PATH='~' ;;
        "$2/"*)     DISPLAY_PATH="~/${DISPLAY_PATH#"$2/"}" ;;
    esac
}
