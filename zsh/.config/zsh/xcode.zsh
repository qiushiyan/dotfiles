# Walk up from $PWD looking for .xcode-tools.zsh.
# Stops at the git root (or filesystem root if no git).
# Echoes the found path on success; returns 1 if not found.
#
# Callers `source` the returned file in their own scope so config
# assignments (SCHEME=..., DESTINATION=...) become locals of the
# calling function (which pre-declares them with `local`). No env
# pollution of the parent shell.
_xcode_tools_find_config() {
  emulate -L zsh
  local dir="${PWD}"
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null)

  while true; do
    if [[ -f "${dir}/.xcode-tools.zsh" ]]; then
      echo "${dir}/.xcode-tools.zsh"
      return 0
    fi
    if [[ "${dir}" == "${git_root}" ]] || [[ "${dir}" == "/" ]] || [[ -z "${dir}" ]]; then
      return 1
    fi
    dir="${dir:h}"
  done
}

xbuild() {
  emulate -L zsh

  # Project-local config (sourced into this function's scope).
  local SCHEME DESTINATION
  local config_path
  config_path=$(_xcode_tools_find_config) && source "${config_path}"

  # Precedence: -s flag > XCODE_SCHEME env > SCHEME from config.
  local scheme="${XCODE_SCHEME:-${SCHEME:-}}"
  if [[ "$1" == "-s" ]]; then
    scheme="$2"
    shift 2
  fi
  if [[ -z "${scheme}" ]]; then
    echo "error: set XCODE_SCHEME, .xcode-tools.zsh SCHEME=, or pass -s <scheme>" >&2
    return 1
  fi

  # Precedence: XCODE_DESTINATION env > DESTINATION from config > macOS default.
  local destination="${XCODE_DESTINATION:-${DESTINATION:-platform=macOS,arch=arm64}}"

  local run_id="${$}_${RANDOM}"
  local derived="/tmp/xcode_derived_${run_id}"
  local log_path="/tmp/xbuild_output_${run_id}.log"
  local cmd_status=0
  local diagnostics=""
  local -a args=(
    -scheme "${scheme}"
    -configuration Debug
    build
    -destination "${destination}"
    -derivedDataPath "${derived}"
  )

  {
    xcodebuild "${args[@]}" > "${log_path}" 2>&1
    cmd_status=$?

    diagnostics=$(grep -E "^/.*(error|warning):" "${log_path}" | head -30 || true)

    if (( cmd_status == 0 )); then
      if grep -q "BUILD SUCCEEDED" "${log_path}"; then
        echo "✅ Build succeeded"
      else
        echo "✅ Build completed"
      fi
      if [[ -n "${diagnostics}" ]]; then
        echo ""
        echo "${diagnostics}"
      fi
      return 0
    fi

    echo "❌ Build failed:"
    echo ""
    if [[ -n "${diagnostics}" ]]; then
      echo "${diagnostics}"
    else
      grep -E "error:|fatal error:|Command .* failed with exit code" "${log_path}" | head -30 || true
    fi
    return "${cmd_status}"
  } always {
    rm -rf "${derived}" "${log_path}"
  }
}

xtest() {
  emulate -L zsh
  setopt pipe_fail

  local SCHEME DESTINATION
  local config_path
  config_path=$(_xcode_tools_find_config) && source "${config_path}"

  local scheme="${XCODE_SCHEME:-${SCHEME:-}}"
  if [[ "$1" == "-s" ]]; then
    scheme="$2"
    shift 2
  fi
  if [[ -z "${scheme}" ]]; then
    echo "error: set XCODE_SCHEME, .xcode-tools.zsh SCHEME=, or pass -s <scheme>" >&2
    return 1
  fi

  local destination="${XCODE_DESTINATION:-${DESTINATION:-platform=macOS,arch=arm64}}"

  local run_id="${$}_${RANDOM}"
  local derived="/tmp/xcode_derived_${run_id}"
  local result_bundle="/tmp/testresults_${run_id}.xcresult"
  local log_path="/tmp/xtest_output_${run_id}.log"
  local build_status=0
  local parser_status=0
  local -a args=(
    -scheme "${scheme}"
    -configuration Debug
    test
    -destination "${destination}"
    -derivedDataPath "${derived}"
  )

  if [[ -n "$1" ]]; then
    args+=("-only-testing:$1")
  fi
  args+=(-resultBundlePath "${result_bundle}")

  {
    rm -rf "${result_bundle}"

    echo "Running tests..."
    xcodebuild "${args[@]}" > "${log_path}" 2>&1
    build_status=$?

    if [[ ! -e "${result_bundle}" ]]; then
      echo "❌ Build failed or result bundle not created:"
      grep -E "error:" "${log_path}" | grep -v "appintentsmetadataprocessor" | head -20 || true
      return "${build_status:-1}"
    fi

    export XTEST_LOG_PATH="${log_path}"
    export XTEST_BUILD_STATUS="${build_status}"
    xcrun xcresulttool get test-results summary --path "${result_bundle}" \
      | python3 -c '
import json
import os
import sys

def print_build_errors(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            errors = [
                line.strip() for line in f
                if "error:" in line and "appintentsmetadataprocessor" not in line
            ]
    except OSError:
        errors = []

    print("\n".join(errors[:20]) if errors else "No compiler errors captured. Run xbuild for details.")

d = json.load(sys.stdin)
passed = int(d.get("passedTests", 0) or 0)
failed = int(d.get("failedTests", 0) or 0)
skipped = int(d.get("skippedTests", 0) or 0)
total = passed + failed + skipped
failures = d.get("testFailures", []) or []
build_status = int(os.environ.get("XTEST_BUILD_STATUS", "0"))
log_path = os.environ["XTEST_LOG_PATH"]

if total == 0:
    print("❌ Build failed (0 tests ran):")
    print()
    print_build_errors(log_path)
    sys.exit(build_status if build_status != 0 else 1)

if failures:
    print(f"❌ {len(failures)} failure(s):")
    print()
    for failure in failures:
        identifier = failure.get("testIdentifierString", "<unknown test>")
        text = failure.get("failureText", "<no failure text>")
        print(f"{identifier} → {text}")
    sys.exit(1)

if build_status != 0:
    print("❌ Test run completed with build errors:")
    print()
    print_build_errors(log_path)
    sys.exit(build_status)

print(f"✅ All {passed} tests passed")
'
    parser_status=$?
    unset XTEST_LOG_PATH XTEST_BUILD_STATUS
    if (( parser_status != 0 )); then
      return "${parser_status}"
    fi

    return 0
  } always {
    rm -rf "${derived}" "${result_bundle}" "${log_path}"
  }
}


xtests-list() {
  emulate -L zsh

  local SCHEME DESTINATION
  local config_path
  config_path=$(_xcode_tools_find_config) && source "${config_path}"

  local scheme="${XCODE_SCHEME:-${SCHEME:-}}"
  if [[ "$1" == "-s" ]]; then
    scheme="$2"
    shift 2
  fi
  if [[ -z "${scheme}" ]]; then
    echo "error: set XCODE_SCHEME, .xcode-tools.zsh SCHEME=, or pass -s <scheme>" >&2
    return 1
  fi

  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  local test_dir="${root}/${scheme}Tests"

  if [[ ! -d "${test_dir}" ]]; then
    test_dir="${root}/${scheme}/${scheme}Tests"
  fi

  if [[ ! -d "${test_dir}" ]]; then
    echo "${scheme}Tests directory not found under ${root}" >&2
    return 1
  fi

  find "${test_dir}" -name "*.swift" -print0 \
    | while IFS= read -r -d '' file; do
        # match XCTest (`func test*`) or Swift Testing (`@Test`, `@Suite`)
        if grep -qE "func test|@Test|@Suite" "${file}"; then
          basename "${file}" .swift
        fi
      done \
    | sort
}
