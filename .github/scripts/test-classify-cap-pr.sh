#!/usr/bin/env bash
# test-classify-cap-pr.sh
#
# Fixture-based tests for classify-cap-pr.sh. Same shape as
# test-security-scan.sh / test-validate-*.sh: each case builds a throwaway
# git repo containing a `base` and `head` commit, then invokes the classifier
# with BASE_SHA/HEAD_SHA/PR_AUTHOR_LOGIN/PR_AUTHOR_EMAIL set from that repo.
#
# The classifier reads MANIFEST_PATH (defaulting to
# commerce-apps-manifest/manifest.json) relative to the current working
# directory, so tests cd into their fixture repo before invoking.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLASSIFY="$SCRIPT_DIR/classify-cap-pr.sh"

PASS=0
FAIL=0
TMPDIR_ROOT=""
cleanup() { [[ -n "$TMPDIR_ROOT" ]] && rm -rf "$TMPDIR_ROOT"; }
trap cleanup EXIT
TMPDIR_ROOT="$(mktemp -d)"

# Build an isolated git repo for one test case. Writes two commits so
# BASE_SHA and HEAD_SHA are meaningful. Echoes the repo path on stdout;
# the caller populates it via the on_base / on_head hooks.
mkrepo() {
  local d
  d="$(mktemp -d "$TMPDIR_ROOT/repo_XXXXXX")"
  git -C "$d" init -q -b main
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "test"
  printf '%s' "$d"
}

commit_all() {
  local repo="$1" msg="$2"
  git -C "$repo" add -A
  git -C "$repo" commit -q --allow-empty -m "$msg"
}

run_classify() {
  # Args: repo, author_login, author_email; sets JSON output var.
  local repo="$1" login="$2" email="$3"
  local base_sha head_sha
  base_sha="$(git -C "$repo" rev-parse HEAD~1)"
  head_sha="$(git -C "$repo" rev-parse HEAD)"
  (
    cd "$repo" || exit 1
    BASE_SHA="$base_sha" HEAD_SHA="$head_sha" \
      PR_AUTHOR_LOGIN="$login" PR_AUTHOR_EMAIL="$email" \
      bash "$CLASSIFY"
  )
}

assert_field() {
  local json="$1" jq_path="$2" want="$3" desc="$4"
  local got
  got="$(jq -r "$jq_path" <<< "$json")"
  if [[ "$got" == "$want" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc  (want '$want', got '$got')"
    echo "    json: $json"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== classify-cap-pr.sh tests ==="
echo ""

# ---------------------------------------------------------------------------
# Case 1: Net-new external app.
# ---------------------------------------------------------------------------
# External contributor adds a brand-new {domain}/{isv-name}/ dir with a ZIP
# and a matching manifest entry. Gate must fire (will_file_gus_wi=true).
echo "--- Case 1: net-new external app ---"
repo="$(mkrepo)"

mkdir -p "$repo/commerce-apps-manifest"
cat > "$repo/commerce-apps-manifest/manifest.json" <<'EOF'
{
  "tax": []
}
EOF
commit_all "$repo" "base"

mkdir -p "$repo/tax/acme"
printf 'PK\x03\x04fake-zip' > "$repo/tax/acme/acme-tax-v1.0.0.zip"
cat > "$repo/commerce-apps-manifest/manifest.json" <<'EOF'
{
  "tax": [
    {
      "id": "acme-tax",
      "name": "Acme Tax",
      "description": "Automate your Acme tax.",
      "iconName": "acme.png",
      "domain": "tax",
      "type": "app",
      "provider": "thirdParty",
      "version": "1.0.0",
      "zip": "acme-tax-v1.0.0.zip",
      "sha256": "abc"
    }
  ]
}
EOF
commit_all "$repo" "head"

json="$(run_classify "$repo" "external-user" "user@example.com")"
assert_field "$json" '.added_zip'          "tax/acme/acme-tax-v1.0.0.zip" "added_zip is the new ZIP"
assert_field "$json" '.isv_dir'            "tax/acme"                     "isv_dir resolves"
assert_field "$json" '.domain'             "tax"                          "domain is tax"
assert_field "$json" '.isv'                "acme"                         "isv is acme"
assert_field "$json" '.manifest.name'      "Acme Tax"                     "manifest.name reads from manifest"
assert_field "$json" '.manifest.version'   "1.0.0"                        "manifest.version reads from manifest"
assert_field "$json" '.manifest.provider'  "thirdParty"                   "manifest.provider reads from manifest"
assert_field "$json" '.author.login'       "external-user"                "author.login"
assert_field "$json" '.author.email'       "user@example.com"             "author.email"
assert_field "$json" '.author.is_internal' "false"                        "external email is_internal=false"
assert_field "$json" '.is_new_app'         "true"                         "net-new dir is_new_app=true"
assert_field "$json" '.will_file_gus_wi'   "true"                         "external + new-app => will_file_gus_wi=true"
echo ""

# ---------------------------------------------------------------------------
# Case 2: Version bump by external author.
# ---------------------------------------------------------------------------
# {domain}/{isv-name}/ already exists on base; the head adds a new ZIP file
# under the same directory. is_new_app=false, so no GUS WI even though the
# submitter is external.
echo "--- Case 2: version bump by external ---"
repo="$(mkrepo)"

mkdir -p "$repo/tax/acme" "$repo/commerce-apps-manifest"
printf 'PK\x03\x04v100' > "$repo/tax/acme/acme-tax-v1.0.0.zip"
cat > "$repo/commerce-apps-manifest/manifest.json" <<'EOF'
{
  "tax": [
    {
      "id": "acme-tax", "name": "Acme Tax", "description": "d",
      "iconName": "acme.png", "domain": "tax", "type": "app",
      "provider": "thirdParty", "version": "1.0.0",
      "zip": "acme-tax-v1.0.0.zip", "sha256": "abc"
    }
  ]
}
EOF
commit_all "$repo" "base"

printf 'PK\x03\x04v110' > "$repo/tax/acme/acme-tax-v1.1.0.zip"
cat > "$repo/commerce-apps-manifest/manifest.json" <<'EOF'
{
  "tax": [
    {
      "id": "acme-tax", "name": "Acme Tax", "description": "d",
      "iconName": "acme.png", "domain": "tax", "type": "app",
      "provider": "thirdParty", "version": "1.1.0",
      "zip": "acme-tax-v1.1.0.zip", "sha256": "def"
    }
  ]
}
EOF
commit_all "$repo" "head"

json="$(run_classify "$repo" "external-user" "user@example.com")"
assert_field "$json" '.added_zip'          "tax/acme/acme-tax-v1.1.0.zip" "added_zip is the new version's ZIP"
assert_field "$json" '.is_new_app'         "false"                        "existing dir => is_new_app=false"
assert_field "$json" '.author.is_internal' "false"                        "external still external"
assert_field "$json" '.will_file_gus_wi'   "false"                        "version bump => no GUS WI"
assert_field "$json" '.manifest.version'   "1.1.0"                        "manifest reflects new version"
echo ""

# ---------------------------------------------------------------------------
# Case 3: Salesforce-authored new app.
# ---------------------------------------------------------------------------
# Author email ends in @salesforce.com. Even a genuinely-new ISV dir must
# not create a GUS WI — internal submissions are triaged out-of-band.
echo "--- Case 3: Salesforce-authored new app ---"
repo="$(mkrepo)"

mkdir -p "$repo/commerce-apps-manifest"
printf '{"tax":[]}' > "$repo/commerce-apps-manifest/manifest.json"
commit_all "$repo" "base"

mkdir -p "$repo/tax/salesforce-thing"
printf 'PK\x03\x04sf' > "$repo/tax/salesforce-thing/sf-thing-v1.0.0.zip"
printf '{"tax":[{"id":"sf-thing","name":"SF Thing","description":"d","iconName":"sf.png","domain":"tax","type":"app","provider":"salesforce","version":"1.0.0","zip":"sf-thing-v1.0.0.zip","sha256":"x"}]}' \
  > "$repo/commerce-apps-manifest/manifest.json"
commit_all "$repo" "head"

json="$(run_classify "$repo" "sf-user" "someone@salesforce.com")"
assert_field "$json" '.is_new_app'         "true"                          "still is_new_app=true"
assert_field "$json" '.author.is_internal' "true"                          "salesforce.com email => internal"
assert_field "$json" '.will_file_gus_wi'   "false"                         "internal author => no GUS WI"
echo ""

# ---------------------------------------------------------------------------
# Case 4: Non-ZIP-only diff.
# ---------------------------------------------------------------------------
# The workflow filters PR events by paths: **/*.zip so this exact shape
# does not trigger the workflow at all — but the classifier is also invoked
# on manual reruns and must degrade cleanly to nulls without crashing when
# there is no added ZIP.
echo "--- Case 4: non-ZIP-only diff ---"
repo="$(mkrepo)"

mkdir -p "$repo/commerce-apps-manifest"
printf '{"tax":[]}' > "$repo/commerce-apps-manifest/manifest.json"
commit_all "$repo" "base"

printf 'update docs\n' > "$repo/README.md"
commit_all "$repo" "head"

json="$(run_classify "$repo" "docs-user" "user@example.com")"
assert_field "$json" '.added_zip'          "null"    "no added zip"
assert_field "$json" '.isv_dir'            "null"    "no isv_dir"
assert_field "$json" '.is_new_app'         "false"   "no zip => not a new app"
assert_field "$json" '.will_file_gus_wi'   "false"   "no zip => no GUS WI"
echo ""

# ---------------------------------------------------------------------------
# Case 5: Injection safety — author email with shell metachars.
# ---------------------------------------------------------------------------
# The classifier passes untrusted fields via jq --arg (never interpolated
# into shell). A crafted email must not affect JSON structure or shell
# behavior.
echo "--- Case 5: hostile author email ---"
repo="$(mkrepo)"
mkdir -p "$repo/commerce-apps-manifest"
printf '{"tax":[]}' > "$repo/commerce-apps-manifest/manifest.json"
commit_all "$repo" "base"
printf 'x' > "$repo/README.md"
commit_all "$repo" "head"

hostile_email='" ; rm -rf / ; echo "@salesforce.com'
json="$(run_classify "$repo" 'attacker' "$hostile_email")"
assert_field "$json" '.author.email' "$hostile_email" "hostile email preserved verbatim as string"
assert_field "$json" '.author.is_internal' "false" "hostile email does not falsely satisfy @salesforce.com"
echo ""

echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
