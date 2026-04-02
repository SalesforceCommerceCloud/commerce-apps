---
name: diff-versions
description: >-
  Compare two versions of a commerce app to identify all changes between releases. Use this skill
  immediately when users mention "what changed", "compare versions", "diff", "show changes", "changelog",
  "see differences", or when reviewing version updates. Also trigger proactively BEFORE submitting PRs
  to help users understand what they're submitting, or when users ask about specific versions to help
  them understand the evolution of an app. Generates detailed file-by-file comparison showing additions,
  deletions, and modifications - essential for code review and changelog generation.
---

# Compare App Versions

Compare two versions of a commerce app to identify what changed between releases.

## Step 1: Identify versions to compare

Gather information:
- App domain and name (e.g., `tax/avalara-tax`)
- Old version (e.g., `0.2.7`)
- New version (e.g., `0.2.8`)

Verify both ZIPs exist:
```bash
ls -lh <domain>/<isv-name>/<appName>-v<oldVersion>.zip
ls -lh <domain>/<isv-name>/<appName>-v<newVersion>.zip
```

## Step 2: Extract both versions

Extract both versions for comparison:

```bash
cd <domain>/<isv-name>/

# Extract old version
unzip -q <appName>-v<oldVersion>.zip

# Extract new version
unzip -q <appName>-v<newVersion>.zip
```

This creates:
- `commerce-<appName>-app-v<oldVersion>/`
- `commerce-<appName>-app-v<newVersion>/`

## Step 3: High-level file comparison

Compare directory structures:

```bash
# List files in both versions
find commerce-<appName>-app-v<oldVersion>/ -type f | sort > /tmp/old_files.txt
find commerce-<appName>-app-v<newVersion>/ -type f | sort > /tmp/new_files.txt

# Show what changed at file level
diff /tmp/old_files.txt /tmp/new_files.txt
```

**Look for:**
- Files added (lines starting with `>`)
- Files removed (lines starting with `<`)
- Changed file count

## Step 4: Compare key configuration files

### Compare commerce-app.json

```bash
diff -u commerce-<appName>-app-v<oldVersion>/commerce-app.json \
        commerce-<appName>-app-v<newVersion>/commerce-app.json
```

**Check for:**
- Version number change (expected)
- Dependency updates
- Publisher information changes
- New or removed fields

### Compare package.json

```bash
diff -u commerce-<appName>-app-v<oldVersion>/cartridges/*/package.json \
        commerce-<appName>-app-v<newVersion>/cartridges/*/package.json
```

**Check for:**
- Dependency version bumps
- New dependencies
- Script changes
- DevDependency updates

### Compare hooks.json

```bash
diff -u commerce-<appName>-app-v<oldVersion>/cartridges/*/cartridge/scripts/hooks.json \
        commerce-<appName>-app-v<newVersion>/cartridges/*/cartridge/scripts/hooks.json
```

**Check for:**
- New hooks added
- Hook script path changes
- Removed hooks

### Compare services.xml

```bash
diff -u commerce-<appName>-app-v<oldVersion>/impex/install/services.xml \
        commerce-<appName>-app-v<newVersion>/impex/install/services.xml
```

**Check for:**
- Service configuration changes
- New service endpoints
- Credential structure changes

## Step 5: Detailed code comparison

Compare source code directories:

```bash
# Compare all JavaScript files
diff -r commerce-<appName>-app-v<oldVersion>/cartridges/ \
        commerce-<appName>-app-v<newVersion>/cartridges/ \
        --exclude="node_modules" --exclude="*.log"
```

For better visualization, use git diff style:
```bash
# Create a temporary git repo for diffing
cd commerce-<appName>-app-v<oldVersion>/
git init
git add .
git commit -m "Old version"

# Copy new files over
cp -r ../commerce-<appName>-app-v<newVersion>/* .

# Show diff
git diff
```

## Step 6: Generate comparison report

Create a structured comparison report:

```markdown
## Version Comparison Report

**App:** <displayName>
**Old Version:** v<oldVersion>
**New Version:** v<newVersion>
**Comparison Date:** <current_date>

### Summary of Changes

**Files Modified:** <count>
**Files Added:** <count>
**Files Deleted:** <count>
**Total Files:** <old_count> → <new_count>

### Configuration Changes

#### commerce-app.json
- Version: <oldVersion> → <newVersion>
- [List other changes if any]

#### Dependencies
- [List dependency updates from package.json]

#### Hooks
- [List new/modified/removed hooks from hooks.json]

#### Services
- [List service configuration changes from services.xml]

### Code Changes

#### Modified Files
<list files with brief description of changes>

#### New Files
<list newly added files>

#### Deleted Files
<list removed files>

### Breaking Changes
<list any breaking changes found>

### Security Considerations
<note any security-relevant changes>

### Recommendations
<suggestions for reviewers or deployers>
```

## Step 7: Focused comparisons

### Compare specific file types

**JavaScript files only:**
```bash
diff -ur commerce-<appName>-app-v<oldVersion>/cartridges/ \
         commerce-<appName>-app-v<newVersion>/cartridges/ \
         --include="*.js"
```

**JSON files only:**
```bash
diff -ur commerce-<appName>-app-v<oldVersion>/ \
         commerce-<appName>-app-v<newVersion>/ \
         --include="*.json"
```

**XML files only:**
```bash
diff -ur commerce-<appName>-app-v<oldVersion>/impex/ \
         commerce-<appName>-app-v<newVersion>/impex/ \
         --include="*.xml"
```

### Compare file sizes

Check if any files grew or shrank significantly:

```bash
# Compare file sizes
find commerce-<appName>-app-v<oldVersion>/ -type f -exec wc -c {} \; | sort > /tmp/old_sizes.txt
find commerce-<appName>-app-v<newVersion>/ -type f -exec wc -c {} \; | sort > /tmp/new_sizes.txt

diff /tmp/old_sizes.txt /tmp/new_sizes.txt
```

Large size changes might indicate:
- Added/removed dependencies
- New features or removed code
- Added assets or documentation

## Step 8: Semantic comparison

Look for specific types of changes:

### API changes
```bash
# Search for function definitions in old version
grep -rn "function\|module.exports" commerce-<appName>-app-v<oldVersion>/cartridges/

# Compare with new version
grep -rn "function\|module.exports" commerce-<appName>-app-v<newVersion>/cartridges/
```

### Configuration changes
```bash
# Compare all configuration files
diff -r commerce-<appName>-app-v<oldVersion>/app-configuration/ \
        commerce-<appName>-app-v<newVersion>/app-configuration/
```

### Test changes
```bash
# Compare test files
diff -r commerce-<appName>-app-v<oldVersion>/cartridges/*/test/ \
        commerce-<appName>-app-v<newVersion>/cartridges/*/test/
```

## Step 9: Side-by-side comparison

For visual comparison, use side-by-side diff:

```bash
diff -y commerce-<appName>-app-v<oldVersion>/commerce-app.json \
        commerce-<appName>-app-v<newVersion>/commerce-app.json
```

Or use a diff tool:
```bash
# macOS
opendiff commerce-<appName>-app-v<oldVersion>/ \
         commerce-<appName>-app-v<newVersion>/

# Linux with meld
meld commerce-<appName>-app-v<oldVersion>/ \
     commerce-<appName>-app-v<newVersion>/
```

## Step 10: Clean up after comparison

**Always** remove extracted directories after comparison:

```bash
cd <domain>/<isv-name>/
rm -rf commerce-<appName>-app-v<oldVersion>/
rm -rf commerce-<appName>-app-v<newVersion>/
rm /tmp/old_files.txt /tmp/new_files.txt
```

**IMPORTANT:**
- Extracted directories should NEVER be committed to the repository
- They are for comparison and inspection only
- Only ZIP and catalog.json belong in the app directory
- Root manifest (commerce-apps-manifest/manifest.json) must be updated separately
- Always verify with `git status` that no extracted directories are staged

## Use cases

### Use case 1: PR Review
Compare versions to understand what changed in a PR before approving.

### Use case 2: Changelog Generation
Generate a changelog by comparing versions and documenting changes.

### Use case 3: Regression Investigation
Compare versions to find what changed that might have caused a regression.

### Use case 4: Migration Planning
Compare versions to plan migration steps and identify breaking changes.

### Use case 5: Learning
Compare versions of reference apps to learn best practices and patterns.

## Quick comparison commands

**Quick file count:**
```bash
find commerce-<appName>-app-v<oldVersion>/ -type f | wc -l
find commerce-<appName>-app-v<newVersion>/ -type f | wc -l
```

**Quick size comparison:**
```bash
du -sh commerce-<appName>-app-v<oldVersion>/
du -sh commerce-<appName>-app-v<newVersion>/
```

**Quick code diff (summary only):**
```bash
diff -rq commerce-<appName>-app-v<oldVersion>/ \
         commerce-<appName>-app-v<newVersion>/ \
         --exclude="node_modules"
```

## Comparison checklist

- [ ] Both versions extracted successfully
- [ ] File structure comparison completed
- [ ] Configuration files compared (commerce-app.json, package.json, hooks.json)
- [ ] Code changes identified and reviewed
- [ ] New/deleted files documented
- [ ] Breaking changes identified
- [ ] Security implications considered
- [ ] Report generated (if needed)
- [ ] Extracted directories cleaned up

## Tips for effective comparisons

1. **Start high-level** - File counts and structure before diving into code
2. **Focus on what matters** - Prioritize hooks, services, and business logic
3. **Ignore noise** - Skip generated files, logs, and dependencies
4. **Document findings** - Create a report for future reference
5. **Use visual tools** - GUI diff tools are great for detailed code review
6. **Test before and after** - If possible, test both versions to validate changes
