#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITES=0
FAILED=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  [[ -f "$test_file" ]] || continue
  echo "=== Running: $(basename "$test_file") ==="
  SUITES=$((SUITES + 1))
  if bash "$test_file"; then
    echo "  -> Suite PASSED"
  else
    echo "  -> Suite FAILED"
    FAILED=$((FAILED + 1))
  fi
  echo ""
done

echo "=== All Suites: $SUITES run, $FAILED failed ==="
[[ "$FAILED" -eq 0 ]]
