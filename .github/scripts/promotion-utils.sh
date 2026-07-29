#!/usr/bin/env bash

# Helpers for forward-integration (auto-promotion) of app artifacts across
# release branches. Promotion is forward-only along the chain
#   release/<oldest> -> ... -> release/<newest> -> main
# Each function is pure (reads args / files, writes stdout) so it can be unit
# tested by test-promotion-utils.sh without a live checkout.

# Prints the next branch in the forward-integration chain for a given ref, or
# nothing when the ref is the end of the chain (main) or not a release branch.
#
#   next_release_branch <current_ref> <newline_separated_branch_list>
#
# Rules:
#   - "main"            -> chain terminates, prints nothing.
#   - "release/X.Y"     -> the smallest release/X'.Y' strictly greater than the
#                          current version; if none exists, "main".
#   - anything else     -> prints nothing (feature branches are not promoted).
#
# Version comparison is numeric on (major, minor); no dependency on `sort -V`
# so the behavior is identical on the CI runner and on macOS.
next_release_branch() {
  local current="${1:?current ref is required}"
  local branch_list="${2:-}"

  if [[ "$current" == "main" ]]; then
    return 0
  fi
  if [[ ! "$current" =~ ^(refs/heads/)?release/([0-9]+)\.([0-9]+)$ ]]; then
    return 0
  fi
  local cmaj="${BASH_REMATCH[2]}" cmin="${BASH_REMATCH[3]}"

  local best_maj="" best_min="" best=""
  local line b maj min
  while IFS= read -r line; do
    b="${line#refs/heads/}"
    [[ "$b" =~ ^release/([0-9]+)\.([0-9]+)$ ]] || continue
    maj="${BASH_REMATCH[1]}"
    min="${BASH_REMATCH[2]}"

    # Keep only versions strictly greater than the current one.
    if (( maj > cmaj || (maj == cmaj && min > cmin) )); then
      # Track the smallest such version (the immediate next hop).
      if [[ -z "$best" ]] || (( maj < best_maj || (maj == best_maj && min < best_min) )); then
        best_maj="$maj"; best_min="$min"; best="release/$maj.$min"
      fi
    fi
  done <<< "$branch_list"

  if [[ -n "$best" ]]; then
    echo "$best"
  else
    echo "main"
  fi
}

# Merges a promoted (version, tag) into the target branch's catalog.json and
# prints the merged JSON to stdout. Two invariants:
#   - versions is a union: the (version, tag) pair is appended only when absent,
#     so re-promoting the same artifact is idempotent.
#   - latest is monotonic: it is recomputed as the highest semver across the
#     merged versions, never blindly overwritten. Promoting an OLDER version
#     forward (e.g. a back-port hop) therefore never regresses `latest` when the
#     target already carries a newer version. A release ranks above a
#     pre-release of the same major.minor.patch.
#
#   merge_catalog_json <target_catalog_path> <version> <tag>
merge_catalog_json() {
  local catalog_path="${1:?target catalog path is required}"
  local version="${2:?version is required}"
  local tag="${3:?tag is required}"

  jq --arg v "$version" --arg t "$tag" '
    # [major, minor, patch] as numbers; the pre-release suffix is dropped for
    # the primary key and handled separately below.
    def mmp($s): ($s | split("-")[0] | split(".") | map(tonumber));
    # 1 for a release, 0 for a pre-release, so release > pre-release at equal MMP.
    def rank($s): (if ($s | test("-")) then 0 else 1 end);

    (.versions // []) as $existing
    | (if any($existing[]; .version == $v and .tag == $t)
         then $existing
         else $existing + [{"version": $v, "tag": $t}]
       end) as $merged
    | {
        "latest": ($merged | max_by([ mmp(.version), rank(.version) ])),
        "versions": $merged
      }
  ' "$catalog_path"
}

# Upserts a manifest entry into a category array of the target branch's
# manifest and prints the merged JSON. The manifest holds exactly one entry per
# app, pinned to its latest version, keyed by `.id` (e.g. loqate carries nine
# catalog versions but a single manifest entry). So the upsert:
#   - matches the existing entry by `.id` (app identity), not by zip filename;
#   - is monotonic on version: it replaces the entry only when the incoming
#     version is >= the existing pinned version, so promoting an OLDER artifact
#     forward (a back-port hop) never regresses the target's pinned version;
#   - appends when the app is not yet present on the target;
#   - creates the category array when the target manifest lacks it.
# A release ranks above a pre-release of the same major.minor.patch.
#
#   merge_manifest_entry <target_manifest_path> <entry_json> <category>
merge_manifest_entry() {
  local manifest_path="${1:?target manifest path is required}"
  local entry_json="${2:?entry JSON is required}"
  local category="${3:?category is required}"

  jq --argjson entry "$entry_json" --arg cat "$category" '
    def mmp($s): ($s | split("-")[0] | split(".") | map(tonumber));
    def rank($s): (if ($s | test("-")) then 0 else 1 end);
    # Compare two semver strings: 1 if a>b, 0 if equal, -1 if a<b.
    def semver_cmp($a; $b):
      ([mmp($a), rank($a)]) as $ka | ([mmp($b), rank($b)]) as $kb
      | if $ka > $kb then 1 elif $ka < $kb then -1 else 0 end;

    ($entry.id) as $id
    | (.[$cat] // []) as $arr
    | ($arr | map(select((.id? // "") == $id)) | first) as $existing
    | if $existing == null then
        # New app on this target -> append.
        .[$cat] = ($arr + [$entry])
      elif (semver_cmp($entry.version; ($existing.version // "0.0.0")) >= 0) then
        # Incoming version is newer or equal -> replace the pinned entry.
        .[$cat] = ((($arr | map(select((.id? // "") != $id)))) + [$entry])
      else
        # Target already pins a newer version -> leave it untouched (monotonic).
        .
      end
  ' "$manifest_path"
}
