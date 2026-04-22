#!/usr/bin/env bash
# tests/run.sh — run the harnish test suite (bats).
#
# Tier 1: bats — fast manifest + script smoke tests (always run, gates CI).
# Tier 2: scripts/test-all.sh — deeper end-to-end suite, opt-in via
#         HARNISH_RUN_DEEP_TESTS=1 (slow, requires jq).
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

fail() { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }
pass() { echo -e "${GREEN}✓ $1${NC}"; }
note() { echo -e "${YELLOW}· $1${NC}"; }

echo "==> bats (manifest + scripts)"
if ! command -v bats >/dev/null 2>&1; then
  fail "bats not installed — brew install bats-core (macOS) / apt install bats (linux)"
fi
bats tests/
pass "bats"

if [[ "${HARNISH_RUN_DEEP_TESTS:-0}" == "1" ]]; then
  echo ""
  echo "==> scripts/test-all.sh (deep suite)"
  bash scripts/test-all.sh
  pass "deep suite"
else
  echo ""
  note "deep suite skipped (set HARNISH_RUN_DEEP_TESTS=1 to enable)"
fi

echo ""
pass "all tests passed"
