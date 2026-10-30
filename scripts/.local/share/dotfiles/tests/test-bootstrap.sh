#!/usr/bin/env bash
# test-bootstrap.sh — the parts of scripts/bootstrap.sh that decide without
# installing: the stow list it reads from twin's manifest for a machine, and
# the closing report of what changed in the clone during a run.
#
# Usage: bash test-bootstrap.sh [B1 B4 ...]     (run it from a scratch directory)
#
# ISOLATION. The script is sourced, which defines its steps and runs none;
# REPO_DIR is a scratch git repository holding a fixture twin.toml in the
# manifest's shape. No step runs, so nothing is installed.

set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT=$(cd "$HERE/../../../../.." && pwd -P)
BOOT=$ROOT/scripts/bootstrap.sh
PASS=0; FAIL=0; FAILED=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-test.XXXXXX")
cd "$SANDBOX" || exit 1
cleanup() { [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "${SANDBOX:-}"; }
trap cleanup EXIT

check() {  # check <name> <expected> <actual>  (bootstrap defines its own ok)
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

# shellcheck source=/dev/null
source_again() { source "$BOOT"; }
source_again
set +e   # the script's errexit would end the suite at the first failed check
REPO_DIR=$SANDBOX/clone
mkdir -p "$REPO_DIR/twin/.config/twin"
cat > "$REPO_DIR/twin/.config/twin/twin.toml" <<'EOF'
reconciles = "mini"

[machines.mac]
ssh = "mac"

# headless
[machines.mini]
ssh = "mini"
packages = [
  "claude", "git",  # a comment inside the list
  "launchd-mini", "zsh",
]

[machines.mini2]
ssh = "mini2"

[dotfiles]
repo = "dotfiles"
packages = ["not", "a", "machine"]
EOF
git -C "$REPO_DIR" init -q && git -C "$REPO_DIR" add -A && git -C "$REPO_DIR" -c user.name=t -c user.email=t@t commit -qm seed

CASE=B1; if want; then
    check "B1 sourcing runs no step" "" "$(source_again 2>&1)"
    check "B1 a run that changes nothing reports nothing after its steps" "==> Sanity check (macOS Apple Silicon)
    ok: macOS arm64" "$(main check_macos 2>&1)"
fi

CASE=B2; if want; then
    before=$(tree_state)
    printf '# pnpm\n' >> "$REPO_DIR/twin/.config/twin/twin.toml"
    mkdir -p "$REPO_DIR/scripts/.local/share/uv" && : > "$REPO_DIR/scripts/.local/share/uv/python"
    out=$(report_tree "$before")
    check "B2 names a tracked file an installer changed" 1 "$(grep -c ' M twin/.config/twin/twin.toml' <<<"$out")"
    check "B2 names an untracked directory an installer added" 1 "$(grep -c '?? scripts/' <<<"$out")"
    check "B2 says what to do" 1 "$(grep -c 'Review with: git -C' <<<"$out")"
fi

CASE=B3; if want; then
    before=$(tree_state)
    check "B3 a change already there before the run is not reported" "" "$(report_tree "$before")"
    git -C "$REPO_DIR" checkout -q -- . && rm -rf "${REPO_DIR:?}/scripts"
fi

CASE=B4; if want; then
    pk() { MACHINE=$1 manifest_packages; }
    check "B4 the mini's stow list, across lines and past a comment" "claude git launchd-mini zsh " "$(pk mini)"
    check "B4 mini2 lists no packages: the default set" "" "$(pk mini2)"
    check "B4 the laptop lists no packages: the default set" "" "$(pk mac)"
    check "B4 an unknown machine lists none, nor another table's packages" "" "$(pk nosuch)"
fi

echo "bootstrap: $PASS passed, $FAIL failed${FAILED:+ —$FAILED}"
[ "$FAIL" -eq 0 ]
