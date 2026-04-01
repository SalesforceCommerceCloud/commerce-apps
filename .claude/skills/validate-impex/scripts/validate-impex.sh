#!/bin/bash
# Validate SFCC impex XML files
# Usage: ./validate-impex.sh [path-to-impex-dir]

IMPEX_DIR="${1:-impex}"
ERRORS=0

echo "=== SFCC Impex Validation ==="
echo ""

# 1. Check directory structure
echo "Checking directory structure..."
if [ ! -d "$IMPEX_DIR/install" ]; then
    echo "✗ Missing $IMPEX_DIR/install directory"
    ERRORS=$((ERRORS+1))
fi
if [ ! -d "$IMPEX_DIR/uninstall" ]; then
    echo "✗ Missing $IMPEX_DIR/uninstall directory"
    ERRORS=$((ERRORS+1))
fi
echo ""

# 2. Validate XML syntax
echo "Validating XML syntax..."
for file in $(find "$IMPEX_DIR" -name "*.xml"); do
    if ! xmllint --noout "$file" 2>/dev/null; then
        echo "✗ Invalid XML: $file"
        ERRORS=$((ERRORS+1))
    else
        echo "✓ Valid XML: $file"
    fi
done
echo ""

# 3. Check services
if [ -f "$IMPEX_DIR/install/services.xml" ]; then
    echo "Validating services..."

    # Check namespace
    if ! grep -q 'xmlns="http://www.demandware.com/xml/impex/services/2015-07-01"' "$IMPEX_DIR/install/services.xml"; then
        echo "✗ Wrong namespace in services.xml"
        ERRORS=$((ERRORS+1))
    fi

    # Check uninstall exists
    if [ ! -f "$IMPEX_DIR/uninstall/services.xml" ]; then
        echo "✗ Missing uninstall/services.xml"
        ERRORS=$((ERRORS+1))
    else
        # Check delete mode
        if ! grep -q 'mode="delete"' "$IMPEX_DIR/uninstall/services.xml"; then
            echo "✗ Missing mode=\"delete\" in uninstall"
            ERRORS=$((ERRORS+1))
        fi
    fi
    echo ""
fi

# 4. Check site preferences
if [ -f "$IMPEX_DIR/install/meta/system-objecttype-extensions.xml" ]; then
    echo "Validating site preferences..."

    # Check for attribute definitions
    if ! grep -q '<attribute-definition' "$IMPEX_DIR/install/meta/system-objecttype-extensions.xml"; then
        echo "⚠ No attribute definitions found"
    fi

    # Check for group definitions
    if ! grep -q '<attribute-group' "$IMPEX_DIR/install/meta/system-objecttype-extensions.xml"; then
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
