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

In order to develop a Commerce App, build your app directory with the following CAP structure:

```
my-commerce-app/
├── src/extensions/{name}/          # React components for UI Targets
│   ├── target-config.json          # Maps components → storefront extension points
│   └── components/
├── cartridges/site_cartridges/     # Script API hook implementations
│   └── {name}/
│       └── cartridge/scripts/
│           ├── hooks.json          # Registers hooks with the platform
│           └── hooks/
├── impex/
│   ├── install/                    # Custom attributes, services, preferences
│   └── uninstall/                  # Clean up for uninstalled commerce apps
├── app-configuration/
│   └── tasksList.json              # Post-install merchant setup steps
└── package.json
```

## Published Apps

Each domain directory contains published Commerce App Packages:

```
tax/avalara-tax/
  ├── avalara-tax-v1.0.0.zip        # The installable CAP
  ├── manifest.json                 # Version metadata + SHA256 hash
  └── catalog.json                  # Version history (updated by CI)
```

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

See [CONTRIBUTING.md](CONTRIBUTING.md) for submission requirements. All external contributors must sign the Contributor License Agreement (CLA). A prompt to sign the agreement appears when a pull request is submitted.

**To publish a new Commerce App:**

1. Package your app as a CAP ZIP file
2. Generate a SHA256 hash: `shasum -a 256 my-app-v1.0.0.zip`
3. Create `manifest.json` with all required fields
4. Create `catalog.json` with INIT placeholder (new apps only)
5. Place files at `{domain}/{app-name}/` and open a PR

CI validates the ZIP hash, creates a Git tag on merge, and updates the catalog automatically.

**To update an existing app:** update the ZIP and `manifest.json` only. Do not modify `catalog.json`.

## Disclaimer

This repository may contain forward-looking statements that involve risks, uncertainties, and assumptions. If any such risks or uncertainties materialize or if any of the assumptions prove incorrect, results could differ materially from those expressed or implied. For more information, see [Salesforce SEC filings](https://investor.salesforce.com/financials/).

---

<p align="center">
  &copy; Copyright 2026 Salesforce, Inc. All rights reserved. Various trademarks held by their respective owners.<br>
  Built for ISV developers by the Commerce Apps team at Salesforce Commerce Cloud.
</p>