---
name: validate-impex
description: >-
  Validate SFCC impex XML files for syntax, structure, and common errors. Checks services,
  site preferences, custom objects, and installation/uninstallation pairs. Use before
  importing impex files or submitting commerce apps.
---

# Validate Impex Files

Validate SFCC impex XML files to catch errors before import.

## Step 1: Identify files to validate

Locate all impex files in your commerce app:

```bash
find impex/ -name "*.xml"
```

**Expected structure:**
```
impex/
├── install/
│   ├── services.xml
│   ├── meta/
│   │   ├── system-objecttype-extensions.xml
│   │   └── custom-objecttype-definitions.xml
│   └── sites/
│       └── SITEID/
│           └── preferences.xml
└── uninstall/
    └── services.xml
```

## Step 2: XML syntax validation

Validate XML is well-formed:

```bash
# Validate all XML files
find impex/ -name "*.xml" -exec xmllint --noout {} \;

# Validate specific file
xmllint --noout impex/install/services.xml

# Show errors with line numbers
xmllint impex/install/services.xml
```

**Common XML syntax errors:**
- Missing closing tags
- Unescaped special characters (`&`, `<`, `>`)
- Missing XML declaration
- Invalid attribute quotes
- Encoding issues

**Fix special characters:**
```xml
<!-- Wrong -->
<display-name>Ratings & Reviews</display-name>

<!-- Right -->
<display-name>Ratings &amp; Reviews</display-name>
```

**Character escapes:**
- `&` → `&amp;`
- `<` → `&lt;`
- `>` → `&gt;`
- `"` → `&quot;`
- `'` → `&apos;`

## Step 3: Validate services.xml

### Installation file checks

**File:** `impex/install/services.xml`

```bash
# Check namespace
grep -q 'xmlns="http://www.demandware.com/xml/impex/services/2015-07-01"' impex/install/services.xml

# Check for credentials
grep -q '<service-credential' impex/install/services.xml

# Check for profiles
grep -q '<service-profile' impex/install/services.xml

# Check for service definitions
grep -q '<service service-id=' impex/install/services.xml
```

**Validation checklist:**
- [ ] XML namespace is `http://www.demandware.com/xml/impex/services/2015-07-01`
- [ ] Root element is `<services>`
- [ ] All credentials have unique `credential-id`
- [ ] All profiles have unique `profile-id`
- [ ] All services have unique `service-id`
- [ ] Service IDs use dotted notation (e.g., `vendor.service.api`)
- [ ] Services reference existing credentials and profiles
- [ ] No hardcoded production credentials
- [ ] Timeouts are reasonable (5000-60000 ms)
- [ ] Rate limiting configured for external APIs

**Common errors:**

| Error | Fix |
|-------|-----|
| Duplicate service-id | Make IDs unique |
| Missing credential reference | Add `<credential credential-id="..."/>` |
| Missing profile reference | Add `<profile profile-id="..."/>` |
| Invalid timeout | Use milliseconds (30000 = 30 seconds) |
| Wrong service-type | Use HTTP, FTP, GENERIC, WEBDAV |
| Hardcoded credentials | Use placeholders |

### Uninstallation file checks

**File:** `impex/uninstall/services.xml`

```bash
# Check for delete mode
grep -q 'mode="delete"' impex/uninstall/services.xml

# Check order (service, then profile, then credential)
```

**Validation checklist:**
- [ ] XML namespace matches install file
- [ ] All services use `mode="delete"`
- [ ] Deletion order: service → profile → credential
- [ ] All service IDs match install file
- [ ] All profile IDs match install file
- [ ] All credential IDs match install file

**Verify install/uninstall pairs match:**

```bash
# Extract service IDs from install
grep 'service-id=' impex/install/services.xml | sed 's/.*service-id="\([^"]*\)".*/\1/' | sort > /tmp/install-services.txt

# Extract service IDs from uninstall
grep 'service-id=' impex/uninstall/services.xml | sed 's/.*service-id="\([^"]*\)".*/\1/' | sort > /tmp/uninstall-services.txt

# Compare (should be identical)
diff /tmp/install-services.txt /tmp/uninstall-services.txt
```

## Step 4: Validate site preferences

### system-objecttype-extensions.xml checks

**File:** `impex/install/meta/system-objecttype-extensions.xml`

**Validation checklist:**
- [ ] XML namespace is `http://www.demandware.com/xml/impex/metadata/2006-10-31`
- [ ] Root element is `<metadata>`
- [ ] Type extension is for `SitePreferences`
- [ ] All attribute IDs are unique
- [ ] All attribute IDs use camelCase
- [ ] All attribute IDs prefixed with app name
- [ ] Display names and descriptions present
- [ ] Appropriate data types used
- [ ] Default values match data types
- [ ] All attributes added to group definition
- [ ] Group ID is descriptive

**Validate attribute types:**

```bash
# Find all attribute types
grep '<type>' impex/install/meta/system-objecttype-extensions.xml
```

**Valid types:**
- `boolean`
- `string`
- `text`
- `integer`
- `decimal`
- `email`
- `password`
- `enum-of-string`
- `enum-of-int`
- `set-of-string`
- `set-of-int`
- `date`
- `datetime`

**Common errors:**

| Error | Fix |
|-------|-----|
| No attribute prefix | Add app name prefix |
| snake_case IDs | Use camelCase |
| Missing default value | Add `<default-value>` |
| Wrong type for enum | Use `enum-of-string` |
| Missing value-definitions | Add for enum types |
| Not in group | Add attribute to group-definitions |
| Missing mandatory-flag | Add `<mandatory-flag>false</mandatory-flag>` |

### preferences.xml checks

**File:** `impex/install/sites/SITEID/preferences.xml`

**Validation checklist:**
- [ ] XML namespace is `http://www.demandware.com/xml/impex/preferences/2006-10-31`
- [ ] Root element is `<preferences>`
- [ ] Uses `SITEID` placeholder (not actual site ID)
- [ ] All preference IDs match attribute definitions
- [ ] Default values match data types
- [ ] No sensitive data (API keys, secrets)

**Verify all preferences defined:**

```bash
# Extract attribute IDs from meta file
grep 'attribute-id=' impex/install/meta/system-objecttype-extensions.xml | sed 's/.*attribute-id="\([^"]*\)".*/\1/' | grep -v '^keyProperty$' | sort > /tmp/defined-attrs.txt

# Extract preference IDs from preferences file
grep 'preference-id=' impex/install/sites/SITEID/preferences.xml | sed 's/.*preference-id="\([^"]*\)".*/\1/' | sort > /tmp/set-prefs.txt

# Check which are missing defaults (optional but good practice)
comm -23 /tmp/defined-attrs.txt /tmp/set-prefs.txt
```

## Step 5: Validate custom objects

**File:** `impex/install/meta/custom-objecttype-definitions.xml`

**Validation checklist:**
- [ ] XML namespace is `http://www.demandware.com/xml/impex/metadata/2006-10-31`
- [ ] Root element is `<metadata>`
- [ ] `key-attribute` defined
- [ ] Key attribute is mandatory
- [ ] Object type ID is PascalCase
- [ ] Storage scope is `site` or `organization`
- [ ] Staging mode is valid (`no-sharing`, `shared`, `source-to-target`)
- [ ] Retention days is 0 or 1-365
- [ ] All attributes added to group
- [ ] Custom type definition matches type extension

**Validate required elements:**

```bash
# Check for key attribute
grep -q '<key-attribute' impex/install/meta/custom-objecttype-definitions.xml

# Check for custom type
grep -q '<custom-type' impex/install/meta/custom-objecttype-definitions.xml

# Check for storage configuration
grep -q '<storage-scope>' impex/install/meta/custom-objecttype-definitions.xml
```

**Common errors:**

| Error | Fix |
|-------|-----|
| Missing key-attribute | Define in type-extension |
| Key not mandatory | Set `<mandatory-flag>true</mandatory-flag>` |
| Invalid staging-mode | Use no-sharing, shared, or source-to-target |
| No retention policy | Add `<retention-days>` |
| Type ID mismatch | Match type-extension and custom-type |

## Step 6: Cross-file validation

### Check file completeness

```bash
# Required files for basic app
[ -f impex/install/services.xml ] && echo "✓ Services install" || echo "✗ Missing services install"
[ -f impex/uninstall/services.xml ] && echo "✓ Services uninstall" || echo "✗ Missing services uninstall"
[ -f impex/install/meta/system-objecttype-extensions.xml ] && echo "✓ Site preferences" || echo "✗ Missing site preferences"
[ -f impex/install/sites/SITEID/preferences.xml ] && echo "✓ Default preferences" || echo "✗ Missing default preferences"
```

### Verify naming consistency

Check that IDs follow consistent patterns:

```bash
# Service IDs should be dotted notation
grep 'service-id=' impex/install/services.xml | grep -v '\.' && echo "⚠ Service IDs should use dotted notation"

# Attribute IDs should be camelCase
grep 'attribute-id=' impex/install/meta/system-objecttype-extensions.xml | grep '_' && echo "⚠ Attribute IDs should use camelCase, not snake_case"

# Attribute IDs should have app prefix
APP_NAME="myapp"
grep 'attribute-id=' impex/install/meta/system-objecttype-extensions.xml | grep -v "attribute-id=\"${APP_NAME}" | grep -v "keyProperty" && echo "⚠ Attribute IDs should be prefixed with ${APP_NAME}"
```

## Step 7: Automated validation script

Create a validation script:

**File:** `validate-impex.sh`

```bash
#!/bin/bash

echo "=== SFCC Impex Validation ==="
echo ""

ERRORS=0

# 1. Check directory structure
echo "Checking directory structure..."
if [ ! -d "impex/install" ]; then
    echo "✗ Missing impex/install directory"
    ERRORS=$((ERRORS+1))
fi
if [ ! -d "impex/uninstall" ]; then
    echo "✗ Missing impex/uninstall directory"
    ERRORS=$((ERRORS+1))
fi
echo ""

# 2. Validate XML syntax
echo "Validating XML syntax..."
for file in $(find impex/ -name "*.xml"); do
    if ! xmllint --noout "$file" 2>/dev/null; then
        echo "✗ Invalid XML: $file"
        ERRORS=$((ERRORS+1))
    else
        echo "✓ Valid XML: $file"
    fi
done
echo ""

# 3. Check services
if [ -f impex/install/services.xml ]; then
    echo "Validating services..."

    # Check namespace
    if ! grep -q 'xmlns="http://www.demandware.com/xml/impex/services/2015-07-01"' impex/install/services.xml; then
        echo "✗ Wrong namespace in services.xml"
        ERRORS=$((ERRORS+1))
    fi

    # Check uninstall exists
    if [ ! -f impex/uninstall/services.xml ]; then
        echo "✗ Missing uninstall/services.xml"
        ERRORS=$((ERRORS+1))
    else
        # Check delete mode
        if ! grep -q 'mode="delete"' impex/uninstall/services.xml; then
            echo "✗ Missing mode=\"delete\" in uninstall"
            ERRORS=$((ERRORS+1))
        fi
    fi
    echo ""
fi

# 4. Check site preferences
if [ -f impex/install/meta/system-objecttype-extensions.xml ]; then
    echo "Validating site preferences..."

    # Check for attribute definitions
    if ! grep -q '<attribute-definition' impex/install/meta/system-objecttype-extensions.xml; then
        echo "⚠ No attribute definitions found"
    fi

    # Check for group definitions
    if ! grep -q '<attribute-group' impex/install/meta/system-objecttype-extensions.xml; then
        echo "⚠ No attribute groups found"
    fi
    echo ""
fi

# 5. Report results
echo "=== Validation Complete ==="
if [ $ERRORS -eq 0 ]; then
    echo "✓ All checks passed!"
    exit 0
else
    echo "✗ Found $ERRORS error(s)"
    exit 1
fi
```

Run the script:

```bash
chmod +x validate-impex.sh
./validate-impex.sh
```

## Step 8: Pre-import checklist

Before importing impex files:

**Security:**
- [ ] No hardcoded production credentials
- [ ] No sensitive data in XML
- [ ] Passwords use `<password>` type
- [ ] API secrets are placeholders

**Structure:**
- [ ] All XML files are well-formed
- [ ] Namespaces are correct
- [ ] File structure matches requirements
- [ ] SITEID placeholder used (not actual site ID)

**Services:**
- [ ] Service IDs are unique and use dotted notation
- [ ] Credentials and profiles referenced correctly
- [ ] Timeouts and rate limits configured
- [ ] Uninstall file matches install file

**Site Preferences:**
- [ ] Attribute IDs prefixed with app name
- [ ] camelCase naming convention used
- [ ] All attributes in group definition
- [ ] Default values match types
- [ ] Descriptions are helpful

**Custom Objects:**
- [ ] Key attribute defined and mandatory
- [ ] Storage scope appropriate
- [ ] Retention policy set
- [ ] Type IDs are unique

## Step 9: Import testing

After validation, test import:

### 1. Test in Sandbox First

Never test in production first!

### 2. Import via Business Manager

1. **Administration > Site Development > Import & Export**
2. Upload impex files
3. Select "Upload" and choose file
4. Click "Import"
5. Review logs for errors

### 3. Import Order

Import in this order:
1. Custom object type definitions
2. Site preference definitions (meta)
3. Services (install)
4. Default preferences

### 4. Verify Import

**Services:**
- Administration > Operations > Services
- Verify services appear
- Check credentials configured
- Test service calls

**Site Preferences:**
- Merchant Tools > Site Preferences > Custom Preferences
- Find your app group
- Verify all preferences present
- Test different values

**Custom Objects:**
- Administration > Site Development > System Object Types
- Find your custom object type
- Verify attributes present
- Test creating objects in code

### 5. Test Uninstall

Test cleanup:
1. Import uninstall services.xml
2. Verify services removed
3. Check profiles and credentials removed

## Common validation errors

| Error | Cause | Fix |
|-------|-------|-----|
| `parser error : Opening and ending tag mismatch` | Unclosed tag | Add closing tag |
| `Namespace prefix dwre on ... is not defined` | Wrong namespace | Use correct SFCC namespace |
| `Service with ID already exists` | Duplicate service ID | Use unique IDs |
| `Attribute not defined in group` | Missing from group | Add to group-definitions |
| `Invalid value for type` | Type mismatch | Match default value to type |
| `Cannot delete service, profile in use` | Wrong delete order | Delete service → profile → credential |
| `SITEID not found` | Actual site ID used | Use SITEID placeholder |
| `Credential not found` | Wrong credential-id | Match credential ID exactly |

## Validation tools

### xmllint (XML validation)
```bash
# Install (macOS)
brew install libxml2

# Install (Linux)
sudo apt-get install libxml2-utils

# Validate
xmllint --noout file.xml
```

### xmlstarlet (XML query)
```bash
# Install (macOS)
brew install xmlstarlet

# Query elements
xmlstarlet sel -t -v "//service-credential/@credential-id" services.xml

# Count services
xmlstarlet sel -t -v "count(//service)" services.xml
```

### jq (JSON validation - for JSON in text fields)
```bash
# Validate JSON strings
echo '{"test": "value"}' | jq .
```

## Quick validation command

Run all validations at once:

```bash
# One-liner to validate all impex files
find impex/ -name "*.xml" | while read f; do echo "Checking $f..."; xmllint --noout "$f" && echo "✓" || echo "✗ ERROR"; done
```

## Best practices summary

1. **Always validate before import** - Catch errors early
2. **Test in sandbox first** - Never test in production
3. **Use consistent naming** - Follow conventions
4. **Match install/uninstall** - Keep them in sync
5. **No hardcoded secrets** - Use placeholders
6. **Validate cross-references** - IDs must match
7. **Set appropriate defaults** - Safe initial values
8. **Document complex configs** - Clear descriptions
9. **Version control impex** - Track changes
10. **Automate validation** - Use scripts and CI/CD
