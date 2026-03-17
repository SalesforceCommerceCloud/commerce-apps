# Contributing to Commerce Apps

Please follow the guidelines below when submitting new or updated commerce app versions to ensure consistency and smooth reviews.

---

## Pull Request Requirements

Each PR **must** include the following items:

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

---

### 2. `manifest.json`

Each PR must include a `manifest.json` file containing the metadata for the app version.

#### Required Fields

The manifest **must** include the following fields:

- `name`
- `displayName`
- `domain`
- `description`
- `version`
- `zip`
- `sha256`

> **Note:** For new versions of an existing app, you must at minimum update the `version`, `zip`, and `sha256` fields.

#### Example `manifest.json`

```json
{
  "name": "avalara-tax",
  "displayName": "Avalara Tax",
  "domain": "tax",
  "description": "Sample Avalara tax app",
  "version": "1.0.0",
  "zip": "avalara-tax-v1.0.0.zip",
  "sha256": "492fb0bc3aa5c762c0209bd22375e14ed2af8f672b679d6105232a37fe726a4f"
}
```

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

---

## Final Checklist

Before submitting your PR, please verify:

- [ ] ZIP file name follows the required format
- [ ] `manifest.json` includes all required fields
- [ ] `version`, `zip`, and `sha256` are updated correctly
- [ ] `catalog.json` is included for new apps only