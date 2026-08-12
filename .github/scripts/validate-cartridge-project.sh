#!/usr/bin/env bash
# Validate that every cartridge root inside a CAP contains a .project file.
#
# Usage: validate-cartridge-project.sh <cap-root>
#
# Exit codes:
#   0 - every cartridge root has a .project file (or the CAP has no
#       cartridges/ directory at all — UI-only apps are skipped gracefully)
#   1 - one or more cartridge roots are missing .project (errors on stderr)
#   2 - usage error (bad args or unreadable input)
#
# Schema:
#   - Cartridge roots are the immediate child directories of
#     cartridges/site_cartridges/ and cartridges/bm_cartridges/ under the
#     CAP root (whichever of the two groups exist).
#   - Every cartridge root MUST contain a .project file. It may be empty
#     (auto-created by scaffold/package tooling) or a real, non-empty
#     Eclipse .project file — both PASS. b2c cartridge discovery requires
#     this file to exist, regardless of contents.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <cap-root>" >&2
  exit 2
fi

cap_root="$1"

if [[ ! -d "$cap_root" ]]; then
  echo "CAP root not found: $cap_root" >&2
  exit 2
fi

cartridges_dir="$cap_root/cartridges"

if [[ ! -d "$cartridges_dir" ]]; then
  echo "No cartridges/ directory - OK (UI-only app)"
  exit 0
fi

missing=()
checked=0

for group in site_cartridges bm_cartridges; do
  group_dir="$cartridges_dir/$group"
  [[ -d "$group_dir" ]] || continue

  while IFS= read -r cartridge_dir; do
    checked=$((checked + 1))
    if [[ ! -f "$cartridge_dir/.project" ]]; then
      missing+=("cartridges/$group/$(basename "$cartridge_dir")/.project")
    fi
  done < <(find "$group_dir" -mindepth 1 -maxdepth 1 -type d | sort)
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing required .project file(s) in cartridge root(s):" >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

echo "cartridges/ .project check passed ($checked cartridge root(s) checked)"
exit 0
