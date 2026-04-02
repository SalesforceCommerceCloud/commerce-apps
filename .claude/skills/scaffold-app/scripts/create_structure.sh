#!/bin/bash
# Create commerce app directory structure
# Usage: ./create_structure.sh <domain> <isv-name> <appName> <version> <cartridgeName>

DOMAIN=$1
ISV_NAME=$2
APP_NAME=$3
VERSION=$4
CARTRIDGE_NAME=$5

APP_DIR="commerce-${APP_NAME}-app-v${VERSION}"

echo "Creating directory structure for ${APP_DIR}..."

mkdir -p "${DOMAIN}/${ISV_NAME}/${APP_DIR}"
cd "${DOMAIN}/${ISV_NAME}/${APP_DIR}" || exit

# Core directories
mkdir -p app-configuration
mkdir -p icons

# Cartridge structure
mkdir -p "cartridges/site_cartridges/${CARTRIDGE_NAME}/cartridge/scripts/"{hooks,helpers,services}
mkdir -p "cartridges/site_cartridges/${CARTRIDGE_NAME}/test/"{mocks,unit}
mkdir -p "cartridges/bm_cartridges/bm_${APP_NAME}"

# Storefront Next extensions
mkdir -p "storefront-next/src/extensions/${APP_NAME}/"{components,context,hooks,locales,middlewares,providers,routes,stores,tests}

# Impex structure
mkdir -p impex/install/meta
mkdir -p impex/install/sites/SITEID
mkdir -p impex/uninstall

echo "✅ Directory structure created at: ${DOMAIN}/${ISV_NAME}/${APP_DIR}/"
