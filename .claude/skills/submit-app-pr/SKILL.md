---
name: submit-app-pr
description: >-
  Submit a PR for commerce app registry. Checks GitHub CLI authentication and creates
  PR automatically if available, otherwise provides manual template. Validates requirements,
  ensures proper formatting, and prepares for CI workflows. Use when ready to submit.
---

# Submit Commerce App PR

Guide developers through the complete PR submission process for commerce app registry.

## Step 0: Check GitHub CLI and Authentication

**FIRST**, check if automated PR creation is available:

```bash
# Check if gh CLI is installed
which gh
```

**If `gh` is installed**, check authentication:
```bash
gh auth status --hostname github.com
```

### Authentication Results

**✅ If authenticated to github.com:**
- This skill will **automatically create the PR** for you
- Continue to next steps

**⚠️ If NOT authenticated to github.com:**

You have two options:

**Option A: Authenticate now (recommended)**
```bash
gh auth login --hostname github.com --web
```
Follow the prompts to authenticate. Once done, this skill will create the PR automatically.

**Option B: Create PR manually**
Skip authentication and this skill will provide a PR template at Step 6 for manual creation via web browser.

**❌ If `gh` CLI is not installed:**

You can install it or proceed with manual PR creation:

**To install:**
- macOS: `brew install gh`
- Linux: See https://cli.github.com/manual/installation
- Windows: Download from https://cli.github.com/

**Or proceed without it:**
This skill will provide a PR template for manual creation at Step 6.

---

## Step 1: Pre-submission validation

Before creating a PR, run validation checks:

1. Use the `/validate-commerce-app` skill to ensure:
   - [ ] All required files are present
   - [ ] Root manifest (commerce-apps-manifest/manifest.json) is updated
   - [ ] SHA256 hash matches
   - [ ] ZIP structure is correct
   - [ ] No junk files included

2. If validation fails, fix issues before proceeding

## Step 2: Check git status

Verify what will be included in the PR:

```bash
git status
```

**Expected changes for new app version:**
- Modified: `commerce-apps-manifest/manifest.json` (root manifest with your app entry)
- Added: `<domain>/<isv-name>/<appName>-v<version>.zip`
- Optional: Modified `<domain>/<isv-name>/catalog.json` (only if brand new app OR deprecating a version)

**IMPORTANT - Do NOT commit:**
- ❌ Extracted app directories (e.g., `commerce-<appName>-app-v<version>/`)
- ❌ node_modules
- ❌ .DS_Store or other junk files
- ❌ Old ZIP versions (delete before committing)

**Common issues to check:**
- [ ] No extracted directories in git status
- [ ] No unwanted files staged (node_modules, .DS_Store, etc.)
- [ ] Old ZIP versions deleted if updating
- [ ] Only ZIP, root manifest, and catalog.json (for new apps) are staged

## Step 3: Commit changes

Create a clear, descriptive commit message:

```bash
git add commerce-apps-manifest/manifest.json
git add <domain>/<isv-name>/<appName>-v<version>.zip

# For new apps only:
git add <domain>/<isv-name>/catalog.json

git commit -m "Add <displayName> v<version>"
```

**Commit message format:**
- New app: `Add <displayName> v<version>`
- Update: `Update <displayName> to v<version>`
- Fix: `Fix <displayName> v<version> - <brief description>`

## Step 4: Create PR branch

Create a descriptive branch name:

```bash
git checkout -b add-<appName>-v<version>
```

**Branch naming conventions:**
- New app: `add-<appName>-v<version>`
- Update: `update-<appName>-v<version>`
- Fix: `fix-<appName>-v<version>`

## Step 5: Push to remote

```bash
git push origin add-<appName>-v<version>
```

## Step 6: Create PR on GitHub

Based on your GitHub CLI authentication status from Step 0, follow the appropriate path:

---

### Path A: Automated PR Creation (GitHub CLI Authenticated) ✅

If you're authenticated to github.com, use the GitHub CLI to create the PR automatically:

```bash
# Get current branch name
CURRENT_BRANCH=$(git branch --show-current)

# Create PR with title and description
gh pr create \
  --title "Add <displayName> v<version>" \
  --body "## Commerce App Submission

**App Name:** <appName>
**Display Name:** <displayName>
**Domain:** <domain>
**Version:** <version>

## Changes
- [ ] New app submission
- [ ] Version update (previous version: v<oldVersion>)
- [ ] Bug fix or patch

## Description
<!-- Brief description of what this app does or what changed in this version -->

## Checklist

- [x] ZIP file name follows the required format: \`<appName>-v<version>.zip\`
- [x] Root manifest \`commerce-apps-manifest/manifest.json\` includes all required fields
- [x] \`version\`, \`zip\`, and \`sha256\` are updated correctly in root manifest
- [x] SHA256 hash verified to match the ZIP file
- [x] \`catalog.json\` included for new apps only (with INIT values)
- [x] ZIP contains single root folder: \`commerce-<appName>-app-v<version>/\`
- [x] No junk files in ZIP (.DS_Store, __MACOSX, hidden files, Thumbs.db)
- [x] commerce-app.json version matches root manifest version
- [x] Validated with \`/validate-commerce-app\` skill

## CI Workflows

This PR will trigger:
- **verify-zip.yml** - Validates ZIP structure, manifest format, and SHA256 hash
- **update-catalog.yml** - Updates registry catalog on merge (if applicable)

## Testing
<!-- Describe any testing performed on the app -->

---

**Submitter's Notes:**
<!-- Any additional context or notes for reviewers -->" \
  --base main \
  --head "$CURRENT_BRANCH"
```

**Expected output:**
```
https://github.com/<owner>/<repo>/pull/<number>
```

The PR is now created! 🎉 Proceed to Step 7 to monitor CI checks.

**Alternative: Interactive Mode**

If you prefer to edit the PR description in your editor:

```bash
gh pr create --title "Add <displayName> v<version>" --fill
```

This opens your default editor for the PR body.

---

### Path B: Manual PR Creation (No GitHub CLI or Not Authenticated) 📝

If GitHub CLI is not available or you're not authenticated, create the PR manually via web browser:

1. **Get the PR creation URL:**
   ```bash
   CURRENT_BRANCH=$(git branch --show-current)
   REPO_URL=$(git remote get-url origin | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
   echo "$REPO_URL/compare/$CURRENT_BRANCH?expand=1"
   ```

2. **Open the URL in your browser** and paste the following template:

**PR Title:**
```
Add <displayName> v<version>
```

**PR Description:**
```markdown
## Commerce App Submission

**App Name:** <appName>
**Display Name:** <displayName>
**Domain:** <domain>
**Version:** <version>

## Changes
- [ ] New app submission
- [ ] Version update (previous version: v<oldVersion>)
- [ ] Bug fix or patch

## Description
<!-- Brief description of what this app does or what changed in this version -->

## Checklist

- [x] ZIP file name follows the required format: `<appName>-v<version>.zip`
- [x] Root manifest `commerce-apps-manifest/manifest.json` includes all required fields (id, name, description, domain, version, zip, sha256, etc.)
- [x] `version`, `zip`, and `sha256` are updated correctly in root manifest
- [x] SHA256 hash verified to match the ZIP file
- [x] `catalog.json` included for new apps only (with INIT values)
- [x] ZIP contains single root folder: `commerce-<appName>-app-v<version>/`
- [x] No junk files in ZIP (.DS_Store, __MACOSX, hidden files, Thumbs.db)
- [x] commerce-app.json version matches root manifest version
- [x] Validated with `/validate-commerce-app` skill

## CI Workflows

This PR will trigger:
- **verify-zip.yml** - Validates ZIP structure, manifest format, and SHA256 hash
- **update-catalog.yml** - Updates registry catalog on merge (if applicable)

## Testing
<!-- Describe any testing performed on the app -->

---

**Submitter's Notes:**
<!-- Any additional context or notes for reviewers -->
```

3. **Customize the template** with your specific app details
4. **Submit the PR**

---

### Commit Message Format Reference

For both paths, use these title formats:

- **New app**: `Add <displayName> v<version>`
- **Update**: `Update <displayName> to v<version>`
- **Fix**: `Fix <displayName> v<version> - <brief description>`

**Examples:**
- `Add Avalara Tax v1.0.0`
- `Update Avalara Tax to v1.0.1`
- `Fix Avalara Tax v1.0.1 - correct service timeout`

## Step 7: Monitor CI checks

After creating the PR, watch for GitHub Actions to run:

1. **verify-zip.yml** workflow will:
   - Validate root manifest format
   - Check SHA256 hash matches
   - Inspect ZIP structure
   - Verify no junk files
   - Check commerce-app.json matches root manifest

2. **update-catalog.yml** will run on merge to:
   - Update commerce-apps-manifest/manifest.json
   - Sync catalog.json if needed

3. If CI fails:
   - Read the error messages carefully
   - Fix issues locally
   - Force push updates to the same branch
   - CI will re-run automatically

## Step 8: Address review feedback

Respond to reviewer comments and make requested changes:

```bash
# Make changes locally
git add <changed-files>
git commit -m "Address review feedback: <brief description>"
git push origin add-<appName>-v<version>
```

## Common CI failures and fixes

| CI Error | Likely Cause | Fix |
|----------|-------------|-----|
| SHA256 mismatch | Hash in root manifest doesn't match ZIP | Recompute hash with `shasum -a 256` and update commerce-apps-manifest/manifest.json |
| Invalid manifest format | Missing required fields | Add all required fields to root manifest |
| Junk files detected | .DS_Store or hidden files in ZIP | Recreate ZIP with proper exclusions |
| Wrong root folder | ZIP has multiple roots or wrong name | Recreate ZIP from correct directory |
| Version mismatch | commerce-app.json version ≠ root manifest version | Update commerce-app.json to match |

## Final checklist before merge

- [ ] All CI checks passing (green checkmarks)
- [ ] Code review approved
- [ ] No merge conflicts with main branch
- [ ] Squash commits if requested
- [ ] Ready to merge

Once merged, the `update-catalog.yml` workflow will automatically update the registry catalog.
