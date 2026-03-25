## Commerce App Submission

**App Name:**
**Display Name:**
**Domain:** <!-- tax, payment, shipping, gift-cards, ratings-and-reviews, loyalty, search, address-verification, analytics, approaching-discounts -->
**ISV/Vendor Name:**
**Version:**

## Type of Change

- [ ] New app submission
- [ ] App version update
- [ ] Bug fix for existing app
- [ ] Documentation update
- [ ] Other (please describe):

## Changes Made

<!-- Describe what this PR includes -->

## Checklist

### Required Files
- [ ] ZIP file name follows format: `{appName}-v{version}.zip`
- [ ] ZIP contains single root folder: `commerce-{appName}-app-v{version}/`
- [ ] `manifest.json` includes all required fields (name, displayName, domain, description, version, zip, sha256)
- [ ] `catalog.json` included for new apps only (with INIT values)
- [ ] If updating existing app: Did NOT add new versions to `catalog.json` (CI handles this)
- [ ] If deprecating a version: Added `"deprecated": true` to existing version in `catalog.json`

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

### Icons (Optional but Recommended)
- [ ] Icon included in `icons/` directory at CAP root (if applicable)
- [ ] Icon named `{isv-name}.{ext}` (e.g., `avalara.png`)
- [ ] Icon format is PNG, SVG, JPG, or JPEG
- [ ] Icon validated (CI will check for icon changes and warn if different from existing)

### Directory Structure
- [ ] App follows structure: `{domain}/{isv-name}/`
- [ ] Only ZIP, manifest.json, and catalog.json are committed
- [ ] No extracted directories (`commerce-*-app-v*/`) committed
- [ ] No system files (`.DS_Store`, `Thumbs.db`) committed

### Validation (if using Claude Code)
- [ ] Ran `/validate-commerce-app` skill
- [ ] Ran `/validate-impex` skill (if app contains impex files)
- [ ] All validation checks passed

### Impex Files (if applicable)
- [ ] Service install file has matching uninstall file
- [ ] Uninstall files use `mode="delete"`
- [ ] All attribute IDs prefixed with app name
- [ ] No hardcoded production credentials in services.xml
- [ ] SITEID placeholder used (not actual site ID)
- [ ] XML files are well-formed and valid

## Testing

<!-- Describe how you tested this app -->

- [ ] Tested installation in sandbox environment
- [ ] Verified service configurations work
- [ ] Tested site preferences are configurable
- [ ] Verified hooks execute correctly
- [ ] Tested UI components render properly (if applicable)
- [ ] Ran unit tests (if applicable)

## Screenshots (if applicable)

<!-- Add screenshots of the app in action, BM configuration screens, etc. -->

## Additional Notes

<!-- Any additional context, migration notes, breaking changes, etc. -->

## Reviewer Notes

<!-- For reviewers: any specific areas to focus on? -->

---

**By submitting this PR, I confirm that:**
- I have read and followed the [CONTRIBUTING.md](../CONTRIBUTING.md) guidelines
- My app follows the required directory structure: `{domain}/{isv-name}/`
- I am only committing ZIP, manifest.json, and catalog.json (no extracted directories)
- All hardcoded credentials are placeholders, not production values
- I have signed the Contributor License Agreement (CLA) if I am an external contributor
