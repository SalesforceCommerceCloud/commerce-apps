# Security Scan Reference

Comprehensive security validation for commerce apps before PR submission.

## Automated security scan

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

## Reporting findings

**Blocking findings:**
- Mark validation as **FAIL**
- Provide specific file paths and line numbers
- Explain the security risk
- Recommend specific fixes

**Warning findings:**
- Include in validation report with clear explanations
- Mark as warnings (non-blocking)
- Explain potential risks and recommended improvements
