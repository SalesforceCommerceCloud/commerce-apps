---
name: scaffold-app
description: >-
  Generate initial directory structure and template files for a new commerce app.
  Creates the complete app scaffolding including cartridges, extensions, impex files,
  and configuration. Use this skill immediately when starting ANY new commerce app from scratch,
  when the user mentions "new app", "scaffold", "starter template", or "create app structure".
  This skill provides the fastest path to a working app skeleton with all required files.
---

# Scaffold Commerce App

Generate a complete starter structure for a new commerce app with all required files and templates.

## When to use this skill

Use this skill proactively whenever:
- User mentions creating a "new app", "new commerce app", or "starter app"
- User asks to "scaffold" or "generate" an app structure
- User wants to build an app "from scratch"
- User needs a template or boilerplate for a commerce app
- Starting any new tax, payment, shipping, or other commerce integration

**Don't wait for the user to explicitly say "scaffold" - if they're starting a new app, use this skill.**

## Step 1: Collect app information

Gather the following information from the user:

| Input | Example | Notes |
|-------|---------|-------|
| Domain | `tax` | One of: `tax`, `payment`, `shipping`, `gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`, `fraud` |
| ISV/Vendor name | `avalara` | Your company name (lowercase, hyphens) |
| App name (kebab-case) | `avalara-tax` | Unique app identifier |
| Display name | `Avalara Tax` | Human-readable name with vendor |
| Initial version | `1.0.0` | Usually start with 1.0.0 |
| Description | `Automate your sales tax compliance with Avalara` | Brief description |
| Publisher name | `Avalara` | Your company name |
| Publisher URL | `https://developer.avalara.com` | Your company website |
| Cartridge name | `int_avalara_tax` | Usually `int_<appname>` |
| Service ID | `avalara.tax.api` | Dotted notation with vendor |

**Valid domains:**
`tax`, `payment`, `shipping`, `gift-cards`, `ratings-and-reviews`, `loyalty`, `search`, `address-verification`, `analytics`, `approaching-discounts`, `fraud`

## Step 2: Create directory structure

Run the structure creation script:

```bash
bash scripts/create_structure.sh <domain> <isv-name> <appName> <version> <cartridgeName>
```

This creates:
```
{domain}/{isv-name}/commerce-{appName}-app-v{version}/
├── commerce-app.json
├── README.md
├── app-configuration/
├── cartridges/site_cartridges/{cartridgeName}/
├── storefront-next/src/extensions/{appName}/
└── impex/
```

**If script fails or you prefer manual creation:**
```bash
mkdir -p <domain>/<isv-name>
cd <domain>/<isv-name>
mkdir -p commerce-<appName>-app-v<version>
cd commerce-<appName>-app-v<version>

# Create all directories
mkdir -p app-configuration icons
mkdir -p cartridges/site_cartridges/<cartridgeName>/cartridge/scripts/{hooks,helpers,services}
mkdir -p cartridges/site_cartridges/<cartridgeName>/test/{mocks,unit}
mkdir -p cartridges/bm_cartridges/bm_<appName>
mkdir -p storefront-next/src/extensions/<appName>/{components,context,hooks,locales,middlewares,providers,routes,stores,tests}
mkdir -p impex/install/meta
mkdir -p impex/install/sites/SITEID
mkdir -p impex/uninstall
```

## Step 3: Generate files from templates

All template files are in `assets/templates/`. Read each template, replace placeholders, and write to the app directory.

### Template Variables

When reading templates, replace these placeholders:
- `{{appName}}` - app name (e.g., `avalara-tax`)
- `{{displayName}}` - display name (e.g., `Avalara Tax`)
- `{{version}}` - version (e.g., `1.0.0`)
- `{{description}}` - app description
- `{{domain}}` - domain (e.g., `tax`)
- `{{publisherName}}` - publisher name
- `{{publisherUrl}}` - publisher URL
- `{{cartridgeName}}` - cartridge name
- `{{serviceId}}` - service ID

### Core Files

**1. commerce-app.json**
- Template: `assets/templates/commerce-app.json.tmpl`
- Location: `commerce-app.json` (root)

**2. README.md**
- Template: `assets/templates/README.md.tmpl`
- Location: `README.md` (root)

**3. app-configuration/tasksList.json**
Create manually:
```json
{
  "tasks": [
    {
      "id": "configure-service",
      "title": "Configure Service Credentials",
      "description": "Set up API credentials for {{displayName}} service",
      "required": true
    },
    {
      "id": "configure-preferences",
      "title": "Configure Site Preferences",
      "description": "Set site-specific preferences for {{displayName}}",
      "required": true
    },
    {
      "id": "test-integration",
      "title": "Test Integration",
      "description": "Verify the integration is working correctly",
      "required": true
    }
  ]
}
```

### Cartridge Files

**4. package.json**
- Template: `assets/templates/package.json.tmpl`
- Location: `cartridges/site_cartridges/<cartridgeName>/package.json`

**5. hooks.json**
- Template: `assets/templates/hooks.json.tmpl`
- Location: `cartridges/site_cartridges/<cartridgeName>/cartridge/scripts/hooks.json`
- **Note:** Adjust hooks based on domain (tax, payment, shipping)

**6. Hook Script**
- Template: `assets/templates/hook-script.js.tmpl`
- Location: `cartridges/site_cartridges/<cartridgeName>/cartridge/scripts/hooks/calculate.js`

**7. Helper Template**
Create `cartridges/site_cartridges/<cartridgeName>/cartridge/scripts/helpers/<appName>Helper.js`:
```javascript
'use strict';

function processRequest(params) {
    var Logger = require('dw/system/Logger');
    var logger = Logger.getLogger('{{appName}}', 'helper');

    try {
        // TODO: Implement helper logic
        return { success: true, data: {} };
    } catch (e) {
        logger.error('Error: {0}', e.message);
        throw e;
    }
}

module.exports = { processRequest: processRequest };
```

**8. Service Wrapper**
- Template: `assets/templates/service-wrapper.js.tmpl`
- Location: `cartridges/site_cartridges/<cartridgeName>/cartridge/scripts/services/<appName>Service.js`

**9. Test Template**
Create `cartridges/site_cartridges/<cartridgeName>/test/unit/<appName>Helper.test.js`:
```javascript
'use strict';

const helper = require('../../cartridge/scripts/helpers/<appName>Helper');

describe('<appName>Helper', () => {
    describe('processRequest', () => {
        it('should process request successfully', () => {
            const params = {};
            const result = helper.processRequest(params);
            expect(result.success).toBe(true);
        });
    });
});
```

### Impex Files

**10. Services Install**
- Template: `assets/templates/services-install.xml.tmpl`
- Location: `impex/install/services.xml`

**11. Services Uninstall**
- Template: `assets/templates/services-uninstall.xml.tmpl`
- Location: `impex/uninstall/services.xml`

**12. Site Preferences**
Use the `/generate-site-preferences-impex` skill to create:
- `impex/install/meta/system-objecttype-extensions.xml`
- `impex/install/sites/SITEID/preferences.xml`

### Storefront Extension

**13. Target Config**
Create `storefront-next/src/extensions/<appName>/target-config.json`:
```json
{
  "targets": {
    "product-details": {
      "slots": [
        {
          "id": "{{appName}}-product-details",
          "component": "./components/ProductDetails"
        }
      ]
    }
  }
}
```

**14. React Component**
Create `storefront-next/src/extensions/<appName>/components/ProductDetails.jsx`:
```jsx
import React from 'react';

const ProductDetails = ({ product }) => {
  return (
    <div className="{{appName}}-product-details">
      <h3>{{displayName}}</h3>
      {/* TODO: Implement component */}
    </div>
  );
};

export default ProductDetails;
```

## Step 4: Update repository .gitignore

Ensure the repository root has a `.gitignore` that excludes extracted directories:

```gitignore
# Commerce App - Extracted directories (DO NOT COMMIT)
**/commerce-*-app-*/

# System files
.DS_Store
__MACOSX/
Thumbs.db

# IDE
.vscode/
.idea/
```

## Step 5: Validation checklist

- [ ] All directories created
- [ ] commerce-app.json generated with correct version
- [ ] README.md created
- [ ] tasksList.json created
- [ ] Cartridge files created (package.json, hooks.json, scripts)
- [ ] Impex files created (services.xml, site preferences)
- [ ] Storefront extension created
- [ ] .gitignore updated

## Step 6: Next steps guidance

Guide the developer:

```
✅ App structure created successfully!

Next steps:

1. Review and customize the generated files
2. Implement your business logic in hooks and helpers
3. Update service endpoints and credentials
4. Write unit tests for your code
5. Test locally with your SFCC instance
6. Use /generate-commerce-app to package into ZIP when ready
7. Use /validate-commerce-app before submitting
8. Delete the extracted directory before committing (only commit ZIP)

Directory: <domain>/<isv-name>/commerce-<appName>-app-v<version>/

⚠️  IMPORTANT: This extracted directory is for development only.
    Do NOT commit it to git. Only commit:
    - <appName>-v<version>.zip
    - catalog.json (new apps only)
    - Update root manifest: commerce-apps-manifest/manifest.json

To get started:
  cd <domain>/<isv-name>/commerce-<appName>-app-v<version>
  cd cartridges/site_cartridges/<cartridgeName>
  npm install
```

## Domain-specific hook patterns

### Tax App
Hooks: `app.tax.calculate`, `app.tax.commit`, `app.tax.cancel`

### Payment App
Hooks: `app.payment.processor.<appName>`

### Shipping App
Hooks: `app.shipping.calculate`

### Ratings/Reviews App
Hooks: `app.data.enrich` (product data)

### Loyalty App
Hooks: `app.loyalty.calculate`, `app.loyalty.points`

### Gift Cards App
Hooks: `app.payment.processor.<appName>`, `app.giftcard.balance`

## Tips

- Always use the template files in `assets/templates/` - don't recreate manually
- Replace ALL placeholders (`{{variable}}`) with actual values
- Adjust hooks.json based on the app domain
- Use descriptive service IDs with dotted notation
- Follow naming conventions: camelCase for preferences, kebab-case for app names
