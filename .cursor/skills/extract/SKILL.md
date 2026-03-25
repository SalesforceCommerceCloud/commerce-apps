---
name: extract
description: >-
  Quickly extract a commerce app ZIP file for development or modification.
  Minimal validation, just extracts and confirms. Use extract-and-inspect for full forensics.
---

# Extract Commerce App

Quickly extract a commerce app ZIP file for development or modification.

## Usage

```bash
/extract <app-name>
# or
/extract <domain>/<app-name>
```

**Examples:**
```bash
/extract avalara-tax
/extract tax/avalara-tax
```

## What it does

1. Finds the ZIP file in the app's directory
2. Validates ZIP integrity
3. Extracts to the app's directory
4. Shows extracted path

## Step 1: Locate ZIP file

Parse the input and find the ZIP:

```bash
# If input is just app name (e.g., "avalara-tax")
# Search for it in all domain directories
find . -name "*<app-name>-v*.zip" -type f | head -1

# If input is domain/app (e.g., "tax/avalara-tax")
# Look directly in that directory
ls <domain>/<app-name>/*-v*.zip
```

**Expected result:** Single ZIP path like `tax/avalara-tax/avalara-tax-v0.2.8.zip`

## Step 2: Validate ZIP

Quick integrity check:

```bash
unzip -t <path-to-zip>
```

**If corrupted:** Exit with error message

## Step 3: Extract ZIP

```bash
cd <domain>/<app-name>/
unzip -q <app-name>-v<version>.zip
```

**Expected result:** Creates `commerce-<app-name>-app-v<version>/` directory

## Step 4: Confirm extraction

```bash
ls -la <domain>/<app-name>/
```

Show the user:
```
✅ Extracted to: tax/avalara-tax/commerce-avalara-tax-app-v0.2.8/

Ready to modify! When done, use /generate-commerce-app to repackage.

⚠️  Remember to delete the extracted directory before committing!
```

## Common workflows

### Quick fix workflow
```bash
/extract avalara-tax
# Edit files in commerce-avalara-tax-app-v0.2.8/
/generate-commerce-app tax/avalara-tax/commerce-avalara-tax-app-v0.2.8
```

### Development workflow
```bash
/extract my-app
cd gift-cards/vendor/commerce-my-app-v1.0.0/
# Make changes
/generate-commerce-app .
```

## Notes

- **Only extracts** - no inspection or validation beyond ZIP integrity
- **For inspection**, use `/extract-and-inspect` instead
- **Always delete** extracted directory before git commit
- If directory already exists, ask user if they want to overwrite
