---
name: generate-custom-object-impex
description: >-
  Generate SFCC custom object type impex files with attribute definitions, key structures,
  and storage configurations. Use when your commerce app needs to store custom data
  like caching, configurations, or app-specific records.
---

# Generate Custom Object Impex

Generate complete custom object type definitions for SFCC commerce apps.

## Step 1: Understand custom objects

**What are custom objects?**
- Key-value storage for custom application data
- Persist data across sessions
- Query and index capabilities
- Can store complex data structures

**Common use cases:**
- Caching API responses
- Storing app configuration
- Logging and audit trails
- Session management
- Custom data storage (wishlists, notifications, etc.)

## Step 2: Collect custom object information

| Input | Example | Notes |
|-------|---------|-------|
| Object Type ID | `RatingsReviewsCache` | PascalCase, unique identifier |
| Display Name | `Ratings & Reviews Cache` | Human-readable name |
| Key Pattern | `{siteID}_{productID}` | How keys are structured |
| Storage Duration | `7 days`, `permanent` | Retention policy |
| Data Attributes | List of fields | What data to store |

## Step 3: Generate meta/custom-objecttype-definitions.xml

Create the custom object type definition:

**File:** `impex/install/meta/custom-objecttype-definitions.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://www.demandware.com/xml/impex/metadata/2006-10-31">

    <!-- Custom Object Type Definition -->
    <type-extension type-id="{ObjectTypeID}">
        <key-attribute attribute-id="keyProperty"/>

        <custom-attribute-definitions>

            <!-- Key Property (Required) -->
            <attribute-definition attribute-id="keyProperty">
                <display-name xml:lang="x-default">Key</display-name>
                <description xml:lang="x-default">Unique identifier for this record</description>
                <type>string</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <min-length>1</min-length>
                <max-length>256</max-length>
            </attribute-definition>

            <!-- Add your custom attributes here -->

        </custom-attribute-definitions>

        <group-definitions>
            <attribute-group group-id="{ObjectTypeID}">
                <display-name xml:lang="x-default">{Display Name}</display-name>
                <attribute attribute-id="keyProperty"/>
                <!-- Add all attributes to group -->
            </attribute-group>
        </group-definitions>

    </type-extension>

    <!-- Storage Configuration -->
    <custom-type type-id="{ObjectTypeID}">
        <display-name xml:lang="x-default">{Display Name}</display-name>
        <description xml:lang="x-default">{Description of what this stores}</description>
        <staging-mode>no-sharing</staging-mode>
        <storage-scope>site</storage-scope>
        <key-definition attribute-id="keyProperty"/>
        <retention-days>{retentionDays}</retention-days>
    </custom-type>

</metadata>
```

## Step 4: Configure storage settings

### Staging Mode

Controls how data syncs between staging and production:

```xml
<staging-mode>no-sharing</staging-mode>
```

**Options:**
- `no-sharing` - Independent in staging and production (most common)
- `shared` - Same data in staging and production
- `source-to-target` - Replicate from staging to production

**Recommendation:** Use `no-sharing` for:
- Cache data
- Session data
- Test data
- Development data

Use `shared` for:
- Configuration data that should be identical
- Reference data

### Storage Scope

Controls data visibility across sites:

```xml
<storage-scope>site</storage-scope>
```

**Options:**
- `site` - Data is site-specific (most common)
- `organization` - Data is shared across all sites

**Recommendation:**
- Use `site` for site-specific data (caches, site configs)
- Use `organization` for shared data (global settings, shared caches)

### Retention Days

Controls automatic cleanup:

```xml
<retention-days>7</retention-days>
```

**Options:**
- `0` - Permanent (never auto-delete)
- `1-365` - Auto-delete after X days

**Recommendation:**
- Cache: 1-7 days
- Logs: 30 days
- Configuration: 0 (permanent)
- Session data: 1 day

## Step 5: Common custom object patterns

### Pattern 1: API Response Cache

**Use case:** Cache expensive API calls to reduce latency and costs

```xml
<metadata xmlns="http://www.demandware.com/xml/impex/metadata/2006-10-31">

    <type-extension type-id="RatingsReviewsCache">
        <key-attribute attribute-id="cacheKey"/>

        <custom-attribute-definitions>
            <!-- Cache Key -->
            <attribute-definition attribute-id="cacheKey">
                <display-name xml:lang="x-default">Cache Key</display-name>
                <description xml:lang="x-default">Unique cache key (e.g., siteID_productID)</description>
                <type>string</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <min-length>1</min-length>
                <max-length>256</max-length>
            </attribute-definition>

            <!-- Cached Response -->
            <attribute-definition attribute-id="responseData">
                <display-name xml:lang="x-default">Response Data</display-name>
                <description xml:lang="x-default">JSON response from API</description>
                <type>text</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
            </attribute-definition>

            <!-- Cache Timestamp -->
            <attribute-definition attribute-id="cachedAt">
                <display-name xml:lang="x-default">Cached At</display-name>
                <description xml:lang="x-default">Timestamp when cached</description>
                <type>datetime</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
            </attribute-definition>

            <!-- TTL (Time to Live) -->
            <attribute-definition attribute-id="ttlSeconds">
                <display-name xml:lang="x-default">TTL (seconds)</display-name>
                <description xml:lang="x-default">Cache lifetime in seconds</description>
                <type>integer</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <min-value>0</min-value>
                <default-value>3600</default-value>
            </attribute-definition>
        </custom-attribute-definitions>

        <group-definitions>
            <attribute-group group-id="ratingsReviewsCache">
                <display-name xml:lang="x-default">Ratings & Reviews Cache</display-name>
                <attribute attribute-id="cacheKey"/>
                <attribute attribute-id="responseData"/>
                <attribute attribute-id="cachedAt"/>
                <attribute attribute-id="ttlSeconds"/>
            </attribute-group>
        </group-definitions>
    </type-extension>

    <custom-type type-id="RatingsReviewsCache">
        <display-name xml:lang="x-default">Ratings & Reviews Cache</display-name>
        <description xml:lang="x-default">Cache for API responses</description>
        <staging-mode>no-sharing</staging-mode>
        <storage-scope>site</storage-scope>
        <key-definition attribute-id="cacheKey"/>
        <retention-days>7</retention-days>
    </custom-type>

</metadata>
```

### Pattern 2: Configuration Storage

**Use case:** Store complex app configuration beyond site preferences

```xml
<metadata xmlns="http://www.demandware.com/xml/impex/metadata/2006-10-31">

    <type-extension type-id="AppConfiguration">
        <key-attribute attribute-id="configKey"/>

        <custom-attribute-definitions>
            <!-- Config Key -->
            <attribute-definition attribute-id="configKey">
                <display-name xml:lang="x-default">Configuration Key</display-name>
                <type>string</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <min-length>1</min-length>
                <max-length>256</max-length>
            </attribute-definition>

            <!-- Config Value (JSON) -->
            <attribute-definition attribute-id="configValue">
                <display-name xml:lang="x-default">Configuration Value</display-name>
                <description xml:lang="x-default">JSON configuration data</description>
                <type>text</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
            </attribute-definition>

            <!-- Environment -->
            <attribute-definition attribute-id="environment">
                <display-name xml:lang="x-default">Environment</display-name>
                <type>enum-of-string</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <value-definitions>
                    <value-definition>
                        <display xml:lang="x-default">Development</display>
                        <value>development</value>
                    </value-definition>
                    <value-definition>
                        <display xml:lang="x-default">Staging</display>
                        <value>staging</value>
                    </value-definition>
                    <value-definition>
                        <display xml:lang="x-default">Production</display>
                        <value>production</value>
                    </value-definition>
                </value-definitions>
                <default-value>production</default-value>
            </attribute-definition>

            <!-- Last Updated -->
            <attribute-definition attribute-id="lastUpdated">
                <display-name xml:lang="x-default">Last Updated</display-name>
                <type>datetime</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
            </attribute-definition>
        </custom-attribute-definitions>

        <group-definitions>
            <attribute-group group-id="appConfiguration">
                <display-name xml:lang="x-default">App Configuration</display-name>
                <attribute attribute-id="configKey"/>
                <attribute attribute-id="configValue"/>
                <attribute attribute-id="environment"/>
                <attribute attribute-id="lastUpdated"/>
            </attribute-group>
        </group-definitions>
    </type-extension>

    <custom-type type-id="AppConfiguration">
        <display-name xml:lang="x-default">App Configuration</display-name>
        <description xml:lang="x-default">Application configuration storage</description>
        <staging-mode>source-to-target</staging-mode>
        <storage-scope>organization</storage-scope>
        <key-definition attribute-id="configKey"/>
        <retention-days>0</retention-days>
    </custom-type>

</metadata>
```

### Pattern 3: Audit Log / Activity Tracking

**Use case:** Track user actions, API calls, or system events

```xml
<metadata xmlns="http://www.demandware.com/xml/impex/metadata/2006-10-31">

    <type-extension type-id="AuditLog">
        <key-attribute attribute-id="logId"/>

        <custom-attribute-definitions>
            <!-- Log ID -->
            <attribute-definition attribute-id="logId">
                <display-name xml:lang="x-default">Log ID</display-name>
                <type>string</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <min-length>1</min-length>
                <max-length>256</max-length>
            </attribute-definition>

            <!-- Event Type -->
            <attribute-definition attribute-id="eventType">
                <display-name xml:lang="x-default">Event Type</display-name>
                <type>enum-of-string</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <value-definitions>
                    <value-definition>
                        <display xml:lang="x-default">API Call</display>
                        <value>api_call</value>
                    </value-definition>
                    <value-definition>
                        <display xml:lang="x-default">Configuration Change</display>
                        <value>config_change</value>
                    </value-definition>
                    <value-definition>
                        <display xml:lang="x-default">Error</display>
                        <value>error</value>
                    </value-definition>
                    <value-definition>
                        <display xml:lang="x-default">User Action</display>
                        <value>user_action</value>
                    </value-definition>
                </value-definitions>
            </attribute-definition>

            <!-- Event Data -->
            <attribute-definition attribute-id="eventData">
                <display-name xml:lang="x-default">Event Data</display-name>
                <description xml:lang="x-default">JSON data about the event</description>
                <type>text</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
            </attribute-definition>

            <!-- User ID -->
            <attribute-definition attribute-id="userId">
                <display-name xml:lang="x-default">User ID</display-name>
                <type>string</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <min-length>0</min-length>
            </attribute-definition>

            <!-- Timestamp -->
            <attribute-definition attribute-id="timestamp">
                <display-name xml:lang="x-default">Timestamp</display-name>
                <type>datetime</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
            </attribute-definition>

            <!-- Severity -->
            <attribute-definition attribute-id="severity">
                <display-name xml:lang="x-default">Severity</display-name>
                <type>enum-of-string</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <value-definitions>
                    <value-definition>
                        <display xml:lang="x-default">Info</display>
                        <value>info</value>
                    </value-definition>
                    <value-definition>
                        <display xml:lang="x-default">Warning</display>
                        <value>warning</value>
                    </value-definition>
                    <value-definition>
                        <display xml:lang="x-default">Error</display>
                        <value>error</value>
                    </value-definition>
                    <value-definition>
                        <display xml:lang="x-default">Critical</display>
                        <value>critical</value>
                    </value-definition>
                </value-definitions>
                <default-value>info</default-value>
            </attribute-definition>
        </custom-attribute-definitions>

        <group-definitions>
            <attribute-group group-id="auditLog">
                <display-name xml:lang="x-default">Audit Log</display-name>
                <attribute attribute-id="logId"/>
                <attribute attribute-id="eventType"/>
                <attribute attribute-id="eventData"/>
                <attribute attribute-id="userId"/>
                <attribute attribute-id="timestamp"/>
                <attribute attribute-id="severity"/>
            </attribute-group>
        </group-definitions>
    </type-extension>

    <custom-type type-id="AuditLog">
        <display-name xml:lang="x-default">Audit Log</display-name>
        <description xml:lang="x-default">Application audit and activity log</description>
        <staging-mode>no-sharing</staging-mode>
        <storage-scope>site</storage-scope>
        <key-definition attribute-id="logId"/>
        <retention-days>30</retention-days>
    </custom-type>

</metadata>
```

### Pattern 4: Session/State Management

**Use case:** Store temporary session data or user state

```xml
<metadata xmlns="http://www.demandware.com/xml/impex/metadata/2006-10-31">

    <type-extension type-id="SessionState">
        <key-attribute attribute-id="sessionId"/>

        <custom-attribute-definitions>
            <!-- Session ID -->
            <attribute-definition attribute-id="sessionId">
                <display-name xml:lang="x-default">Session ID</display-name>
                <type>string</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <min-length>1</min-length>
                <max-length>256</max-length>
            </attribute-definition>

            <!-- Session Data -->
            <attribute-definition attribute-id="sessionData">
                <display-name xml:lang="x-default">Session Data</display-name>
                <description xml:lang="x-default">JSON session state</description>
                <type>text</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
            </attribute-definition>

            <!-- Created At -->
            <attribute-definition attribute-id="createdAt">
                <display-name xml:lang="x-default">Created At</display-name>
                <type>datetime</type>
                <mandatory-flag>true</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
            </attribute-definition>

            <!-- Last Accessed -->
            <attribute-definition attribute-id="lastAccessed">
                <display-name xml:lang="x-default">Last Accessed</display-name>
                <type>datetime</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
            </attribute-definition>

            <!-- Customer ID -->
            <attribute-definition attribute-id="customerId">
                <display-name xml:lang="x-default">Customer ID</display-name>
                <type>string</type>
                <mandatory-flag>false</mandatory-flag>
                <externally-managed-flag>false</externally-managed-flag>
                <min-length>0</min-length>
            </attribute-definition>
        </custom-attribute-definitions>

        <group-definitions>
            <attribute-group group-id="sessionState">
                <display-name xml:lang="x-default">Session State</display-name>
                <attribute attribute-id="sessionId"/>
                <attribute attribute-id="sessionData"/>
                <attribute attribute-id="createdAt"/>
                <attribute attribute-id="lastAccessed"/>
                <attribute attribute-id="customerId"/>
            </attribute-group>
        </group-definitions>
    </type-extension>

    <custom-type type-id="SessionState">
        <display-name xml:lang="x-default">Session State</display-name>
        <description xml:lang="x-default">Temporary session state storage</description>
        <staging-mode>no-sharing</staging-mode>
        <storage-scope>site</storage-scope>
        <key-definition attribute-id="sessionId"/>
        <retention-days>1</retention-days>
    </custom-type>

</metadata>
```

## Step 6: Key design patterns

### Key Structure Best Practices

Good key patterns:
- `{siteID}_{productID}` - Site-specific product cache
- `{customerID}_{timestamp}` - Customer activity log
- `config_{environment}_{feature}` - Environment-specific config
- `session_{sessionID}` - Session identifier

Bad key patterns:
- Random UUIDs (hard to query/debug)
- No delimiters (hard to parse)
- Overly long keys (performance impact)

### Data Storage

**For small data (<4KB):**
- Use `string` type for simple values
- Store JSON in `text` type for structured data

**For large data (>4KB):**
- Split into multiple custom objects
- Use external storage (S3, etc.) and store reference

**JSON storage example:**
```javascript
var customObj = customObjectMgr.createCustomObject('MyCache', cacheKey);
customObj.custom.responseData = JSON.stringify({
    productId: product.ID,
    rating: 4.5,
    reviewCount: 123,
    lastUpdated: new Date().toISOString()
});
```

## Step 7: Best practices

### Performance

1. **Index frequently queried fields:** Use key property for lookups
2. **Set retention days:** Auto-cleanup prevents storage bloat
3. **Use site scope when possible:** Better performance than organization
4. **Cache appropriately:** Balance freshness vs. API costs

### Data Management

1. **Clean up old data:** Use retention or manual cleanup jobs
2. **Monitor storage:** Track custom object counts
3. **Handle missing data:** Always check if object exists
4. **Validate before storing:** Check data types and sizes

### Security

1. **Don't store sensitive data:** No passwords, credit cards, PII
2. **Encrypt if needed:** Use SFCC encryption for sensitive config
3. **Access control:** Limit who can read/write custom objects
4. **Audit logging:** Track changes to important data

## Step 8: Validation checklist

- [ ] Object type ID is PascalCase and unique
- [ ] Key attribute defined and mandatory
- [ ] All attributes have appropriate types
- [ ] Display names and descriptions are clear
- [ ] Storage scope appropriate (site vs organization)
- [ ] Staging mode correct (usually no-sharing)
- [ ] Retention days set appropriately
- [ ] All attributes added to group
- [ ] XML is well-formed and valid
- [ ] No sensitive data stored unencrypted

## Step 9: Testing

After generating the impex:

1. **Validate XML:**
   ```bash
   xmllint --noout impex/install/meta/custom-objecttype-definitions.xml
   ```

2. **Import via Business Manager:**
   - Administration > Site Development > Import & Export
   - Import custom object type definition

3. **Verify in Business Manager:**
   - Administration > Site Development > System Object Types
   - Find your custom object type
   - Verify all attributes present

4. **Test in code:**
   ```javascript
   var CustomObjectMgr = require('dw/object/CustomObjectMgr');

   // Create
   var obj = CustomObjectMgr.createCustomObject('MyObjectType', 'test-key');
   obj.custom.myAttribute = 'value';

   // Read
   var obj = CustomObjectMgr.getCustomObject('MyObjectType', 'test-key');

   // Query
   var objs = CustomObjectMgr.queryCustomObjects('MyObjectType', '', 'creationDate desc');

   // Delete
   CustomObjectMgr.remove(obj);
   ```

## Common mistakes to avoid

| Mistake | Impact | Fix |
|---------|--------|-----|
| Missing key-attribute | Type won't work | Define key attribute |
| No retention policy | Storage bloat | Set appropriate retention days |
| Wrong storage scope | Performance or data issues | Use site scope unless shared needed |
| Storing sensitive data | Security risk | Use encryption or don't store |
| No cleanup strategy | Storage limits | Set retention or create cleanup job |
| Complex key patterns | Hard to query | Keep keys simple and consistent |
| Text for small data | Wasted storage | Use string for small values |
| No validation | Bad data | Validate before storing |

## Quick reference template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://www.demandware.com/xml/impex/metadata/2006-10-31">

    <type-extension type-id="MyCustomObject">
        <key-attribute attribute-id="keyProperty"/>

        <custom-attribute-definitions>
            <attribute-definition attribute-id="keyProperty">
                <display-name xml:lang="x-default">Key</display-name>
                <type>string</type>
                <mandatory-flag>true</mandatory-flag>
                <min-length>1</min-length>
                <max-length>256</max-length>
            </attribute-definition>

            <!-- Add your attributes -->
        </custom-attribute-definitions>

        <group-definitions>
            <attribute-group group-id="myCustomObject">
                <display-name xml:lang="x-default">My Custom Object</display-name>
                <attribute attribute-id="keyProperty"/>
            </attribute-group>
        </group-definitions>
    </type-extension>

    <custom-type type-id="MyCustomObject">
        <display-name xml:lang="x-default">My Custom Object</display-name>
        <description xml:lang="x-default">Description</description>
        <staging-mode>no-sharing</staging-mode>
        <storage-scope>site</storage-scope>
        <key-definition attribute-id="keyProperty"/>
        <retention-days>7</retention-days>
    </custom-type>

</metadata>
```
