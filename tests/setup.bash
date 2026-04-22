#!/usr/bin/env bash
# tests/setup.bash — shared sandboxing helpers for bats tests.
# load via:  load "$BATS_TEST_DIRNAME/setup.bash"
#
# Every test that touches the filesystem MUST call `harnish_sandbox_setup` in
# setup() and `harnish_sandbox_teardown` in teardown(). These swap HOME and
# the working directory to ephemeral temp directories so no test can reach
# the user's real ~/.claude/ or any project's real .harnish/.

set -euo pipefail

# Record the real HOME once, before any test swaps it.
: "${HARNISH_TEST_REAL_HOME:=$HOME}"
export HARNISH_TEST_REAL_HOME

# Resolve repo root from this file's own location — robust across bats /
# subshell / arbitrary cwd. setup.bash lives at <repo>/tests/setup.bash.
_harnish_setup_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_harnish_setup_dir/.." && pwd)"
unset _harnish_setup_dir
export REPO_ROOT
export CLAUDE_PLUGIN_ROOT="$REPO_ROOT"

harnish_sandbox_setup() {
  HARNISH_SANDBOX_HOME="$(mktemp -d -t harnish-test-home-XXXXXX)"
  HARNISH_SANDBOX_PROJECT="$(mktemp -d -t harnish-test-proj-XXXXXX)"
  export HOME="$HARNISH_SANDBOX_HOME"
  export CLAUDE_PROJECT_DIR="$HARNISH_SANDBOX_PROJECT"
  # Pin the asset base to the sandbox project so resolve_base_dir() in
  # scripts/common.sh writes there even if a test changes cwd.
  export ASSET_BASE_DIR="$HARNISH_SANDBOX_PROJECT/.harnish"
  mkdir -p "$HOME/.claude"
  harnish_preflight_guard
}

harnish_sandbox_teardown() {
  harnish_preflight_guard
  [[ -n "${HARNISH_SANDBOX_HOME:-}"    && -d "$HARNISH_SANDBOX_HOME"    ]] && rm -rf "$HARNISH_SANDBOX_HOME"
  [[ -n "${HARNISH_SANDBOX_PROJECT:-}" && -d "$HARNISH_SANDBOX_PROJECT" ]] && rm -rf "$HARNISH_SANDBOX_PROJECT"
  unset ASSET_BASE_DIR
}

# Abort if HOME is the user's real home or outside an OS temp root.
harnish_preflight_guard() {
  if [[ "$HOME" == "$HARNISH_TEST_REAL_HOME" ]]; then
    echo "FATAL: test attempted to use real HOME ($HOME)" >&2
    exit 99
  fi
  case "$HOME" in
    /tmp/*|/var/folders/*|/private/var/folders/*|/private/tmp/*) ;;
    *)
      echo "FATAL: HOME not in an OS temp root: $HOME" >&2
      exit 99
      ;;
  esac
}
