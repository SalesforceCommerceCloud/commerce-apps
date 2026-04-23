# Contributing to Commerce App Registry

Please follow the guidelines below when submitting new or updated commerce app versions to ensure consistency and smooth reviews.

---

## Using Claude Code Skills

If you're using Claude Code, several skills are available to streamline the contribution process:

### Building Apps
- **`/scaffold-app`** - Generate initial directory structure and template files for a new commerce app from scratch
- **`/package-app`** - Package an existing app directory into a registry-ready Commerce App Package (CAP) ZIP

### Impex Generation
- **`/generate-service-impex`** - Generate SFCC service configuration impex (credentials, profiles, definitions)
- **`/generate-site-preferences-impex`** - Generate site preference impex with custom attributes and groups
- **`/generate-custom-object-impex`** - Generate custom object type impex for data storage
- **`/validate-impex`** - Validate all impex XML files for syntax and common errors

### Validation & Updates
- **`/validate-app`** - Comprehensive validation before submission (checks structure, manifest, SHA256, impex XML, icons, translations)
- **`/validate-impex`** - Deep validation of impex files only (useful during development, also included in `/validate-app`)
- **`/package-app`** - Package app into registry-ready ZIP (handles both new apps and version bumps)

### Submission
- **`/submit-app`** - Guide through the PR submission process with proper formatting and checklist

**Typical workflow:**
1. Start new app → `/scaffold-app`
2. Build your app code and logic
3. Package for registry → `/package-app`
4. Validate before submitting → `/validate-app`
5. Submit PR → `/submit-app`

These skills automate many of the manual steps described below and help catch common issues early.

---

## Pull Request Requirements

Each PR **must** include the following items:

> **Important:** Do NOT commit extracted app directories (e.g., `commerce-{appName}-app-v{version}/`). Only commit the ZIP file, `manifest.json`, and `catalog.json` (for new apps only). Extracted directories are for development/testing only and should be in `.gitignore`.

### 1. Commerce App ZIP File

Include the packaged app as a ZIP file with the following naming convention:

```
[appName]-v[appVersion].zip
```

**Example:**
```
avalara-tax-v1.0.0.zip
```

#### How to Generate the ZIP File

When creating your ZIP file, it's important to exclude system files and hidden files that shouldn't be included in the archive. Use the following commands based on your operating system:

##### macOS & Linux (Terminal)

Both macOS and Linux use the `zip` utility. The `-x` flag is your best friend here—it tells the utility to exclude specific patterns.

**The Command:**
```bash
zip -r my_archive.zip folder_to_zip/ -x "*.DS_Store" -x "__MACOSX/*" -x "*/.*" -x "Thumbs.db"
```

**Breakdown of the flags:**
- `-r`: Stands for "recursive." It tells the computer to look inside every subfolder.
- `"*.DS_Store"`: Excludes the macOS folder settings file.
- `"__MACOSX/*"`: Prevents the creation of those annoying resource fork folders.
- `"*/.*"`: The "nuclear option"—this excludes all hidden files (anything starting with a dot).
- `"Thumbs.db"`: Excludes the Windows thumbnail cache.

##### Windows (PowerShell)

Windows doesn't have a native "exclude" flag built into its basic `Compress-Archive` command. To do this cleanly without third-party software, you have to filter the files first and then pipe them into the zip command.

**The Command:**
```powershell
Get-ChildItem -Path ".\folder_name" -Recurse -File | Where-Object { 
    $_.FullName -notmatch '\\\.DS_Store$' -and 
    $_.FullName -notmatch '__MACOSX' -and 
    $_.Name -notmatch '^\.' -and
    $_.Name -notmatch 'Thumbs\.db'
} | Compress-Archive -DestinationPath "my_archive.zip"
```

**How this works:**
- `Get-ChildItem`: Grabs every file in your folder.
- `Where-Object`: This acts as a filter. We tell it to only keep files that do not match our "junk" patterns (no .DS_Store, no __MACOSX, no files starting with a dot, and no Thumbs.db).
- `Compress-Archive`: Takes that filtered list and zips it up.

#### Delete Old ZIP Versions

**CRITICAL:** Before committing a new version, delete any existing ZIP files for your app:

```bash
cd {domain}/{isv-name}/
rm -f {appName}-v*.zip  # Remove all old versions
```

**Why this matters:**
- Keeps the repository clean and focused on the latest version
- Prevents confusion about which version is current
- Reduces repository size
- Ensures clean git status for PR review

**What to keep:**
- ✅ Only the latest ZIP version (e.g., `avalara-tax-v1.0.0.zip`)
- ✅ `catalog.json` (managed by CI)

**What to delete:**
- ❌ All previous ZIP versions (e.g., `avalara-tax-v0.9.9.zip`)

The CI workflow on the main branch maintains historical versions, so old ZIPs are not needed in PRs or the repository.

---

### 2. Update Root Manifest

Each PR must update the root manifest at `commerce-apps-manifest/manifest.json` with your app’s metadata.

#### Required Fields

Find your app’s entry in the appropriate domain array (e.g., `tax`, `shipping`, `payment`, `gift-cards`) and update or add an entry with the following fields:

- `id` - App identifier (kebab-case)
- `name` - Display name
- `description` - App description
- `iconName` - Icon filename (e.g., `avalara.png`)
- `domain` - One of: `tax`, `payment`, `shipping`, `gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`, `fraud`
- `type` - Always `"app"` for commerce apps
- `provider` - Always `"thirdParty"` for ISV apps
- `version` - Semantic version (e.g., `"1.0.0"`)
- `zip` - ZIP filename (e.g., `"avalara-tax-v1.0.0.zip"`)
- `sha256` - SHA256 hash of the ZIP file

> **Note:** For new versions of an existing app, you must at minimum update the `version`, `zip`, and `sha256` fields.

#### Computing `sha256`

The `sha256` value must match the ZIP you are submitting. On **macOS**, you can generate it with:

```bash
shasum -a 256 /path/to/zip
```

Copy the hex digest from the output into the `sha256` field (without the filename suffix).

On **Linux**, the equivalent is usually `sha256sum /path/to/zip`.

#### Example Root Manifest Entries

**Standard domain (tax, payment, shipping):**
```json
{
  "tax": [
    {
      "id": "avalara-tax",
      "name": "Avalara",
      "description": "Automate your sales tax compliance with Avalara.",
      "iconName": "avalara.png",
      "domain": "tax",
      "type": "app",
      "provider": "thirdParty",
      "version": "1.0.0",
      "zip": "avalara-tax-v1.0.0.zip",
      "sha256": "492fb0bc3aa5c762c0209bd22375e14ed2af8f672b679d6105232a37fe726a4f"
    }
  ]
}
```

**Additional domain (multiple providers under one domain):**
```json
{
  "ratings-and-reviews": [
    {
      "id": "bazaarvoice-ratings",
      "name": "Bazaarvoice Ratings & Reviews",
      "description": "Customer ratings and reviews powered by Bazaarvoice.",
      "iconName": "bazaarvoice.png",
      "domain": "ratings-and-reviews",
      "type": "app",
      "provider": "thirdParty",
      "version": "1.0.0",
      "zip": "bazaarvoice-ratings-v1.0.0.zip",
      "sha256": "abc123..."
    },
    {
      "id": "yotpo-reviews",
      "name": "Yotpo Reviews",
      "description": "Product reviews and UGC powered by Yotpo.",
      "iconName": "yotpo.png",
      "domain": "ratings-and-reviews",
      "type": "app",
      "provider": "thirdParty",
      "version": "1.0.0",
      "zip": "yotpo-reviews-v1.0.0.zip",
      "sha256": "def456..."
    }
  ]
}
```

> Entries sharing the same domain are displayed as provider options under a single hub tile (e.g., a "Ratings & Reviews" tile with Bazaarvoice and Yotpo as choices). Domains `tax`, `payment`, and `shipping` show under "Providers" on the checkout hub; all other domains show under "Additional Setup".

---

## Repository Structure

Your app should be organized in the registry as follows:

```
{domain}/{isv-name}/
├── {appName}-v{version}.zip        # The packaged app (COMMIT THIS)
└── catalog.json                     # Version catalog (COMMIT THIS - new apps only)
```

**Example:**
```
tax/avalara/
├── avalara-tax-v0.2.8.zip
└── catalog.json

ratings-and-reviews/bazaarvoice/
├── bazaarvoice-ratings-v1.0.0.zip
└── catalog.json
```

**Root Manifest:**
```
commerce-apps-manifest/
├── manifest.json                    # Global app registry (UPDATE THIS)
└── icons/                           # Extracted app icons
```

> **Do NOT commit:** Extracted directories like `commerce-{appName}-app-v{version}/`. These are for development only.

## ZIP Structure Requirements

The ZIP file **must** contain a single root directory named:

```
commerce-[appName]-app-v[version]/
```

**Example ZIP contents:**
```
avalara-tax-v1.0.0.zip
└── commerce-avalara-tax-app-v1.0.0/
    ├── commerce-app.json
    ├── README.md
    ├── app-configuration/
    ├── cartridges/
    ├── storefront-next/
    ├── impex/
    └── icons/ (optional)
```

### Required Files

At minimum, your app directory must contain:

- **`commerce-app.json`** - App metadata (id, name, version, domain, publisher)
- **`README.md`** - Installation and configuration documentation
- **`app-configuration/tasksList.json`** - Post-install checklist
- **`cartridges/`** - At least one site or BM cartridge
- **`impex/install/services.xml`** - Service definitions
- **`impex/uninstall/services.xml`** - Cleanup instructions

### Optional Files

- **`icons/`** - App/ISV icon for display in the registry
  - Place icon files (PNG, SVG, JPG, or JPEG) in the `icons/` directory at the root of your CAP
  - Icons should be named `{isv-name}.{ext}` (e.g., `avalara.png`, `bazaarvoice.svg`)
  - **Icon Updates:**
    - ✅ **Allowed:** Submitting the same icon (same hash) in new app versions
    - ✅ **Allowed:** First-time icon submission for your ISV
    - ⚠️  **Allowed with warning:** Changing your ISV's icon (rebranding)
      - CI will warn about the icon change
      - The new icon will overwrite the existing one on merge
      - Reviewers will verify this is intentional
  - Recommended size: 512x512px for PNG/JPG, scalable for SVG
  - CI will automatically extract icons and add them to `commerce-apps-manifest/icons/` on merge
  - If no icon is provided, a default placeholder will be used

### commerce-app.json Validation

The `commerce-app.json` file inside your ZIP must match the root manifest entry:

```json
{
  "id": "avalara-tax",
  "name": "Avalara Tax",
  "version": "1.0.0",  // Must match root manifest version
  "domain": "tax",     // Must match root manifest domain
  "publisher": {
    "name": "Avalara",
    "url": "https://developer.avalara.com/",
    "support": "https://developer.avalara.com/"
  },
  "dependencies": {}
}
```

**Critical:** The `version` field in `commerce-app.json` **must** match the `version` in the root manifest (`commerce-apps-manifest/manifest.json`).

---

## Brand New Apps

If you are contributing a **brand new app**, you must also create a `catalog.json` file with **exactly** the following content so CI can update it:

```json
{
  "latest": {
    "version": "INIT",
    "tag": "INIT"
  },
  "versions": []
}
```

## Managing catalog.json

### Rules for catalog.json

The `catalog.json` file tracks version history and is managed primarily by CI. Follow these rules:

#### ✅ Allowed Changes

**1. Deprecating existing versions:**
You may add `"deprecated": true` to existing versions in the `versions` array to mark them as deprecated.

**Example:**
```json
{
  "latest": {
    "version": "1.0.2",
    "tag": "v1.0.2"
  },
  "versions": [
    {
      "version": "1.0.2",
      "tag": "v1.0.2",
      "sha256": "abc123...",
      "releaseDate": "2026-03-20"
    },
    {
      "version": "1.0.1",
      "tag": "v1.0.1",
      "sha256": "def456...",
      "releaseDate": "2026-03-15",
      "deprecated": true    // ✅ You can add this
    },
    {
      "version": "1.0.0",
      "tag": "v1.0.0",
      "sha256": "ghi789...",
      "releaseDate": "2026-03-10"
    }
  ]
}
```

**When to deprecate:**
- Security vulnerabilities found in a version
- Critical bugs that should prevent new installations
- Version no longer supported
- Breaking changes require migration

**Note:** Deprecated versions remain in the registry but may be hidden or flagged in the UI.

#### ❌ Prohibited Changes

**1. Adding new versions to the `versions` array:**
Do NOT manually add new version entries. CI automatically adds them when your PR is merged.

**Wrong:**
```json
{
  "versions": [
    {
      "version": "1.0.2",    // ❌ Don't add this manually
      "tag": "v1.0.2",
      "sha256": "...",
      "releaseDate": "2026-03-20"
    }
  ]
}
```

**Right:**
Submit your ZIP and manifest.json. CI adds the version entry automatically on merge.

**2. Modifying the `latest` object:**
Do NOT update the `latest` version. CI manages this automatically.

**3. Removing versions from the array:**
Do NOT delete version entries. Use `"deprecated": true` instead.

**4. Changing existing version metadata:**
Do NOT modify `tag`, `sha256`, or `releaseDate` of existing versions.

### Summary

| Action | Allowed? | Who Does It? |
|--------|----------|--------------|
| Create catalog.json for new app | ✅ Yes | Developer (with INIT values) |
| Add new version to versions array | ❌ No | CI (automatic on merge) |
| Update latest object | ❌ No | CI (automatic on merge) |
| Add "deprecated": true to existing version | ✅ Yes | Developer |
| Remove version from array | ❌ No | Never (use deprecated flag) |
| Modify existing version metadata | ❌ No | Never |

---

## Final Checklist

Before submitting your PR, please verify:

### Required Files
- [ ] ZIP file name follows the required format: `[appName]-v[version].zip`
- [ ] ZIP contains single root folder: `commerce-[appName]-app-v[version]/`
- [ ] `manifest.json` includes all required fields (name, displayName, domain, description, version, zip, sha256)
- [ ] `catalog.json` is included for new apps only (with INIT values)

### Version and Hash Validation
- [ ] `version` in `manifest.json` matches `version` in `commerce-app.json`
- [ ] `zip` field in `manifest.json` matches actual ZIP filename
- [ ] `sha256` in `manifest.json` matches computed hash of ZIP file
- [ ] SHA256 hash verified with: `shasum -a 256 [path-to-zip]`

### ZIP Content Validation
- [ ] No junk files (`.DS_Store`, `__MACOSX`, `Thumbs.db`, hidden files)
- [ ] No registry path prefixes in ZIP (no `tax/`, `domain/`, etc.)
- [ ] All required files present (commerce-app.json, README.md, tasksList.json, services.xml)
- [ ] All referenced scripts/files exist
- [ ] No absolute paths in code
- [ ] No hardcoded credentials

### Domain and Naming
- [ ] App follows structure: `{domain}/{isv-name}/`
- [ ] Directory names are consistent with version
- [ ] File references use relative paths

### Git Commit Checklist
- [ ] Only ZIP, manifest.json, and catalog.json are staged
- [ ] No extracted directories (commerce-*-app-*/) in git status
- [ ] No system files (.DS_Store, Thumbs.db) staged
- [ ] Old ZIP versions removed (if updating)

### CI Workflow Readiness
- [ ] Ran `/validate-app` skill (if using Claude Code)
- [ ] Tested ZIP extraction locally
- [ ] Reviewed ZIP contents with `unzip -l`
- [ ] Ready for `verify-zip.yml` CI workflow

### Icons (Optional but Recommended)
- [ ] Icon file included in `icons/` directory at CAP root
- [ ] Icon named `{isv-name}.{ext}` (e.g., `avalara.png`, `bazaarvoice.svg`)
- [ ] Icon format is PNG, SVG, JPG, or JPEG
- [ ] Icon is unique to your ISV (not a duplicate of another vendor's icon)
- [ ] Icon is high quality: 512x512px for raster formats, scalable for SVG
- [ ] If changing existing icon: Confirm this is intentional rebranding (CI will warn reviewers)

---

## Troubleshooting Common Issues

### SHA256 Hash Mismatch
**Problem:** CI reports SHA256 hash doesn't match.

**Solution:**
```bash
# Recompute the hash
shasum -a 256 [domain]/[appName]/[appName]-v[version].zip

# Update manifest.json with the exact output (hex string only)
```

### Junk Files in ZIP
**Problem:** CI detects `.DS_Store`, `__MACOSX`, or hidden files.

**Solution:** Recreate the ZIP with proper exclusions:
```bash
zip -r [appName]-v[version].zip commerce-[appName]-app-v[version]/ \
  -x "*.DS_Store" -x "__MACOSX/*" -x "*/.*" -x "Thumbs.db"
```

### Version Mismatch
**Problem:** `commerce-app.json` version doesn't match `manifest.json`.

**Solution:** Edit `commerce-app.json` inside the extracted directory, then regenerate the ZIP.

### Wrong ZIP Structure
**Problem:** ZIP contains multiple root folders or registry paths.

**Solution:** Ensure you're zipping from the correct directory:
```bash
cd [domain]/[appName]/
zip -r [appName]-v[version].zip commerce-[appName]-app-v[version]/
```

### Missing Required Files
**Problem:** CI can't find `commerce-app.json`, `services.xml`, or other required files.

**Solution:** Extract the ZIP and verify all required files exist in the correct locations:
```bash
unzip -l [appName]-v[version].zip
# Or extract fully to inspect:
unzip [appName]-v[version].zip
```

---

## .gitignore Configuration

Ensure your repository root `.gitignore` includes:

```gitignore
# Commerce App - Extracted directories (DO NOT COMMIT)
# Only commit ZIP files, manifest.json, and catalog.json
**/commerce-*-app-*/

# System files
.DS_Store
__MACOSX/
Thumbs.db

# IDE files
.vscode/
.idea/
*.iml
```

**What to commit:**
- ✅ `{appName}-v{version}.zip` - The packaged app
- ✅ `manifest.json` - App metadata
- ✅ `catalog.json` - Version catalog (new apps only)

**What NOT to commit:**
- ❌ `commerce-{appName}-app-v{version}/` - Extracted directories
- ❌ `.DS_Store` - macOS system files
- ❌ `node_modules/` - Dependencies
- ❌ Old ZIP versions

---

## Getting Help

- **CI Failures:** Check GitHub Actions logs for specific error messages
- **Validation Issues:** Use `/validate-app` skill for detailed diagnostics
- **Questions:** Open a discussion or contact the registry maintainers


