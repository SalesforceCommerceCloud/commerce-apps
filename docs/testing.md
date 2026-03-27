# Testing Commerce Apps

This guide explains how to test your Commerce App locally before submitting to the registry.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Testing Workflow](#testing-workflow)
- [Testing Cartridges](#testing-cartridges)
- [Testing Impex Files](#testing-impex-files)
- [Testing UI Components](#testing-ui-components)
- [Testing Services](#testing-services)
- [End-to-End Testing](#end-to-end-testing)
- [Performance Testing](#performance-testing)
- [Validation Before Submission](#validation-before-submission)

---

## Prerequisites

### Required Access
- SFCC Sandbox environment (Account Manager or Business Manager access)
- UX Studio or VS Code with Prophet extension
- Node.js and npm (for frontend testing)

### Recommended Tools
- **xmllint** - Validate XML impex files
- **Postman** - Test service endpoints
- **Chrome DevTools** - Debug frontend components
- **Claude Code** - Use validation skills

---

## Testing Workflow

```
1. Develop → 2. Test Locally → 3. Test in Sandbox → 4. Validate → 5. Submit
```

### Complete Testing Checklist

- [ ] Cartridges upload successfully
- [ ] Impex files import without errors
- [ ] Services authenticate and respond
- [ ] Hooks execute correctly
- [ ] UI components render properly
- [ ] Site preferences are configurable
- [ ] Custom objects store/retrieve data
- [ ] No errors in logs
- [ ] Performance is acceptable
- [ ] Validation passes

---

## Testing Cartridges

### 1. Upload Cartridges to Sandbox

**Via UX Studio:**
1. Right-click on cartridge → Upload to Server
2. Verify upload completes successfully

**Via dwupload (Prophet):**
```bash
cd cartridges/site_cartridges/my_cartridge
npm run upload
```

**Via VS Code with Prophet:**
1. Configure `.prophet.conf.json`
2. Right-click cartridge → Upload

### 2. Add to Cartridge Path

1. Business Manager → Administration → Sites → Manage Sites
2. Select your site → Settings tab
3. Add cartridge to path (in correct order):
   ```
   int_myapp:site_genesis:other_cartridges
   ```
4. Save and verify

### 3. Test Hooks

**Verify hooks are registered:**
```javascript
// In your cartridge's hooks.json
{
  "hooks": [
    {
      "name": "sf.commerce.app.tax.calculate",
      "script": "./hooks/calculate.js"
    }
  ]
}
```

**Test hook execution:**
- Trigger the hook in storefront (e.g., add to cart for tax calculation)
- Check custom logs in Business Manager:
  - Administration → Operations → Logs → Custom Logs
  - Look for your app's log prefix

**Debug hooks:**
```javascript
// Add debug logging
var Logger = require('dw/system/Logger');
var logger = Logger.getLogger('myApp', 'calculate');

logger.debug('Hook triggered with params: {0}', JSON.stringify(params));
```

### 4. Run Unit Tests

If your cartridge has unit tests:

```bash
cd cartridges/site_cartridges/my_cartridge
npm install
npm test
```

**Test coverage:**
```bash
npm run test:coverage
```

---

## Testing Impex Files

### 1. Validate XML Syntax

Before importing, validate XML:

```bash
# Validate services.xml
xmllint --noout impex/install/services.xml

# Validate all impex files
find impex/ -name "*.xml" -exec xmllint --noout {} \;
```

**Using Claude Code:**
```
/validate-impex
```

### 2. Import Service Configurations

**Via Business Manager:**
1. Administration → Site Development → Import & Export
2. Upload `impex/install/services.xml`
3. Click Import and wait for completion
4. Check for errors in import log

**Verify services created:**
1. Administration → Operations → Services
2. Find your service ID (e.g., `myapp.api`)
3. Verify credential, profile, and service definition

### 3. Import Site Preferences

**Import metadata:**
1. Upload `impex/install/meta/system-objecttype-extensions.xml`
2. Import and check logs

**Import default values:**
1. Replace `SITEID` with your actual site ID in `preferences.xml`
2. Upload and import

**Verify preferences:**
1. Merchant Tools → Site Preferences → Custom Preferences
2. Find your app's preference group
3. Verify all preferences appear
4. Test different values

### 4. Import Custom Object Types

**Import definitions:**
1. Upload `impex/install/meta/custom-objecttype-definitions.xml`
2. Import and check logs

**Verify custom objects:**
1. Administration → Site Development → System Object Types
2. Find your custom object type
3. Verify attributes are defined

**Test in code:**
```javascript
var CustomObjectMgr = require('dw/object/CustomObjectMgr');

// Create test object
var obj = CustomObjectMgr.createCustomObject('MyObjectType', 'test-key');
obj.custom.myAttribute = 'test value';

// Retrieve
var retrieved = CustomObjectMgr.getCustomObject('MyObjectType', 'test-key');
Logger.debug('Retrieved: {0}', retrieved.custom.myAttribute);

// Delete test object
CustomObjectMgr.remove(obj);
```

### 5. Test Uninstall

**IMPORTANT:** Only test in sandbox!

1. Import `impex/uninstall/services.xml`
2. Verify services are removed
3. Re-import install files to restore

---

## Testing UI Components

### 1. Local Development

If your app includes Storefront Next extensions:

```bash
cd storefront-next
npm install
npm run dev
```

**Test components in Storybook:**
```bash
npm run storybook
```

### 2. Component Testing

**Unit tests with Vitest:**
```bash
npm run test
```

**Test coverage:**
```bash
npm run test:coverage
```

### 3. Integration Testing

Deploy to sandbox and test in context:

1. Build extensions:
   ```bash
   npm run build
   ```

2. Deploy to sandbox (consult SFCC documentation for deployment)

3. Navigate to storefront and verify:
   - Components render correctly
   - Styling is correct
   - Interactions work
   - Data loads properly

### 4. Browser Testing

Test across browsers:
- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)

**Use DevTools:**
- Check console for errors
- Inspect network requests
- Verify responsive design
- Test accessibility

---

## Testing Services

### 1. Configure Service Credentials

1. Administration → Operations → Services
2. Select your service
3. Configure credentials:
   - Use sandbox/test API keys
   - Set correct endpoint URL
   - Test authentication

### 2. Test Service Calls

**Via Service Definition:**
1. In Business Manager → Operations → Services
2. Click your service → Test tab
3. Enter test request
4. Click Test and verify response

**Via Script:**
```javascript
var MyService = require('*/cartridge/scripts/services/myService');

// Test call
var result = MyService.call({
    param1: 'test',
    param2: 'value'
});

if (result.success) {
    Logger.info('Service call successful: {0}', JSON.stringify(result.data));
} else {
    Logger.error('Service call failed: {0}', result.error);
}
```

**Monitor service calls:**
1. Administration → Operations → Services → Service Monitoring
2. View call history, response times, errors

### 3. Test Error Handling

**Simulate failures:**
- Invalid credentials (expect auth error)
- Malformed requests (expect validation error)
- Network timeout (expect timeout error)
- Service unavailable (expect circuit breaker)

**Verify error handling:**
```javascript
try {
    var result = MyService.call(params);
    if (!result.success) {
        // Handle gracefully
        Logger.error('Service error: {0}', result.error);
        // Don't break checkout flow
        return defaultBehavior();
    }
} catch (e) {
    Logger.error('Exception calling service: {0}', e.message);
    return defaultBehavior();
}
```

### 4. Test Rate Limiting

**Trigger rate limits:**
- Make rapid successive calls
- Verify rate limiting kicks in
- Check circuit breaker behavior

**Monitor in logs:**
- Look for rate limit messages
- Verify circuit opens/closes as expected

---

## End-to-End Testing

### 1. Installation Test

**Fresh install:**
1. Import all impex files
2. Upload cartridges
3. Configure site preferences
4. Complete post-install tasks (from tasksList.json)
5. Verify app works end-to-end

### 2. Checkout Flow (for checkout-related apps)

**Test complete checkout:**
1. Add products to cart
2. Proceed to checkout
3. Verify your app's functionality (tax calc, shipping rates, payment, etc.)
4. Complete order
5. Check order in Business Manager
6. Verify all hooks executed correctly

**Check logs:**
- Custom logs for your app
- System logs for errors
- Service call logs

### 3. Typical User Scenarios

**Create test scenarios:**
```
Scenario 1: Tax Calculation
1. Customer in New York adds product to cart
2. Tax calculated correctly for NY
3. Customer changes address to California
4. Tax recalculated for CA
5. Order completes with correct tax

Scenario 2: Shipping Rates
1. Customer adds items to cart
2. Shipping rates fetch successfully
3. Customer selects shipping method
4. Correct shipping cost applied
5. Order completes with correct shipping
```

### 4. Edge Cases

**Test edge cases:**
- Empty cart
- Single item vs. multiple items
- High-value orders
- International shipping (if applicable)
- Invalid addresses
- Service timeouts
- Network failures

---

## Performance Testing

### 1. Response Time

**Measure hook execution time:**
```javascript
var startTime = Date.now();

// Your hook logic

var duration = Date.now() - startTime;
Logger.info('Hook execution time: {0}ms', duration);
```

**Target response times:**
- Tax calculation: < 1000ms
- Shipping rates: < 1500ms
- Payment authorization: < 2000ms
- Non-critical hooks: < 500ms

### 2. Service Call Performance

**Monitor in Business Manager:**
- Administration → Operations → Services → Service Monitoring
- Check average response times
- Identify slow calls

**Optimize if needed:**
- Add caching (custom objects)
- Reduce payload size
- Use appropriate timeouts
- Implement circuit breakers

### 3. Caching Strategy

**Test cache behavior:**
```javascript
// Cache hit
var cached = getCachedData(key);
if (cached) {
    Logger.debug('Cache hit for key: {0}', key);
    return cached;
}

// Cache miss - fetch and cache
var data = fetchFromService();
cacheData(key, data, ttl);
return data;
```

**Verify cache expiration:**
- Check TTL behavior
- Test cache invalidation
- Monitor cache hit rate

---

## Validation Before Submission

### 1. Automated Validation

**Using Claude Code:**
```
/validate-commerce-app
/validate-impex
```

**Manual validation:**
```bash
# XML syntax
find impex/ -name "*.xml" -exec xmllint --noout {} \;

# SHA256 hash
shasum -a 256 my-app-v1.0.0.zip
# Compare with manifest.json

# ZIP structure
unzip -l my-app-v1.0.0.zip | head -20
```

### 2. Final Checklist

Before submitting to registry:

**Files:**
- [ ] ZIP file follows naming convention
- [ ] manifest.json has all required fields
- [ ] SHA256 hash matches
- [ ] catalog.json included (new apps only)
- [ ] Only ZIP, manifest.json, catalog.json committed
- [ ] No extracted directories committed

**ZIP Contents:**
- [ ] Single root folder with correct name
- [ ] No junk files (.DS_Store, __MACOSX, etc.)
- [ ] commerce-app.json present and valid
- [ ] README.md included
- [ ] All referenced files exist

**Testing:**
- [ ] Installed in sandbox successfully
- [ ] All impex files import without errors
- [ ] Services authenticate and respond
- [ ] Hooks execute correctly
- [ ] UI components render properly
- [ ] No errors in logs during testing
- [ ] Performance is acceptable
- [ ] Edge cases handled gracefully

**Security:**
- [ ] No hardcoded production credentials
- [ ] No sensitive data in code or impex
- [ ] Input validation implemented
- [ ] Error messages don't leak information

**Documentation:**
- [ ] README.md is complete and accurate
- [ ] Installation steps are clear
- [ ] Configuration documented
- [ ] Troubleshooting section included

### 3. Get Feedback

**Before final submission:**
- Have a colleague review
- Test on a fresh sandbox
- Verify all post-install tasks are clear
- Check that merchants can configure successfully

---

## Common Testing Issues

### Issue: Cartridge Upload Fails
**Solutions:**
- Check file permissions
- Verify cartridge name in manifest
- Check for syntax errors in code
- Ensure cartridge path is correct

### Issue: Impex Import Errors
**Solutions:**
- Validate XML syntax with xmllint
- Check for duplicate IDs
- Verify namespaces are correct
- Replace SITEID with actual site ID

### Issue: Service Call Fails
**Solutions:**
- Verify credentials are correct
- Check endpoint URL
- Test with Postman first
- Check service logs for details
- Verify network access from SFCC

### Issue: Hook Not Executing
**Solutions:**
- Verify hooks.json is correct
- Check hook is registered: `require('dw/system/HookMgr').hasHook('hook.name')`
- Verify cartridge is in path
- Check for syntax errors in hook script
- Add debug logging

### Issue: UI Component Not Rendering
**Solutions:**
- Check browser console for errors
- Verify component is registered in target-config.json
- Check that extension is deployed
- Verify data is loading correctly
- Test in isolation (Storybook)

---

## Best Practices

### 1. Test Early and Often
- Test as you build, not just at the end
- Test each component independently
- Integration test after components work individually

### 2. Use Separate Sandbox
- Don't test in production (obviously!)
- Use dedicated test sandbox if available
- Keep test data realistic but not production data

### 3. Automate Testing
- Write unit tests for business logic
- Use CI/CD for validation
- Automate impex validation

### 4. Document Test Results
- Keep notes on what you tested
- Document any workarounds needed
- Note performance metrics

### 5. Test Uninstall
- Verify cleanup works correctly
- Test in sandbox before providing to merchants
- Ensure no orphaned data

---

## Getting Help

If you encounter testing issues:

1. **Check logs:**
   - Custom logs in Business Manager
   - System logs
   - Service call logs
   - Browser console

2. **Review documentation:**
   - [SFCC Documentation](https://developer.salesforce.com/docs/commerce/b2c-commerce)
   - [CONTRIBUTING.md](../CONTRIBUTING.md)
   - [README.md](../README.md)

3. **Ask for help:**
   - GitHub Discussions
   - Salesforce Developer Forums
   - Internal team if part of organization

4. **Use validation skills:**
   - `/validate-commerce-app`
   - `/validate-impex`
   - `/extract-and-inspect`

---

## Summary

Good testing ensures:
- ✅ App works correctly in all scenarios
- ✅ No errors during installation
- ✅ Merchant can configure successfully
- ✅ Performance is acceptable
- ✅ Code is production-ready

Take time to test thoroughly - it saves time in code review and prevents issues for merchants!
