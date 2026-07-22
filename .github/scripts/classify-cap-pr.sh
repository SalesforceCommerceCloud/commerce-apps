#!/usr/bin/env bash
# classify-cap-pr.sh
#
# Shared classifier consumed by .github/workflows/gus-security-review.yml
# (which gates on external-author AND new-app) and
# .github/workflows/notify-slack-cap-pr.yml (which uses it only for message
# content). Classification logic must live in exactly one place so the two
# workflows never disagree.
#
# Reads the PR diff between BASE_SHA and HEAD_SHA (env vars) and emits a
# single JSON object on stdout. Diagnostic prose is written to stderr and does
# not pollute the JSON blob.
#
# Required env:
#   BASE_SHA               PR base SHA (github.event.pull_request.base.sha)
#   HEAD_SHA               PR head SHA (github.event.pull_request.head.sha)
#   PR_AUTHOR_LOGIN        github.event.pull_request.user.login
#   PR_AUTHOR_EMAIL        email of the author (blank if the API omitted it)
#
# Optional env:
#   MANIFEST_PATH          override manifest.json location (tests use this)
#
# Emitted JSON shape:
#   {
#     "added_zip": "<path>|null",
#     "isv_dir":   "<domain>/<isv-name>|null",
#     "domain":    "<domain>|null",
#     "isv":       "<isv-name>|null",
#     "manifest": {
#       "name":     "<display name>|null",
#       "version":  "<semver>|null",
#       "domain":   "<domain>|null",
#       "provider": "<provider>|null",
#       "zip":      "<zip filename>|null"
#     },
#     "author": {
#       "login":       "<gh handle>",
#       "email":       "<email or empty>",
#       "is_internal": true|false     # email endswith @salesforce.com
#     },
#     "is_new_app":         true|false, # net-new {domain}/{isv-name}/ on BASE_SHA
#     "will_file_gus_wi":   true|false  # !is_internal AND is_new_app
#   }
#
# Exit codes:
#   0  success — JSON emitted (even when there is no CAP-relevant change; fields
#      are then null / defaulted)
#   2  environment / usage error

set -euo pipefail

: "${BASE_SHA:?BASE_SHA is required}"
: "${HEAD_SHA:?HEAD_SHA is required}"
: "${PR_AUTHOR_LOGIN:?PR_AUTHOR_LOGIN is required}"
PR_AUTHOR_EMAIL="${PR_AUTHOR_EMAIL:-}"
MANIFEST_PATH="${MANIFEST_PATH:-commerce-apps-manifest/manifest.json}"

# Pick the first ADDED (A) *.zip path in the PR diff. A CAP-relevant PR either
# adds a new ZIP under a net-new ISV directory or bumps a version by adding a
# new ZIP under an existing one; both cases surface as an A-status *.zip diff
# entry, so filter-A is the shared signal. Modified-only ZIPs (M) are not CAP
# submissions and stay null here.
added_zip="$(git diff --name-only --diff-filter=A -z "$BASE_SHA" "$HEAD_SHA" -- '**/*.zip' \
  | tr '\0' '\n' | head -n 1 || true)"

isv_dir="null"
domain_val="null"
isv_val="null"
if [[ -n "$added_zip" ]]; then
  # Path shape: {domain}/{isv-name}/{app}-v{ver}.zip
  isv_dir="$(dirname "$added_zip")"
  domain_val="$(printf '%s' "$isv_dir" | cut -d/ -f1)"
  isv_val="$(printf '%s' "$isv_dir" | cut -d/ -f2)"
fi

# is_new_app: does {domain}/{isv-name}/ exist as a tree on BASE_SHA?
# Absent = net-new (external submission); present = version bump.
is_new_app="false"
if [[ -n "$added_zip" && "$isv_dir" != "null" ]]; then
  if git cat-file -e "$BASE_SHA:$isv_dir" 2>/dev/null; then
    is_new_app="false"
  else
    is_new_app="true"
  fi
fi

# Manifest entry lookup — best-effort. The manifest may not yet describe the
# newly-added ZIP (PRs sometimes stage the ZIP without the manifest update);
# treat that as null fields rather than an error, so the classifier still emits
# a usable blob for the Slack canary.
m_name="null"; m_version="null"; m_domain="null"; m_provider="null"; m_zip="null"
if [[ -n "$added_zip" && -f "$MANIFEST_PATH" ]]; then
  zip_basename="$(basename "$added_zip")"
  entry="$(jq -c --arg z "$zip_basename" '
    [
      to_entries[]
      | select(.value | type == "array")
      | .value[]?
      | select(type == "object" and (.zip? == $z))
    ] | .[0] // null
  ' "$MANIFEST_PATH")"

  if [[ "$entry" != "null" && -n "$entry" ]]; then
    m_name="$(jq -r '.name // "null"' <<< "$entry")"
    m_version="$(jq -r '.version // "null"' <<< "$entry")"
    m_domain="$(jq -r '.domain // "null"' <<< "$entry")"
    m_provider="$(jq -r '.provider // "null"' <<< "$entry")"
    m_zip="$(jq -r '.zip // "null"' <<< "$entry")"
  fi
fi

# Internal author check. External submitters (the reason this workflow exists)
# must not have an @salesforce.com email; only well-formed emails whose entire
# domain part is exactly `salesforce.com` are treated as internal. A plain
# suffix match (`*@salesforce.com`) would let a crafted email like
# `hostile" ; rm -rf / ; echo "@salesforce.com` pass — anchoring against a
# valid local-part rules that out.
is_internal="false"
if [[ "$PR_AUTHOR_EMAIL" =~ ^[A-Za-z0-9._%+-]+@salesforce\.com$ ]]; then
  is_internal="true"
fi

will_file_gus_wi="false"
if [[ "$is_internal" == "false" && "$is_new_app" == "true" ]]; then
  will_file_gus_wi="true"
fi

# Emit a single JSON blob. jq builds it so quoting is safe even when the
# manifest name / other fields contain characters that would break a
# hand-assembled string.
jq -n \
  --arg added_zip "$added_zip" \
  --arg isv_dir "$isv_dir" \
  --arg domain "$domain_val" \
  --arg isv "$isv_val" \
  --arg m_name "$m_name" \
  --arg m_version "$m_version" \
  --arg m_domain "$m_domain" \
  --arg m_provider "$m_provider" \
  --arg m_zip "$m_zip" \
  --arg author_login "$PR_AUTHOR_LOGIN" \
  --arg author_email "$PR_AUTHOR_EMAIL" \
  --argjson is_internal "$is_internal" \
  --argjson is_new_app "$is_new_app" \
  --argjson will_file "$will_file_gus_wi" \
  '{
    added_zip: (if $added_zip == "" then null else $added_zip end),
    isv_dir:   (if $isv_dir == "null" then null else $isv_dir end),
    domain:    (if $domain == "null" then null else $domain end),
    isv:       (if $isv == "null" then null else $isv end),
    manifest: {
      name:     (if $m_name == "null" then null else $m_name end),
      version:  (if $m_version == "null" then null else $m_version end),
      domain:   (if $m_domain == "null" then null else $m_domain end),
      provider: (if $m_provider == "null" then null else $m_provider end),
      zip:      (if $m_zip == "null" then null else $m_zip end)
    },
    author: {
      login:       $author_login,
      email:       $author_email,
      is_internal: $is_internal
    },
    is_new_app:       $is_new_app,
    will_file_gus_wi: $will_file
  }'
