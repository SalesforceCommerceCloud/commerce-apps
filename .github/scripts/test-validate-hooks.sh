#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-hooks.sh"
export HOOKS_CONFIG="$SCRIPT_DIR/../config/domain-hooks.json"

PASS=0
FAIL=0
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
cd "$ROOT"
export ROOT_MANIFEST="$ROOT/manifest.json"
printf '%s' '{"payment":[{"id":"sf-native","domain":"payment","provider":"salesforce"},{"id":"acme-pay","domain":"payment","provider":"thirdParty"}],"tax":[{"id":"m1","domain":"tax"},{"id":"m2","domain":"shipping"},{"id":"m3","domain":"tax"}],"shipping":[{"id":"m3","domain":"shipping"}]}' > "$ROOT_MANIFEST"

# make_zip <domain> <app> <hooks-json|-> <cap-json> [script-body-for-all-hooks]
# Hook scripts are generated per hook name (suffix function defined) unless body given.
make_zip() {
  local domain="$1" app="$2" hooks="$3" cap="$4" body="${5:-}"
  # mktemp, not $RANDOM: a collision reuses the previous app directory and the
  # zip then contains both apps. find returns the first commerce-app.json.
  local work pkg
  work="$(mktemp -d "$ROOT/work.XXXXXX")"
  pkg="$work/commerce-$app-app-v1.0.0"
  mkdir -p "$pkg" "$ROOT/$domain/$app"
  printf '%s' "$cap" > "$pkg/commerce-app.json"
  if [[ "$hooks" != "-" ]]; then
    mkdir -p "$pkg/cartridges/site_cartridges/int_x/cartridge/scripts/hooks"
    printf '%s' "{\"hooks\":$hooks}" > "$pkg/cartridges/site_cartridges/int_x/cartridge/scripts/hooks.json"
    printf '%s' "{\"name\":\"int_x\",\"hooks\":\"${PKG_HOOKS_PTR-./cartridge/scripts/hooks.json}\"}" > "$pkg/cartridges/site_cartridges/int_x/package.json"
    [[ -z "${PKG_HOOKS_PTR-x}" ]] && printf '{"name":"int_x"}' > "$pkg/cartridges/site_cartridges/int_x/package.json"
    while IFS= read -r name; do
      local suffix="${name##*.}"
      printf '%s\n' "${body:-exports.$suffix = function () {};}" > "$pkg/cartridges/site_cartridges/int_x/cartridge/scripts/hooks/$suffix.js"
    done < <(jq -r '.[].name' <<< "$hooks")
  fi
  (cd "$work" && zip -qr "$ROOT/$domain/$app/$app-v1.0.0.zip" .)
  echo "$domain/$app/$app-v1.0.0.zip"
}

hooks_for() { # <domain> <suffix...> -> hooks.json array
  local d="$1"; shift
  local out="[" sep=""
  for s in "$@"; do
    out+="$sep{\"name\":\"sfcc.app.$d.$s\",\"script\":\"./hooks/$s.js\"}"; sep=","
  done
  echo "$out]"
}

run() { OUT="$(bash "$VALIDATE" "$1" 2>&1)" && RC=0 || RC=$?; }

expect() { # desc, expected rc, substring
  if [[ "$RC" -eq "$2" && "$OUT" == *"$3"* ]]; then
    echo "  PASS: $1"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $1 (rc=$RC, wanted $2, substring '$3')"; echo "    $OUT"; FAIL=$((FAIL + 1))
  fi
}

echo "=== validate-hooks.sh tests ==="

z="$(make_zip tax t1 "$(hooks_for tax calculate commit cancel checkConnectionHealth)" '{"domain":"tax","name":"T"}')"
run "$z"; expect "tax with all required hooks passes" 0 "Hook checks passed"

z="$(make_zip tax t2 "$(hooks_for tax calculate commit)" '{"domain":"tax"}')"
run "$z"; expect "tax missing cancel is an error" 1 'Missing required hook "sfcc.app.tax.cancel"'

z="$(make_zip tax t3 '[{"name":"sfcc.app.tax.calculate","script":"./hooks/calculate.js"},{"name":"sfcc.app.tax.commit","script":"./hooks/commit.js"},{"name":"sfcc.app.tax.cancel","script":"./hooks/cancel.js"},{"name":"dw.ocapi.shop.order.afterPOST","script":"./hooks/calculate.js"}]' '{"domain":"tax"}')"
run "$z"; expect "tax rejects non-sfcc.app hooks (strict allow-list)" 1 "Disallowed hook"

z="$(make_zip tax t4 "$(hooks_for tax calculate commit cancel)" '{"domain":"tax"}' 'exports.other = function () {};')"
run "$z"; expect "exported function name must match hook suffix" 1 'named "calculate"'

z="$(make_zip tax t5 "$(hooks_for tax calculate commit cancel)" '{"domain":"shipping"}')"
run "$z"; expect "commerce-app.json domain must match directory" 1 "does not match directory domain"

z="$(make_zip tax t6 "$(hooks_for tax calculate commit cancel)" '{"domain":"tax","name":"   "}')"
run "$z"; expect "blank commerce-app.json name rejected" 1 "is blank"

long="$(printf 'x%.0s' $(seq 1 300))"
z="$(make_zip tax t7 "$(hooks_for tax calculate commit cancel)" "{\"domain\":\"tax\",\"name\":\"$long\"}")"
run "$z"; expect "oversized commerce-app.json name rejected" 1 "exceeds 256 bytes"

z="$(make_zip tax t8 "$(hooks_for payment getClaimedPaymentMethods)" '{"domain":"tax"}')"
run "$z"; expect "hook for another domain is an error" 1 "is not in this app's domain"

z="$(make_zip tax t9 "$(hooks_for tax calculate commit cancel bogus)" '{"domain":"tax"}')"
run "$z"; expect "unknown hook in own domain is an error for tax" 1 'Unknown hook "sfcc.app.tax.bogus"'

echo "-- package.json hooks pointer"
z="$(make_zip tax k1 "$(hooks_for tax calculate commit cancel)" '{"domain":"tax"}')"
run "$z"; expect "package.json pointer to hooks.json passes" 0 "Hook checks passed"

z="$(PKG_HOOKS_PTR="" make_zip tax k2 "$(hooks_for tax calculate commit cancel)" '{"domain":"tax"}')"
run "$z"; expect "hooks.json present but no package.json pointer is an error" 1 "no site cartridge package.json has a"

z="$(PKG_HOOKS_PTR="./cartridge/wrong/hooks.json" make_zip tax k3 "$(hooks_for tax calculate commit cancel)" '{"domain":"tax"}')"
run "$z"; expect "package.json pointer to a missing file is an error" 1 "which does not exist"

z="$(PKG_HOOKS_PTR="../../outside/hooks.json" make_zip tax k4 "$(hooks_for tax calculate commit cancel)" '{"domain":"tax"}')"
run "$z"; expect "package.json pointer escaping the cartridge is an error" 1 "must be a path inside the cartridge"

echo "-- root manifest cross-check"
z="$(make_zip tax m1 "$(hooks_for tax calculate commit cancel)" '{"domain":"tax"}')"
run "$z"; expect "manifest entry matching directory domain passes" 0 "Hook checks passed"

z="$(make_zip tax m2 "$(hooks_for tax calculate commit cancel)" '{"domain":"tax"}')"
run "$z"; expect "manifest entry domain field differs from directory" 1 'has domain "shipping"'

z="$(make_zip shipping m3 "$(hooks_for shipping calculate quote)" '{"domain":"shipping"}')"
run "$z"; expect "same id listed under another domain key is flagged" 1 'lists "m3" under "tax"'

echo "-- shipping"
z="$(make_zip shipping s1 "$(hooks_for shipping calculate quote estimate)" '{"domain":"shipping"}')"
run "$z"; expect "shipping with calculate+quote+estimate passes" 0 "Hook checks passed"

z="$(make_zip shipping s2 "$(hooks_for shipping calculate)" '{"domain":"shipping"}')"
run "$z"; expect "shipping missing quote is an error" 1 '::error'
expect "shipping missing quote names the hook" 1 'sfcc.app.shipping.quote'

echo "-- payment"
z="$(make_zip payment p1 "$(hooks_for payment getClaimedPaymentMethods onAttemptOrderTransition reversePayment)" '{"domain":"payment"}')"
run "$z"; expect "payment with required hooks passes" 0 "Hook checks passed"

z="$(make_zip payment p2 "$(hooks_for payment getClaimedPaymentMethods)" '{"domain":"payment"}')"
run "$z"; expect "payment missing reversePayment is an error" 1 'sfcc.app.payment.reversePayment'

z="$(make_zip payment p3 "$(hooks_for payment getClaimedPaymentMethods onAttemptOrderTransition reversePayment)" '{"domain":"payment"}' 'exports.getClaimedPaymentMethods = function(){ return ["COMMERCE_APP_GIFT_CARD"]; }; exports.onAttemptOrderTransition=function(){}; exports.reversePayment=function(){};')"
run "$z"; expect "payment claiming COMMERCE_APP_GIFT_CARD is an error" 1 "COMMERCE_APP_GIFT_CARD"

z="$(make_zip payment p4 "$(hooks_for payment processor)" '{"domain":"payment"}')"
run "$z"; expect "legacy payment.processor hook name is unknown" 1 'Unknown hook "sfcc.app.payment.processor"'

z="$(make_zip payment acme-native "-" '{"domain":"payment"}')"
run "$z"; expect "third-party payment app without cartridges is an error" 1 "No hooks registered"

z="$(make_zip payment sf-native "-" '{"domain":"payment"}')"
run "$z"; expect "Salesforce-native payment app without cartridges is skipped" 0 "Salesforce-native"

echo "-- giftcard / fraud"
z="$(make_zip giftcard g1 "$(hooks_for giftcard getBalance capture refund)" '{"domain":"giftcard"}')"
run "$z"; expect "giftcard with getBalance+capture+refund passes" 0 "Hook checks passed"

z="$(make_zip giftcard g2 "$(hooks_for giftcard getBalance)" '{"domain":"giftcard"}')"
run "$z"; expect "giftcard missing capture is an error" 1 'sfcc.app.giftcard.capture'

z="$(make_zip fraud f1 "$(hooks_for fraud beforePayment)" '{"domain":"fraud"}')"
run "$z"; expect "fraud with only beforePayment passes" 0 "Hook checks passed"

z="$(make_zip fraud f2 "$(hooks_for fraud checkConnectionHealth)" '{"domain":"fraud"}')"
run "$z"; expect "fraud with neither hook is an error" 1 "at least one of"

z="$(make_zip fraud f3 "$(hooks_for fraud afterPayment)" '{"domain":"fraud"}' 'var OrderMgr = require("dw/order/OrderMgr"); exports.afterPayment = function(){};')"
run "$z"; expect "fraud afterPayment using OrderMgr is an error" 1 "uses OrderMgr"

echo "-- other domains"
z="$(make_zip analytics a1 "-" '{"domain":"analytics"}')"
run "$z"; expect "domains without hook rules are skipped" 0 "No hook rules"

echo "-- hooks that do not start with sfcc.app.* (warning only)"
pay="$(hooks_for payment getClaimedPaymentMethods onAttemptOrderTransition reversePayment)"
extra="$(jq -c '. + [
  {"name":"dw.ocapi.shop.basket.beforePOST","script":"./hooks/beforePOST.js"},
  {"name":"dw.ocapi.shop.basket.calculate","script":"./hooks/calculate.js"},
  {"name":"custom.integration.modifyResponse","script":"./hooks/modifyResponse.js"}
]' <<< "$pay")"
z="$(make_zip payment c1 "$extra" '{"domain":"payment"}')"
summary="$ROOT/step-summary.md"
: > "$summary"
export GITHUB_STEP_SUMMARY="$summary"
run "$z"
unset GITHUB_STEP_SUMMARY
expect "beforePOST is a warning and does not fail" 0 'Hook "dw.ocapi.shop.basket.beforePOST" is not an app-specific hook'
expect "calculate is a warning" 0 'Hook "dw.ocapi.shop.basket.calculate" is not an app-specific hook'
expect "custom hook is a warning" 0 'Hook "custom.integration.modifyResponse" is not an app-specific hook'
if [[ "$OUT" == *'Hook "sfcc.app.payment.'*' is not an app-specific hook'* ]]; then
  echo "  FAIL: an sfcc.app.payment hook was warned"; echo "    $OUT"; FAIL=$((FAIL + 1))
else
  echo "  PASS: sfcc.app.payment hooks were not warned"; PASS=$((PASS + 1))
fi
if grep -q '### Hook warnings' "$summary" && grep -q 'dw.ocapi.shop.basket.beforePOST' "$summary" && grep -q 'custom.integration.modifyResponse' "$summary"; then
  echo "  PASS: warnings are written to the job summary"; PASS=$((PASS + 1))
else
  echo "  FAIL: job summary missing hook warnings"; echo "    $(cat "$summary")"; FAIL=$((FAIL + 1))
fi

z="$(make_zip fraud f4 "$(hooks_for fraud beforePayment afterPayment)" '{"domain":"fraud"}')"
run "$z"; expect "sfcc.app beforePayment/afterPayment still pass" 0 "Hook checks passed"
if [[ "$OUT" == *"is not an app-specific hook"* ]]; then
  echo "  FAIL: domain hooks were warned"; echo "    $OUT"; FAIL=$((FAIL + 1))
else
  echo "  PASS: domain hooks were not warned"; PASS=$((PASS + 1))
fi

z="$(make_zip analytics a2 '[{"name":"dw.ocapi.shop.basket.items.beforePOST","script":"./hooks/beforePOST.js"}]' '{"domain":"analytics"}')"
run "$z"; expect "non-sfcc.app hook warns when the domain has no hook rules" 0 'Hook "dw.ocapi.shop.basket.items.beforePOST" is not an app-specific hook'

tax="$(hooks_for tax calculate commit cancel)"
tax_extra="$(jq -c '. + [{"name":"dw.ocapi.shop.order.afterPOST","script":"./hooks/afterPOST.js"}]' <<< "$tax")"
z="$(make_zip tax c3 "$tax_extra" '{"domain":"tax"}')"
run "$z"; expect "strict domain still errors on a non-sfcc.app hook" 1 "Disallowed hook"
expect "strict domain also warns" 1 'Hook "dw.ocapi.shop.order.afterPOST" is not an app-specific hook'

echo ""
echo "Passed: $PASS, Failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
