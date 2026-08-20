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

mkfile() {
  # mktemp (not a shared counter) so each call yields a distinct path even
  # though mkfile always runs in a subshell via $(mkfile ...) - a counter
  # variable's increment can't survive back to the parent shell, so every
  # call would otherwise collide on the same path (silently breaking any
  # test that needs two live files at once, e.g. a target + a source).
  local f
  f="$(mktemp "$TMPDIR_ROOT/file.XXXXXX")"
  printf '%s\n' "$1" > "$f"
  printf '%s' "$f"
}

mkextractdir() {
  mktemp -d "$TMPDIR_ROOT/extract_XXXXXX"
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
# find_cap_icons_dir
# ---------------------------------------------------------------------------
echo "--- find_cap_icons_dir ---"

# CAP root icons/ is found (the normal case: <root>/<cap>/icons/).
e1="$(mkextractdir)"
mkdir -p "$e1/commerce-avalara-tax-app-v1.1.3/icons"
touch "$e1/commerce-avalara-tax-app-v1.1.3/icons/avalara.png"
assert_eq "finds CAP-root icons dir" \
  "$e1/commerce-avalara-tax-app-v1.1.3/icons" \
  find_cap_icons_dir "$e1"

# A nested icons/ dir inside a cartridge (e.g. BM static theme assets) must be
# ignored; only the CAP-root one is returned. This is the exact shape of the
# bug from PR #87: a nested icons/ dir was picked up instead of the CAP root.
e2="$(mkextractdir)"
mkdir -p "$e2/commerce-avalara-tax-app-v1.1.3/icons"
touch "$e2/commerce-avalara-tax-app-v1.1.3/icons/avalara.png"
mkdir -p "$e2/commerce-avalara-tax-app-v1.1.3/cartridges/int_avatax/cartridge/static/default/icons"
touch "$e2/commerce-avalara-tax-app-v1.1.3/cartridges/int_avatax/cartridge/static/default/icons/circle-info-solid-min.png"
assert_eq "ignores nested cartridge-static icons dir" \
  "$e2/commerce-avalara-tax-app-v1.1.3/icons" \
  find_cap_icons_dir "$e2"

# No CAP-root icons/ dir at all -> prints nothing, even if a nested one exists.
e3="$(mkextractdir)"
mkdir -p "$e3/commerce-noicon-app-v1.0.0/cartridges/int_noicon/cartridge/static/default/icons"
touch "$e3/commerce-noicon-app-v1.0.0/cartridges/int_noicon/cartridge/static/default/icons/theme.png"
assert_eq "no CAP-root icons dir -> empty" \
  "" \
  find_cap_icons_dir "$e3"

echo ""

# ---------------------------------------------------------------------------
# next_release_branch
# ---------------------------------------------------------------------------
echo "--- next_release_branch ---"

assert_eq "26.8 -> 26.9"                 "release/26.9" next_release_branch "release/26.8" "$BRANCHES"
assert_eq "26.9 -> 27.0"                 "release/27.0" next_release_branch "release/26.9" "$BRANCHES"
assert_eq "highest release terminates"   ""             next_release_branch "release/27.0" "$BRANCHES"
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
# seed_init_catalog_if_absent (auto-promo: INIT only for brand-new apps)
# ---------------------------------------------------------------------------
echo "--- seed_init_catalog_if_absent ---"

# Brand-new app: no catalog.json on the target -> write INIT, do not invent a version.
new_cat="$TMPDIR_ROOT/new-app/catalog.json"
seeded_result="$(seed_init_catalog_if_absent "$new_cat")"
assert_eq "absent catalog is seeded" "seeded" printf '%s' "$seeded_result"
assert_json_eq "seeded catalog is INIT template" \
  '{"latest":{"version":"INIT","tag":"INIT"},"versions":[]}' \
  cat "$new_cat"

# Version bump: catalog.json already exists -> leave it untouched (no merge, no INIT overwrite).
existing_cat="$(mkfile '{"latest":{"version":"1.0.0","tag":"app-v1.0.0"},"versions":[{"version":"1.0.0","tag":"app-v1.0.0"}]}')"
skipped_result="$(seed_init_catalog_if_absent "$existing_cat")"
assert_eq "existing catalog is skipped" "skipped" printf '%s' "$skipped_result"
assert_json_eq "existing catalog content is untouched" \
  '{"latest":{"version":"1.0.0","tag":"app-v1.0.0"},"versions":[{"version":"1.0.0","tag":"app-v1.0.0"}]}' \
  cat "$existing_cat"

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

# Same app id, newer version -> overlay onto the single pinned entry (no dup, zip advances).
m2="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}]}')"
assert_json_eq "replaces pinned entry with newer version" \
  '{"shipping":[{"id":"a","zip":"a-v1.1.0.zip","version":"1.1.0"}]}' \
  merge_manifest_entry "$m2" '{"id":"a","zip":"a-v1.1.0.zip","version":"1.1.0"}' "shipping"

# Same app id, same version -> idempotent replace (metadata may update, no dup).
m2b="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0","sha256":"old"}]}')"
assert_json_eq "idempotent upsert at equal version" \
  '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0","sha256":"new"}]}' \
  merge_manifest_entry "$m2b" '{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0","sha256":"new"}' "shipping"

# Same app id, same version, target has extra keys the source lacks (e.g. 26.9
# carousel fields, 26.8 entry without them) -> extras are preserved, not wiped.
m2d="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0","sha256":"old","isFeatured":true,"badge":"popular"}]}')"
assert_json_eq "equal-version overlay preserves target-only keys" \
  '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0","sha256":"new","isFeatured":true,"badge":"popular"}]}' \
  merge_manifest_entry "$m2d" '{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0","sha256":"new"}' "shipping"

# Same app id, NEWER version, target has extra keys -> version/zip advance and
# extras are still preserved. Also stays in its original array position.
m2e="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0","isFeatured":true},{"id":"b","zip":"b-v1.0.0.zip","version":"1.0.0"}]}')"
assert_json_eq "newer-version overlay preserves target-only keys and position" \
  '{"shipping":[{"id":"a","zip":"a-v1.1.0.zip","version":"1.1.0","isFeatured":true},{"id":"b","zip":"b-v1.0.0.zip","version":"1.0.0"}]}' \
  merge_manifest_entry "$m2e" '{"id":"a","zip":"a-v1.1.0.zip","version":"1.1.0"}' "shipping"

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

# The committed manifest.json is 4-space indented; the upsert MUST preserve that
# so a promotion produces a minimal diff instead of reformatting the whole file.
# assert_json_eq above canonicalizes whitespace and cannot catch this, so assert
# the raw indentation of a nested key directly.
m4="$(mkfile '{"analytics":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}]}')"
m4_indent="$(merge_manifest_entry "$m4" '{"id":"b","zip":"b-v1.0.0.zip","version":"1.0.0"}' "analytics" \
  | grep -m1 '"analytics"' | sed -E 's/[^ ].*//' | tr -d '\n' | wc -c | tr -d ' ')"
assert_eq "upsert emits 4-space indentation" "4" printf '%s' "$m4_indent"

# Byte-identical re-upsert must be a true no-op: it must NOT rewrite or move
# the entry (which would reorder every other entry for zero effect on a
# fully-idempotent re-promotion).
m5="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"},{"id":"b","zip":"b-v1.0.0.zip","version":"1.0.0"}]}')"
assert_json_eq "byte-identical re-upsert does not reorder" \
  '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"},{"id":"b","zip":"b-v1.0.0.zip","version":"1.0.0"}]}' \
  merge_manifest_entry "$m5" '{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}' "shipping"
m5_order="$(merge_manifest_entry "$m5" '{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}' "shipping" | jq -r '.shipping[0].id')"
assert_eq "byte-identical re-upsert keeps original position" "a" printf '%s' "$m5_order"

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

# ---------------------------------------------------------------------------
# merge_manifest_file (whole-manifest merge for manual manifest.json edits
# promoted with no ZIP)
# ---------------------------------------------------------------------------
echo "--- merge_manifest_file ---"

# Source has a newer entry for an app the target already pins -> overlays it,
# same monotonic guard as merge_manifest_entry, applied across every category.
mf1_target="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}]}')"
mf1_source="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.1.0.zip","version":"1.1.0"}]}')"
assert_json_eq "newer entry from source replaces target's pin" \
  '{"shipping":[{"id":"a","zip":"a-v1.1.0.zip","version":"1.1.0"}]}' \
  merge_manifest_file "$mf1_target" "$mf1_source"

# Source has an OLDER entry than target already pins -> target wins (monotonic).
mf2_target="$(mkfile '{"shipping":[{"id":"a","zip":"a-v2.0.0.zip","version":"2.0.0"}]}')"
mf2_source="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}]}')"
assert_json_eq "older source entry does not regress target's pin" \
  '{"shipping":[{"id":"a","zip":"a-v2.0.0.zip","version":"2.0.0"}]}' \
  merge_manifest_file "$mf2_target" "$mf2_source"

# Source introduces a brand-new app in an existing category -> appended.
mf3_target="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}]}')"
mf3_source="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}],"tax":[{"id":"t","zip":"t-v1.0.0.zip","version":"1.0.0"}]}')"
assert_json_eq "new category/app from source is added" \
  '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}],"tax":[{"id":"t","zip":"t-v1.0.0.zip","version":"1.0.0"}]}' \
  merge_manifest_file "$mf3_target" "$mf3_source"

# Re-merging the same source into an already-merged target is idempotent.
mf4_target="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.1.0.zip","version":"1.1.0"}]}')"
mf4_source="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.1.0.zip","version":"1.1.0"}]}')"
assert_json_eq "idempotent re-merge (no dup)" \
  '{"shipping":[{"id":"a","zip":"a-v1.1.0.zip","version":"1.1.0"}]}' \
  merge_manifest_file "$mf4_target" "$mf4_source"

# Whole-file promote of an equal-version source that lacks target-only keys
# must not wipe them (the #113 26.8→26.9 carousel-field regression).
mf4b_target="$(mkfile '{"tax":[{"id":"avalara-tax","zip":"avalara-tax-v1.0.0.zip","version":"1.0.0","isFeatured":true,"badge":"popular","featuredLearnMoreUrl":"https://example.com"}]}')"
mf4b_source="$(mkfile '{"tax":[{"id":"avalara-tax","zip":"avalara-tax-v1.0.0.zip","version":"1.0.0"}]}')"
assert_json_eq "whole-file equal-version merge preserves target-only keys" \
  '{"tax":[{"id":"avalara-tax","zip":"avalara-tax-v1.0.0.zip","version":"1.0.0","isFeatured":true,"badge":"popular","featuredLearnMoreUrl":"https://example.com"}]}' \
  merge_manifest_file "$mf4b_target" "$mf4b_source"

# A scalar top-level field (e.g. defaultLocale) has no per-entry version to
# compare, so it must still carry forward verbatim rather than being silently
# dropped by a merge that only knows how to walk category arrays.
mf5_target="$(mkfile '{"defaultLocale":"en","shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}]}')"
mf5_source="$(mkfile '{"defaultLocale":"fr","shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}]}')"
assert_json_eq "scalar field carries forward from source" \
  '{"defaultLocale":"fr","shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}]}' \
  merge_manifest_file "$mf5_target" "$mf5_source"

# A single malformed entry (e.g. missing/non-semver version) must not abort the
# whole merge under `set -e` - every other, well-formed entry in the same
# source manifest still merges normally.
mf6_target="$(mkfile '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}],"tax":[{"id":"t","zip":"t-v1.0.0.zip","version":"1.0.0"}]}')"
mf6_source="$(mkfile '{"shipping":[{"id":"a","zip":"a-vBAD.zip","version":"not-a-semver"}],"tax":[{"id":"t","zip":"t-v1.1.0.zip","version":"1.1.0"}]}')"
assert_json_eq "malformed entry is skipped, other entries still merge" \
  '{"shipping":[{"id":"a","zip":"a-v1.0.0.zip","version":"1.0.0"}],"tax":[{"id":"t","zip":"t-v1.1.0.zip","version":"1.1.0"}]}' \
  merge_manifest_file "$mf6_target" "$mf6_source"

echo ""

# ---------------------------------------------------------------------------
# merge_translations_file (additive per-key merge for locale files)
# ---------------------------------------------------------------------------
echo "--- merge_translations_file ---"

# New app id in source, absent on target -> added.
tr1_target="$(mkfile '{"app-a":{"name":"App A","description":"desc a"}}')"
tr1_source="$(mkfile '{"app-b":{"name":"App B","description":"desc b"}}')"
assert_json_eq "adds new app id from source" \
  '{"app-a":{"name":"App A","description":"desc a"},"app-b":{"name":"App B","description":"desc b"}}' \
  merge_translations_file "$tr1_target" "$tr1_source"

# App id present on both, with different content -> target's key wins
# (additive-only: never overwrite an existing target key).
tr2_target="$(mkfile '{"app-a":{"name":"Target Name","description":"target desc"}}')"
tr2_source="$(mkfile '{"app-a":{"name":"Source Name","description":"source desc"}}')"
assert_json_eq "existing target key is never overwritten" \
  '{"app-a":{"name":"Target Name","description":"target desc"}}' \
  merge_translations_file "$tr2_target" "$tr2_source"

# Re-merging the same source is idempotent (no change on second pass).
tr3_target="$(mkfile '{"app-a":{"name":"App A","description":"desc a"}}')"
tr3_source="$(mkfile '{"app-b":{"name":"App B","description":"desc b"}}')"
merge_translations_file "$tr3_target" "$tr3_source" > "$tr3_target.tmp1"
assert_json_eq "idempotent re-merge (no dup/no change)" \
  '{"app-a":{"name":"App A","description":"desc a"},"app-b":{"name":"App B","description":"desc b"}}' \
  merge_translations_file "$tr3_target.tmp1" "$tr3_source"

echo ""

# ---------------------------------------------------------------------------
# apply_non_cap_patch (plain-content promotion for docs/skills/.github/etc.)
# ---------------------------------------------------------------------------
echo "--- apply_non_cap_patch ---"

# Empty patch (no non-CAP files changed) -> no-op, exit 0.
empty_patch="$(mkfile '')"
: > "$empty_patch"
assert_eq "empty patch is a no-op" "no-op" apply_non_cap_patch "$empty_patch"

# A patch that applies cleanly onto the current working tree -> "applied",
# and the file content changes and is staged.
np_dir="$(mktemp -d -p "$TMPDIR_ROOT")"
(
  cd "$np_dir"
  git init -q
  git config user.email test@example.com
  git config user.name test
  mkdir -p docs
  printf 'line1\n' > docs/readme.md
  git add -A && git commit -qm init
  before="$(git rev-parse HEAD)"
  printf 'line1\nline2\n' > docs/readme.md
  git add -A && git commit -qm change
  after="$(git rev-parse HEAD)"
  git diff "$before" "$after" -- docs/readme.md > "$TMPDIR_ROOT/apply.patch"
  git checkout -q "$before" -- docs/readme.md
)
result="$(cd "$np_dir" && apply_non_cap_patch "$TMPDIR_ROOT/apply.patch")"
assert_eq "clean patch applies" "applied" printf '%s' "$result"
applied_content="$(cat "$np_dir/docs/readme.md")"
assert_eq "applied patch content matches" "$(printf 'line1\nline2')" printf '%s' "$applied_content"

# Re-applying the SAME patch onto a tree that already has the change
# (reverse-check succeeds) -> idempotent no-op, not an error and not a
# duplicate/conflicting apply.
result2="$(cd "$np_dir" && apply_non_cap_patch "$TMPDIR_ROOT/apply.patch")"
assert_eq "already-applied patch is idempotent no-op" "no-op" printf '%s' "$result2"

# A patch that conflicts with intentional target-only divergence -> skipped,
# never forced, and does not abort the caller (still exit 0).
conflict_dir="$(mktemp -d -p "$TMPDIR_ROOT")"
(
  cd "$conflict_dir"
  git init -q
  git config user.email test@example.com
  git config user.name test
  mkdir -p docs
  printf 'shared-base\n' > docs/readme.md
  git add -A && git commit -qm init
  # Target-only divergence: a change the patch does not know about, on the
  # exact same line the (unrelated) source-side patch also touches.
  printf 'target-only-change\n' > docs/readme.md
  git add -A && git commit -qm "target diverges"
)
conflict_result="$(cd "$conflict_dir" && apply_non_cap_patch "$TMPDIR_ROOT/apply.patch")"
assert_eq "conflicting patch is skipped, not forced" "skipped" printf '%s' "$conflict_result"
conflict_content="$(cat "$conflict_dir/docs/readme.md")"
assert_eq "target-only divergence is preserved on skip" "target-only-change" printf '%s' "$conflict_content"

# A patch that ADDS a brand-new file (source created it, target never had it)
# must apply and stage the new file, not just modify existing content.
add_dir="$(mktemp -d -p "$TMPDIR_ROOT")"
(
  cd "$add_dir"
  git init -q
  git config user.email test@example.com
  git config user.name test
  printf 'seed\n' > seed.txt
  git add -A && git commit -qm init
  before="$(git rev-parse HEAD)"
  mkdir -p docs
  printf 'new file\n' > docs/new.md
  git add -A && git commit -qm add
  after="$(git rev-parse HEAD)"
  git diff --binary "$before" "$after" -- docs/new.md > "$TMPDIR_ROOT/add.patch"
  git reset --hard -q "$before"
)
add_result="$(cd "$add_dir" && apply_non_cap_patch "$TMPDIR_ROOT/add.patch")"
assert_eq "patch adding a new file applies" "applied" printf '%s' "$add_result"
assert_eq "new file content matches" "new file" printf '%s' "$(cat "$add_dir/docs/new.md")"

# A patch that DELETES a file (present on target, removed on source) must
# apply and stage the deletion, not error.
del_dir="$(mktemp -d -p "$TMPDIR_ROOT")"
(
  cd "$del_dir"
  git init -q
  git config user.email test@example.com
  git config user.name test
  mkdir -p docs
  printf 'to be removed\n' > docs/gone.md
  git add -A && git commit -qm init
  before="$(git rev-parse HEAD)"
  git rm -q docs/gone.md
  git commit -qm remove
  after="$(git rev-parse HEAD)"
  git diff --binary "$before" "$after" -- docs/gone.md > "$TMPDIR_ROOT/del.patch"
  git checkout -q "$before" -- docs/gone.md
)
del_result="$(cd "$del_dir" && apply_non_cap_patch "$TMPDIR_ROOT/del.patch")"
assert_eq "patch deleting a file applies" "applied" printf '%s' "$del_result"
if [[ ! -f "$del_dir/docs/gone.md" ]]; then
  echo "  PASS: deleted file removed from working tree"
  PASS=$((PASS + 1))
else
  echo "  FAIL: deleted file removed from working tree"
  FAIL=$((FAIL + 1))
fi

echo ""

# ---------------------------------------------------------------------------
# NON_CAP_PATHSPEC
# ---------------------------------------------------------------------------
echo "--- NON_CAP_PATHSPEC ---"

pathspec_dir="$(mktemp -d -p "$TMPDIR_ROOT")"
(
  cd "$pathspec_dir"
  git init -q
  git config user.email test@example.com
  git config user.name test
  mkdir -p .github/workflows docs commerce-apps-manifest/translations
  printf 'a\n' > .github/workflows/ci.yml
  printf 'b\n' > docs/readme.md
  printf '{}\n' > commerce-apps-manifest/manifest.json
  printf '{}\n' > commerce-apps-manifest/translations/en.json
  git add -A && git commit -qm init
)
non_cap_out="$(cd "$pathspec_dir" && git ls-files -- "${NON_CAP_PATHSPEC[@]}")"
if grep -qx '.github/workflows/ci.yml' <<< "$non_cap_out"; then
  echo "  FAIL: .github/workflows/** excluded from NON_CAP_PATHSPEC"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: .github/workflows/** excluded from NON_CAP_PATHSPEC"
  PASS=$((PASS + 1))
fi
if grep -qx 'docs/readme.md' <<< "$non_cap_out"; then
  echo "  PASS: plain docs file included in NON_CAP_PATHSPEC"
  PASS=$((PASS + 1))
else
  echo "  FAIL: plain docs file included in NON_CAP_PATHSPEC"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
