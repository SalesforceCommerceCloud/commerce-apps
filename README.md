<h1 align="center">Commerce Apps</h1>
<h3 align="center">Salesforce Commerce Cloud</h3>

<p align="center">
  Build, package, and distribute installable extensions for Salesforce Commerce Cloud storefronts.
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> •
  <a href="#published-apps">Published Apps</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#disclaimer">Disclaimer</a>
</p>

---

## What Are Commerce Apps?

Commerce Apps are packaged extensions that add capabilities to [Storefront Next](https://developer.salesforce.com/docs/commerce/b2c-commerce) storefronts. A single app can bundle frontend UI components, backend API adapters, platform configuration, and merchant setup guidance into one installable unit called a **Commerce App Package (CAP)**.

Merchants install Commerce Apps through Business Manager with a click-to-install experience. Developers build them here.

**Three ways to build:**

| Path | You Build | Platform Provides | Example |
|------|-----------|-------------------|---------|
| **UI Target Only** | React components for storefront extension points | Build-time injection via Vite plugin | Ratings widget, store locator, loyalty badge |
| **API Adapter Only** | Script API hooks implementing platform contracts | Hook dispatch, lifecycle management | Tax calculation (Avalara), fraud detection |
| **Full App** | Both UI components and backend adapters | All of the above | Shipping estimator, BNPL provider |

## Quick Start

### Using Claude Code Skills

If you're using Claude Code, we provide comprehensive skills to streamline development:

**Start a new app:**
```
/scaffold-app
```

**Generate impex files:**
```
/generate-service-impex
/generate-site-preferences-impex
/generate-custom-object-impex
```

**Package and validate:**
```
/package-app
/validate-app
/validate-impex
```

**Submit to registry:**
```
/submit-app
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for complete skill documentation.

### Manual Development

Build your app directory with the following CAP structure:

```
commerce-{app-name}-app-v{version}/
├── commerce-app.json                # App metadata
├── README.md                        # Documentation
├── app-configuration/
│   └── tasksList.json              # Post-install merchant setup steps
├── icons/                          # App icon (required)
│   └── {icon-filename}.png         # CI extracts to commerce-apps-manifest/icons/
├── cartridges/                     # Backend-only or Fullstack apps
│   ├── site_cartridges/{name}/    # Script API hook implementations
│   │   ├── package.json
│   │   ├── cartridge/scripts/
│   │   │   ├── hooks.json         # Registers hooks with the platform
│   │   │   ├── hooks/             # Hook implementations
│   │   │   ├── helpers/           # Business logic
│   │   │   └── services/          # Service framework wrappers
│   │   └── test/                  # Unit tests
│   └── bm_cartridges/             # Business Manager extensions (optional)
├── storefront-next/src/extensions/{name}/  # UI-only or Fullstack apps
│   ├── target-config.json         # Maps components → storefront extension points
│   ├── index.ts                   # Barrel exports
│   ├── components/
│   └── locales/                   # Required: en-US, en-GB, it-IT
│       ├── en-US/translations.json
│       ├── en-GB/translations.json
│       └── it-IT/translations.json
├── impex/                          # Backend-only or Fullstack apps
│   ├── install/                   # Service configs, custom attributes, preferences
│   │   ├── services.xml
│   │   ├── meta/
│   │   │   ├── system-objecttype-extensions.xml
│   │   │   └── custom-objecttype-definitions.xml
│   │   └── sites/SITEID/
│   │       └── preferences.xml
│   └── uninstall/                 # Cleanup for uninstalled apps
│       └── services.xml
```

**Three architectures:**
- **UI-only**: Has `storefront-next/`, no `cartridges/` or `impex/`
- **Backend-only**: Has `cartridges/` and `impex/`, no `storefront-next/`
- **Fullstack**: Has all three: `storefront-next/`, `cartridges/`, and `impex/`

## Published Apps

Apps are organized by domain and app name:

```
{domain}/{appName}/
  ├── {appName}-v{version}.zip     # The installable CAP
  └── catalog.json                  # Version history (updated by CI)

commerce-apps-manifest/
  ├── manifest.json                 # Root manifest with all app entries
  ├── icons/
  │   └── {iconName}.png            # App icons
  └── translations/
      ├── en-US.json                # App translations (minimum)
      ├── de.json
      ├── fr.json
      └── ... (13 locale files)
```

**Example structure:**

```
tax/
├── avalara-tax/
│   ├── avalara-tax-v0.2.8.zip
│   └── catalog.json
└── vertex-tax/
    ├── vertex-tax-v1.0.0.zip
    └── catalog.json

payment/
├── stripe-payment/
│   ├── stripe-payment-v1.0.0.zip
│   └── catalog.json
└── adyen-payment/
    ├── adyen-payment-v1.0.0.zip
    └── catalog.json

commerce-apps-manifest/
├── manifest.json              # Contains all app entries
├── icons/
│   ├── avalara.png
│   ├── stripe.png
│   └── bazaarvoice.png
└── translations/
    ├── en-US.json            # All app translations
    ├── de.json
    └── ... (13 locale files)
```

**Note:** Extracted app directories (`commerce-{app-name}-app-v{version}/`) are for development only and should NOT be committed to the repository.

### Domains

Every app's `domain` field must be one of these. Domains use hyphen-case. Provider domains (`tax`, `payment`, `shipping`) show under "Providers" on the checkout hub; all other domains show under "Additional Setup".

| Domain | Section | Description | Example Apps |
|--------|---------|-------------|--------------|
| `tax` | Providers | Tax calculation and compliance | Avalara, Vertex |
| `payment` | Providers | Payment processing | Stripe, Adyen, PayPal |
| `shipping` | Providers | Shipping and fulfillment | ShipStation, EasyPost |
| `gift-cards` | Additional Setup | Gift card purchasing, redemption, and balance | Salesforce Gift Cards, Adyen Gift Cards |
| `ratings-and-reviews` | Additional Setup | Product ratings and reviews | Bazaarvoice, Yotpo, PowerReviews |
| `loyalty` | Additional Setup | Loyalty programs and rewards | LoyaltyLion, Smile.io |
| `search` | Additional Setup | Search and merchandising | Algolia, Elasticsearch |
| `address-verification` | Additional Setup | Address validation and standardization | Smarty, Google Address Validation |
| `analytics` | Additional Setup | Analytics and reporting | Google Analytics, Segment |
| `approaching-discounts` | Additional Setup | Approaching discount notifications | Salesforce Approaching Discounts |
| `fraud` | Additional Setup | Fraud detection and prevention | Signifyd, Forter, Riskified |

## Tech Stack

Commerce App frontend extensions target the Storefront Next stack:

| Layer | Technology |
|-------|-----------|
| Framework | React 19 |
| Language | TypeScript (strict) |
| Build | Vite |
| Styling | Tailwind CSS 4 (`@theme inline`, no config file) |
| Components | ShadCN UI (29 primitives on Radix UI) |
| Variants | CVA (class-variance-authority) |
| Routing | React Router 7 |
| i18n | react-i18next |
| Component docs | Storybook 10 |
| Unit testing | Vitest + React Testing Library |
| E2E testing | CodeceptJS + Playwright |

Backend adapters use the Commerce Cloud Script API (CommonJS, `require('dw/...')` modules).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for complete submission requirements and Claude Code skills documentation.

### Publishing Workflow

**Using Claude Code (Recommended):**

1. **Scaffold new app:** `/scaffold-app`
2. **Build your app code** (cartridges, extensions, etc.)
3. **Generate impex:** `/generate-service-impex`, `/generate-site-preferences-impex`
4. **Package app:** `/package-app`
5. **Validate:** `/validate-app`
6. **Submit PR:** `/submit-app`

**Manual Process:**

1. Build your app directory with required structure
2. Package as a CAP ZIP file: `zip -r my-app-v1.0.0.zip commerce-my-app-app-v1.0.0/ -x "*.DS_Store" -x "__MACOSX/*" -x "*/.*"`
3. Generate SHA256 hash: `shasum -a 256 my-app-v1.0.0.zip`
4. Update root manifest at `commerce-apps-manifest/manifest.json` with app entry (id, name, description, iconName, domain, version, zip, sha256)
5. Add translations to `commerce-apps-manifest/translations/en-US.json` (minimum requirement)
6. Create `catalog.json` with INIT placeholder (new apps only)
7. Place ZIP at `{domain}/{appName}/` where `{appName}` matches the "id" field (e.g., `tax/avalara-tax/` or `address-verification/loqate-address-verification/`)
9. Delete old ZIP versions: `rm -f {app-name}-v*.zip` (keep only the latest version)
10. Commit ONLY the ZIP, root manifest, icon, translations, and catalog.json (do NOT commit extracted directories)
11. Open a PR

**CI Validation:** Validates ZIP structure, manifest format, and SHA256 hash. On merge, creates a Git tag, extracts app icons to `commerce-apps-manifest/icons/`, and updates the catalog automatically.

**Updating an app:** Update the ZIP, root manifest entry, and icon/translations (if changed). Do NOT add new versions to `catalog.json` (CI handles it). You may add `"deprecated": true` to existing versions if needed.

### What to Commit

Only commit these files to the repository:

✅ **DO commit:**
- `{domain}/{appName}/{appName}-v{version}.zip` - The packaged app
- `commerce-apps-manifest/manifest.json` - Root manifest with app entry
- `commerce-apps-manifest/translations/en-US.json` - App translations (minimum)
- `{domain}/{appName}/catalog.json` - Version catalog (new apps only, with INIT values)

**Note:** App icons are automatically extracted from the ZIP by the CI workflow and added to `commerce-apps-manifest/icons/` - do NOT manually commit icons.

❌ **DO NOT commit:**
- `commerce-{app-name}-app-v{version}/` - Extracted app directories (dev only)
- `.DS_Store`, `Thumbs.db` - System files
- `node_modules/` - Dependencies
- Old ZIP versions - Delete before committing
- IDE files (`.vscode/`, `.idea/`)

The repository `.gitignore` is configured to exclude extracted directories and system files.

### Claude Code Skills

This repository includes comprehensive skills for Commerce App development:

**App Development:**
- `/scaffold-app` - Generate complete app structure (UI-only, Backend-only, or Fullstack)
- `/package-app` - Package app into registry-ready ZIP (handles both new apps and version bumps)

**Impex Generation:**
- `/generate-service-impex` - Service credentials, profiles, definitions
- `/generate-site-preferences-impex` - Custom site preferences
- `/generate-custom-object-impex` - Custom object types
- `/validate-impex` - Validate all impex files

**Validation:**
- `/validate-app` - Comprehensive architecture-aware validation (structure, manifest, impex, icons, translations)

**Submission:**
- `/submit-app` - Guide through PR submission process with automated GitHub CLI integration

### External Contributors

All external contributors must sign the Contributor License Agreement (CLA). A prompt to sign the agreement appears when a pull request is submitted.

## Disclaimer

This repository may contain forward-looking statements that involve risks, uncertainties, and assumptions. If any such risks or uncertainties materialize or if any of the assumptions prove incorrect, results could differ materially from those expressed or implied. For more information, see [Salesforce SEC filings](https://investor.salesforce.com/financials/).

---

<p align="center">
  &copy; Copyright 2026 Salesforce, Inc. All rights reserved. Various trademarks held by their respective owners.<br>
  Built for ISV developers by the Commerce Apps team at Salesforce Commerce Cloud.
</p>
