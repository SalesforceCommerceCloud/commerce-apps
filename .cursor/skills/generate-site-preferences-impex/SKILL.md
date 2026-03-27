---
name: generate-site-preferences-impex
description: >-
  Generate SFCC site preference impex files with custom attribute definitions, groups,
  and default values. Supports all attribute types (string, boolean, enum, text, etc.),
  validation, and multi-language localization. Use when adding configurable settings to commerce apps.
---

# Generate Site Preferences Impex

Generate complete site preference configuration impex files for SFCC commerce apps.

## Step 1: Collect preference information

Gather the following information for each site preference:

| Input | Example | Notes |
|-------|---------|-------|
| App name | `ratings-reviews` | Used for grouping and prefixing |
| Preference ID | `ratingsReviewsEnabled` | camelCase, unique identifier |
| Display name | `Enable Ratings & Reviews` | Human-readable name |
| Description | `Enable or disable ratings functionality` | Help text for merchants |
| Data type | `boolean`, `string`, `enum`, `text`, etc. | See supported types below |
| Default value | `false`, `""`, etc. | Initial value |
| Mandatory | Yes/No | Required field? |
| Group ID | `ratingsReviews` | Logical grouping of preferences |

## Step 2: Supported attribute types

### Boolean (true/false)

**Use for:** Enable/disable flags, feature toggles

```xml
<attribute-definition attribute-id="ratingsReviewsEnabled">
    <display-name xml:lang="x-default">Enable Ratings &amp; Reviews</display-name>
    <description xml:lang="x-default">Enable or disable the ratings and reviews functionality</description>
    <type>boolean</type>
    <mandatory-flag>false</mandatory-flag>
    <externally-managed-flag>false</externally-managed-flag>
    <default-value>false</default-value>
</attribute-definition>
```

### String (short text)

**Use for:** API keys, URLs, short configuration values

```xml
<attribute-definition attribute-id="ratingsReviewsApiKey">
    <display-name xml:lang="x-default">API Key</display-name>
    <description xml:lang="x-default">Your Ratings &amp; Reviews API key</description>
    <type>string</type>
    <mandatory-flag>false</mandatory-flag>
    <externally-managed-flag>false</externally-managed-flag>
    <min-length>0</min-length>
    <max-length>255</max-length>
    <default-value></default-value>
</attribute-definition>
```

### Text (long text)

**Use for:** Long descriptions, JSON configurations, multi-line content

```xml
<attribute-definition attribute-id="ratingsReviewsCustomConfig">
    <display-name xml:lang="x-default">Custom Configuration</display-name>
    <description xml:lang="x-default">Custom JSON configuration for advanced settings</description>
    <type>text</type>
    <mandatory-flag>false</mandatory-flag>
    <externally-managed-flag>false</externally-managed-flag>
    <default-value>{}</default-value>
</attribute-definition>
```

### Integer (whole numbers)

**Use for:** Counts, limits, numeric settings

```xml
<attribute-definition attribute-id="ratingsReviewsMaxReviews">
    <display-name xml:lang="x-default">Maximum Reviews Per Product</display-name>
    <description xml:lang="x-default">Maximum number of reviews to display per product</description>
    <type>integer</type>
    <mandatory-flag>false</mandatory-flag>
    <externally-managed-flag>false</externally-managed-flag>
    <min-value>1</min-value>
    <max-value>100</max-value>
    <default-value>10</default-value>
</attribute-definition>
```

### Decimal (numbers with decimals)

**Use for:** Percentages, monetary values, precise numeric values

```xml
<attribute-definition attribute-id="ratingsReviewsMinimumRating">
    <display-name xml:lang="x-default">Minimum Rating Threshold</display-name>
    <description xml:lang="x-default">Minimum rating required to display (0.0 - 5.0)</description>
    <type>decimal</type>
    <mandatory-flag>false</mandatory-flag>
    <externally-managed-flag>false</externally-managed-flag>
    <min-value>0.0</min-value>
    <max-value>5.0</max-value>
    <default-value>0.0</default-value>
    <scale>1</scale>
</attribute-definition>
```

### Enum (dropdown selection)

**Use for:** Pre-defined options, modes, environments

```xml
<attribute-definition attribute-id="ratingsReviewsEnvironment">
    <display-name xml:lang="x-default">Environment</display-name>
    <description xml:lang="x-default">Select the API environment</description>
    <type>enum-of-string</type>
    <mandatory-flag>false</mandatory-flag>
    <externally-managed-flag>false</externally-managed-flag>
    <value-definitions>
        <value-definition>
            <display xml:lang="x-default">Sandbox</display>
            <value>sandbox</value>
        </value-definition>
        <value-definition>
            <display xml:lang="x-default">Production</display>
            <value>production</value>
        </value-definition>
    </value-definitions>
    <default-value>sandbox</default-value>
</attribute-definition>
```

### Set of String (multiple selections)

**Use for:** Multiple values, feature lists, category selections

```xml
<attribute-definition attribute-id="ratingsReviewsEnabledFeatures">
    <display-name xml:lang="x-default">Enabled Features</display-name>
    <description xml:lang="x-default">Select which features to enable</description>
    <type>set-of-string</type>
    <mandatory-flag>false</mandatory-flag>
    <externally-managed-flag>false</externally-managed-flag>
    <value-definitions>
        <value-definition>
            <display xml:lang="x-default">Product Ratings</display>
            <value>ratings</value>
        </value-definition>
        <value-definition>
            <display xml:lang="x-default">Written Reviews</display>
            <value>reviews</value>
        </value-definition>
        <value-definition>
            <display xml:lang="x-default">Photo Upload</display>
            <value>photos</value>
        </value-definition>
        <value-definition>
            <display xml:lang="x-default">Video Upload</display>
            <value>videos</value>
        </value-definition>
    </value-definitions>
</attribute-definition>
```

### Email

**Use for:** Email addresses, notification recipients

```xml
<attribute-definition attribute-id="ratingsReviewsNotificationEmail">
    <display-name xml:lang="x-default">Notification Email</display-name>
    <description xml:lang="x-default">Email address for review notifications</description>
    <type>email</type>
    <mandatory-flag>false</mandatory-flag>
    <externally-managed-flag>false</externally-managed-flag>
    <default-value></default-value>
</attribute-definition>
```

### Password (encrypted string)

**Use for:** API secrets, passwords, sensitive data

```xml
<attribute-definition attribute-id="ratingsReviewsApiSecret">
    <display-name xml:lang="x-default">API Secret</display-name>
    <description xml:lang="x-default">Your API secret (encrypted)</description>
    <type>password</type>
    <mandatory-flag>false</mandatory-flag>
    <externally-managed-flag>false</externally-managed-flag>
    <min-length>0</min-length>
</attribute-definition>
```

### URL

**Use for:** Webhook URLs, API endpoints, redirect URLs

```xml
<attribute-definition attribute-id="ratingsReviewsWebhookUrl">
    <display-name xml:lang="x-default">Webhook URL</display-name>
    <description xml:lang="x-default">URL for webhook notifications</description>
    <type>string</type>
    <mandatory-flag>false</mandatory-flag>
    <externally-managed-flag>false</externally-managed-flag>
    <min-length>0</min-length>
    <default-value></default-value>
</attribute-definition>
```

## Step 3: Generate meta/system-objecttype-extensions.xml

Create the attribute definitions file:

**File:** `impex/install/meta/system-objecttype-extensions.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://www.demandware.com/xml/impex/metadata/2006-10-31">
    <type-extension type-id="SitePreferences">
        <custom-attribute-definitions>

            <!-- Enable/Disable Feature -->
            <attribute-definition attribute-id="{appName}Enabled">
                <display-name xml:lang="x-default">Enable {displayName}</display-name>
                <description xml:lang="x-default">Enable or disable {displayName} integration</description>
                <type>boolean</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <default-value>false</default-value>
            </attribute-definition>

            <!-- API Credentials -->
            <attribute-definition attribute-id="{appName}ApiKey">
                <display-name xml:lang="x-default">{displayName} API Key</display-name>
                <description xml:lang="x-default">Your {displayName} API key</description>
                <type>string</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <min-length>0</min-length>
                <default-value></default-value>
            </attribute-definition>

            <attribute-definition attribute-id="{appName}ApiSecret">
                <display-name xml:lang="x-default">{displayName} API Secret</display-name>
                <description xml:lang="x-default">Your {displayName} API secret (encrypted)</description>
                <type>password</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <min-length>0</min-length>
            </attribute-definition>

            <!-- Environment Selection -->
            <attribute-definition attribute-id="{appName}Environment">
                <display-name xml:lang="x-default">{displayName} Environment</display-name>
                <description xml:lang="x-default">Select the API environment (sandbox or production)</description>
                <type>enum-of-string</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <value-definitions>
                    <value-definition>
                        <display xml:lang="x-default">Sandbox (Testing)</display>
                        <value>sandbox</value>
                    </value-definition>
                    <value-definition>
                        <display xml:lang="x-default">Production (Live)</display>
                        <value>production</value>
                    </value-definition>
                </value-definitions>
                <default-value>sandbox</default-value>
            </attribute-definition>

            <!-- Debug Mode -->
            <attribute-definition attribute-id="{appName}DebugMode">
                <display-name xml:lang="x-default">Debug Mode</display-name>
                <description xml:lang="x-default">Enable detailed logging for troubleshooting</description>
                <type>boolean</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <default-value>false</default-value>
            </attribute-definition>

            <!-- Add more preferences as needed -->

        </custom-attribute-definitions>

        <!-- Group Definitions (organize preferences in BM) -->
        <group-definitions>
            <attribute-group group-id="{appName}">
                <display-name xml:lang="x-default">{displayName}</display-name>
                <attribute attribute-id="{appName}Enabled"/>
                <attribute attribute-id="{appName}ApiKey"/>
                <attribute attribute-id="{appName}ApiSecret"/>
                <attribute attribute-id="{appName}Environment"/>
                <attribute attribute-id="{appName}DebugMode"/>
                <!-- Add all attributes to the group -->
            </attribute-group>
        </group-definitions>

    </type-extension>
</metadata>
```

## Step 4: Generate sites/SITEID/preferences.xml

Create default preference values:

**File:** `impex/install/sites/SITEID/preferences.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<preferences xmlns="http://www.demandware.com/xml/impex/preferences/2006-10-31">
    <!-- Set default values for each preference -->
    <preference preference-id="{appName}Enabled">false</preference>
    <preference preference-id="{appName}Environment">sandbox</preference>
    <preference preference-id="{appName}DebugMode">false</preference>

    <!-- Note: Leave sensitive values (API keys, secrets) empty -->
    <!-- Merchants will configure these manually after installation -->
</preferences>
```

**Important:** SITEID is a placeholder. Merchants replace with actual site IDs during installation.

## Step 5: Add localization (multi-language support)

Add translations for international merchants:

```xml
<attribute-definition attribute-id="{appName}Enabled">
    <display-name xml:lang="x-default">Enable {displayName}</display-name>
    <display-name xml:lang="de">Aktiviere {displayName}</display-name>
    <display-name xml:lang="fr">Activer {displayName}</display-name>
    <display-name xml:lang="es">Activar {displayName}</display-name>
    <display-name xml:lang="ja">{displayName}を有効にする</display-name>

    <description xml:lang="x-default">Enable or disable {displayName} integration</description>
    <description xml:lang="de">Aktivieren oder deaktivieren Sie die {displayName}-Integration</description>
    <description xml:lang="fr">Activer ou désactiver l'intégration {displayName}</description>
    <description xml:lang="es">Activar o desactivar la integración {displayName}</description>
    <description xml:lang="ja">{displayName}統合を有効または無効にする</description>

    <type>boolean</type>
    <mandatory-flag>false</mandatory-flag>
    <externally-managed-flag>false</externally-managed-flag>
    <default-value>false</default-value>
</attribute-definition>
```

**Supported language codes:**
- `x-default` - English (default)
- `de` - German
- `fr` - French
- `es` - Spanish
- `it` - Italian
- `ja` - Japanese
- `zh` - Chinese
- `pt` - Portuguese
- `nl` - Dutch

## Step 6: Common preference patterns by app type

### Tax App Preferences

```xml
<custom-attribute-definitions>
    <!-- Enable/Disable -->
    <attribute-definition attribute-id="taxCalculationEnabled">
        <display-name xml:lang="x-default">Enable Tax Calculation</display-name>
        <type>boolean</type>
        <default-value>false</default-value>
    </attribute-definition>

    <!-- Company Code -->
    <attribute-definition attribute-id="taxCompanyCode">
        <display-name xml:lang="x-default">Company Code</display-name>
        <type>string</type>
        <min-length>0</min-length>
    </attribute-definition>

    <!-- Environment -->
    <attribute-definition attribute-id="taxEnvironment">
        <display-name xml:lang="x-default">Environment</display-name>
        <type>enum-of-string</type>
        <value-definitions>
            <value-definition>
                <display xml:lang="x-default">Sandbox</display>
                <value>sandbox</value>
            </value-definition>
            <value-definition>
                <display xml:lang="x-default">Production</display>
                <value>production</value>
            </value-definition>
        </value-definitions>
        <default-value>sandbox</default-value>
    </attribute-definition>

    <!-- Commit on Invoice -->
    <attribute-definition attribute-id="taxCommitOnInvoice">
        <display-name xml:lang="x-default">Commit Tax on Invoice</display-name>
        <description xml:lang="x-default">Automatically commit tax when invoice is created</description>
        <type>boolean</type>
        <default-value>true</default-value>
    </attribute-definition>
</custom-attribute-definitions>
```

### Payment App Preferences

```xml
<custom-attribute-definitions>
    <!-- Enable Payment Method -->
    <attribute-definition attribute-id="paymentEnabled">
        <display-name xml:lang="x-default">Enable Payment Gateway</display-name>
        <type>boolean</type>
        <default-value>false</default-value>
    </attribute-definition>

    <!-- Merchant ID -->
    <attribute-definition attribute-id="paymentMerchantId">
        <display-name xml:lang="x-default">Merchant ID</display-name>
        <type>string</type>
        <min-length>0</min-length>
    </attribute-definition>

    <!-- API Credentials -->
    <attribute-definition attribute-id="paymentPublicKey">
        <display-name xml:lang="x-default">Public API Key</display-name>
        <type>string</type>
        <min-length>0</min-length>
    </attribute-definition>

    <attribute-definition attribute-id="paymentSecretKey">
        <display-name xml:lang="x-default">Secret API Key</display-name>
        <type>password</type>
        <min-length>0</min-length>
    </attribute-definition>

    <!-- Test Mode -->
    <attribute-definition attribute-id="paymentTestMode">
        <display-name xml:lang="x-default">Test Mode</display-name>
        <description xml:lang="x-default">Enable test mode for development</description>
        <type>boolean</type>
        <default-value>true</default-value>
    </attribute-definition>

    <!-- Payment Methods -->
    <attribute-definition attribute-id="paymentEnabledMethods">
        <display-name xml:lang="x-default">Enabled Payment Methods</display-name>
        <type>set-of-string</type>
        <value-definitions>
            <value-definition>
                <display xml:lang="x-default">Credit Card</display>
                <value>credit_card</value>
            </value-definition>
            <value-definition>
                <display xml:lang="x-default">Debit Card</display>
                <value>debit_card</value>
            </value-definition>
            <value-definition>
                <display xml:lang="x-default">PayPal</display>
                <value>paypal</value>
            </value-definition>
            <value-definition>
                <display xml:lang="x-default">Apple Pay</display>
                <value>apple_pay</value>
            </value-definition>
        </value-definitions>
    </attribute-definition>
</custom-attribute-definitions>
```

### Shipping App Preferences

```xml
<custom-attribute-definitions>
    <!-- Enable Shipping -->
    <attribute-definition attribute-id="shippingEnabled">
        <display-name xml:lang="x-default">Enable Shipping Integration</display-name>
        <type>boolean</type>
        <default-value>false</default-value>
    </attribute-definition>

    <!-- Account Number -->
    <attribute-definition attribute-id="shippingAccountNumber">
        <display-name xml:lang="x-default">Carrier Account Number</display-name>
        <type>string</type>
        <min-length>0</min-length>
    </attribute-definition>

    <!-- Origin Address -->
    <attribute-definition attribute-id="shippingOriginZip">
        <display-name xml:lang="x-default">Origin Zip Code</display-name>
        <type>string</type>
        <min-length>0</min-length>
    </attribute-definition>

    <!-- Service Levels -->
    <attribute-definition attribute-id="shippingEnabledServices">
        <display-name xml:lang="x-default">Enabled Shipping Services</display-name>
        <type>set-of-string</type>
        <value-definitions>
            <value-definition>
                <display xml:lang="x-default">Ground</display>
                <value>ground</value>
            </value-definition>
            <value-definition>
                <display xml:lang="x-default">2-Day</display>
                <value>2day</value>
            </value-definition>
            <value-definition>
                <display xml:lang="x-default">Overnight</display>
                <value>overnight</value>
            </value-definition>
        </value-definitions>
    </attribute-definition>
</custom-attribute-definitions>
```

### Reviews/Ratings App Preferences

```xml
<custom-attribute-definitions>
    <!-- Enable Reviews -->
    <attribute-definition attribute-id="reviewsEnabled">
        <display-name xml:lang="x-default">Enable Reviews</display-name>
        <type>boolean</type>
        <default-value>false</default-value>
    </attribute-definition>

    <!-- Client ID -->
    <attribute-definition attribute-id="reviewsClientId">
        <display-name xml:lang="x-default">Client ID</display-name>
        <type>string</type>
        <min-length>0</min-length>
    </attribute-definition>

    <!-- Moderation -->
    <attribute-definition attribute-id="reviewsAutoModeration">
        <display-name xml:lang="x-default">Auto Moderation</display-name>
        <description xml:lang="x-default">Automatically moderate reviews before publishing</description>
        <type>boolean</type>
        <default-value>true</default-value>
    </attribute-definition>

    <!-- Display Settings -->
    <attribute-definition attribute-id="reviewsMaxPerPage">
        <display-name xml:lang="x-default">Reviews Per Page</display-name>
        <type>integer</type>
        <min-value>1</min-value>
        <max-value>100</max-value>
        <default-value>10</default-value>
    </attribute-definition>

    <!-- Minimum Rating -->
    <attribute-definition attribute-id="reviewsMinimumRating">
        <display-name xml:lang="x-default">Minimum Rating to Display</display-name>
        <type>decimal</type>
        <min-value>0.0</min-value>
        <max-value>5.0</max-value>
        <default-value>0.0</default-value>
        <scale>1</scale>
    </attribute-definition>
</custom-attribute-definitions>
```

## Step 7: Best practices

### Naming Conventions

1. **Prefix with app name:** `{appName}SettingName`
   - Example: `ratingsReviewsEnabled`, `taxCalculationEnabled`
   - Prevents conflicts with other apps

2. **Use camelCase:** `myPreferenceName`
   - Not: `my_preference_name` or `MyPreferenceName`

3. **Be descriptive:** `autoCommitTaxOnInvoice`
   - Not: `commit`, `flag1`

### Grouping

1. **Create logical groups:** Group related preferences together
2. **Use clear group names:** Match app name or feature area
3. **Order attributes logically:** Most important first

### Default Values

1. **Safe defaults:** Start with features disabled
2. **Sensible values:** Choose defaults that work for most cases
3. **Empty credentials:** Don't include placeholder API keys

### Validation

1. **Set min/max values:** Prevent invalid input
2. **Use appropriate types:** Boolean for toggles, enum for fixed options
3. **Mark mandatory carefully:** Only require truly essential fields

### Security

1. **Use password type:** For API secrets and sensitive data
2. **Don't expose secrets:** Keep API keys empty in defaults
3. **Document sensitive fields:** Clear descriptions of what goes where

## Step 8: Validation checklist

- [ ] All attribute IDs prefixed with app name
- [ ] Attribute IDs use camelCase
- [ ] Display names are clear and descriptive
- [ ] Descriptions provide helpful guidance
- [ ] Appropriate data types chosen
- [ ] Default values are safe and sensible
- [ ] Mandatory flags used sparingly
- [ ] Min/max values set for numeric types
- [ ] Password type used for secrets
- [ ] All attributes added to group definition
- [ ] Group ID matches app name
- [ ] XML is well-formed and valid
- [ ] Localization added for key languages (optional)
- [ ] Default preferences.xml created
- [ ] Sensitive values left empty in defaults

## Step 9: Testing

After generating the impex files:

1. **Validate XML syntax:**
   ```bash
   xmllint --noout impex/install/meta/system-objecttype-extensions.xml
   xmllint --noout impex/install/sites/SITEID/preferences.xml
   ```

2. **Import via Business Manager:**
   - Administration > Site Development > Import & Export
   - Import meta file first
   - Then import preferences

3. **Verify in Business Manager:**
   - Merchant Tools > Site Preferences > Custom Preferences
   - Check your app group appears
   - Verify all preferences are present
   - Test data types (dropdowns, checkboxes, etc.)
   - Check descriptions are helpful

4. **Test in code:**
   - Read preferences via `Site.current.preferences.custom.{attributeId}`
   - Verify default values
   - Test with different values

## Common mistakes to avoid

| Mistake | Impact | Fix |
|---------|--------|-----|
| Missing app name prefix | ID conflicts | Prefix all IDs with app name |
| Wrong data type | Validation errors | Choose appropriate type |
| No default values | Undefined behavior | Set sensible defaults |
| Everything mandatory | Poor merchant experience | Only require essentials |
| Generic descriptions | Confusion | Provide clear guidance |
| Hardcoded credentials | Security risk | Leave empty for merchants |
| Missing from group | Hidden in BM | Add all attributes to group |
| No validation | Bad input | Set min/max, use enums |
| Missing localization | International issues | Add key languages |
| Forgot SITEID placeholder | Import errors | Use SITEID, not actual ID |

## Quick reference template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://www.demandware.com/xml/impex/metadata/2006-10-31">
    <type-extension type-id="SitePreferences">
        <custom-attribute-definitions>

            <attribute-definition attribute-id="{appName}Enabled">
                <display-name xml:lang="x-default">Enable {App Name}</display-name>
                <description xml:lang="x-default">Enable or disable {App Name}</description>
                <type>boolean</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <default-value>false</default-value>
            </attribute-definition>

            <!-- Add more attributes here -->

        </custom-attribute-definitions>

        <group-definitions>
            <attribute-group group-id="{appName}">
                <display-name xml:lang="x-default">{App Name}</display-name>
                <attribute attribute-id="{appName}Enabled"/>
                <!-- Add all attributes -->
            </attribute-group>
        </group-definitions>
    </type-extension>
</metadata>
```
