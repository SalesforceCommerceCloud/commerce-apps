#!/usr/bin/env bash

# Helpers for forward-integration (auto-promotion) of app artifacts across
# release branches. Promotion is forward-only along the chain
#   release/<oldest> -> ... -> release/<newest>
# The newest release branch is the end of the chain; auto-promote never opens
# a PR into main.
# Each function is pure (reads args / files, writes stdout) so it can be unit
# tested by test-promotion-utils.sh without a live checkout.

# Prints the next branch in the forward-integration chain for a given ref, or
# nothing when the ref is the end of the chain or not a release branch.
#
#   next_release_branch <current_ref> <newline_separated_branch_list>
#
# Rules:
#   - "main"            -> chain terminates, prints nothing.
#   - "release/X.Y"     -> the smallest release/X'.Y' strictly greater than the
#                          current version; if none exists, prints nothing
#                          (newest release is the end of the chain — never hops
#                          to main).
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
  fi
}

# Prints the path to a CAP's own icons/ directory within its unpacked ZIP, or
# nothing if it has none.
#
#   find_cap_icons_dir <extracted_zip_root>
#
# ZIPs unpack to <extracted_zip_root>/<cap-root>/, so the CAP-level icons/ is
# always exactly two levels below the extraction root (one level below the
# cap-root). Anchoring to that exact depth (rather than an unbounded
# `find -name icons`) avoids picking up an
# unrelated nested icons/ dir that a bundled cartridge asset may carry (e.g.
# Business Manager static theme icons under
# cartridges/*/cartridge/static/default/icons/), which would otherwise be
# copied into commerce-apps-manifest/icons/ and could overwrite the real app
# icon with the wrong file.
find_cap_icons_dir() {
  local extracted_root="${1:?extracted ZIP root is required}"
  find "$extracted_root" -mindepth 2 -maxdepth 2 -type d -name icons -print -quit
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

# INIT catalog.json template used when promoting a brand-new app onto a target
# that has no catalog.json yet. Version history is then populated by the
# target branch's own update-catalog-pr job (CONTRIBUTING.md contract).
INIT_CATALOG_JSON='{
  "latest": {
    "version": "INIT",
    "tag": "INIT"
  },
  "versions": []
}'

# Seeds catalog.json with the INIT template iff the file does not already
# exist. Prints "seeded" when a new file is written, or "skipped" when an
# existing catalog.json is left untouched. Version bumps of pre-existing apps
# must not rewrite catalog.json in the auto-promo PR — that file is owned by
# the target branch's catalog CI job.
#
#   seed_init_catalog_if_absent <catalog_path>
seed_init_catalog_if_absent() {
  local catalog_path="${1:?catalog path is required}"
  if [[ -f "$catalog_path" ]]; then
    echo "skipped"
    return 0
  fi
  mkdir -p "$(dirname "$catalog_path")"
  printf '%s\n' "$INIT_CATALOG_JSON" > "$catalog_path"
  echo "seeded"
}

# Builds the promote-forward items TSV from a changed-ZIP list. Each input path
# is relative to source_root. A ZIP is emitted only when the file exists on
# the source (deletions are skipped) AND the source manifest has a matching
# entry (back-ported/unpinned ZIPs are skipped). Output rows:
#   zip_path<TAB>version<TAB>category
# Skip notes go to stderr so they cannot pollute the TSV.
#
# Requires lookup_manifest_entry_for_zip (root-manifest-utils.sh).
#
#   collect_promotable_zips <source_root> <source_manifest_path> <changed_zips_file>
collect_promotable_zips() {
  local source_root="${1:?source root is required}"
  local manifest_path="${2:?source manifest path is required}"
  local changed_zips_file="${3:?changed-zips list file is required}"

  local zip_path src_file zip_file entry version category
  while IFS= read -r zip_path; do
    [[ -z "$zip_path" ]] && continue
    src_file="$zip_path"
    if [[ "$zip_path" != /* ]]; then
      src_file="$source_root/$zip_path"
    fi
    [[ -f "$src_file" ]] || continue
    zip_file="$(basename "$zip_path")"
    entry="$(lookup_manifest_entry_for_zip "$zip_file" "$manifest_path")"
    if [[ -z "$entry" ]]; then
      echo "No manifest entry for $zip_file; not promoting (back-ported/unpinned artifact)." >&2
      continue
    fi
    version="$(jq -r '.version // empty' <<< "$entry")"
    category="$(jq -r --arg z "$zip_file" '
      to_entries[]
      | select(.value | type == "array")
      | select(any(.value[]?; .zip? == $z))
      | .key
    ' "$manifest_path")"
    if [[ -z "$version" || "$version" == "null" || -z "$category" ]]; then
      echo "::error file=$manifest_path::Missing version/category for ZIP $zip_file" >&2
      return 1
    fi
    printf '%s\t%s\t%s\n' "$zip_path" "$version" "$category"
  done < "$changed_zips_file"
}

# Copies one promoted ZIP onto the target working tree, overlays its source
# manifest entry (monotonic), and seeds INIT catalog.json only when the target
# has no catalog yet. Prints "seeded" or "skipped" (the catalog result) so the
# caller can git-add the catalog only when a new INIT file was written.
# Unlisted apps' ZIPs and catalogs are not touched.
#
# Requires get_manifest_entry_for_zip (root-manifest-utils.sh).
#
#   apply_promoted_zip_onto_target <target_root> <source_zip> <zip_relpath> <source_manifest> <category>
apply_promoted_zip_onto_target() {
  local target_root="${1:?target root is required}"
  local source_zip="${2:?source ZIP is required}"
  local zip_relpath="${3:?zip relpath is required}"
  local source_manifest="${4:?source manifest is required}"
  local category="${5:?category is required}"

  local dest="$target_root/$zip_relpath"
  mkdir -p "$(dirname "$dest")"
  cp "$source_zip" "$dest"

  local zip_file entry tmp manifest_path
  zip_file="$(basename "$zip_relpath")"
  entry="$(get_manifest_entry_for_zip "$zip_file" "$source_manifest")"
  manifest_path="$target_root/commerce-apps-manifest/manifest.json"
  tmp="$(mktemp)"
  merge_manifest_entry "$manifest_path" "$entry" "$category" > "$tmp"
  mv "$tmp" "$manifest_path"

  seed_init_catalog_if_absent "$(dirname "$dest")/catalog.json"
}

# Upserts a manifest entry into a category array of the target branch's
# manifest and prints the merged JSON. The manifest holds exactly one entry per
# app, pinned to its latest version, keyed by `.id` (e.g. loqate carries nine
# catalog versions but a single manifest entry). So the upsert:
#   - matches the existing entry by `.id` (app identity), not by zip filename;
#   - is monotonic on version: it overlays the incoming entry onto the existing
#     one only when the incoming version is >= the existing pinned version, so
#     promoting an OLDER artifact forward (a back-port hop) never regresses the
#     target's pinned version;
#   - overlays rather than replaces: keys present only on the target (e.g.
#     workspace-carousel fields added on a newer release branch) are preserved
#     even when the source entry at the same or newer version lacks them.
#     Overlapping keys still take the incoming value, so version/zip/sha256
#     advance and an intentional source-side metadata edit still promotes;
#   - updates in place (no remove-and-append), so category order is stable;
#   - appends when the app is not yet present on the target;
#   - creates the category array when the target manifest lacks it.
# A release ranks above a pre-release of the same major.minor.patch.
#
#   merge_manifest_entry <target_manifest_path> <entry_json> <category>
merge_manifest_entry() {
  local manifest_path="${1:?target manifest path is required}"
  local entry_json="${2:?entry JSON is required}"
  local category="${3:?category is required}"

  # The committed manifest.json uses 4-space indentation, so pass --indent 4
  # to keep the upsert a minimal diff (just the changed entry) instead of
  # reformatting the whole file to jq's 2-space default on every promotion.
  jq --indent 4 --argjson entry "$entry_json" --arg cat "$category" '
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
      elif ($existing == $entry) then
        # Byte-for-byte identical already -> true no-op. Without this branch,
        # jq would still rewrite the whole file (indent/key order) for zero
        # effect on an otherwise fully-idempotent re-promotion.
        .
      elif (semver_cmp($entry.version; ($existing.version // "0.0.0")) >= 0) then
        # Incoming version is newer, or equal with changed/additional fields.
        # Overlay source keys onto the existing entry IN PLACE so target-only
        # keys (isFeatured, badge, featured*, companyName, …) are never dropped
        # just because the older branch lacks them.
        .[$cat] = ($arr | map(if (.id? // "") == $id then . + $entry else . end))
      else
        # Target already pins a newer version -> leave it untouched (monotonic).
        .
      end
  ' "$manifest_path"
}

# Merges every entry across every category of a source manifest.json into a
# target manifest.json, applying the same per-id monotonic overlay as
# merge_manifest_entry (above) to each entry individually. This is what lets a
# manual, hand-edited manifest.json change (not tied to any ZIP push) promote
# forward: the edited entry is MERGED into the target - respecting the
# monotonic, id-keyed guard - rather than the whole file being overwritten.
# Equal-or-newer source entries overlay onto the target (source wins on
# overlapping keys; target-only keys are preserved), so a newer-branch field
# such as isFeatured cannot be wiped by an older-branch promote that simply
# lacks the key. An older source version never regresses the target's pin.
#
# A single malformed entry (e.g. a non-semver version string) must not abort
# the whole merge under the caller's `set -e` - that would silently discard
# every entry already merged earlier in the loop. So each entry's upsert is
# guarded individually: on failure, that one entry is skipped (with a
# `::warning::` naming it) and every other entry still merges normally.
#
# Top-level fields that are NOT category arrays (e.g. `defaultLocale`) have no
# per-entry version to compare, so there is no monotonic ordering to preserve;
# a manual edit to one of those fields simply carries forward verbatim.
#
#   merge_manifest_file <target_manifest_path> <source_manifest_path>
merge_manifest_file() {
  local target_path="${1:?target manifest path is required}"
  local source_path="${2:?source manifest path is required}"

  local categories
  categories="$(jq -r 'to_entries[] | select(.value | type == "array") | .key' "$source_path")"

  local current="$target_path"
  local cat entries entry tmp entry_id
  while IFS= read -r cat; do
    [[ -z "$cat" ]] && continue
    entries="$(jq -c --arg c "$cat" '.[$c][]' "$source_path")"
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      tmp="$(mktemp)"
      if merge_manifest_entry "$current" "$entry" "$cat" > "$tmp" 2>/dev/null; then
        [[ "$current" != "$target_path" ]] && rm -f "$current"
        current="$tmp"
      else
        entry_id="$(jq -r '.id // "<unknown>"' <<< "$entry" 2>/dev/null)"
        echo "::warning::Skipping malformed manifest entry '$entry_id' in category '$cat' (failed to merge); leaving target unchanged for this entry." >&2
        rm -f "$tmp"
      fi
    done <<< "$entries"
  done <<< "$categories"

  jq --slurpfile s "$source_path" '
    reduce ($s[0] | to_entries[] | select(.value | type != "array")) as $e (.; .[$e.key] = $e.value)
  ' "$current"
  [[ "$current" != "$target_path" ]] && rm -f "$current"
}

# Merges a translations locale file (commerce-apps-manifest/translations/*.json
# - a flat object keyed by app id, e.g. {"salesforce-flat-tax": {"name": ...,
# "description": ...}}) additively: keys already present on the target are
# left untouched (so this can never regress an intentional target-only
# translation edit), and keys present only in the source are added. There is
# no version to compare (translation entries aren't versioned), so "monotonic"
# here means "never overwrite an existing target key", not semver ordering.
#
#   merge_translations_file <target_locale_path> <source_locale_path>
merge_translations_file() {
  local target_path="${1:?target locale path is required}"
  local source_path="${2:?source locale path is required}"

  jq --slurpfile s "$source_path" '
    reduce ($s[0] | to_entries[]) as $e (.; if has($e.key) then . else .[$e.key] = $e.value end)
  ' "$target_path"
}

# Applies a non-CAP file-content patch (a `git diff --binary` between two
# commits, scoped to a SINGLE file - see NON_CAP_PATHSPEC below) onto the
# current working tree/index. The caller must build one patch per changed
# file (not one combined patch for the whole push): git apply/reverse-check
# treat a patch as all-or-nothing, so a single conflicting or binary file
# bundled into one combined patch would cause every OTHER, unrelated file in
# that same patch to be skipped too. `--binary` on the diff side is required
# so a binary file's hunk carries literal patch data instead of rendering as
# an unapplyable "Binary files ... differ" placeholder.
#
# Non-CAP files are plain content, not a monotonic merge like the
# catalog/manifest, so re-promotion must stay idempotent and must never
# clobber intentional per-branch divergence:
#   - empty patch                              -> "no-op"   (nothing to do)
#   - applies cleanly                          -> "applied" (staged via -index)
#   - already present on target (reverse-check succeeds) -> "no-op" (idempotent)
#   - genuine conflict with target-only changes -> "skipped" (never force it)
# All three non-error outcomes return 0 so the caller can keep promoting the
# rest of the change (CAP artifacts, manifest) even when the non-CAP patch is
# skipped; only a real git failure propagates a non-zero exit.
#
#   apply_non_cap_patch <patch_file>
apply_non_cap_patch() {
  local patch_file="${1:?patch file is required}"

  if [[ ! -s "$patch_file" ]]; then
    echo "no-op"
    return 0
  fi

  if git apply --check "$patch_file" 2>/dev/null; then
    git apply --index "$patch_file"
    echo "applied"
    return 0
  fi

  if git apply --reverse --check "$patch_file" 2>/dev/null; then
    echo "no-op"
    return 0
  fi

  echo "::warning::Non-CAP patch does not apply cleanly onto the target branch (likely per-branch divergence); skipping non-CAP file promotion this round." >&2
  echo "skipped"
  return 0
}

# The non-CAP pathspec: every tracked file EXCEPT the artifacts already owned
# by the CAP promotion path (ZIPs, their sibling catalog.json, extracted
# icons), manifest.json (promoted via merge_manifest_file, a monotonic
# per-entry merge), and the translations locale files (promoted via
# merge_translations_file, an additive per-key merge) - none of those are
# plain file copies, so none belong on the generic patch-apply path. Each is
# keyed content (by app id) that two branches can independently and
# non-conflictingly add to at the same point in the file, which is exactly
# the shape a single git-diff patch handles poorly (see apply_non_cap_patch).
#
# .github/workflows/** is also excluded: the promotion PR is pushed with the
# default GITHUB_TOKEN, and GitHub hard-blocks any token-driven push that adds
# or modifies a workflow file unless the token holds the `workflows`
# permission - a permission `GITHUB_TOKEN` can never be granted via the
# `permissions:` block. Promoting a workflow change would fail PR creation
# outright, not just skip harmlessly, so it is excluded rather than attempted.
#
# Anything else - docs/**, skills, READMEs, other config - is eligible for
# plain-content forward promotion.
NON_CAP_PATHSPEC=(
  '.'
  ':(exclude,glob)**/*.zip'
  ':(exclude,glob)**/catalog.json'
  ':(exclude,glob)commerce-apps-manifest/icons/**'
  ':(exclude)commerce-apps-manifest/manifest.json'
  ':(exclude,glob)commerce-apps-manifest/translations/**'
  ':(exclude,glob).github/workflows/**'
)
