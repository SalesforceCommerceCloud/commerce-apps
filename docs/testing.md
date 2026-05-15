# Testing Commerce Apps

This guide explains how to test your Commerce App locally before submitting to the registry. For full documentation on designing, building, testing, and submitting Commerce apps, see the [developer guide](https://dpkoal18ck1fm.cloudfront.net/docs/commerce/b2c-commerce/guide/index.html).

The recommended workflow uses the [`b2c` CLI](#tooling) — it covers cartridge upload, impex import, CAP install/uninstall, log inspection, and metadata validation against the SFCC XSDs in a single tool. If you're using a coding agent, the [`cap-dev` agent skills](#agent-skills-optional) shipped in this repository add scaffolding, impex codegen, registry-specific validation, and PR automation on top.

---

## Table of Contents

- [Tooling](#tooling)
- [Testing Workflow](#testing-workflow)
- [Validating the App Package](#validating-the-app-package)
- [Installing on a Sandbox](#installing-on-a-sandbox)
- [Testing Cartridges](#testing-cartridges)
- [Testing Impex Files](#testing-impex-files)
- [Testing UI Components](#testing-ui-components)
- [Testing Services](#testing-services)
- [Inspecting Logs](#inspecting-logs)
- [End-to-End Testing](#end-to-end-testing)
- [Performance Testing](#performance-testing)
- [Pre-Submission Checklist](#pre-submission-checklist)
- [Common Testing Issues](#common-testing-issues)

---

## Tooling

### Required Access
- A B2C Commerce sandbox (On-Demand Sandbox or partner sandbox)
- A WebDAV access key (Account Manager → Profile → Application access keys → WebDAV)
- An OCAPI/Account Manager API client with the permissions required by the commands you plan to run (see the [Authentication Guide](https://salesforcecommercecloud.github.io/b2c-developer-tooling/guide/authentication))

### B2C DX VS Code Extension (recommended IDE)

The [B2C DX VS Code extension](https://salesforcecommercecloud.github.io/b2c-developer-tooling/vscode-extension/) provides an integrated development experience on top of the same `b2c` CLI. It picks up the same `dw.json` configuration, so configuring once works for both.

Most useful for app development:

- **Cartridge upload + watch** — edit locally, changes sync to the active code version on save.
- **B2C Script Debugger** — set breakpoints in cartridge controllers, jobs, hooks, and Custom SCAPI API scripts; step through, watch variables, drop log points.
- **CAP-aware tooling** — surfaces `cap validate`, `cap install`, `cap list`, etc. in the UI.
- **WebDAV browser** — open and edit `Impex/`, `Logs/`, and catalog files like local files.
- **SCAPI API Explorer** — try Shopper and Admin APIs from a built-in Swagger UI with auth handled.
- **Log tailing** — stream `error-*.log`, `warn-*.log`, and custom logs into a VS Code output channel.
- **Sandbox Realm Explorer** — start/stop/clone/delete on-demand sandboxes from a tree view.

Install per the [extension installation docs](https://salesforcecommercecloud.github.io/b2c-developer-tooling/vscode-extension/installation). The extension is a developer preview — file issues at the [b2c-developer-tooling repo](https://github.com/SalesforceCommerceCloud/b2c-developer-tooling).

### `b2c` CLI

The [`b2c` CLI](https://salesforcecommercecloud.github.io/b2c-developer-tooling/cli/) is the primary tool for testing apps against a sandbox. Install it once and configure your sandbox connection.

```bash
# Install
npm install -g @salesforce/b2c-cli
# or use without install: npx @salesforce/b2c-cli ...

# Configure interactively — writes a dw.json
b2c setup instance
```

The idiomatic configuration is a `dw.json` file at the project root (or any parent directory). The same file is picked up by the [B2C DX VS Code extension](https://salesforcecommercecloud.github.io/b2c-developer-tooling/vscode-extension/), so configuring once works for both. CLI flags and `SFCC_*` environment variables are also supported. See the [Configuration guide](https://salesforcecommercecloud.github.io/b2c-developer-tooling/guide/configuration) for the full schema, multi-instance setups, and the precedence rules.

Key commands referenced in this guide:

| Command | Purpose |
|---------|---------|
| `b2c cap validate <path>` | Validate CAP structure (manifest, required files, no pipelines, etc.) |
| `b2c cap package <path>` | Package a directory into a `.zip` |
| `b2c cap install <path> -s <site>` | Install a CAP on a sandbox site (uploads + runs `sfcc-install-commerce-app`) |
| `b2c cap uninstall <id> -s <site>` | Uninstall a CAP from a site |
| `b2c cap list` / `cap tasks` | Inspect installed features and post-install tasks |
| `b2c code deploy` / `code watch` | Deploy or live-sync cartridges via WebDAV |
| `b2c job import <path>` | Import a site archive (impex) via `sfcc-site-archive-import` |
| `b2c job run <id> --wait` | Execute and wait on a job |
| `b2c logs tail` / `logs get` | Stream or fetch instance logs (custom logs, errors, etc.) |
| `b2c sandbox list` / `sandbox start` | Manage On-Demand Sandboxes |

> **Safety:** Set `SFCC_SAFETY_LEVEL=NO_DELETE` (or `READ_ONLY`) in shared/CI environments to block destructive operations. See the [Safety Mode docs](https://salesforcecommercecloud.github.io/b2c-developer-tooling/guide/safety).

### Agent Skills (optional)

If you're using a coding agent (Claude Code, Cursor, GitHub Copilot, Codex), this repository ships the `cap-dev` plugin. Each skill gives the agent the context to perform a specific part of the workflow:

- `scaffold-app` — guidance for generating a new app directory (UI-only / backend-only / fullstack), including the templates and conventions
- `generate-service-impex`, `generate-site-preferences-impex`, `generate-custom-object-impex` — guidance for producing impex XML, covering schema, namespaces, IDs, and install/uninstall pairing
- `validate-impex` — guidance for impex validation, covering syntax, namespaces, install/uninstall pairing, ID conventions, hardcoded credentials, and XSD validation against the bundled SFCC schemas via `b2c docs schema --path`
- `validate-app` — guidance for registry-specific validation: SHA256 against `commerce-apps-manifest/manifest.json`, manifest fields, icon hash, translations, security scan
- `package-app` — guidance for building the ZIP and updating the registry manifest entry
- `submit-app` — guidance for opening the registry PR with the correct template

See the [Agent Skills section in the README](../README.md#agent-skills) for installation.

---

## Testing Workflow

```
1. Develop  →  2. Test Locally  →  3. Test in Sandbox  →  4. Validate  →  5. Submit
```

For an app directory `tax/my-app/commerce-my-app-app-v1.0.0/`, run these commands in order:

```bash
# 1. Develop — edit cartridges, impex, storefront-next/

# 2. Test locally
#    Validate impex XML against the SFCC schemas
xmllint --schema "$(b2c docs schema metadata --path)" \
  impex/install/meta/system-objecttype-extensions.xml --noout
xmllint --schema "$(b2c docs schema services --path)" impex/install/services.xml --noout

#    Run cartridge unit tests if present
( cd cartridges/site_cartridges/int_myapp && npm install && npm test )

#    Validate the CAP structure
b2c cap validate ./commerce-my-app-app-v1.0.0

# 3. Test in sandbox
#    Install the CAP — this imports impex, deploys cartridges, registers the feature
b2c cap install ./commerce-my-app-app-v1.0.0 --site-id RefArch

#    Tail logs (run in a second terminal while exercising the storefront)
b2c logs tail --filter customerror --filter error

#    Iterate on cartridge code without re-installing the CAP
b2c code watch ./commerce-my-app-app-v1.0.0/cartridges

#    Verify post-install tasks and complete them in Business Manager
b2c cap tasks my-app --site-id RefArch

#    Confirm uninstall works cleanly
b2c cap uninstall my-app --site-id RefArch
b2c cap list --site-id RefArch  # confirm gone

# 4. Validate the registry package
b2c cap package ./commerce-my-app-app-v1.0.0 --output tax/my-app/
b2c cap validate tax/my-app/my-app-v1.0.0.zip
shasum -a 256 tax/my-app/my-app-v1.0.0.zip  # update manifest.json sha256 to match

# 5. Submit
#    Open a PR per CONTRIBUTING.md — commit only the ZIP, manifest.json, and (new apps) catalog.json
```

> **Agent-driven shortcuts:** with the `cap-dev` skills installed, `/validate-impex` and `/validate-app` cover steps 2 and 4 (the latter adds registry-specific checks like SHA256 and translation verification), `/package-app` builds the ZIP and updates the manifest entry, and `/submit-app` opens the PR.

### Complete Testing Checklist

- [ ] Cartridges upload successfully (CAP install completes without errors)
- [ ] Impex files import without errors (check `b2c job log sfcc-install-commerce-app --failed`)
- [ ] Services authenticate and respond
- [ ] Hooks execute correctly
- [ ] UI components render properly (Storefront Next apps)
- [ ] Site preferences are configurable in Business Manager
- [ ] Custom objects store/retrieve data
- [ ] No errors in `b2c logs get --since 1h --level ERROR`
- [ ] Performance is acceptable
- [ ] Uninstall path cleans up everything
- [ ] `b2c cap validate` passes on the final ZIP

---

## Validating the App Package

Run validation **before** installing on a sandbox to catch structural issues early.

### CAP structural validation

`b2c cap validate` checks the rules enforced by the install job:

- `commerce-app.json` exists and has `id`, `name`, `version`, `domain`
- `version` is valid semver
- `app-configuration/tasksList.json` exists and is a JSON array with `taskNumber`, `name`, `description`, `link` per task
- At least one of `cartridges/`, `storefront-next/`, or `impex/` is present
- No `pipeline/` directories or `*.ds` pipeline descriptor files
- Site cartridges (`cartridges/site_cartridges/`) contain no `controllers/`
- `README.md` exists

```bash
# From a directory
b2c cap validate ./commerce-my-app-app-v1.0.0

# From a ZIP
b2c cap validate ./my-app-v1.0.0.zip

# Machine-readable
b2c cap validate ./commerce-my-app-app-v1.0.0 --json
```

### Registry-level validation

In addition to `b2c cap validate`, the registry has a few rules that aren't enforced by the install job:

- ZIP at the correct `{domain}/{appName}/` path
- SHA256 in `commerce-apps-manifest/manifest.json` matches the actual hash (`shasum -a 256 <zip>`)
- `manifest.json` has all required fields (`id`, `name`, `iconName`, `domain`, `type=app`, `provider=thirdParty`, `version`, `zip`, `sha256`)
- `storefrontSupport` (if present) has matching values in root `manifest.json` **and** `commerce-app.json`
- No junk files in the ZIP (`.DS_Store`, `__MACOSX/*`, hidden files)
- Single root folder named `commerce-{appName}-app-v{version}/`

The `cap-dev` plugin's `/validate-app` skill bundles all of these checks if you're using a coding agent.

### Impex validation

Beyond `b2c cap validate`, validate the XML directly:

- Well-formed XML for every file under `impex/`
- Correct SFCC namespaces (`http://www.demandware.com/xml/impex/services/2015-07-01`, etc.)
- `mode="delete"` on every entry in `impex/uninstall/`
- Service IDs in install match uninstall, deletion order is service → profile → credential
- Attribute IDs are camelCase and prefixed with the app name
- `SITEID` placeholder used in `preferences.xml` (not a real site ID)
- No hardcoded production credentials

The `b2c` CLI bundles the SFCC XSD schemas — pair `b2c docs schema --path` with `xmllint --schema`. If `b2c` isn't installed globally, swap in `npx @salesforce/b2c-cli` anywhere `b2c` appears:

```bash
# List bundled schemas
b2c docs schema --list

# Validate site preferences and custom object metadata against the metadata schema
xmllint --schema "$(b2c docs schema metadata --path)" \
  impex/install/meta/system-objecttype-extensions.xml --noout

xmllint --schema "$(b2c docs schema metadata --path)" \
  impex/install/meta/custom-objecttype-definitions.xml --noout

# Validate services
xmllint --schema "$(b2c docs schema services --path)" impex/install/services.xml --noout

# Validate preferences (after substituting SITEID)
xmllint --schema "$(b2c docs schema preferences --path)" impex/install/preferences.xml --noout
```

For a quick well-formedness check without schema validation:

```bash
find impex/ -name "*.xml" -exec xmllint --noout {} \;
```

---

## Installing on a Sandbox

### Install the CAP

The supported way to install a CAP is via the `sfcc-install-commerce-app` system job, which `b2c cap install` triggers:

```bash
# Install from a ZIP or directory (directories are zipped automatically)
b2c cap install tax/my-app/commerce-my-app-app-v1.0.0.zip --site-id RefArch

# Skip pre-install validation (already validated separately)
b2c cap install ./commerce-my-app-app-v1.0.0 -s RefArch --skip-validate

# Remove the uploaded archive after install completes
b2c cap install ./commerce-my-app-app-v1.0.0 -s RefArch --clean-archive
```

Behind the scenes the CLI uploads the ZIP to `Impex/commerce-apps/`, runs the install job, and waits for it to finish.

### Verify installation

```bash
# Confirm the feature is registered for the site
b2c cap list --site-id RefArch

# View the post-install tasks (clickable Business Manager links)
b2c cap tasks my-app --site-id RefArch
```

`cap list` shows install status, config status, version, source (`CUSTOM` for WebDAV upload, `REGISTRY` for App Registry), and timestamp.

### Uninstall

Always test the uninstall path in a sandbox before submitting:

```bash
b2c cap uninstall my-app --site-id RefArch
```

The CLI looks up the app's domain from the feature state and runs the appropriate cleanup.

### Pulling installed apps back

If you need to grab a CAP that's already installed (for inspection or to deploy cartridges to a code version), use:

```bash
# Pull every registry-installed app
b2c cap pull

# Pull a single app
b2c cap pull my-app --site-id RefArch --output ./pulled-apps
```

---

## Testing Cartridges

For most apps the CAP install handles cartridge upload and adds them to the cartridge path. When iterating on cartridge code without rerunning the install, deploy directly to a code version.

### Deploy cartridges directly

```bash
# Deploy every cartridge under the current directory (cartridges discovered via .project files)
b2c code deploy

# Deploy to a specific code version
b2c code deploy ./commerce-my-app-app-v1.0.0/cartridges --code-version version1

# Deploy and reload (toggle activation to force reload of new code)
b2c code deploy --reload

# Deploy a subset
b2c code deploy -c int_myapp -c plugin_myapp_storefront
```

### Live-reload during development

```bash
b2c code watch ./commerce-my-app-app-v1.0.0/cartridges
```

Press `Ctrl+C` to stop. File adds/changes are batched and uploaded; deletions are removed from the server.

The [B2C DX VS Code extension](https://salesforcecommercecloud.github.io/b2c-developer-tooling/vscode-extension/) provides the same behavior integrated into the editor — open the cartridge folder, connect to your sandbox, and changes upload on save.

### Verify cartridge path

After install, confirm the cartridge is on the site path: Business Manager → Administration → Sites → Manage Sites → *your site* → Settings. The CAP install job appends to the path automatically.

### Test hooks

Verify the hook is registered and firing:

```javascript
// In code, query the hook manager
require('dw/system/HookMgr').hasHook('dw.order.calculateTax');
```

Trigger the hook (e.g., add to cart for tax calc) and watch logs:

```bash
b2c logs tail --filter customerror --filter customwarn --filter custominfo --search myapp
```

For interactive debugging — stepping through hook execution, inspecting `basket`/`order` state, watching variables — use the **B2C Script Debugger** in the [VS Code extension](https://salesforcecommercecloud.github.io/b2c-developer-tooling/vscode-extension/). It supports breakpoints, log points, and step-through for cartridge controllers, jobs, hooks, and Custom SCAPI API scripts.

### Run unit tests

If your cartridge ships with mocha tests (see `tax/avalara-tax/` for the pattern):

```bash
cd commerce-my-app-app-v1.0.0/cartridges/site_cartridges/int_myapp
npm install
npm test
```

---

## Testing Impex Files

**The CAP install job imports impex automatically.** During development, the recommended workflow is to package and install the CAP — this exercises exactly the same `sfcc-install-commerce-app` job a merchant runs, including the impex import, cartridge upload, and post-install task setup.

### Recommended development loop

```bash
# 1. Validate impex XML well-formedness
find impex/ -name "*.xml" -exec xmllint --noout {} \;

# 2. Validate against the SFCC XSDs (catches most schema errors)
xmllint --schema "$(b2c docs schema metadata --path)" \
  impex/install/meta/system-objecttype-extensions.xml --noout
xmllint --schema "$(b2c docs schema services --path)" impex/install/services.xml --noout

# 3. Validate the CAP itself
b2c cap validate ./commerce-my-app-app-v1.0.0

# 4. Install — this imports impex, deploys cartridges, and registers the feature
b2c cap install ./commerce-my-app-app-v1.0.0 --site-id RefArch

# 5. Tail logs while the install runs
b2c logs tail --filter customerror --filter error
```

### Verify imported metadata

| What | Where to look |
|------|----------------|
| Services | Administration → Operations → Services |
| Site preferences | Merchant Tools → Site Preferences → Custom Preferences |
| Custom object types | Administration → Site Development → System Object Types → Custom Object Types |
| Cartridge path | Administration → Sites → Manage Sites → *site* → Settings |
| Install job log on failure | `b2c job log sfcc-install-commerce-app --failed` |

### Test the uninstall path

`b2c cap uninstall` runs the uninstall impex from `impex/uninstall/`. Always test it on a sandbox before submitting:

```bash
b2c cap uninstall my-app --site-id RefArch
b2c cap list --site-id RefArch  # confirm gone
```

Then re-install to confirm the install/uninstall cycle is repeatable.

> **Note:** Never test uninstall in production.

### Iterating on impex without re-installing the CAP

When you only need to push a metadata change and want to skip the full CAP install loop, use `b2c job import` to run `sfcc-site-archive-import` directly:

```bash
# Import a directory (zipped automatically) or an existing zip
b2c job import ./impex/install
b2c job import ./my-archive.zip

# Keep the archive on the instance after import
b2c job import ./impex/install --keep-archive

# Import an archive already on the instance
b2c job import existing-archive.zip --remote
```

The CLI uploads to `Impex/src/instance/` and waits for the job. Errors are in `b2c job log sfcc-site-archive-import --failed`.

> **Caveat:** This bypasses the CAP install pipeline (no cartridge path updates, no feature state registration, no post-install tasks). Use it for metadata-only iteration, then run a full `b2c cap install` before considering the change tested.

### Importing manually from Business Manager

Available as a fallback if the CLI isn't an option:

1. Zip the `impex/install/` directory
2. Administration → Site Development → Site Import & Export → upload the archive
3. Select the archive and click **Import**
4. Watch the import status; review the job log when it finishes (Administration → Operations → Jobs → `sfcc-site-archive-import`)
5. To test uninstall, repeat with `impex/uninstall/`

This path doesn't run the CAP install logic either — same caveat as `b2c job import`.

### Custom object smoke test

After install, verify a custom object type accepts data:

```javascript
var CustomObjectMgr = require('dw/object/CustomObjectMgr');
var Transaction = require('dw/system/Transaction');

Transaction.wrap(function () {
    var obj = CustomObjectMgr.createCustomObject('MyAppCache', 'test-key');
    obj.custom.payload = 'test value';
});

var retrieved = CustomObjectMgr.getCustomObject('MyAppCache', 'test-key');
require('dw/system/Logger').debug('Retrieved: {0}', retrieved.custom.payload);
```

---

## Testing UI Components

If your app includes Storefront Next extensions under `storefront-next/`:

### Local development

```bash
cd storefront-next
npm install
npm run dev
```

Component-level tests (Vitest) and Storybook stories run locally without a sandbox:

```bash
npm run test
npm run test:coverage
npm run storybook
```

### Integration testing

Build the extensions, then deploy to your Storefront Next environment per the [Storefront Next documentation](https://dpkoal18ck1fm.cloudfront.net/docs/commerce/b2c-commerce/guide/index.html).

Verify in the storefront:

- Components render at the configured `target-config.json` targets
- Data loads (check the network tab for SCAPI calls)
- Styling, interactions, and responsive layouts work
- No console errors

### Browser coverage

Test on the latest Chrome/Edge, Firefox, Safari, and at least one mobile browser (iOS Safari or Chrome Mobile).

---

## Testing Services

### Configure credentials

After install, set sandbox/test credentials for each service:

1. Administration → Operations → Services → *your service* → Credentials
2. Set the test endpoint URL and API key/secret
3. Save

### Test a service call

**From Business Manager:** Operations → Services → *your service* → click the service definition → use the test request tool.

**From a script:**

```javascript
var MyService = require('*/cartridge/scripts/services/myService');

var result = MyService.call({
    param1: 'test',
    param2: 'value'
});

if (result.status === 'OK') {
    require('dw/system/Logger').info('Success: {0}', JSON.stringify(result.object));
} else {
    require('dw/system/Logger').error('Failed: {0} {1}', result.error, result.errorMessage);
}
```

### Monitor service calls

Administration → Operations → Services → Service Status / Service Monitoring shows call counts, error rates, and average response times.

### Verify error handling

Test each failure mode:

- Invalid credentials → service returns auth error, app falls back gracefully
- Malformed request → validation error logged, no exception bubbles to checkout
- Timeout → app respects timeout configured on the service profile
- Circuit open → after the configured failure threshold, calls short-circuit instead of blocking

```javascript
try {
    var result = MyService.call(params);
    if (result.status !== 'OK') {
        Logger.error('Service error: {0}', result.errorMessage);
        return defaultBehavior();
    }
    return result.object;
} catch (e) {
    Logger.error('Exception: {0}', e.message);
    return defaultBehavior();
}
```

---

## Inspecting Logs

Use `b2c logs` instead of downloading log files via WebDAV manually.

### Tail logs in real time

```bash
# Default: error + customerror
b2c logs tail

# Custom logs only, filtered to your app
b2c logs tail --filter custominfo --filter customwarn --filter customerror --search myapp

# Only ERROR and FATAL entries
b2c logs tail --level ERROR --level FATAL

# NDJSON output (for piping to a parser)
b2c logs tail --json
```

Press `Ctrl+C` to stop. The command tracks log rotation automatically.

### One-shot retrieval

```bash
# Last 50 entries from error+customerror
b2c logs get --count 50

# Last hour of ERROR-level entries containing "PaymentProcessor"
b2c logs get --since 1h --level ERROR --search PaymentProcessor

# JSON for tooling
b2c logs get --since 5m --json
```

Paths in log entries are auto-normalized to local cartridge paths so IDEs can click-to-open. Use `--no-normalize` to disable.

### Job logs

```bash
# Most recent execution log
b2c job log my-job

# Most recent failed execution
b2c job log my-job --failed

# Specific execution
b2c job log my-job abc123-def456
```

### Custom log levels

Custom log files are produced by `Logger.debug/info/warn/error/fatal`. By default `customwarn`, `customerror`, and `customfatal` are always enabled; `custominfo` and `customdebug` must be enabled in Administration → Operations → Custom Log Settings.

---

## End-to-End Testing

### Fresh-install scenario

1. Start from a clean sandbox site (uninstall any prior version: `b2c cap uninstall my-app -s RefArch`)
2. `b2c cap install my-app-v1.0.0.zip --site-id RefArch`
3. Run through the post-install tasks: `b2c cap tasks my-app --site-id RefArch`
4. Smoke test the storefront flow your app extends (checkout, search, account, etc.)

### Checkout-flow apps (tax, payment, shipping)

Walk a complete order through the storefront and verify in Business Manager that:

- Hooks executed (custom logs show entry/exit)
- Service calls succeeded (Service Monitoring)
- Order totals are correct (tax, shipping, payment status)
- No errors in `error` / `customerror` logs (`b2c logs get --since 10m --level ERROR`)

### Edge cases to cover

- Empty cart / single item / many items
- High-value order
- International shipping (if applicable)
- Invalid address or invalid card
- Service timeout (temporarily set a tiny timeout on the service profile)
- Network failure (block the service URL via the platform firewall, or use an unreachable endpoint)

### Uninstall scenario

After end-to-end install testing:

```bash
b2c cap uninstall my-app --site-id RefArch
b2c cap list --site-id RefArch  # confirm gone
```

Verify services, preferences, custom objects, and cartridge path entries are all removed.

---

## Performance Testing

### Hook execution time

```javascript
var startTime = Date.now();
// ... hook logic ...
require('dw/system/Logger').info('Hook execution time: {0}ms', Date.now() - startTime);
```

Suggested targets:

| Hook | Target |
|------|--------|
| Tax calculation | < 1000 ms |
| Shipping rates | < 1500 ms |
| Payment authorization | < 2000 ms |
| Non-critical hooks | < 500 ms |

### Service performance

Administration → Operations → Services → Service Monitoring shows averages and per-call timing. Optimize by:

- Caching responses in a custom object
- Reducing payload size
- Tightening timeouts so failures fail fast
- Confirming the circuit breaker thresholds on the service profile

### Cache validation

```javascript
var cached = getCachedData(key);
if (cached) { return cached; }
var data = fetchFromService();
cacheData(key, data, ttlSeconds);
return data;
```

Verify TTL by waiting past the configured window and confirming a fresh service call. Verify cache invalidation paths if your app exposes one.

---

## Pre-Submission Checklist

Before opening the PR:

**Validation:**
- [ ] All impex XML is well-formed and validates against the SFCC XSDs (`xmllint --schema "$(b2c docs schema <name> --path)" ...`)
- [ ] `b2c cap validate <zip>` passes
- [ ] SHA256 in `manifest.json` matches the ZIP (`shasum -a 256 <zip>`)

**Files committed:**
- [ ] `{domain}/{appName}/{appName}-v{version}.zip`
- [ ] `{domain}/{appName}/manifest.json` (with matching SHA256)
- [ ] `{domain}/{appName}/catalog.json` (new apps only)
- [ ] **No** extracted directories (`commerce-{appName}-app-v{version}/`)

**ZIP contents:**
- [ ] Single root folder `commerce-{appName}-app-v{version}/`
- [ ] No junk files (`.DS_Store`, `__MACOSX`, hidden files)
- [ ] `commerce-app.json`, `README.md`, `app-configuration/tasksList.json` present
- [ ] No `pipeline/` directories or `*.ds` files
- [ ] No `controllers/` under `cartridges/site_cartridges/*`

**Sandbox testing:**
- [ ] CAP installs cleanly via `b2c cap install`
- [ ] Post-install tasks (`b2c cap tasks`) make sense and have working BM links
- [ ] App functions correctly in storefront
- [ ] No errors in `b2c logs get --since 1h --level ERROR`
- [ ] `b2c cap uninstall` removes everything

**Security:**
- [ ] No hardcoded production credentials anywhere
- [ ] Sensitive site preferences use `<password>` type
- [ ] Error messages don't leak internal details
- [ ] Input validation at trust boundaries

**Documentation:**
- [ ] `README.md` covers installation, configuration, and troubleshooting
- [ ] `app-configuration/tasksList.json` lists every required post-install task with a working BM link

---

## Common Testing Issues

### `cap install` fails with structural errors
Run `b2c cap validate` to see the specific rule violation. Most commonly: missing `commerce-app.json` field, invalid semver, missing `tasksList.json`, or pipeline files left in cartridges.

### Impex import errors
- Validate against the SFCC XSDs: `xmllint --schema "$(b2c docs schema metadata --path)" <file> --noout`
- Check for unescaped `&` or `<` in XML (`&amp;` / `&lt;`)
- Confirm namespaces match the SFCC schema (e.g., `services/2015-07-01`)
- `SITEID` placeholder in `preferences.xml` should be substituted at install time — never commit a real site ID
- Get the failing job's log: `b2c job log sfcc-install-commerce-app --failed`

### Service call fails
- Verify credentials are sandbox/test values, not production
- Confirm the endpoint is reachable from SFCC (check Service Monitoring for the actual error)
- Run `b2c logs get --search myService.api --since 10m`
- Check the circuit-breaker state in Service Monitoring — a tripped circuit keeps the service offline until reset

### Hook not firing
- Confirm the cartridge is on the site path (Manage Sites → Settings)
- Verify `package.json` `"hooks"` (or `hooks.json`) is correct and the script paths resolve
- `require('dw/system/HookMgr').hasHook('your.hook.name')` returns `true`?
- Add `Logger.info` at the top of the hook and tail logs

### UI component not rendering
- Check browser console for errors
- Confirm the component is registered in `target-config.json` and the target ID matches a real Storefront Next target
- Confirm the extension is deployed to the storefront environment
- Test the component in isolation (Storybook) to rule out target/data issues

### SHA256 mismatch on PR
The hash in `manifest.json` doesn't match the ZIP. Recompute with `shasum -a 256 <zip>` and update `manifest.json`.

---

## Best Practices

- **Test as you build.** Validate impex against the SFCC XSDs on every change. Tail logs in a side terminal during development.
- **Use a dedicated sandbox.** Don't share with someone else's in-progress work, and never test on production.
- **Test the uninstall path.** A clean uninstall is a release requirement, not an afterthought.
- **Automate validation.** Wire `b2c cap validate` and `xmllint --schema` checks into CI for app repos that live outside this registry.
- **Keep credentials out of the repo.** Configure `dw.json` outside the project (or `.gitignore` it) — never commit credentials.

---

## Getting Help

1. **Logs first:** `b2c logs tail`, `b2c logs get --since 10m --level ERROR`, `b2c job log <id> --failed`
2. **Documentation:**
   - [B2C Developer Tooling docs](https://salesforcecommercecloud.github.io/b2c-developer-tooling/)
   - [SFCC Documentation](https://developer.salesforce.com/docs/commerce/b2c-commerce)
   - [CONTRIBUTING.md](../CONTRIBUTING.md)
   - [AGENTS.md](../AGENTS.md) — guidance for AI assistants in this repo
3. **Reference app:** `tax/avalara-tax/` — a working CAP with cartridges, hooks, impex, and unit tests
4. **Agent skills:** see the [Agent Skills section in the README](../README.md#agent-skills) if you'd like an agent to drive validation/packaging/submission
