---
name: package-app
description: >-
  Package a commerce app directory into a registry-ready ZIP file. This is the FINAL step
  before submission - use this immediately when the app is ready to be packaged, whenever
  users mention "create ZIP", "package app", "build app", "ready to submit", or after making
  ANY changes to an extracted app directory. Also use when users say "generate ZIP",
  "make ZIP", or "prepare for submission". Don't wait - if there's an extracted app directory
  that needs to be packaged, use this skill proactively.
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
| Domain | `tax` | Yes (one of: `tax`, `payment`, `shipping`, `gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`, `fraud`) |
| Version | `0.2.8` | Yes |
| Description | `Automated tax compliance by Avalara` | Yes |
| Publisher name | `Avalara` | Yes |
| Publisher URL | `https://developer.avalara.com/` | Yes |

## Step 2: Check version and determine strategy

**CRITICAL:** Before proceeding, check if this is a new app or an update to an existing app.

1. **Check for existing catalog.json:**
   ```bash
   cat <domain>/<isv-name>/catalog.json
   ```

2. **Determine versioning strategy:**

   - **IF catalog.json does NOT exist:**
     - This is a brand new app
     - Proceed with the version from commerce-app.json
     - Skip to Step 3

   - **IF catalog.json shows `"latest": { "version": "INIT" }` AND `"versions": []`:**
     - Version hasn't been published yet
     - **ASK USER:** "The current version `<version>` hasn't been published. Do you want to:"
       1. Replace `<version>` with your changes (recommended if no one has it)
       2. Bump to a new version (e.g., `<next-version>`) for better tracking
     - Wait for user choice before proceeding

   - **IF the version from commerce-app.json EXISTS in catalog.json's `versions` array:**
     - **FORCE VERSION BUMP** - no option to replace
     - **STOP and tell the user:** "Version `<version>` already exists in catalog.json and cannot be replaced. Please bump to a new version."
     - **ASK USER:** "What version should this release be? (e.g., `<suggested-next-version>`)"
     - Use `/update-app-version` skill instead for proper version bumping
     - Do NOT proceed until user provides a new version number

3. **Version validation rules:**
   - If version exists in `catalog.json` versions → MUST bump version (no exceptions)
   - Always confirm version with user before generating ZIP
   - Never silently change version without explicit user approval

## Step 3: Verify directory structure and detect architecture

The extracted app directory must be named `commerce-<appName>-app-v<version>/`.

**Detect architecture type:**
```bash
cd <domain>/<isv-name>/

# Check for storefront-next
HAS_UI=$(find commerce-<appName>-app-v<version>/ -type d -name "storefront-next" | wc -l)

# Check for cartridges
HAS_BACKEND=$(find commerce-<appName>-app-v<version>/ -type d -name "cartridges" | wc -l)

# Determine architecture
if [ $HAS_UI -gt 0 ] && [ $HAS_BACKEND -eq 0 ]; then
    echo "UI-only"
elif [ $HAS_BACKEND -gt 0 ] && [ $HAS_UI -eq 0 ]; then
    echo "Backend-only"
elif [ $HAS_UI -gt 0 ] && [ $HAS_BACKEND -gt 0 ]; then
    echo "Fullstack"
fi
```

**Expected structure by architecture:**

### All Architectures (Required)
```
commerce-<appName>-app-v<version>/
├── commerce-app.json              # App identity & metadata
├── README.md                      # Documentation
├── app-configuration/
│   └── tasksList.json             # Merchant post-install checklist
└── icons/                         # App icon (recommended)
```

### UI-only Architecture
```
commerce-<appName>-app-v<version>/
├── (all base files above)
└── storefront-next/src/extensions/<app-name>/
    ├── target-config.json         # Extension target mappings
    ├── index.ts                   # Barrel exports
    ├── components/                # React components (.tsx)
    ├── hooks/                     # Custom React hooks
    ├── providers/                 # Context providers
    ├── locales/                   # i18n (en-US, en-GB, it-IT)
    └── tests/                     # Component tests
```

### Backend-only Architecture
```
commerce-<appName>-app-v<version>/
├── (all base files above)
├── cartridges/
│   ├── site_cartridges/<cartridge_name>/
│   │   ├── package.json           # Hooks path, test scripts
│   │   ├── cartridge/scripts/
│   │   │   ├── hooks.json         # Hook → script mappings
│   │   │   ├── hooks/             # Hook implementations
│   │   │   ├── helpers/           # Business logic
│   │   │   └── services/          # Service wrappers
│   │   └── test/                  # Unit tests
│   └── bm_cartridges/<bm_name>/   # BM extensions (optional)
└── impex/
    ├── install/
    │   ├── services.xml           # Service definitions
    │   ├── meta/system-objecttype-extensions.xml  # Site prefs
    │   └── sites/SITEID/preferences.xml
    └── uninstall/
        └── services.xml           # Service cleanup
```

### Fullstack Architecture
```
commerce-<appName>-app-v<version>/
├── (all base files above)
├── storefront-next/               # UI files (as in UI-only)
├── cartridges/                    # Backend files (as in Backend-only)
└── impex/                         # Backend config (as in Backend-only)
```

Validate that every file referenced by the code actually exists and architecture-specific directories are correct.

## Step 4: Update commerce-app.json

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

## Step 5: Delete old ZIP versions

**CRITICAL:** Before generating the new ZIP, delete any existing ZIP files for this app to avoid clutter:

```bash
cd <domain>/<isv-name>/
rm -f <appName>-v*.zip
```

This ensures:
- Only the latest version is in the repository
- No confusion about which ZIP is current
- Clean git status

## Step 6: Generate the ZIP

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
   - Architecture-specific directories present:
     - UI-only: Has `storefront-next/`, NO `cartridges/` or `impex/`
     - Backend-only: Has `cartridges/` and `impex/`, NO `storefront-next/`
     - Fullstack: Has `storefront-next/`, `cartridges/`, AND `impex/`

## Step 7: Compute SHA256 hash

Generate the hash for the ZIP:

```bash
shasum -a 256 <domain>/<isv-name>/<appName>-v<version>.zip
```

Copy the hex digest (the long string before the filename).

## Step 8: Update root manifest

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

Valid domains: `tax`, `payment`, `shipping`, `gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`, `fraud`.

**For new apps:** Add a new entry to the appropriate domain array.
**For updates:** Update the existing entry's `version`, `zip`, and `sha256` fields.

## Step 9: Handle catalog.json

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

## Step 10: Final validation checklist

**All architectures:**
- [ ] ZIP name matches `<appName>-v<version>.zip`
- [ ] ZIP contains a single root folder `commerce-<appName>-app-v<version>/`
- [ ] No junk files (`.DS_Store`, `__MACOSX`, hidden files)
- [ ] `commerce-app.json` version matches the ZIP version
- [ ] `app-configuration/tasksList.json` exists with merchant post-installation tasks
- [ ] `commerce-apps-manifest/manifest.json` is updated with correct version and hash
- [ ] `sha256` in root manifest matches the actual ZIP hash
- [ ] `catalog.json` included only for brand new apps
- [ ] Architecture detected correctly (UI-only, Backend-only, or Fullstack)

**UI-only or Fullstack:**
- [ ] `storefront-next/src/extensions/<app-name>/target-config.json` exists
- [ ] `storefront-next/src/extensions/<app-name>/index.ts` exists
- [ ] All three locale directories present: `locales/en-US/`, `locales/en-GB/`, `locales/it-IT/`

**Backend-only or Fullstack:**
- [ ] `cartridges/site_cartridges/<cartridge>/` exists with at least one cartridge
- [ ] `cartridges/site_cartridges/<cartridge>/package.json` includes `"hooks"` field
- [ ] `impex/install/` directory exists
- [ ] `impex/uninstall/` directory exists for cleanup

## Step 11: Clean up extracted directory

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
