#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/promotion-utils.sh"
source "$SCRIPT_DIR/root-manifest-utils.sh"

PASS=0
FAIL=0
TMPDIR_ROOT=""
cleanup() { [[ -n "$TMPDIR_ROOT" ]] && rm -rf "$TMPDIR_ROOT"; }
trap cleanup EXIT
TMPDIR_ROOT="$(mktemp -d)"

assert_eq() {
  local desc="$1" expected="$2"; shift 2
  local actual
  actual="$("$@" 2>/dev/null)" || { echo "  FAIL: $desc (command failed)"; FAIL=$((FAIL + 1)); return; }
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_json_eq() {
  local desc="$1" expected="$2"; shift 2
  local actual
  actual="$("$@" 2>/dev/null)" || { echo "  FAIL: $desc (command failed)"; FAIL=$((FAIL + 1)); return; }
  # Compare canonicalized JSON so key order / whitespace do not matter.
  local en an
  en="$(jq -S . <<< "$expected")"
  an="$(jq -S . <<< "$actual")"
  if [[ "$en" == "$an" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: $en"
    echo "    actual:   $an"
    FAIL=$((FAIL + 1))
  fi
}

assert_fails() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  FAIL: $desc (expected non-zero exit, got success)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

_FC=0
mkfile() {
  _FC=$((_FC + 1))
  local f="$TMPDIR_ROOT/file_${_FC}.json"
  printf '%s\n' "$1" > "$f"
  printf '%s' "$f"
}

BRANCHES="$(printf '%s\n' \
  refs/heads/main \
  refs/heads/release/26.8 \
  refs/heads/release/26.9 \
  refs/heads/release/27.0 \
  refs/heads/shaurye/feature-x \
  refs/heads/CI/update-catalog-123)"

echo "=== promotion-utils.sh tests ==="
echo ""

# ---------------------------------------------------------------------------
# next_release_branch
# ---------------------------------------------------------------------------
echo "--- next_release_branch ---"

assert_eq "26.8 -> 26.9"                 "release/26.9" next_release_branch "release/26.8" "$BRANCHES"
assert_eq "26.9 -> 27.0"                 "release/27.0" next_release_branch "release/26.9" "$BRANCHES"
assert_eq "highest release -> main"      "main"         next_release_branch "release/27.0" "$BRANCHES"
assert_eq "refs/heads/ prefix accepted"  "release/26.9" next_release_branch "refs/heads/release/26.8" "$BRANCHES"
assert_eq "major rollover picks minimal" "release/27.0" next_release_branch "release/26.9" \
  "$(printf '%s\n' refs/heads/release/27.5 refs/heads/release/27.0 refs/heads/release/28.0)"
assert_eq "unlisted current -> next existing" "release/26.8" next_release_branch "release/26.7" "$BRANCHES"

# Terminal / non-participating refs print nothing.
assert_eq "main terminates"              "" next_release_branch "main" "$BRANCHES"
assert_eq "feature branch ignored"       "" next_release_branch "shaurye/feature-x" "$BRANCHES"
assert_eq "CI branch ignored"            "" next_release_branch "CI/update-catalog-123" "$BRANCHES"

echo ""

# ---------------------------------------------------------------------------
# merge_catalog_json
# ---------------------------------------------------------------------------
echo "--- merge_catalog_json ---"

# Append a newer version -> latest advances.
c1="$(mkfile '{"latest":{"version":"1.0.0","tag":"app-v1.0.0"},"versions":[{"version":"1.0.0","tag":"app-v1.0.0"}]}')"
assert_json_eq "appends new version, advances latest" \
  '{"latest":{"version":"1.1.0","tag":"app-v1.1.0"},"versions":[{"version":"1.0.0","tag":"app-v1.0.0"},{"version":"1.1.0","tag":"app-v1.1.0"}]}' \
  merge_catalog_json "$c1" "1.1.0" "app-v1.1.0"

# Re-promote same pair -> idempotent, no duplicate.
c2="$(mkfile '{"latest":{"version":"1.1.0","tag":"app-v1.1.0"},"versions":[{"version":"1.0.0","tag":"app-v1.0.0"},{"version":"1.1.0","tag":"app-v1.1.0"}]}')"
assert_json_eq "idempotent re-promote (no dup)" \
  '{"latest":{"version":"1.1.0","tag":"app-v1.1.0"},"versions":[{"version":"1.0.0","tag":"app-v1.0.0"},{"version":"1.1.0","tag":"app-v1.1.0"}]}' \
  merge_catalog_json "$c2" "1.1.0" "app-v1.1.0"

# Promote an OLDER version forward into a branch that already has a newer one
# -> version is unioned in, but latest must NOT regress (monotonic).
c3="$(mkfile '{"latest":{"version":"2.0.0","tag":"app-v2.0.0"},"versions":[{"version":"2.0.0","tag":"app-v2.0.0"}]}')"
assert_json_eq "older version does not regress latest" \
  '{"latest":{"version":"2.0.0","tag":"app-v2.0.0"},"versions":[{"version":"2.0.0","tag":"app-v2.0.0"},{"version":"1.5.0","tag":"app-v1.5.0"}]}' \
  merge_catalog_json "$c3" "1.5.0" "app-v1.5.0"

# Patch-level ordering is numeric (10 > 9), not lexicographic.
c4="$(mkfile '{"latest":{"version":"1.0.9","tag":"app-v1.0.9"},"versions":[{"version":"1.0.9","tag":"app-v1.0.9"}]}')"
assert_json_eq "numeric patch ordering (1.0.10 > 1.0.9)" \
  '{"latest":{"version":"1.0.10","tag":"app-v1.0.10"},"versions":[{"version":"1.0.9","tag":"app-v1.0.9"},{"version":"1.0.10","tag":"app-v1.0.10"}]}' \
  merge_catalog_json "$c4" "1.0.10" "app-v1.0.10"

# A release outranks a pre-release of the same MMP.
c5="$(mkfile '{"latest":{"version":"1.2.0-rc.1","tag":"app-v1.2.0-rc.1"},"versions":[{"version":"1.2.0-rc.1","tag":"app-v1.2.0-rc.1"}]}')"
assert_json_eq "release outranks equal pre-release" \
  '{"latest":{"version":"1.2.0","tag":"app-v1.2.0"},"versions":[{"version":"1.2.0-rc.1","tag":"app-v1.2.0-rc.1"},{"version":"1.2.0","tag":"app-v1.2.0"}]}' \
  merge_catalog_json "$c5" "1.2.0" "app-v1.2.0"

# Missing versions array is tolerated (treated as empty).
c6="$(mkfile '{}')"
assert_json_eq "empty catalog seeds first entry" \
  '{"latest":{"version":"1.0.0","tag":"app-v1.0.0"},"versions":[{"version":"1.0.0","tag":"app-v1.0.0"}]}' \
  merge_catalog_json "$c6" "1.0.0" "app-v1.0.0"

echo ""

# ---------------------------------------------------------------------------
# merge_manifest_entry
# ---------------------------------------------------------------------------
echo "--- merge_manifest_entry ---"

# Different app id -> append (one entry per app coexists).
m1="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}]}')"
assert_json_eq "appends new app to category" \
  '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"},{"id":"b","zip":"b-v1.0.0.zip","version":"1.0.0"}]}' \
  merge_manifest_entry "$m1" '{"id":"b","zip":"b-v1.0.0.zip","version":"1.0.0"}' "shipping"

# Same app id, newer version -> replace the single pinned entry (no dup, zip advances).
m2="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}]}')"
assert_json_eq "replaces pinned entry with newer version" \
  '{"shipping":[{"id":"a","zip":"a-v1.1.0.zip","version":"1.1.0"}]}' \
  merge_manifest_entry "$m2" '{"id":"a","zip":"a-v1.1.0.zip","version":"1.1.0"}' "shipping"

# Same app id, same version -> idempotent replace (metadata may update, no dup).
m2b="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0","sha256":"old"}]}')"
assert_json_eq "idempotent upsert at equal version" \
  '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0","sha256":"new"}]}' \
  merge_manifest_entry "$m2b" '{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0","sha256":"new"}' "shipping"

# Same app id, OLDER version (back-port hop) -> target's newer pin is untouched.
m2c="$(mkfile '{"shipping":[{"id":"a","zip":"a-v2.0.0.zip","version":"2.0.0"}]}')"
assert_json_eq "older version does not regress pinned entry" \
  '{"shipping":[{"id":"a","zip":"a-v2.0.0.zip","version":"2.0.0"}]}' \
  merge_manifest_entry "$m2c" '{"id":"a","zip":"a-v1.5.0.zip","version":"1.5.0"}' "shipping"

# New category is created on the target when absent.
m3="$(mkfile '{"defaultLocale":"en","tax":[{"id":"t","zip":"t-v1.0.0.zip","version":"1.0.0"}]}')"
assert_json_eq "creates missing category" \
  '{"defaultLocale":"en","tax":[{"id":"t","zip":"t-v1.0.0.zip","version":"1.0.0"}],"analytics":[{"id":"n","zip":"n-v1.0.0.zip","version":"1.0.0"}]}' \
  merge_manifest_entry "$m3" '{"id":"n","zip":"n-v1.0.0.zip","version":"1.0.0"}' "analytics"

echo ""

# ---------------------------------------------------------------------------
# lookup_manifest_entry_for_zip (tolerant lookup used by catalog/promotion jobs)
# ---------------------------------------------------------------------------
echo "--- lookup_manifest_entry_for_zip ---"

# Present entry -> returned verbatim.
lk1="$(mkfile '{"analytics":[{"id":"a","zip":"a-v1.0.2.zip","version":"1.0.2"}]}')"
assert_json_eq "returns entry when present" \
  '{"id":"a","zip":"a-v1.0.2.zip","version":"1.0.2"}' \
  lookup_manifest_entry_for_zip "a-v1.0.2.zip" "$lk1"

# Back-ported ZIP with no matching entry (manifest pinned to newer version)
# -> empty stdout, exit 0 (the skip signal the workflow relies on).
lk2="$(mkfile '{"analytics":[{"id":"a","zip":"a-v1.0.2.zip","version":"1.0.2"}]}')"
assert_eq "missing entry -> empty (no error)" \
  "" \
  lookup_manifest_entry_for_zip "a-v1.0.0.zip" "$lk2"

# Ambiguous duplicate zip across entries -> hard error (still fails).
lk3="$(mkfile '{"analytics":[{"id":"a","zip":"dup.zip","version":"1.0.0"}],"tax":[{"id":"b","zip":"dup.zip","version":"2.0.0"}]}')"
assert_fails "duplicate zip -> error" \
  lookup_manifest_entry_for_zip "dup.zip" "$lk3"

# Regression lock for the actual bug: capturing an absent entry via $(...) under
# `set -euo pipefail` must NOT abort (empty stdout + exit 0), so the workflow's
# skip branch can fire. This mirrors the exact call-site pattern.
lk4="$(mkfile '{"analytics":[{"id":"a","zip":"a-v1.0.2.zip","version":"1.0.2"}]}')"
if (
  set -euo pipefail
  source "$SCRIPT_DIR/root-manifest-utils.sh"
  entry="$(lookup_manifest_entry_for_zip "a-v1.0.0.zip" "$lk4")"
  [[ -z "$entry" ]]
); then
  echo "  PASS: absent entry under set -e -> no abort, empty capture"
  PASS=$((PASS + 1))
else
  echo "  FAIL: absent entry under set -e -> unexpected abort or non-empty"
  FAIL=$((FAIL + 1))
fi

# Duplicate error annotation goes to stderr (survives $(...) stdout capture).
lk5="$(mkfile '{"analytics":[{"id":"a","zip":"dup.zip","version":"1.0.0"}],"tax":[{"id":"b","zip":"dup.zip","version":"2.0.0"}]}')"
dup_err="$(lookup_manifest_entry_for_zip "dup.zip" "$lk5" 2>&1 >/dev/null || true)"
if [[ "$dup_err" == *"Multiple manifest entries"* ]]; then
  echo "  PASS: duplicate error emitted on stderr"
  PASS=$((PASS + 1))
else
  echo "  FAIL: duplicate error not on stderr"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
