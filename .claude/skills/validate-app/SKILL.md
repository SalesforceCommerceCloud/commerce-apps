---
name: validate-app
description: >-
  Run comprehensive validation on a commerce app package before PR submission. Use this skill
  immediately before ANY submission attempt, when users mention "validate", "check app", "verify",
  "ready to submit", or after packaging an app. Also trigger proactively BEFORE calling submit-pr
  to catch errors early and save CI/CD cycles. This is a REQUIRED pre-submission step - don't let
  users submit without validation. Checks directory structure, manifest format, SHA256 hashes,
  impex XML syntax, and runs the complete CONTRIBUTING.md checklist. Use whenever debugging
  validation failures or import errors - it will identify the root cause.
---

# Validate Commerce App Package

Run comprehensive validation checks on a commerce app before submitting a PR.

## Step 1: Identify the app to validate

Gather or infer:
- Domain (one of: `tax`, `payment`, `shipping`, `gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`, `fraud`)
- App name (e.g., `avalara-tax`)
- Version to validate (or use latest ZIP in directory)

## Step 2: Validate ZIP file exists

Check that ZIP file exists at `<domain>/<isv-name>/<appName>-v<version>.zip`

## Step 3: Compute and verify SHA256

1. Compute SHA256 hash:
   ```bash
   shasum -a 256 <domain>/<isv-name>/<appName>-v<version>.zip
   ```

2. Read the root manifest at `commerce-apps-manifest/manifest.json`

3. Find your app's entry in the appropriate domain array (e.g., `tax`, `payment`, `gift-cards`)

4. Compare computed hash with `sha256` field in the manifest entry

5. **CRITICAL**: Hashes must match exactly

## Step 4: Validate root manifest entry

Check that the app entry in `commerce-apps-manifest/manifest.json` contains all required fields:

**Required fields:**
- `id` - must match app name
- `name` - human-readable display name
- `description` - app description
- `iconName` - icon filename (e.g., `avalara.png`)
- `domain` - must be one of: `tax`, `payment`, `shipping`, `gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`, `fraud`
- `type` - must be `"app"`
- `provider` - must be `"thirdParty"`
- `version` - semantic version (e.g., `0.2.8`)
- `zip` - must match `<appName>-v<version>.zip`
- `sha256` - must match actual ZIP hash

**Validation steps:**
1. Verify entry exists in correct domain array
2. Verify all required fields are present and non-empty
3. Verify `domain` is a valid value (hyphen-case)
4. Verify version format follows semantic versioning
6. Verify zip filename matches the actual file
7. Verify SHA256 matches computed hash

## Step 5: Validate ZIP contents

Extract and inspect the ZIP structure:

1. List ZIP contents without extracting:
   ```bash
   unzip -l <domain>/<isv-name>/<appName>-v<version>.zip
   ```

2. Check for common issues:
   - [ ] Single root folder named `commerce-<appName>-app-v<version>/`
   - [ ] No registry path prefixes (no `tax/`, `domain/`, etc.)
   - [ ] No junk files (`.DS_Store`, `__MACOSX`, `Thumbs.db`, hidden files)
   - [ ] No duplicate directory trees
   - [ ] commerce-app.json exists at root

3. Verify required files are present:
   - [ ] `commerce-app.json`
   - [ ] `README.md`
   - [ ] `app-configuration/tasksList.json`
   - [ ] `cartridges/` directory with at least one cartridge
   - [ ] `impex/install/services.xml`

## Step 6: Validate commerce-app.json

Extract and read `commerce-<appName>-app-v<version>/commerce-app.json`:

**Required fields:**
- `id` - must match app name
- `name` - display name
- `description`
- `domain` - must match root manifest domain
- `version` - must match root manifest version
- `publisher.name`
- `publisher.url`
- `publisher.support`

**Validation steps:**
1. Verify version in commerce-app.json matches root manifest version
2. Verify id matches app name
3. Verify domain matches
4. Check that publisher fields are valid URLs

## Step 7: Validate impex files

Extract the ZIP and validate all impex XML files for correctness:

### XML Syntax Validation

Validate all XML files are well-formed:
```bash
find commerce-<appName>-app-v<version>/impex/ -name "*.xml" -exec xmllint --noout {} \;
```

### Services Validation

**Install file (`impex/install/services.xml`):**
- [ ] XML namespace is `http://www.demandware.com/xml/impex/services/2015-07-01`
- [ ] All service IDs use dotted notation (e.g., `vendor.service.api`)
- [ ] All services reference valid credentials and profiles
- [ ] No hardcoded production credentials or secrets
- [ ] Timeouts are reasonable (5000-60000 ms)
- [ ] Rate limiting configured for external APIs

**Uninstall file (`impex/uninstall/services.xml`):**
- [ ] All services use `mode="delete"`
- [ ] Deletion order: service → profile → credential
- [ ] All service/profile/credential IDs match install file exactly

### Site Preferences Validation

**Metadata file (`impex/install/meta/system-objecttype-extensions.xml`):**
- [ ] XML namespace is `http://www.demandware.com/xml/impex/metadata/2006-10-31`
- [ ] All attribute IDs use camelCase (not snake_case)
- [ ] All attribute IDs prefixed with app name
- [ ] All attributes have display names and descriptions
- [ ] Default values match data types
- [ ] All attributes added to group definition
- [ ] Valid attribute types used (string, boolean, integer, enum-of-string, etc.)

**Preferences file (`impex/install/sites/SITEID/preferences.xml`):**
- [ ] Uses `SITEID` placeholder (not actual site ID)
- [ ] All preference IDs match attribute definitions
- [ ] Default values match data types
- [ ] No sensitive data (API keys, secrets)

### Custom Objects Validation (if present)

**Custom object definitions (`impex/install/meta/custom-objecttype-definitions.xml`):**
- [ ] `key-attribute` defined and mandatory
- [ ] Storage scope is `site` or `organization`
- [ ] Retention policy set (0 or 1-365 days)
- [ ] Valid staging mode (`no-sharing`, `shared`, or `source-to-target`)
- [ ] All attributes added to group

### Cross-File Validation

Verify install/uninstall pairs match:
```bash
# Extract and compare service IDs
grep 'service-id=' impex/install/services.xml | sed 's/.*service-id="\([^"]*\)".*/\1/' | sort > /tmp/install.txt
grep 'service-id=' impex/uninstall/services.xml | sed 's/.*service-id="\([^"]*\)".*/\1/' | sort > /tmp/uninstall.txt
diff /tmp/install.txt /tmp/uninstall.txt
```

### Common Impex Errors

Check for these common issues:
- [ ] No unescaped special characters (`&` → `&amp;`, `<` → `&lt;`, etc.)
- [ ] No duplicate service/credential/profile IDs
- [ ] Service IDs don't use underscores (use dots instead)
- [ ] Attribute IDs don't use underscores (use camelCase)
- [ ] All XML files are well-formed (no unclosed tags)

If any impex validation fails, report specific issues with file paths and lines.

## Step 8: Check for catalog.json

- If this is an **existing app** (catalog.json already exists):
  - [ ] Do NOT modify catalog.json - CI will update it
  - [ ] Verify catalog.json exists but unchanged in PR

- If this is a **brand new app** (no catalog.json):
  - [ ] Verify catalog.json is created with INIT values:
    ```json
    {
      "latest": {
        "version": "INIT",
        "tag": "INIT"
      },
      "versions": []
    }
    ```

## Step 9: Run final PR checklist

From CONTRIBUTING.md:

**Package Structure:**
- [ ] ZIP file name follows format: `<appName>-v<version>.zip`
- [ ] ZIP contains no junk files (.DS_Store, __MACOSX, etc.)
- [ ] No extracted directories are committed
- [ ] All file paths are relative to app root (no absolute paths)

**Manifest Validation:**
- [ ] Root manifest (commerce-apps-manifest/manifest.json) is updated
- [ ] Root manifest entry has all required fields
- [ ] version, zip, and sha256 in root manifest are correct
- [ ] SHA256 hash matches the actual ZIP file
- [ ] commerce-app.json version matches root manifest version
- [ ] catalog.json is included for new apps only (with INIT values)

**Impex Validation:**
- [ ] All XML files are well-formed (pass xmllint validation)
- [ ] Services have valid configuration and no hardcoded credentials
- [ ] Install/uninstall services match exactly
- [ ] Site preferences use camelCase and app-name prefixes
- [ ] SITEID placeholder used (not actual site ID)
- [ ] No sensitive data in impex files

## Report validation results

Provide a clear summary:
- **✅ PASS** - All validations passed, ready for PR
- **❌ FAIL** - List specific issues found with file paths and line numbers
- Provide fix recommendations for each issue
