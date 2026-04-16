---
name: package-app
description: >-
  Package a commerce app directory into a registry-ready ZIP file. This skill handles BOTH
  new apps AND version bumps of existing apps. Use this IMMEDIATELY when users mention
  "package", "ZIP", "build app", "ready to submit", "bump version", "new version",
  "update version", "release", "patch", "minor update", "major release", or after ANY
  changes to an app directory. Trigger proactively whenever you see a commerce-*-app-v*
  directory that needs packaging - don't wait for explicit requests.
---

# Package Commerce App

Build a registry-ready Commerce App Package (CAP) ZIP from an app directory.

## Step 1: Collect inputs

| Input | Example | Required |
|-------|---------|----------|
| App name | `avalara-tax` | Yes |
| Display name | `Avalara Tax` | Yes |
| Domain | `tax` | Yes |
| Version | `0.2.8` | Yes |
| Description | Short description | Yes |
| Publisher name | `Avalara` | Yes |
| Publisher URL | `https://developer.avalara.com/` | Yes |

**Valid domains:** `tax`, `payment`, `shipping`, `gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`, `fraud`

**Structure:** Apps must be at `{domain}/{appName}/` where `{appName}` matches the "id" field. See `references/folder-structure.md`.

## Step 2: Version strategy

Check for existing `catalog.json`:

```bash
cat <domain>/<appName>/catalog.json
```

**Decision tree:**
- **No catalog.json:** New app → proceed with version from commerce-app.json
- **catalog.json with `"latest": {"version": "INIT"}` and `"versions": []`:** Ask user to replace or bump
- **Version EXISTS in catalog.json versions array:** MUST bump - ask user for new version

**Version validation:**
- Published versions cannot be replaced
- Always confirm version with user
- Use semantic versioning: major.minor.patch

## Step 3: Update commerce-app.json

Ensure version matches throughout:

```json
{
  "id": "<appName>",
  "name": "<displayName>",
  "description": "<description>",
  "domain": "<domain>",
  "version": "<version>",
  "publisher": {
    "name": "<publisherName>",
    "url": "<publisherUrl>",
    "support": "<publisherUrl>"
  },
  "dependencies": {}
}
```

## Step 4: Run validation

**CRITICAL:** Validate before packaging:

```
/validate-app
```

Checks architecture, structure, manifest, impex, icons, translations, and security. Address all failures before continuing.

## Step 5: Delete old ZIPs

```bash
cd <domain>/<appName>/
rm -f <appName>-v*.zip
```

## Step 6: Generate ZIP

```bash
cd <domain>/<appName>/
zip -r <appName>-v<version>.zip commerce-<appName>-app-v<version>/ \
  -x "*.DS_Store" -x "__MACOSX/*" -x "*/.*" -x "Thumbs.db"
```

Verify structure:
```bash
unzip -l <appName>-v<version>.zip | head -20
```

Confirm:
- Single root: `commerce-<appName>-app-v<version>/`
- No junk files
- Architecture-specific directories present

## Step 7: Compute hash

```bash
shasum -a 256 <domain>/<appName>/<appName>-v<version>.zip
```

## Step 8: Update root manifest

Update `commerce-apps-manifest/manifest.json`:

```json
{
  "id": "<appName>",
  "name": "<displayName>",
  "description": "<description>",
  "iconName": "<appName>.png",
  "domain": "<domain>",
  "type": "app",
  "provider": "thirdParty",
  "version": "<version>",
  "zip": "<appName>-v<version>.zip",
  "sha256": "<computed_hash>"
}
```

**Icon:** Must match filename in ZIP's `icons/` directory. CI extracts automatically.

## Step 9: Add translations

Update `commerce-apps-manifest/translations/en-US.json` (minimum):

```bash
jq '. + {"<appName>": {"name": "<displayName>", "description": "<description>"}}' \
  commerce-apps-manifest/translations/en-US.json > temp.json && \
  mv temp.json commerce-apps-manifest/translations/en-US.json
```

Repeat for other locales or use English as fallback.

## Step 10: Handle catalog.json

- **Existing app:** Don't modify - CI updates on merge
- **New app:** Create with INIT values:

```json
{
  "latest": {"version": "INIT", "tag": "INIT"},
  "versions": []
}
```

## Step 11: Final validation

```
/validate-app
```

All checks must pass.

## Step 12: Clean up

```bash
cd <domain>/<appName>/
rm -rf commerce-<appName>-app-v<version>/
```

**Commit only:**
- ✅ `<appName>-v<version>.zip`
- ✅ `commerce-apps-manifest/manifest.json`
- ✅ `commerce-apps-manifest/translations/*.json`
- ✅ `catalog.json` (new apps only)

**Don't commit:**
- ❌ Extracted directories
- ❌ Old ZIP versions
- ❌ Junk files
