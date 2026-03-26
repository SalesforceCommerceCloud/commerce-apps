# Guide for AI Assistants

This document provides context and guidance for AI assistants (including Claude Code) working with developers in the Commerce Apps registry repository.

---

## Repository Overview

This is a **Commerce App Registry** for Salesforce Commerce Cloud B2C Commerce. It contains packaged apps (extensions) that merchants can install into their storefronts via Business Manager.

**Key Concepts:**
- **Commerce App Package (CAP):** A ZIP file containing cartridges, UI extensions, impex configs, and documentation
- **Domain:** Functional category for the app. Can be a provider domain (`tax`, `payment`, `shipping`) or a feature domain (`gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`, `fraud`)
- **ISV:** Independent Software Vendor (the company publishing the app)
- **Impex:** XML configuration files for SFCC (services, site preferences, custom objects)

## Directory Structure

```
{domain}/{isv-name}/
├── {app-name}-v{version}.zip    # COMMIT THIS - The packaged app
├── manifest.json                 # COMMIT THIS - App metadata + SHA256 hash
└── catalog.json                  # COMMIT THIS - Version history (new apps only)

# DO NOT COMMIT:
commerce-{app-name}-app-v{version}/  # Extracted directory (dev only)
```

**Examples:**
- `tax/avalara/avalara-tax-v0.2.8.zip`
- `gift-cards/salesforce-gift-cards/salesforce-gift-cards-v0.0.1.zip`

**Critical Rule:** Extracted app directories are for development only. Only ZIP, manifest.json, and catalog.json should be committed.

## Available Skills

### App Development & Packaging
| Skill | When to Use | What It Does |
|-------|-------------|--------------|
| `/scaffold-commerce-app` | Starting a new app from scratch | Generates complete directory structure with templates |
| `/generate-commerce-app` | Ready to package app for registry | Creates ZIP, updates manifest.json with SHA256 |
| `/update-app-version` | Bumping version of existing app | Updates version, regenerates ZIP, computes new hash |

### Impex Generation
| Skill | When to Use | What It Does |
|-------|-------------|--------------|
| `/generate-service-impex` | Need external API integration | Creates service credentials, profiles, definitions (install + uninstall) |
| `/generate-site-preferences-impex` | Need merchant-configurable settings | Creates custom site preferences with all attribute types |
| `/generate-custom-object-impex` | Need data storage (cache, config, logs) | Creates custom object type definitions with storage config |
| `/validate-impex` | Before importing or submitting | Validates XML syntax, structure, install/uninstall pairs |

### Validation & Inspection
| Skill | When to Use | What It Does |
|-------|-------------|--------------|
| `/validate-commerce-app` | Before submitting PR | Validates ZIP structure, manifest, SHA256, commerce-app.json |
| `/extract-and-inspect` | Reviewing or debugging a ZIP | Extracts and inspects ZIP contents safely |
| `/compare-app-versions` | Code review or changelog generation | Compares two versions to see what changed |

### Submission
| Skill | When to Use | What It Does |
|-------|-------------|--------------|
| `/submit-app-pr` | Ready to submit app to registry | Guides through PR creation with proper format and checklist |

## Common Workflows

### Workflow 1: New App from Scratch

```
User: "I want to build a ratings and reviews app"

Your response:
1. Suggest `/scaffold-commerce-app`
2. Gather info: domain (ratings-and-reviews), ISV name, app details
3. After scaffolding, guide them to build their app code
4. Suggest `/generate-service-impex` for API integration
5. Suggest `/generate-site-preferences-impex` for settings
6. When ready: `/generate-commerce-app` → `/validate-commerce-app` → `/submit-app-pr`
```

### Workflow 2: Update Existing App

```
User: "I need to release version 1.0.1 of my app"

Your response:
1. Suggest `/update-app-version`
2. Extract current version, update code, regenerate ZIP
3. Suggest `/validate-commerce-app` before submitting
4. Suggest `/submit-app-pr` when ready
```

### Workflow 3: Generate Impex Files

```
User: "I need to add a service configuration for my API"

Your response:
1. Suggest `/generate-service-impex`
2. Gather: service ID, auth type, base URL, rate limits
3. Generate both install and uninstall files
4. Suggest `/validate-impex` to check syntax
```

### Workflow 4: Validate Before Submission

```
User: "Is my app ready to submit?"

Your response:
1. Run `/validate-commerce-app` - checks ZIP, manifest, structure
2. Run `/validate-impex` - checks all XML files
3. Review checklist from CONTRIBUTING.md
4. If all pass, suggest `/submit-app-pr`
```

## Critical Rules & Conventions

### 1. Directory Structure
- **ALWAYS** use `{domain}/{isv-name}/` structure
- **NEVER** commit extracted directories (`commerce-*-app-v*/`)
- Only commit: ZIP, manifest.json, catalog.json

### 2. File Naming
- ZIP: `{app-name}-v{version}.zip` (e.g., `avalara-tax-v0.2.8.zip`)
- Extracted dir: `commerce-{app-name}-app-v{version}/`
- Service IDs: dotted notation (e.g., `avalara.tax.api`)
- Attribute IDs: camelCase with app prefix (e.g., `avalaraTaxEnabled`)

### 3. Version Management
- Semantic versioning: `major.minor.patch`
- Version in `commerce-app.json` MUST match `manifest.json`
- SHA256 in `manifest.json` MUST match actual ZIP hash
- Do NOT add new versions to `catalog.json` when updating (CI handles it)
- You MAY add `"deprecated": true` to existing versions in `catalog.json`

### 4. Security
- NO hardcoded production credentials in impex
- Use placeholders for API keys/secrets
- Use `<password>` type for sensitive site preferences
- Mark sensitive data clearly in documentation

### 5. Impex Rules
- Service install files MUST have matching uninstall files
- Uninstall MUST use `mode="delete"`
- Deletion order: service → profile → credential
- Use `SITEID` placeholder, not actual site IDs
- All attribute IDs MUST be prefixed with app name

### 6. ZIP Contents
- Single root folder: `commerce-{app-name}-app-v{version}/`
- NO junk files: `.DS_Store`, `__MACOSX`, `Thumbs.db`, hidden files
- NO `node_modules`, `.git`, IDE files
- Optional: `icons/` directory with ISV icon(s)
- Use exclusions when creating ZIP:
  ```bash
  zip -r app.zip folder/ -x "*.DS_Store" -x "__MACOSX/*" -x "*/.*" -x "Thumbs.db"
  ```

### 7. Icons (Optional)
- Place icon files in `icons/` directory at CAP root
- Name icons `{isv-name}.{ext}` (e.g., `avalara.png`)
- Supported formats: PNG, SVG, JPG, JPEG
- **Icon validation (by hash):**
  - ✅ Same icon as existing = PASS (reusing icon in new version)
  - ✅ New ISV's first icon = PASS
  - ⚠️ Different icon for existing ISV = WARNING (rebranding allowed, requires review)
- Recommended size: 512x512px for raster, scalable for SVG
- CI automatically extracts icons to `commerce-apps-manifest/icons/` on merge

**Icon validation examples:**
```
Scenario 1: Avalara v0.2.8 with avalara.png (hash: abc123)
            Commerce-apps-manifest already has avalara.png (hash: abc123)
            Result: ✅ PASS - Same hash, no changes needed

Scenario 2: New ISV v1.0.0 with newisv.svg (new ISV)
            No existing icon in commerce-apps-manifest
            Result: ✅ PASS - First icon for ISV, will be added

Scenario 3: Avalara v0.3.0 with avalara.png (hash: xyz789)
            Commerce-apps-manifest has avalara.png (hash: abc123)
            Result: ⚠️ WARNING - Icon change detected (rebranding)
                   - CI warns reviewers about icon change
                   - Icon will be updated on merge if approved
                   - Verify with developer this is intentional
```

## When to Suggest Each Skill

### Starting Fresh
- **User mentions:** "new app", "start building", "create app", "scaffold"
- **Suggest:** `/scaffold-commerce-app`

### Packaging
- **User mentions:** "package", "create ZIP", "ready to submit", "build registry package"
- **Suggest:** `/generate-commerce-app`

### Service Integration
- **User mentions:** "API", "external service", "third-party", "integration", "webhook", "credentials"
- **Suggest:** `/generate-service-impex`

### Configuration
- **User mentions:** "settings", "preferences", "configure", "options", "merchant settings"
- **Suggest:** `/generate-site-preferences-impex`

### Data Storage
- **User mentions:** "cache", "store data", "custom object", "save configuration", "logging"
- **Suggest:** `/generate-custom-object-impex`

### Validation
- **User mentions:** "check", "validate", "verify", "ready?", "errors", "problems"
- **Suggest:** `/validate-commerce-app` and/or `/validate-impex`

### Version Updates
- **User mentions:** "new version", "update version", "bump version", "release"
- **Suggest:** `/update-app-version`

### Inspection/Review
- **User mentions:** "what's inside", "check ZIP", "review", "inspect"
- **Suggest:** `/extract-and-inspect`

### Comparison
- **User mentions:** "what changed", "diff", "compare versions", "changelog"
- **Suggest:** `/compare-app-versions`

### Submission
- **User mentions:** "submit", "pull request", "PR", "contribute", "publish"
- **Suggest:** `/submit-app-pr`

## catalog.json Rules

### What Developers Can Do

**✅ Allowed:**
- Create `catalog.json` for brand new apps (with INIT values)
- Add `"deprecated": true` to existing versions

**Example deprecation:**
```json
{
  "versions": [
    {
      "version": "1.0.1",
      "deprecated": true    // ✅ Can add this
    }
  ]
}
```

### What Developers Cannot Do

**❌ Prohibited:**
- Add new versions to the `versions` array (CI does this automatically)
- Modify the `latest` object (CI manages this)
- Remove versions from the array (use deprecated flag instead)
- Change existing version metadata (tag, sha256, releaseDate)

### When to Mark as Deprecated

Suggest deprecation when:
- Security vulnerability found
- Critical bug that prevents proper functionality
- Version no longer supported
- Breaking changes require migration to newer version

### Important Notes

- CI automatically adds new versions on merge
- CI automatically updates `latest` object
- Developers only touch `catalog.json` for deprecation or initial creation
- Never remove versions - deprecated versions remain in history

## Common Pitfalls to Avoid

### ❌ Wrong Directory Structure
```
# WRONG - using app name instead of ISV name
tax/avalara-tax/avalara-tax-v0.2.8.zip

# RIGHT
tax/avalara/avalara-tax-v0.2.8.zip

# WRONG - using different domain naming
giftCards/salesforce-gift-cards/salesforce-gift-cards-v0.0.1.zip

# RIGHT - domain uses hyphen-case
gift-cards/salesforce-gift-cards/salesforce-gift-cards-v0.0.1.zip
```

### ❌ Committing Extracted Directories
```
# WRONG - DO NOT COMMIT
tax/avalara/commerce-avalara-tax-app-v0.2.8/

# RIGHT - Only commit these
tax/avalara/avalara-tax-v0.2.8.zip
tax/avalara/manifest.json
tax/avalara/catalog.json
```

### ❌ Hardcoded Credentials
```xml
<!-- WRONG -->
<user-id>live_prod_key_12345</user-id>
<password>sk_live_secret_67890</password>

<!-- RIGHT -->
<user-id>YOUR_API_KEY</user-id>
<password>YOUR_API_SECRET</password>
```

### ❌ Missing Uninstall Mode
```xml
<!-- WRONG -->
<service service-id="myapp.api"/>

<!-- RIGHT -->
<service service-id="myapp.api" mode="delete"/>
```

### ❌ Version Mismatch
```json
// manifest.json
{ "version": "1.0.0" }

// commerce-app.json (inside ZIP)
{ "version": "1.0.1" }  // WRONG - must match!
```

### ❌ Wrong Attribute Naming
```xml
<!-- WRONG -->
<attribute-definition attribute-id="enabled">              <!-- Too generic -->
<attribute-definition attribute-id="api_key">              <!-- snake_case -->
<attribute-definition attribute-id="MyAppEnabled">         <!-- PascalCase -->

<!-- RIGHT -->
<attribute-definition attribute-id="myAppEnabled">         <!-- Prefixed, camelCase -->
```

### ❌ Junk Files in ZIP
```bash
# WRONG - Creates junk files
zip -r app.zip folder/

# RIGHT - Excludes junk files
zip -r app.zip folder/ -x "*.DS_Store" -x "__MACOSX/*" -x "*/.*" -x "Thumbs.db"
```

## Understanding the Domain

### Commerce Cloud Context
- **SFCC:** Salesforce Commerce Cloud (formerly Demandware)
- **Business Manager:** Admin interface for merchants
- **Storefront Next:** Modern React-based storefront platform
- **Script API:** Server-side JavaScript API (`dw.*` modules)
- **Hooks:** Extension points in the platform lifecycle

### Domains

The `domain` field in manifest entries and `commerce-app.json` must be one of these values (using hyphen-case):

#### Provider Domains (show under "Providers" in Checkout Hub)
| Domain | Description |
|--------|-------------|
| `tax` | Tax calculation and compliance |
| `payment` | Payment processing |
| `shipping` | Shipping and fulfillment |

#### Feature Domains (show under "Additional Setup" in Checkout Hub)
| Domain | Description | Example Apps |
|--------|-------------|--------------|
| `gift-cards` | Gift card purchasing, redemption, and balance | Salesforce Gift Cards |
| `ratings-and-reviews` | Product ratings and reviews | |
| `loyalty` | Loyalty programs and rewards | |
| `search` | Search and merchandising | |
| `address-verification` | Address validation and standardization | |
| `analytics` | Analytics and reporting | |
| `approaching-discounts` | Approaching discount notifications | Salesforce Approaching Discounts |
| `fraud` | Fraud detection and prevention | |

### Common App Patterns
| Type | What It Does | Typical Components |
|------|-------------|-------------------|
| Tax | Calculate sales tax | Service integration, hooks (calculate, commit, cancel) |
| Payment | Process payments | Payment processor integration, authorization hooks |
| Shipping | Calculate shipping rates | Carrier API integration, rate calculation hooks |
| Reviews (`ratings-and-reviews`) | Product ratings/reviews | Reviews API, React components for display |
| Loyalty | Points and rewards | Customer data sync, points calculation |
| Gift Cards (`gift-cards`) | Gift card management | Payment method integration, balance API |

### Impex File Types

**services.xml**
- Service credentials (API keys, URLs)
- Service profiles (timeouts, rate limits, circuit breakers)
- Service definitions (HTTP, FTP, etc.)

**system-objecttype-extensions.xml**
- Custom site preferences
- Merchant-configurable settings
- Attribute types: boolean, string, enum, text, integer, etc.

**custom-objecttype-definitions.xml**
- Custom data storage
- Key-value objects
- Caching, configuration, logging

**preferences.xml**
- Default site preference values
- Uses SITEID placeholder

## Skill Combinations

### Common Skill Chains

**Full App Development:**
```
/scaffold-commerce-app
  → Build app code
  → /generate-service-impex
  → /generate-site-preferences-impex
  → /generate-custom-object-impex (if needed)
  → /validate-impex
  → /generate-commerce-app
  → /validate-commerce-app
  → /submit-app-pr
```

**Quick Update:**
```
/update-app-version
  → /validate-commerce-app
  → /submit-app-pr
```

**Add Configuration:**
```
/generate-site-preferences-impex
  → /validate-impex
  → (rebuild app)
  → /generate-commerce-app
```

**Debugging:**
```
/extract-and-inspect
  → (identify issues)
  → (fix issues)
  → /generate-commerce-app
  → /validate-commerce-app
```

**Review Process:**
```
/extract-and-inspect
  → /compare-app-versions
  → (review changes)
  → Approve or request changes
```

## Validation Checklist

Before suggesting `/submit-app-pr`, verify:

**File Structure:**
- [ ] Files at `{domain}/{isv-name}/` (correct path)
- [ ] Only ZIP, manifest.json, catalog.json present
- [ ] No extracted directories committed

**ZIP Contents:**
- [ ] Single root folder: `commerce-{app-name}-app-v{version}/`
- [ ] No junk files (`.DS_Store`, `__MACOSX`, hidden files)
- [ ] All required files present (commerce-app.json, README.md, etc.)

**Manifest Validation:**
- [ ] All required fields present
- [ ] Version matches commerce-app.json
- [ ] SHA256 matches actual ZIP hash
- [ ] ZIP filename matches `zip` field

**Impex Validation:**
- [ ] XML syntax valid (no parsing errors)
- [ ] Service install has matching uninstall
- [ ] Attribute IDs prefixed with app name
- [ ] No hardcoded production credentials
- [ ] SITEID placeholder used (not actual site ID)

**Security:**
- [ ] No sensitive data in XML
- [ ] Passwords use `<password>` type
- [ ] API keys are placeholders

## Helping Developers Effectively

### 1. Be Proactive
- When user starts building an app, suggest `/scaffold-commerce-app`
- When they mention services, suggest `/generate-service-impex`
- Always suggest validation before submission

### 2. Provide Context
- Explain WHY certain conventions exist
- Reference CONTRIBUTING.md for detailed requirements
- Point to example apps (avalara-tax) as reference

### 3. Catch Mistakes Early
- Check directory structure immediately
- Verify they're not committing extracted directories
- Validate impex XML syntax as they build

### 4. Guide Workflows
- Don't just answer questions, guide through complete workflows
- Suggest next steps in the process
- Recommend validation at key checkpoints

### 5. Use the Right Tools
- Don't manually parse XML when `/validate-impex` exists
- Don't manually compute hashes when `/generate-commerce-app` does it
- Don't manually write boilerplate when skills generate it

## Common Questions & Answers

**Q: "How do I start a new ratings app?"**
A: Use `/scaffold-commerce-app` and provide: domain=`ratings-and-reviews`, ISV name, app details. It generates the complete structure.

**Q: "How do I add API integration?"**
A: Use `/generate-service-impex` - it creates both install and uninstall service configs with proper authentication, rate limiting, and circuit breakers.

**Q: "My ZIP is ready, what's next?"**
A: Run `/validate-commerce-app` to check everything, then `/submit-app-pr` to create the PR with proper formatting.

**Q: "What files should I commit?"**
A: Only 3 files: `{app-name}-v{version}.zip`, `manifest.json`, `catalog.json` (new apps only). Never commit extracted directories.

**Q: "How do I update to a new version?"**
A: Use `/update-app-version` - it handles extracting, updating version numbers, regenerating ZIP, and computing new hash.

**Q: "The CI is failing with SHA256 mismatch"**
A: The hash in manifest.json doesn't match the ZIP. Run `/generate-commerce-app` to regenerate with correct hash.

**Q: "Can I modify catalog.json?"**
A: Depends on what you're doing:
- New app: YES - Create with INIT values
- Adding new version: NO - CI adds it automatically on merge
- Deprecating existing version: YES - Add `"deprecated": true` to that version entry
- Anything else: NO - CI manages it

**Q: "Where does my app go in the registry?"**
A: `{domain}/{isv-name}/` where domain is one of: `tax`, `payment`, `shipping`, `gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`, or `fraud`. The domain uses hyphen-case and is specified directly in the manifest.

## Key Files to Reference

- **CONTRIBUTING.md** - Full submission requirements and guidelines
- **README.md** - Repository overview and quick start
- **.gitignore** - Already configured to exclude extracted directories
- **tax/avalara/** - Reference implementation to study
- **.claude/skills/** - All skill definitions and documentation

## Success Metrics

A successful AI assistant interaction:
1. ✅ User completes task efficiently with appropriate skills
2. ✅ No incorrect files committed (e.g., extracted directories)
3. ✅ Validation passes before submission
4. ✅ User understands WHY, not just HOW
5. ✅ PR passes CI on first attempt

## Remember

- **Skills exist for a reason** - Use them instead of manual processes
- **Structure matters** - `{domain}/{isv-name}/` is not optional
- **Validation is critical** - Always validate before submission
- **Security first** - No hardcoded credentials, ever
- **Guide, don't just answer** - Help users through complete workflows

This is a professional ISV developer environment. Help them build production-ready Commerce Apps efficiently and correctly.
