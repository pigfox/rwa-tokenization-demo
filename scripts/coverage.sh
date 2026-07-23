#!/usr/bin/env bash
# Enforce 100% coverage over src/. Fails if any line, statement, branch, or
# function in a src/ file is uncovered. Excludes test/ and script/ from the
# report (they are the harness, not the product).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SUMMARY="coverage-summary.txt"

forge coverage --no-match-coverage '(test|script)/' --report summary | tee "$SUMMARY"

# Any percentage that is not 100.00% on a src/ row fails the gate.
if grep -E '^\| src/' "$SUMMARY" | grep -vqE '100\.00%.*100\.00%.*100\.00%.*100\.00%'; then
	echo "COVERAGE GATE FAILED: a src/ file is below 100%." >&2
	exit 1
fi

echo "COVERAGE GATE PASSED: src/ is 100% across lines, statements, branches, functions."
