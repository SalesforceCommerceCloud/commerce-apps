---
name: inspect-app
description: >-
  Extract and inspect a commerce app ZIP to explore its structure and contents without modification.
  Use this skill immediately when users want to "look at", "inspect", "explore", "review", "examine",
  or "see what's inside" any app ZIP. Also trigger when users mention specific app names to learn from
  them, when debugging issues, during code review, or when they want to understand how an existing app
  works. This is a READ-ONLY operation perfect for learning and investigation - use it proactively
  whenever users express curiosity about any app's implementation, structure, or contents.
---

# Extract and Inspect Commerce App

Safely extract and inspect commerce app ZIP files without making modifications.

## Step 1: Identify ZIP to extract

Parse the input and locate the ZIP file. Since each app directory only has ONE ZIP version, auto-detect it.

**Usage:**
```bash
/extract-and-inspect avalara-tax
/extract-and-inspect tax/avalara-tax
```

**Find the ZIP:**

```bash
# If input is just app name (e.g., "avalara-tax")
# Search for it in all domain directories
find . -name "*<app-name>-v*.zip" -type f | head -1

# If input is domain/app (e.g., "tax/avalara-tax")
# Look directly in that directory
ls <domain>/<app-name>/*-v*.zip | head -1
```

**Expected result:** Single ZIP path like `tax/avalara-tax/avalara-tax-v0.2.8.zip`

Extract the components from the ZIP path:
- Domain: `tax`
- App directory: `avalara-tax`
- Full ZIP name: `avalara-tax-v0.2.8.zip`
- Version: `0.2.8`

## Step 2: Pre-extraction validation

Before extracting, verify ZIP integrity:

```bash
# Check if ZIP exists
ls -lh <domain>/<isv-name>/<appName>-v<version>.zip

# List contents without extracting
unzip -l <domain>/<isv-name>/<appName>-v<version>.zip

# Verify ZIP is not corrupted
unzip -t <domain>/<isv-name>/<appName>-v<version>.zip
```

**Check for red flags:**
- Multiple root folders (should only be one)
- Path prefixes like `tax/`, `domain/` in the ZIP
- Junk files: `.DS_Store`, `__MACOSX`, `Thumbs.db`
- Hidden files (starting with `.`)
- Unexpected file extensions

## Step 3: Extract ZIP

Extract to the app's directory:

```bash
cd <domain>/<isv-name>/
unzip -q <appName>-v<version>.zip
```

Expected result:
- Creates directory: `commerce-<appName>-app-v<version>/`
- All app files nested inside this single root folder

**Note:** If the directory already exists, you may need to remove it first:
```bash
rm -rf commerce-<appName>-app-v<version>/
unzip -q <appName>-v<version>.zip
```

## Step 4: Inspect directory structure

Generate and review the directory tree:

```bash
cd commerce-<appName>-app-v<version>/
tree -L 3 -I 'node_modules|*.log'
```

Or if tree is not available:
```bash
find . -type f -not -path "*/node_modules/*" | head -50
```

**Expected structure:**
```
commerce-<appName>-app-v<version>/
├── commerce-app.json
├── README.md
├── app-configuration/
│   └── tasksList.json
├── cartridges/
│   ├── site_cartridges/<cartridge_name>/
│   │   ├── package.json
│   │   ├── cartridge/scripts/
│   │   └── test/
│   └── bm_cartridges/<bm_cartridge_name>/
├── storefront-next/src/extensions/<app-name>/
│   ├── target-config.json
│   ├── components/
│   ├── context/
│   ├── hooks/
│   ├── locales/
│   ├── middlewares/
│   ├── providers/
│   ├── routes/
│   ├── stores/
│   └── tests/
├── impex/
│   ├── install/
│   │   ├── services.xml
│   │   ├── meta/system-objecttype-extensions.xml
│   │   └── sites/SITEID/preferences.xml
│   └── uninstall/
│       └── services.xml
└── icons/
```

## Step 5: Inspect key files

Read and validate key configuration files:

### commerce-app.json
```bash
cat commerce-app.json | jq .
```

**Check:**
- [ ] `id` matches app name
- [ ] `version` matches expected version
- [ ] `domain` is correct
- [ ] Publisher information is complete

### README.md
```bash
head -30 README.md
```

**Check:**
- [ ] Clear installation instructions
- [ ] Configuration documentation
- [ ] Support/contact information

### Hooks configuration
```bash
cat cartridges/site_cartridges/*/cartridge/scripts/hooks.json | jq .
```

**Check:**
- [ ] Hook names follow conventions
- [ ] Script paths are valid
- [ ] All referenced scripts exist

### Services configuration
```bash
cat impex/install/services.xml
```

**Check:**
- [ ] Service ID is unique
- [ ] Profile and credential IDs are consistent
- [ ] Service definitions reference correct cartridge paths

## Step 6: Validate file references

Check that all referenced files actually exist:

```bash
# Find all .js files referenced in hooks.json
grep -r "\.js" cartridges/*/cartridge/scripts/hooks.json

# Verify those files exist
ls -la cartridges/*/cartridge/scripts/hooks/
ls -la cartridges/*/cartridge/scripts/helpers/
ls -la cartridges/*/cartridge/scripts/services/
```

## Step 7: Check for common issues

Run automated checks:

```bash
# Check for junk files that shouldn't be there
find . -name ".DS_Store" -o -name "Thumbs.db" -o -name "*.swp"

# Check for node_modules (shouldn't be in ZIP)
find . -type d -name "node_modules"

# Check for absolute paths (bad practice)
grep -r "/Users/" . 2>/dev/null || echo "No absolute paths found"
grep -r "C:\\\\" . 2>/dev/null || echo "No absolute Windows paths found"

# Check for TODO/FIXME comments
grep -rn "TODO\|FIXME" cartridges/ || echo "No TODOs found"

# Check for hardcoded credentials (security issue)
grep -ri "password\|apikey\|secret" cartridges/ impex/ || echo "No hardcoded secrets found"
```

## Step 8: Compare with reference implementation

If available, compare with the reference app (e.g., `avalara-tax`):

```bash
# Compare directory structures
diff <(cd /path/to/reference && find . -type f | sort) \
     <(cd /path/to/current && find . -type f | sort)

# Compare specific files
diff /path/to/reference/commerce-app.json ./commerce-app.json
```

## Step 9: Generate inspection report

Create a summary of findings:

**Report template:**

```markdown
## Inspection Report: <appName> v<version>

**Extracted from:** `<domain>/<isv-name>/<appName>-v<version>.zip`
**Extraction date:** <current_date>

### Directory Structure
- Root folder: `commerce-<appName>-app-v<version>/`
- Total files: <count>
- Cartridges: <list>
- Extensions: <list>

### Validation Results
- [ ] commerce-app.json valid
- [ ] All hook scripts exist
- [ ] Services configured correctly
- [ ] No junk files found
- [ ] No hardcoded secrets
- [ ] Documentation present

### Issues Found
<list any issues or none>

### Files Reviewed
- commerce-app.json
- README.md
- hooks.json
- services.xml
- <other key files>

### Recommendations
<any suggestions for improvement>
```

## Step 10: Clean up extracted directory

After inspection, **always** remove the extracted directory:

```bash
cd <domain>/<isv-name>/
rm -rf commerce-<appName>-app-v<version>/
```

**IMPORTANT:**
- Extracted directories should NEVER be committed to the repository
- They are for inspection, debugging, and development only
- Only ZIP and catalog.json belong in the app directory
- Root manifest (commerce-apps-manifest/manifest.json) must be updated separately

**Keep extracted directory temporarily if:**
- You need to make modifications and repackage
- You're actively comparing versions
- You're debugging an issue
- You're generating a new ZIP from it

**But always delete before committing to git!**

## Use cases

### Use case 1: Code review
Extract and review structure before approving a PR.

### Use case 2: Debugging
Extract to investigate why CI validation is failing.

### Use case 3: Learning
Extract reference apps to learn best practices and patterns.

### Use case 4: Version comparison
Extract multiple versions to compare changes (see `/compare-app-versions`).

### Use case 5: Re-packaging
Extract, modify, and re-package using `/generate-commerce-app`.
