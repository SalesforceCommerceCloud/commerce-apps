# Security Scan Reference

Comprehensive security validation for commerce apps before PR submission.

## Two-phase security validation

### Phase 1: Automated scan script

```bash
bash .github/scripts/security-scan.sh commerce-<appName>-app-v<version>/
```

**Blocking issues (must fix):**
- Dynamic code evaluation constructs — code injection sinks
- Dynamic module loading with concatenation
- Unsafe HTML manipulation — XSS risk
- Hardcoded secrets (API keys, AWS keys, GitHub PATs, Slack tokens, private keys)
- Hardcoded credentials in impex XML
- Hook scripts referenced in hooks.json that don't exist
- Missing uninstall/services.xml or missing mode="delete"

**Warnings (should review):**
- Non-cryptographic random number generation
- Inline Authorization headers instead of service framework
- Console logging in cartridge code — use dw.system.Logger
- HTTPClient without explicit timeout
- Service profile XML missing timeout-millis
- Hook scripts without try/catch error handling
- Hook exports not matching expected function names
- Hardcoded site-id instead of SITEID placeholder
- Absolute file paths in code
- Install/uninstall service ID mismatches

### Phase 2: AI-powered semantic review

After the script runs, perform semantic analysis:

**Data exfiltration patterns:**
- Review hook scripts and service calls for unauthorized data collection
- Does the app send basket, customer, or order data to endpoints unrelated to its declared domain?
- Example violation: Tax app sending customer emails to external analytics service

**Permission scope creep:**
- Does the app access Script API objects or customer data beyond its stated purpose?
- Example violation: Shipping app reading dw.customer.Profile payment instruments

**Business logic vulnerabilities:**
- Could hook implementations be manipulated? (negative tax values, price overrides)
- Race conditions in shared state access?
- Improper input validation that could affect calculations?

**Service call patterns:**
- Are external API calls batched efficiently, or one call per line item?
- Are service responses validated before use?
- Is retry logic present that could cause duplicate side effects (double-charging)?

**Impex safety:**
- Do install impex files create overly broad permissions?
- Do custom object definitions expose sensitive data without access controls?
- Are retention policies appropriate for data sensitivity?

## Reporting findings

**Blocking findings:**
- Mark validation as **FAIL**
- Provide specific file paths and line numbers
- Explain the security risk
- Recommend specific fixes

**Warnings from semantic review:**
- Include in validation report with clear explanations
- Mark as warnings (non-blocking)
- Explain potential risks and recommended improvements
