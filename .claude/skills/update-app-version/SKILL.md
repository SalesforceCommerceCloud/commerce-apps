---
name: update-app-version
description: >-
  Streamline version bumps for existing commerce apps. Updates version in commerce-app.json,
  renames directories, regenerates ZIP with new version, and updates root manifest with
  new hash. Use when releasing a new version of an existing app.
---

# Update App Version

Streamline the process of bumping version numbers for existing commerce apps.

## Step 1: Determine version bump

Identify the version change:
- Current version (from existing catalog.json or ZIP)
- New version (semantic versioning: major.minor.patch)

**Semantic versioning guide:**
- **Major** (x.0.0): Breaking changes, incompatible API changes
- **Minor** (0.x.0): New features, backwards-compatible
- **Patch** (0.0.x): Bug fixes, backwards-compatible

Example: `0.2.7` → `0.2.8` (patch), or `0.2.8` → `0.3.0` (minor)

## Step 2: Extract current version

Extract the latest ZIP to work with:

```bash
cd <domain>/<isv-name>/
unzip -q <appName>-v<currentVersion>.zip
```

This creates: `commerce-<appName>-app-v<currentVersion>/`

## Step 3: Update commerce-app.json

Edit the version field in commerce-app.json:

```bash
cd commerce-<appName>-app-v<currentVersion>/
```

Open `commerce-app.json` and update:
```json
{
  "id": "<appName>",
  "name": "<displayName>",
  "version": "<newVersion>",  // UPDATE THIS
  ...
}
```

**Important:** Only update the `version` field. Do not modify other fields unless specifically needed.

## Step 4: Make other necessary changes

If this version bump includes code changes, make them now:

**Common changes:**
- Bug fixes in cartridge scripts
- Updated hooks or services
- New features in extensions
- Updated README.md
- Modified tasksList.json

**Remember to:**
- Test changes locally if possible
- Update README.md with new features or fixes
- Document breaking changes
- Update dependencies if needed

## Step 5: Rename directory to new version

Rename the directory to match the new version:

```bash
cd <domain>/<isv-name>/
mv commerce-<appName>-app-v<currentVersion>/ commerce-<appName>-app-v<newVersion>/
```

**Critical:** Directory name must exactly match:
```
commerce-<appName>-app-v<newVersion>/
```

## Step 6: Generate new ZIP

Create the ZIP for the new version:

```bash
cd <domain>/<isv-name>/
zip -r <appName>-v<newVersion>.zip commerce-<appName>-app-v<newVersion>/ \
  -x "*.DS_Store" -x "__MACOSX/*" -x "*/.*" -x "Thumbs.db"
```

**Verify the ZIP:**
```bash
unzip -l <appName>-v<newVersion>.zip | head -20
```

Check for:
- [ ] Single root folder: `commerce-<appName>-app-v<newVersion>/`
- [ ] No junk files (.DS_Store, __MACOSX, hidden files)
- [ ] commerce-app.json is included

## Step 7: Compute new SHA256 hash

Generate the hash for the new ZIP:

```bash
shasum -a 256 <domain>/<isv-name>/<appName>-v<newVersion>.zip
```

Copy the hex digest (the long string before the filename).

## Step 8: Update root manifest

**CRITICAL:** Update the root manifest at `commerce-apps-manifest/manifest.json`:

Find your app's entry in the appropriate domain array (e.g., `tax`, `payment`, `gift-cards`) and update:

```json
{
  "id": "<appName>",
  "name": "<displayName>",
  "description": "<description>",
  "iconName": "<appName>.png",
  "domain": "<domain>",
  "type": "app",
  "provider": "thirdParty",
  "version": "<newVersion>",      // UPDATE
  "zip": "<appName>-v<newVersion>.zip",  // UPDATE
  "sha256": "<new_computed_hash>"  // UPDATE
}
```

**Fields to update:**
- `version` - new version number
- `zip` - new ZIP filename
- `sha256` - new computed hash

**Do NOT modify:**
- `id`, `name`, `description`, `iconName`, `domain`, `type`, `provider`

## Step 9: Verify manifest matches ZIP

Double-check that the root manifest is correct:

```bash
# Verify ZIP exists
ls -lh <domain>/<isv-name>/<appName>-v<newVersion>.zip

# Verify hash matches
shasum -a 256 <domain>/<isv-name>/<appName>-v<newVersion>.zip
# Compare output with sha256 field in commerce-apps-manifest/manifest.json
```

**They must match exactly!**

## Step 10: Clean up extracted directories and old files

Remove extracted directories and old files:

```bash
cd <domain>/<isv-name>/

# Delete BOTH extracted directories (these should never be committed)
rm -rf commerce-<appName>-app-v<currentVersion>/
rm -rf commerce-<appName>-app-v<newVersion>/

# Delete old ZIP (optional - keep for rollback if needed)
rm <appName>-v<currentVersion>.zip
```

**What should remain in the directory:**
```
<domain>/<isv-name>/
├── <appName>-v<newVersion>.zip    ✅ Keep (to commit)
└── catalog.json                    ✅ Keep (already committed)

commerce-apps-manifest/
└── manifest.json                   ✅ Updated (to commit)
```

**Note:**
- Extracted directories should NEVER be committed to git
- Consider keeping old ZIP temporarily until new version is validated and merged
- Only the ZIP, catalog.json, and updated root manifest belong in the commit

## Step 11: catalog.json Rules

**Important:** For existing apps, follow these rules for `catalog.json`:

### ❌ Do NOT:
- Add new versions to the `versions` array (CI does this automatically on merge)
- Modify the `latest` object (CI manages this)
- Remove versions from the array
- Change existing version metadata (tag, sha256, releaseDate)

### ✅ You MAY:
- Add `"deprecated": true` to existing versions that should no longer be used

**Example - Deprecating a version:**
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
    }
  ]
}
```

**Why deprecate?**
- Security vulnerability
- Critical bug
- No longer supported
- Requires migration to newer version

**CI Workflow:** The `update-catalog.yml` workflow automatically adds your new version to the catalog on merge.

## Step 12: Validate the update

Run validation before committing:

Use `/validate-commerce-app` skill to verify:
- [ ] Root manifest has correct version and hash
- [ ] ZIP structure is correct
- [ ] commerce-app.json version matches root manifest
- [ ] No junk files in ZIP
- [ ] catalog.json is unchanged

## Step 13: Commit and PR

Create a commit with the version update:

```bash
git add <domain>/<isv-name>/<appName>-v<newVersion>.zip
git add commerce-apps-manifest/manifest.json

# If you deleted old ZIP
git rm <domain>/<isv-name>/<appName>-v<currentVersion>.zip

git commit -m "Update <displayName> to v<newVersion>"
```

Then follow the `/submit-app-pr` skill to create the PR.

## Quick reference checklist

- [ ] Extract current version ZIP
- [ ] Update `version` in commerce-app.json
- [ ] Make any code changes needed for this version
- [ ] Rename directory to match new version
- [ ] Generate new ZIP with exclusions
- [ ] Compute new SHA256 hash
- [ ] Update commerce-apps-manifest/manifest.json (version, zip, sha256)
- [ ] Verify hash matches
- [ ] Delete old ZIP and extracted directories
- [ ] Do NOT modify catalog.json
- [ ] Run `/validate-commerce-app`
- [ ] Commit changes
- [ ] Create PR with `/submit-app-pr`

## Common pitfalls

| Issue | Cause | Fix |
|-------|-------|-----|
| SHA256 mismatch | Hash not recomputed after ZIP creation | Recompute hash and update root manifest |
| Version mismatch | commerce-app.json not updated | Edit commerce-app.json to match root manifest |
| Wrong directory name | Directory not renamed | Rename to `commerce-<appName>-app-v<newVersion>/` |
| Junk files in ZIP | Didn't use exclusion flags | Regenerate ZIP with `-x` flags |
| catalog.json modified | Manually edited | Revert changes to catalog.json |

## Tips for smooth version updates

1. **Always extract first** - Never try to edit files inside the ZIP directly
2. **Test changes** - If possible, deploy and test the app before packaging
3. **Document changes** - Update README.md with what changed in this version
4. **Keep old ZIP temporarily** - Easy rollback if something goes wrong
5. **Validate before commit** - Catch issues early with `/validate-commerce-app`
6. **Use semantic versioning** - Major.Minor.Patch has meaning
