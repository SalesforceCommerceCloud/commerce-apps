---
name: generate-service-impex
description: >-
  Generate SFCC service configuration impex files (credentials, profiles, and definitions).
  Supports multiple authentication patterns, rate limiting, circuit breakers, and uninstall
  scripts. Use when creating or updating service integrations for commerce apps.
---

# Generate Service Impex

Generate complete service configuration impex files for SFCC commerce apps.

## Step 1: Collect service information

Gather the following information:

| Input | Example | Notes |
|-------|---------|-------|
| Service ID | `avalara.tax.api` | Dotted notation, unique identifier |
| Service Name | `Avalara Tax API` | Human-readable name |
| Credential ID | `avalara.tax.credential` | Usually `{vendor}.{service}.credential` |
| Profile ID | `avalara.tax.profile` | Usually `{vendor}.{service}.profile` |
| Base URL | `https://rest.avatax.com/api/v2` | API endpoint base URL |
| Authentication Type | `bearer`, `basic`, `apikey`, `oauth2` | Auth method |
| Timeout (ms) | `30000` | Default: 30000 (30 seconds) |
| Rate limiting | Yes/No | Enable rate limiting? |
| Circuit breaker | Yes/No | Enable circuit breaker? |

## Step 2: Choose authentication pattern

### Pattern 1: Bearer Token / API Key (Most Common)

**Use for:**
- Modern REST APIs with API keys
- Token-based authentication
- SaaS platforms (e.g., Avalara)

**Credential structure:**
```xml
<service-credential credential-id="{credentialId}">
    <url>{baseUrl}</url>
    <user-id>{apiKeyPlaceholder}</user-id>
    <password>{apiSecretPlaceholder}</password>
</service-credential>
```

### Pattern 2: Basic Authentication

**Use for:**
- Legacy APIs
- Simple username/password APIs

**Credential structure:**
```xml
<service-credential credential-id="{credentialId}">
    <url>{baseUrl}</url>
    <user-id>{username}</user-id>
    <password>{password}</password>
</service-credential>
```

### Pattern 3: OAuth 2.0

**Use for:**
- OAuth-based APIs
- Three-legged authentication

**Credential structure:**
```xml
<service-credential credential-id="{credentialId}">
    <url>{baseUrl}</url>
    <user-id>{clientId}</user-id>
    <password>{clientSecret}</password>
    <!-- Add OAuth-specific parameters in service definition -->
</service-credential>
```

### Pattern 4: Custom Headers / Query Params

**Use for:**
- APIs requiring custom authentication headers
- API keys in query strings

**Note:** Credential stores the key, custom headers added in service wrapper code.

## Step 3: Generate install/services.xml

Create the service installation file:

**File:** `impex/install/services.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<services xmlns="http://www.demandware.com/xml/impex/services/2015-07-01">

    <!-- Service Credential -->
    <service-credential credential-id="{credentialId}">
        <url>{baseUrl}</url>
        <user-id>{placeholder_api_key}</user-id>
        <password>{placeholder_api_secret}</password>
        <!-- Optional: Add custom authentication parameters -->
        <!--
        <custom>
            <authentication-type>bearer</authentication-type>
            <token-endpoint>https://auth.example.com/token</token-endpoint>
        </custom>
        -->
    </service-credential>

    <!-- Service Profile (Performance & Reliability Settings) -->
    <service-profile profile-id="{profileId}">
        <!-- Timeout in milliseconds (default: 30000) -->
        <timeout-millis>{timeout}</timeout-millis>

        <!-- Rate Limiting (optional but recommended) -->
        <rate-limit-enabled>{rateLimitEnabled}</rate-limit-enabled>
        <!-- Max calls per time window -->
        <rate-limit-calls>100</rate-limit-calls>
        <!-- Time window in milliseconds (1000ms = 1 second) -->
        <rate-limit-millis>1000</rate-limit-millis>

        <!-- Circuit Breaker (recommended for external APIs) -->
        <circuit-breaker-enabled>{circuitBreakerEnabled}</circuit-breaker-enabled>
        <!-- Max failures before opening circuit -->
        <circuit-breaker-max-calls>5</circuit-breaker-max-calls>

        <!-- Optional: Caching Configuration -->
        <!--
        <cacheable>false</cacheable>
        <cache-time>3600000</cache-time>
        -->
    </service-profile>

    <!-- Service Definition -->
    <service service-id="{serviceId}">
        <service-type>HTTP</service-type>
        <enabled>true</enabled>

        <!-- Log Prefix (appears in logs for debugging) -->
        <log-prefix>{serviceName}</log-prefix>

        <!-- Communication Settings -->
        <communication-log>true</communication-log>
        <mock-mode-enabled>false</mock-mode-enabled>

        <!-- Link to Credential and Profile -->
        <credential credential-id="{credentialId}"/>
        <profile profile-id="{profileId}"/>
    </service>

</services>
```

## Step 4: Generate uninstall/services.xml

Create the service cleanup file:

**File:** `impex/uninstall/services.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<services xmlns="http://www.demandware.com/xml/impex/services/2015-07-01">
    <!-- Delete in reverse order: service, profile, credential -->
    <service service-id="{serviceId}" mode="delete"/>
    <service-profile profile-id="{profileId}" mode="delete"/>
    <service-credential credential-id="{credentialId}" mode="delete"/>
</services>
```

**CRITICAL:** Always use `mode="delete"` and reverse order (service → profile → credential).

## Step 5: Advanced configurations

### Configuration 1: Multiple Environments

Support different URLs for sandbox vs production:

```xml
<!-- Production Credential -->
<service-credential credential-id="{credentialId}.prod">
    <url>https://api.example.com</url>
    <user-id>prod_api_key</user-id>
    <password>prod_api_secret</password>
</service-credential>

<!-- Sandbox Credential -->
<service-credential credential-id="{credentialId}.sandbox">
    <url>https://sandbox.api.example.com</url>
    <user-id>sandbox_api_key</user-id>
    <password>sandbox_api_secret</password>
</service-credential>

<!-- Service can switch between them via site preference -->
<service service-id="{serviceId}">
    <service-type>HTTP</service-type>
    <enabled>true</enabled>
    <log-prefix>{serviceName}</log-prefix>
    <!-- Default to sandbox, switch via code based on preference -->
    <credential credential-id="{credentialId}.sandbox"/>
    <profile profile-id="{profileId}"/>
</service>
```

### Configuration 2: Multiple Services (Same Provider)

When your app uses multiple API endpoints:

```xml
<!-- Shared Profile -->
<service-profile profile-id="{vendor}.profile">
    <timeout-millis>30000</timeout-millis>
    <rate-limit-enabled>true</rate-limit-enabled>
    <rate-limit-calls>100</rate-limit-calls>
    <rate-limit-millis>1000</rate-limit-millis>
</service-profile>

<!-- Ratings API Service -->
<service-credential credential-id="{vendor}.ratings.credential">
    <url>https://api.example.com/ratings</url>
    <user-id>api_key</user-id>
    <password>api_secret</password>
</service-credential>

<service service-id="{vendor}.ratings.api">
    <service-type>HTTP</service-type>
    <enabled>true</enabled>
    <log-prefix>{vendor} Ratings</log-prefix>
    <credential credential-id="{vendor}.ratings.credential"/>
    <profile profile-id="{vendor}.profile"/>
</service>

<!-- Reviews API Service -->
<service-credential credential-id="{vendor}.reviews.credential">
    <url>https://api.example.com/reviews</url>
    <user-id>api_key</user-id>
    <password>api_secret</password>
</service-credential>

<service service-id="{vendor}.reviews.api">
    <service-type>HTTP</service-type>
    <enabled>true</enabled>
    <log-prefix>{vendor} Reviews</log-prefix>
    <credential credential-id="{vendor}.reviews.credential"/>
    <profile profile-id="{vendor}.profile"/>
</service>
```

### Configuration 3: FTP/SFTP Services

For file-based integrations:

```xml
<service-credential credential-id="{credentialId}">
    <url>sftp://ftp.example.com</url>
    <user-id>ftp_username</user-id>
    <password>ftp_password</password>
</service-credential>

<service service-id="{serviceId}">
    <service-type>FTP</service-type>
    <enabled>true</enabled>
    <log-prefix>{serviceName} FTP</log-prefix>
    <credential credential-id="{credentialId}"/>
</service>
```

## Step 6: Service configuration best practices

### Rate Limiting Guidelines

| API Type | Calls | Window | Notes |
|----------|-------|--------|-------|
| Tax calculation | 100 | 1 second | High volume during checkout |
| Payment authorization | 50 | 1 second | Moderate volume |
| Product data sync | 10 | 1 second | Background jobs |
| Shipping rates | 100 | 1 second | High volume during checkout |
| Review submission | 10 | 1 second | Lower volume |

### Timeout Guidelines

| API Type | Timeout (ms) | Notes |
|----------|--------------|-------|
| Real-time checkout | 5000-10000 | Fast response required |
| Background jobs | 30000-60000 | Can wait longer |
| File uploads | 60000+ | Large files need time |
| Webhooks | 10000 | Quick acknowledgment |

### Circuit Breaker Settings

```xml
<circuit-breaker-enabled>true</circuit-breaker-enabled>
<circuit-breaker-max-calls>5</circuit-breaker-max-calls>
```

**Recommended values:**
- **Critical services (payment, tax):** `max-calls="3"` (fail fast)
- **Non-critical services (reviews, analytics):** `max-calls="5-10"` (more tolerance)
- **Background jobs:** Circuit breaker optional

## Step 7: Common service patterns by app type

### Tax App Services

```xml
<service-credential credential-id="tax.calculation.credential">
    <url>https://api.taxprovider.com</url>
    <user-id>COMPANY_CODE</user-id>
    <password>API_KEY</password>
</service-credential>

<service-profile profile-id="tax.profile">
    <timeout-millis>5000</timeout-millis>
    <rate-limit-enabled>true</rate-limit-enabled>
    <rate-limit-calls>100</rate-limit-calls>
    <rate-limit-millis>1000</rate-limit-millis>
    <circuit-breaker-enabled>true</circuit-breaker-enabled>
    <circuit-breaker-max-calls>3</circuit-breaker-max-calls>
</service-profile>

<service service-id="tax.calculation.api">
    <service-type>HTTP</service-type>
    <enabled>true</enabled>
    <log-prefix>Tax Calculation</log-prefix>
    <communication-log>true</communication-log>
    <credential credential-id="tax.calculation.credential"/>
    <profile profile-id="tax.profile"/>
</service>
```

### Payment App Services

```xml
<service-credential credential-id="payment.gateway.credential">
    <url>https://api.paymentgateway.com</url>
    <user-id>MERCHANT_ID</user-id>
    <password>API_SECRET</password>
</service-credential>

<service-profile profile-id="payment.profile">
    <timeout-millis>10000</timeout-millis>
    <rate-limit-enabled>true</rate-limit-enabled>
    <rate-limit-calls>50</rate-limit-calls>
    <rate-limit-millis>1000</rate-limit-millis>
    <circuit-breaker-enabled>true</circuit-breaker-enabled>
    <circuit-breaker-max-calls>3</circuit-breaker-max-calls>
</service-profile>

<service service-id="payment.authorization.api">
    <service-type>HTTP</service-type>
    <enabled>true</enabled>
    <log-prefix>Payment Authorization</log-prefix>
    <communication-log>true</communication-log>
    <credential credential-id="payment.gateway.credential"/>
    <profile profile-id="payment.profile"/>
</service>
```

### Shipping App Services

```xml
<service-credential credential-id="shipping.carrier.credential">
    <url>https://api.carrier.com</url>
    <user-id>ACCOUNT_NUMBER</user-id>
    <password>API_KEY</password>
</service-credential>

<service-profile profile-id="shipping.profile">
    <timeout-millis>5000</timeout-millis>
    <rate-limit-enabled>true</rate-limit-enabled>
    <rate-limit-calls>100</rate-limit-calls>
    <rate-limit-millis>1000</rate-limit-millis>
    <circuit-breaker-enabled>true</circuit-breaker-enabled>
    <circuit-breaker-max-calls>5</circuit-breaker-max-calls>
</service-profile>

<service service-id="shipping.rates.api">
    <service-type>HTTP</service-type>
    <enabled>true</enabled>
    <log-prefix>Shipping Rates</log-prefix>
    <communication-log>true</communication-log>
    <credential credential-id="shipping.carrier.credential"/>
    <profile profile-id="shipping.profile"/>
</service>
```

### Reviews/Ratings App Services

```xml
<service-credential credential-id="reviews.platform.credential">
    <url>https://api.reviews.com</url>
    <user-id>CLIENT_ID</user-id>
    <password>API_KEY</password>
</service-credential>

<service-profile profile-id="reviews.profile">
    <timeout-millis>10000</timeout-millis>
    <rate-limit-enabled>true</rate-limit-enabled>
    <rate-limit-calls>50</rate-limit-calls>
    <rate-limit-millis>1000</rate-limit-millis>
    <circuit-breaker-enabled>false</circuit-breaker-enabled>
</service-profile>

<service service-id="reviews.api">
    <service-type>HTTP</service-type>
    <enabled>true</enabled>
    <log-prefix>Reviews Platform</log-prefix>
    <communication-log>true</communication-log>
    <credential credential-id="reviews.platform.credential"/>
    <profile profile-id="reviews.profile"/>
</service>
```

## Step 8: Validation checklist

- [ ] Service ID uses dotted notation and is unique
- [ ] Credential ID matches naming convention
- [ ] Profile ID matches naming convention
- [ ] Base URL is placeholder or generic (no hardcoded production keys)
- [ ] Timeout appropriate for service type
- [ ] Rate limiting configured based on API limits
- [ ] Circuit breaker enabled for external APIs
- [ ] Uninstall file includes all services in reverse order
- [ ] All services use `mode="delete"` in uninstall
- [ ] XML is well-formed and valid
- [ ] Log prefix is descriptive for debugging
- [ ] Communication log enabled for troubleshooting

## Step 9: Testing and verification

After generating the impex files:

1. **Validate XML syntax:**
   ```bash
   xmllint --noout impex/install/services.xml
   xmllint --noout impex/uninstall/services.xml
   ```

2. **Test installation:**
   - Import via Business Manager
   - Verify services appear in Administration > Operations > Services
   - Check credentials are created
   - Verify profile settings

3. **Test service calls:**
   - Use service wrapper to make test calls
   - Check logs for proper logging
   - Verify rate limiting works
   - Test circuit breaker behavior

4. **Test uninstallation:**
   - Import uninstall services.xml
   - Verify all services, profiles, and credentials are removed

## Common mistakes to avoid

| Mistake | Impact | Fix |
|---------|--------|-----|
| Hardcoded production credentials | Security risk | Use placeholders |
| Missing uninstall script | Services not cleaned up | Create matching uninstall |
| Wrong deletion order | Import errors | Delete: service → profile → credential |
| No rate limiting | API throttling errors | Add rate limit config |
| Timeout too short | Frequent timeouts | Increase based on API response time |
| No circuit breaker | Cascading failures | Enable for external APIs |
| Generic service IDs | ID conflicts | Use vendor-specific dotted notation |
| Missing log prefix | Hard to debug | Add descriptive log prefix |

## Quick reference templates

### Minimal Service (No Rate Limiting)

```xml
<services xmlns="http://www.demandware.com/xml/impex/services/2015-07-01">
    <service-credential credential-id="myapp.api.credential">
        <url>https://api.example.com</url>
        <user-id>API_KEY</user-id>
        <password>API_SECRET</password>
    </service-credential>

    <service service-id="myapp.api">
        <service-type>HTTP</service-type>
        <enabled>true</enabled>
        <log-prefix>MyApp API</log-prefix>
        <credential credential-id="myapp.api.credential"/>
    </service>
</services>
```

### Production-Ready Service (Full Configuration)

```xml
<services xmlns="http://www.demandware.com/xml/impex/services/2015-07-01">
    <service-credential credential-id="myapp.api.credential">
        <url>https://api.example.com</url>
        <user-id>API_KEY</user-id>
        <password>API_SECRET</password>
    </service-credential>

    <service-profile profile-id="myapp.api.profile">
        <timeout-millis>30000</timeout-millis>
        <rate-limit-enabled>true</rate-limit-enabled>
        <rate-limit-calls>100</rate-limit-calls>
        <rate-limit-millis>1000</rate-limit-millis>
        <circuit-breaker-enabled>true</circuit-breaker-enabled>
        <circuit-breaker-max-calls>5</circuit-breaker-max-calls>
    </service-profile>

    <service service-id="myapp.api">
        <service-type>HTTP</service-type>
        <enabled>true</enabled>
        <log-prefix>MyApp API</log-prefix>
        <communication-log>true</communication-log>
        <credential credential-id="myapp.api.credential"/>
        <profile profile-id="myapp.api.profile"/>
    </service>
</services>
```
