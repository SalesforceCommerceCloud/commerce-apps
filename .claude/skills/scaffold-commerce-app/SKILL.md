---
name: scaffold-commerce-app
description: >-
  Generate initial directory structure and template files for a new commerce app.
  Creates the complete app scaffolding including cartridges, extensions, impex files,
  and configuration. Use when starting a new commerce app from scratch.
---

# Scaffold Commerce App

Generate a complete starter structure for a new commerce app with all required files and templates.

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

**Directory structure:**
```
{domain}/{isv-name}/commerce-{appName}-app-v{version}/
```

**Examples:**
- `tax/avalara/commerce-avalara-tax-app-v0.2.8/`
- `gift-cards/salesforce-gift-cards/commerce-salesforce-gift-cards-app-v0.0.1/`

**Domains:**
- `tax` - Tax calculation and compliance
- `payment` - Payment processing
- `shipping` - Shipping and fulfillment
- `gift-cards` - Gift card purchasing, redemption, and balance
- `ratings-and-reviews` - Product ratings and reviews
- `loyalty` - Loyalty programs and rewards
- `search` - Search and merchandising
- `address-verification` - Address validation and standardization
- `analytics` - Analytics and reporting
- `approaching-discounts` - Approaching discount notifications
- `fraud` - Fraud detection and prevention

## Step 2: Create domain and ISV directories

Create the domain and ISV/vendor directories if they don't exist:

```bash
mkdir -p <domain>/<isv-name>
cd <domain>/<isv-name>
```

**Example:**
```bash
mkdir -p tax/avalara
cd tax/avalara
```

## Step 3: Create app directory structure

Create the complete directory structure:

```bash
# Create main app directory
mkdir -p commerce-<appName>-app-v<version>
cd commerce-<appName>-app-v<version>

# Create required directories
mkdir -p app-configuration
mkdir -p icons

# Cartridge structure
mkdir -p cartridges/site_cartridges/<cartridgeName>/cartridge/scripts/{hooks,helpers,services}
mkdir -p cartridges/site_cartridges/<cartridgeName>/test/{mocks,unit}
mkdir -p cartridges/bm_cartridges/bm_<appName>

# Storefront Next extensions
mkdir -p storefront-next/src/extensions/<appName>/{components,context,hooks,locales,middlewares,providers,routes,stores,tests}

# Impex structure
mkdir -p impex/install/meta
mkdir -p impex/install/sites/SITEID
mkdir -p impex/uninstall
```

## Step 4: Generate commerce-app.json

Create the main app metadata file:

**File:** `commerce-app.json`

```json
{
  "id": "<appName>",
  "name": "<displayName>",
  "description": "<description>",
  "domain": "<domain>",
  "version": "<version>",
  "publisher": {
    "name": "<publisherName>",
    "url": "<publisherUrl>",
    "support": "<publisherUrl>"
  },
  "dependencies": {}
}
```

## Step 5: Generate README.md

Create documentation template:

**File:** `README.md`

```markdown
# <displayName>

<description>

## Overview

[Describe what this app does and the problem it solves]

## Features

- Feature 1
- Feature 2
- Feature 3

## Prerequisites

- Salesforce Commerce Cloud B2C Commerce instance
- API access enabled
- [Any other requirements]

## Installation

1. Download the app from the Commerce App Registry
2. Import the app using Business Manager
3. Navigate to Administration > Site Development > Manage Sites
4. Select your site and add the cartridge to the cartridge path
5. Configure the service credentials

## Configuration

### Service Credentials

1. Navigate to Administration > Operations > Services
2. Find the `<serviceId>` service
3. Configure credentials:
   - **Username/API Key:** [Instructions]
   - **Password/Secret:** [Instructions]
   - **Endpoint URL:** [Instructions]

### Site Preferences

1. Navigate to Merchant Tools > Site Preferences > Custom Preferences
2. Configure <displayName> settings:
   - **Preference 1:** [Description]
   - **Preference 2:** [Description]

## Post-Installation Checklist

After installation, complete the following tasks:

- [ ] Configure service credentials
- [ ] Set site preferences
- [ ] Test the integration on a test site
- [ ] Review and complete app-configuration tasks

## Usage

[Provide usage examples and common scenarios]

## Testing

Run unit tests:

\`\`\`bash
cd cartridges/site_cartridges/<cartridgeName>
npm install
npm test
\`\`\`

## Troubleshooting

### Issue 1
**Problem:** [Description]
**Solution:** [Steps to resolve]

### Issue 2
**Problem:** [Description]
**Solution:** [Steps to resolve]

## Support

For questions or issues:
- Email: support@<publisherUrl>
- Documentation: <publisherUrl>/docs
- GitHub: <publisherUrl>/github

## License

[Your license information]

## Changelog

### v<version>
- Initial release
```

## Step 6: Generate app-configuration/tasksList.json

Create post-install checklist:

**File:** `app-configuration/tasksList.json`

```json
{
  "tasks": [
    {
      "id": "configure-service",
      "title": "Configure Service Credentials",
      "description": "Set up API credentials for <displayName> service",
      "required": true,
      "link": "https://documentation.example.com/setup"
    },
    {
      "id": "configure-preferences",
      "title": "Configure Site Preferences",
      "description": "Set site-specific preferences for <displayName>",
      "required": true
    },
    {
      "id": "test-integration",
      "title": "Test Integration",
      "description": "Verify the integration is working correctly",
      "required": true
    },
    {
      "id": "review-documentation",
      "title": "Review Documentation",
      "description": "Read through the README and documentation",
      "required": false
    }
  ]
}
```

## Step 7: Generate cartridge package.json

Create Node.js package configuration:

**File:** `cartridges/site_cartridges/<cartridgeName>/package.json`

```json
{
  "name": "<cartridgeName>",
  "version": "<version>",
  "description": "<description>",
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint cartridge/"
  },
  "keywords": [
    "commerce-cloud",
    "sfcc",
    "<domain>",
    "<appName>"
  ],
  "paths": {
    "base": "./cartridge/"
  },
  "devDependencies": {
    "jest": "^29.0.0",
    "eslint": "^8.0.0"
  }
}
```

## Step 8: Generate hooks.json

Create hook configuration:

**File:** `cartridges/site_cartridges/<cartridgeName>/cartridge/scripts/hooks.json`

```json
{
  "hooks": [
    {
      "name": "app.payment.processor.<appName>",
      "script": "./hooks/payment.js"
    },
    {
      "name": "app.<domain>.<appName>.calculate",
      "script": "./hooks/calculate.js"
    }
  ]
}
```

**Note:** Adjust hooks based on app type. Common hook patterns:
- **Tax:** `app.tax.calculate`, `app.tax.commit`, `app.tax.cancel`
- **Payment:** `app.payment.processor.*`
- **Shipping:** `app.shipping.calculate`
- **Promotion:** `app.promotion.calculate`

## Step 9: Generate hook scripts

Create template hook script:

**File:** `cartridges/site_cartridges/<cartridgeName>/cartridge/scripts/hooks/calculate.js`

```javascript
'use strict';

/**
 * Calculate hook for <displayName>
 * @param {dw.order.Basket} basket - The current basket
 * @returns {Object} Result object
 */
function calculate(basket) {
    var Logger = require('dw/system/Logger');
    var logger = Logger.getLogger('<appName>', 'calculate');

    try {
        logger.info('Starting calculation for basket: {0}', basket.UUID);

        // TODO: Implement your business logic here

        return {
            success: true,
            message: 'Calculation completed successfully'
        };
    } catch (e) {
        logger.error('Error in calculate: {0}', e.message);
        return {
            success: false,
            error: e.message
        };
    }
}

module.exports = {
    calculate: calculate
};
```

## Step 10: Generate helper template

Create business logic helper:

**File:** `cartridges/site_cartridges/<cartridgeName>/cartridge/scripts/helpers/<appName>Helper.js`

```javascript
'use strict';

/**
 * Helper functions for <displayName>
 */

/**
 * Example helper function
 * @param {Object} params - Parameters
 * @returns {Object} Result
 */
function processRequest(params) {
    var Logger = require('dw/system/Logger');
    var logger = Logger.getLogger('<appName>', 'helper');

    try {
        // TODO: Implement helper logic

        return {
            success: true,
            data: {}
        };
    } catch (e) {
        logger.error('Error in processRequest: {0}', e.message);
        throw e;
    }
}

module.exports = {
    processRequest: processRequest
};
```

## Step 11: Generate service wrapper

Create service framework integration:

**File:** `cartridges/site_cartridges/<cartridgeName>/cartridge/scripts/services/<appName>Service.js`

```javascript
'use strict';

var LocalServiceRegistry = require('dw/svc/LocalServiceRegistry');

/**
 * Create service definition
 */
var service = LocalServiceRegistry.createService('<serviceId>', {
    /**
     * Create request
     * @param {dw.svc.Service} svc - Service instance
     * @param {Object} params - Request parameters
     * @returns {String} Request body
     */
    createRequest: function(svc, params) {
        svc.setRequestMethod('POST');
        svc.addHeader('Content-Type', 'application/json');

        // Add authentication header if needed
        var credential = svc.getConfiguration().getCredential();
        if (credential && credential.getUser()) {
            svc.addHeader('Authorization', 'Bearer ' + credential.getPassword());
        }

        return JSON.stringify(params);
    },

    /**
     * Parse response
     * @param {dw.svc.Service} svc - Service instance
     * @param {dw.net.HTTPClient} client - HTTP client
     * @returns {Object} Parsed response
     */
    parseResponse: function(svc, client) {
        return JSON.parse(client.text);
    },

    /**
     * Filter log message
     * @param {String} msg - Log message
     * @returns {String} Filtered message
     */
    filterLogMessage: function(msg) {
        // Remove sensitive data from logs
        return msg;
    }
});

/**
 * Call the service
 * @param {Object} params - Request parameters
 * @returns {Object} Service response
 */
function call(params) {
    var result = service.call(params);

    if (result.status === 'OK') {
        return {
            success: true,
            data: result.object
        };
    } else {
        return {
            success: false,
            error: result.errorMessage,
            errorCode: result.error
        };
    }
}

module.exports = {
    call: call
};
```

## Step 12: Generate test templates

Create unit test structure:

**File:** `cartridges/site_cartridges/<cartridgeName>/test/unit/<appName>Helper.test.js`

```javascript
'use strict';

const helper = require('../../cartridge/scripts/helpers/<appName>Helper');

describe('<appName>Helper', () => {
    describe('processRequest', () => {
        it('should process request successfully', () => {
            const params = {
                // Test parameters
            };

            const result = helper.processRequest(params);

            expect(result.success).toBe(true);
        });

        it('should handle errors gracefully', () => {
            const params = {
                // Invalid parameters
            };

            expect(() => {
                helper.processRequest(params);
            }).toThrow();
        });
    });
});
```

## Step 13: Generate services.xml

Create service definitions for impex:

**File:** `impex/install/services.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<services xmlns="http://www.demandware.com/xml/impex/services/2015-07-01">
    <!-- Service Credential -->
    <service-credential credential-id="<appName>.credential">
        <url>https://api.example.com</url>
        <user-id>YOUR_API_KEY</user-id>
        <password>YOUR_API_SECRET</password>
    </service-credential>

    <!-- Service Profile -->
    <service-profile profile-id="<appName>.profile">
        <timeout-millis>30000</timeout-millis>
        <rate-limit-enabled>true</rate-limit-enabled>
        <rate-limit-calls>100</rate-limit-calls>
        <rate-limit-millis>1000</rate-limit-millis>
        <circuit-breaker-enabled>true</circuit-breaker-enabled>
    </service-profile>

    <!-- Service Definition -->
    <service service-id="<serviceId>">
        <service-type>HTTP</service-type>
        <enabled>true</enabled>
        <log-prefix><appName></log-prefix>
        <credential credential-id="<appName>.credential"/>
        <profile profile-id="<appName>.profile"/>
    </service>
</services>
```

**File:** `impex/uninstall/services.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<services xmlns="http://www.demandware.com/xml/impex/services/2015-07-01">
    <service service-id="<serviceId>" mode="delete"/>
    <service-profile profile-id="<appName>.profile" mode="delete"/>
    <service-credential credential-id="<appName>.credential" mode="delete"/>
</services>
```

## Step 14: Generate site preferences

Create custom preference definitions:

**File:** `impex/install/meta/system-objecttype-extensions.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://www.demandware.com/xml/impex/metadata/2006-10-31">
    <type-extension type-id="SitePreferences">
        <custom-attribute-definitions>
            <attribute-definition attribute-id="<appName>Enabled">
                <display-name xml:lang="x-default">Enable <displayName></display-name>
                <description xml:lang="x-default">Enable or disable <displayName> integration</description>
                <type>boolean</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <default-value>false</default-value>
            </attribute-definition>

            <attribute-definition attribute-id="<appName>ApiKey">
                <display-name xml:lang="x-default"><displayName> API Key</display-name>
                <description xml:lang="x-default">API key for <displayName> service</description>
                <type>string</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <min-length>0</min-length>
            </attribute-definition>
        </custom-attribute-definitions>

        <group-definitions>
            <attribute-group group-id="<appName>">
                <display-name xml:lang="x-default"><displayName></display-name>
                <attribute attribute-id="<appName>Enabled"/>
                <attribute attribute-id="<appName>ApiKey"/>
            </attribute-group>
        </group-definitions>
    </type-extension>
</metadata>
```

**File:** `impex/install/sites/SITEID/preferences.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<preferences xmlns="http://www.demandware.com/xml/impex/preferences/2006-10-31">
    <preference preference-id="<appName>Enabled">false</preference>
</preferences>
```

## Step 15: Generate storefront extension

Create React component template:

**File:** `storefront-next/src/extensions/<appName>/target-config.json`

```json
{
  "targets": {
    "product-details": {
      "slots": [
        {
          "id": "<appName>-product-details",
          "component": "./components/ProductDetails"
        }
      ]
    }
  }
}
```

**File:** `storefront-next/src/extensions/<appName>/components/ProductDetails.jsx`

```jsx
import React from 'react';

/**
 * <displayName> Product Details Component
 */
const ProductDetails = ({ product }) => {
  return (
    <div className="<appName>-product-details">
      <h3><displayName></h3>
      {/* TODO: Implement component */}
    </div>
  );
};

export default ProductDetails;
```

## Step 16: Update repository .gitignore

Ensure the repository root has a `.gitignore` that excludes extracted app directories:

**Add to repository root `.gitignore` (if not already present):**

```gitignore
# Commerce App - Extracted directories (DO NOT COMMIT)
# Only commit ZIP files and catalog.json
**/commerce-*-app-*/

# System files
.DS_Store
__MACOSX/
Thumbs.db
*.swp
*.swo

# IDE
.vscode/
.idea/
*.iml

# Temp files
*.tmp
.tmp/
```

**IMPORTANT:**
- Extracted app directories (e.g., `commerce-{appName}-app-v{version}/`) should NEVER be committed
- Only commit: ZIP file and catalog.json (for new apps)
- Update the root manifest at `commerce-apps-manifest/manifest.json` with your app's entry
- The extracted directory is for development/testing only

## Step 17: Validation checklist

Verify the generated structure:

- [ ] All directories created
- [ ] commerce-app.json generated with correct version
- [ ] README.md created with documentation template
- [ ] tasksList.json created
- [ ] package.json created in cartridge
- [ ] hooks.json created with example hooks
- [ ] Hook scripts created
- [ ] Helper files created
- [ ] Service wrapper created
- [ ] Test structure created
- [ ] services.xml created (install and uninstall)
- [ ] Site preference definitions created
- [ ] Storefront extension created
- [ ] .gitignore created

## Step 18: Next steps guidance

After scaffolding, guide the developer:

```
✅ App structure created successfully!

Next steps:

1. Review and customize the generated files
2. Implement your business logic in hooks and helpers
3. Update service endpoints and credentials
4. Write unit tests for your code
5. Test locally with your SFCC instance
6. Use `/generate-commerce-app` to package into ZIP when ready
7. Use `/validate-commerce-app` before submitting
8. Delete the extracted directory before committing (only commit ZIP)

Directory created at: <domain>/<isv-name>/commerce-<appName>-app-v<version>/

⚠️  IMPORTANT: This extracted directory is for development only.
    Do NOT commit it to git. Only commit:
    - <appName>-v<version>.zip
    - catalog.json (new apps only)

    Update root manifest: commerce-apps-manifest/manifest.json

To get started:
  cd <domain>/<isv-name>/commerce-<appName>-app-v<version>
  cd cartridges/site_cartridges/<cartridgeName>
  npm install
```

## Common app scaffolding patterns

### Tax App
- Hooks: calculate, commit, cancel
- Service: Tax calculation API
- Helpers: Tax calculation logic, address validation

### Payment App
- Hooks: payment authorization, capture, refund
- Service: Payment gateway API
- Helpers: Payment processing, fraud detection

### Shipping App
- Hooks: shipping calculation
- Service: Shipping carrier API
- Helpers: Rate calculation, address validation

### Ratings/Reviews App (`ratings-and-reviews`)
- Hooks: product data enrichment
- Service: Reviews platform API
- Helpers: Review aggregation, moderation

### Loyalty App (`loyalty`)
- Hooks: order completion, points calculation
- Service: Loyalty platform API
- Helpers: Points calculation, rewards management

### Gift Cards App (`gift-cards`)
- Hooks: payment method integration, balance check
- Service: Gift card platform API
- Helpers: Balance management, redemption
