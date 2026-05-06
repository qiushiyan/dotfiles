#!/usr/bin/env bash
# Audit which sensitive paths exist on the OLD machine before migration.
# Read-only: prints sizes + names; never reads file contents.
# Writes secrets-manifest.txt (rsync --files-from format) to the cwd.
#
# Usage:
#   ./scripts/list-secrets.sh

set -euo pipefail

MANIFEST="secrets-manifest.txt"
: > "$MANIFEST"  # truncate

# Paths to copy verbatim. Manifest entries are paths relative to $HOME.
COPY_PATHS=(
    ".secrets"
    ".ssh"
    ".gnupg"
    ".aws"
    ".netrc"
    ".npmrc"
    ".kube/config"
    ".docker/config.json"
)

# Paths intentionally skipped (re-auth on new machine instead).
SKIP_PATHS=(
    ".config/gh:re-auth with \`gh auth login\`"
    ".config/gcloud:re-auth with \`gcloud auth login\`"
)

human_size() {
    local path="$1"
    if [[ -e "$HOME/$path" ]]; then
        du -sh "$HOME/$path" 2>/dev/null | awk '{print $1}'
    else
        echo "-"
    fi
}

printf "== Sensitive paths to transfer ==\n\n"

for path in "${COPY_PATHS[@]}"; do
    if [[ -e "$HOME/$path" ]]; then
        size="$(human_size "$path")"
        printf "[present]  ~/%-30s %6s\n" "$path" "$size"
        printf "%s\n" "$path" >> "$MANIFEST"
    else
        printf "[missing]  ~/%-30s (skipping)\n" "$path"
    fi
done

printf "\n== Re-auth (skip copy; re-authenticate on new machine) ==\n\n"

for entry in "${SKIP_PATHS[@]}"; do
    path="${entry%%:*}"
    note="${entry#*:}"
    if [[ -e "$HOME/$path" ]]; then
        printf "[skip]     ~/%-30s %s\n" "$path" "$note"
    else
        printf "[absent]   ~/%-30s (no current session)\n" "$path"
    fi
done

printf "\nWrote %s with %d entries.\n" "$MANIFEST" "$(wc -l < "$MANIFEST" | tr -d ' ')"
printf "\nTransfer (LAN, requires SSH access from old to new):\n"
printf "  rsync -av --files-from=%s ~ user@new-mbp:/Users/qiushi/\n" "$MANIFEST"
printf "\nOr via USB/AirDrop: tar the listed paths from \$HOME and copy.\n"
