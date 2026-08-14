#!/usr/bin/env bash
# Shim. The index itself is baton_index.py — Python because the work is parsing
# and grouping, and its styling comes from rich rather than hand-rolled escapes.
# uv resolves the dependency from the script's own PEP 723 header, so there is
# nothing to install.
#
# The name stays `.sh`: two skills grant this exact path in their allowed-tools,
# and `bash baton-index.sh` is what their prose tells the model to run.
set -euo pipefail
exec uv run --quiet "$(dirname "${BASH_SOURCE[0]}")/baton_index.py" "$@"
