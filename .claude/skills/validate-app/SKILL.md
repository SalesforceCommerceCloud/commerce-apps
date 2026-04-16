---
name: validate-app
description: >-
  Run comprehensive pre-submission validation on commerce app packages. Use IMMEDIATELY when users
  mention "validate", "check", "verify", or "ready to submit". REQUIRED before calling submit-app
  - trigger proactively to catch errors early. Validates directory structure, manifest format,
  SHA256 hashes, impex XML, security issues, and runs complete CONTRIBUTING.md checklist. Also use
  when debugging validation failures or import errors to identify root cause quickly.
---

# Validate Commerce App Package

Run comprehensive validation checks on a commerce app before submitting a PR.

## Step 1: Identify app

Gather:
- Domain (e.g., `tax`, `payment`, `shipping`)
- App name (e.g., `avalara-tax`)
- Version (or use latest ZIP)

**Structure:** Apps must be at `{domain}/{appName}/` where `{appName}` matches the "id" field. See `references/folder-structure.md`.

## Step 2: Verify ZIP exists

```bash
ls -lh <domain>/<appName>/<appName>-v<version>.zip
```

## Step 3: Validate SHA256

```bash
# Compute hash
shasum -a 256 <domain>/<appName>/<appName>-v<version>.zip

# Compare with commerce-apps-manifest/manifest.json
jq '.[] | .[] | select(.id == "<appName>")' commerce-apps-manifest/manifest.json
```

Hashes must match exactly.

## Step 4: Validate manifest entry

Check `commerce-apps-manifest/manifest.json` has all required fields:

- `id` - matches app name
- `name` - display name
- `description`
- `iconName` - matches icon in ZIP `icons/` directory
- `domain` - valid domain (hyphen-case)
- `type` - must be `"app"`
- `provider` - must be `"thirdParty"`
- `version` - semantic versioning
- `zip` - matches actual filename
- `sha256` - matches computed hash

## Step 5: Validate ZIP contents

```bash
unzip -l <domain>/<appName>/<appName>-v<version>.zip | head -30
```

Check:
- Single root: `commerce-<appName>-app-v<version>/`
- No junk files (`.DS_Store`, `__MACOSX`, hidden files)
- No registry paths (`tax/`, `domain/`)
- Required: `commerce-app.json`, `README.md`, `app-configuration/tasksList.json`

## Step 6: Detect architecture

```bash
HAS_UI=$(unzip -l <zip> | grep -c "storefront-next/" || echo 0)
HAS_BACKEND=$(unzip -l <zip> | grep -c "cartridges/" || echo 0)
```

Determine:
- **UI-only:** Has `storefront-next/`, NO `cartridges/`
- **Backend-only:** Has `cartridges/`, NO `storefront-next/`
- **Fullstack:** Has both

## Step 7: Validate commerce-app.json

Extract and check:

```bash
unzip -p <zip> */commerce-app.json | jq .
```

Required fields:
- `id`, `name`, `description`, `domain`, `version`
- `publisher.name`, `publisher.url`, `publisher.support`

Version must match root manifest version.

## Step 8: Validate storefront files (UI-only/Fullstack)

**Skip if Backend-only.**

Check for:
- `storefront-next/src/extensions/<appName>/target-config.json`
- `storefront-next/src/extensions/<appName>/index.ts`
- Required locales: `en-US/`, `en-GB/`, `it-IT/`

## Step 9: Validate impex (Backend-only/Fullstack)

**Skip if UI-only.**

```bash
# Extract and validate XML
unzip -q <zip>
find commerce-<appName>-app-v<version>/impex/ -name "*.xml" -exec xmllint --noout {} \;
```

See `references/impex-validation.md` for detailed rules:
- Services use dotted notation
- Install/uninstall pairs match
- Attribute IDs use camelCase with app prefix
- SITEID placeholder (not actual site ID)
- No hardcoded credentials

## Step 10: Verify catalog.json

- **Existing app:** catalog.json exists, unchanged in PR
- **New app:** catalog.json has INIT values:
```json
{
  "latest": {"version": "INIT", "tag": "INIT"},
  "versions": []
}
```

## Step 11: Validate translations

```bash
jq '."<appName>"' commerce-apps-manifest/translations/en-US.json
```

Check:
- Entry exists in `en-US.json` (minimum)
- Has `name` and `description` fields
- Valid JSON structure

## Step 12: Validate icon

```bash
# Get iconName from manifest
ICON_NAME=$(jq -r '.[] | .[] | select(.id == "<appName>") | .iconName' commerce-apps-manifest/manifest.json)

# Check ZIP contains matching icon
unzip -l <zip> | grep "icons/$ICON_NAME"
```

Icon filename must match `iconName` field exactly. CI extracts automatically.

## Step 13: Security scan

```bash
unzip -q <zip>
bash .github/scripts/security-scan.sh commerce-<appName>-app-v<version>/
```

**If blocking findings (exit 1):** FAIL - fix issues first.
**If warnings only:** Continue with warnings for review.

See `references/security-scan.md` for details.

## Step 14: Clean up

```bash
rm -rf commerce-<appName>-app-v<version>/
```

## Report results

- **✅ PASS** - All validations passed, ready for `/submit-app`
- **❌ FAIL** - List specific issues with file paths and line numbers

Provide fix recommendations for each issue.
