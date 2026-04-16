# Security Scan Reference

Run before packaging any app to catch security issues early.

## Running the scan

```bash
bash .github/scripts/security-scan.sh <domain>/<appName>/commerce-<appName>-app-v<version>/
```

## Blocking findings (exit code 1)

**Must fix before packaging:**
- Dynamic code evaluation constructs — code injection sinks
- Hardcoded secrets or credentials (API keys, AWS keys, GitHub PATs, Slack tokens, private keys)
- Hook scripts referenced in hooks.json that don't exist on disk
- Missing uninstall/services.xml or missing mode="delete" attributes
- Unsafe HTML manipulation — XSS risk

## Warning findings (review recommended)

**Should fix but non-blocking:**
- Console logging in cartridge code — use dw.system.Logger instead
- HTTPClient without explicit timeout configuration
- Service profile XML missing timeout-millis element
- Hook scripts without try/catch error handling
- Non-cryptographic random number generation
- Inline Authorization headers instead of service framework

## Response to findings

If **blocking** findings are found:
- **Stop packaging** — do not generate ZIP
- Report specific file paths and line numbers
- Help developer fix each issue
- Re-run scan after fixes

If only **warnings** are found:
- Continue with packaging
- Report warnings for developer review
- Suggest fixes but don't block
