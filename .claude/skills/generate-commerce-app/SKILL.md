---
name: generate-commerce-app
description: >-
  Generate a Commerce App Package (CAP) ZIP for the registry. Use when building,
  packaging, or submitting a new or updated commerce app ZIP, or when the user
  mentions CAP, commerce app, registry ZIP, manifest.json, or commerce-app.json.
---

# Generate Commerce App Package

Build a registry-ready Commerce App Package (CAP) ZIP from an extracted app directory.

## Reference implementation

Use `tax/avalara-tax/` as the canonical reference. Extract the latest ZIP to study the structure before generating.

## Step 1: Collect inputs

Gather from the user (or infer from context):

| Input | Example | Required |
|-------|---------|----------|
| App name (kebab-case) | `avalara-tax` | Yes |
| Display name | `Avalara Tax` | Yes |
| Domain | `tax` | Yes (one of: `tax`, `payment`, `shipping`, `gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`) |
| Version | `0.2.8` | Yes |
| Description | `Automated tax compliance by Avalara` | Yes |
| Publisher name | `Avalara` | Yes |
| Publisher URL | `https://developer.avalara.com/` | Yes |

## Step 2: Verify directory structure

The extracted app directory must be named `commerce-<appName>-app-v<version>/` and contain:

```
commerce-<appName>-app-v<version>/
├── commerce-app.json                          # App identity & metadata
├── README.md                                  # Documentation
├── app-configuration/
│   └── tasksList.json                         # Post-install checklist
├── cartridges/
│   ├── site_cartridges/<cartridge_name>/
│   │   ├── package.json                       # Hooks path, test scripts, devDeps
│   │   ├── cartridge/scripts/
│   │   │   ├── hooks.json                     # Hook name → script mappings
│   │   │   ├── hooks/                         # calculate.js, commit.js, cancel.js
│   │   │   ├── helpers/                       # Business logic
│   │   │   └── services/                      # Service framework wrapper
│   │   └── test/                              # Unit tests (mocks/ + unit/)
│   └── bm_cartridges/<bm_cartridge_name>/     # BM extensions (can be empty)
├── storefront-next/src/extensions/<app-name>/
│   ├── target-config.json                     # Extension target mappings
│   └── components/                            # React components
├── impex/
│   ├── install/
│   │   ├── services.xml                       # Service credential, profile, definition
│   │   ├── meta/system-objecttype-extensions.xml  # Site preference definitions
│   │   └── sites/SITEID/preferences.xml       # Default preference values
│   └── uninstall/
│       └── services.xml                       # Service deletion (mode="delete")
└── icons/                                     # App icon (optional)
```

Validate that every file referenced by the code actually exists and vice versa.

## Step 3: Update commerce-app.json

This file provides package-level identity. Update it to match the current version:

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

## Step 4: Delete old ZIP versions

**CRITICAL:** Before generating the new ZIP, delete any existing ZIP files for this app to avoid clutter:

```bash
cd <domain>/<isv-name>/
rm -f <appName>-v*.zip
```

This ensures:
- Only the latest version is in the repository
- No confusion about which ZIP is current
- Clean git status

## Step 5: Generate the ZIP

Run from the **parent directory** of the app folder so the root entry is `commerce-<appName>-app-v<version>/`:

```bash
cd <domain>/<isv-name>/
zip -r <appName>-v<version>.zip commerce-<appName>-app-v<version>/ \
  -x "*.DS_Store" -x "__MACOSX/*" -x "*/.*" -x "Thumbs.db"
```

Verify the ZIP:
1. Run `unzip -l <appName>-v<version>.zip` and confirm:
   - Single root folder: `commerce-<appName>-app-v<version>/`
   - No `tax/` or other registry path prefixes leaking in
   - No `.DS_Store`, `__MACOSX`, or hidden files
   - No duplicate directory trees

## Step 6: Compute SHA256 hash

Generate the hash for the ZIP:

```bash
shasum -a 256 <domain>/<isv-name>/<appName>-v<version>.zip
```

Copy the hex digest (the long string before the filename).

## Step 7: Update root manifest

**CRITICAL:** Update the root manifest at `commerce-apps-manifest/manifest.json`:

Find the entry for your app in the appropriate domain array (e.g., `tax`, `payment`, `gift-cards`) and update it:

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

Valid domains: `tax`, `payment`, `shipping`, `gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`.

**For new apps:** Add a new entry to the appropriate domain array.
**For updates:** Update the existing entry's `version`, `zip`, and `sha256` fields.

## Step 8: Handle catalog.json

- **Existing app**: Do not modify `catalog.json` — CI updates it on merge.
- **Brand new app**: Create `catalog.json` next to the ZIP:

```json
{
  "latest": {
    "version": "INIT",
    "tag": "INIT"
  },
  "versions": []
}
```

## Step 9: Final validation checklist

- [ ] ZIP name matches `<appName>-v<version>.zip`
- [ ] ZIP contains a single root folder `commerce-<appName>-app-v<version>/`
- [ ] No junk files (`.DS_Store`, `__MACOSX`, hidden files)
- [ ] `commerce-app.json` version matches the ZIP version
- [ ] `commerce-apps-manifest/manifest.json` is updated with correct version and hash
- [ ] `sha256` in root manifest matches the actual ZIP hash
- [ ] `catalog.json` included only for brand new apps

## Step 10: Clean up extracted directory

After generating the ZIP, delete the extracted directory (it should NOT be committed):

```bash
cd <domain>/<isv-name>/
rm -rf commerce-<appName>-app-v<version>/
```

**What should be in the repository:**
```
<domain>/<isv-name>/
├── <appName>-v<version>.zip     ✅ COMMIT
└── catalog.json                  ✅ COMMIT (new apps only)

commerce-apps-manifest/
└── manifest.json                 ✅ COMMIT (updated entry)
```

**What should NOT be committed:**
- ❌ `commerce-<appName>-app-v<version>/` (extracted directory)
- ❌ `.DS_Store` or other junk files
- ❌ Old ZIP versions

The extracted directory is only needed during development. Once packaged into a ZIP, it can be deleted.
