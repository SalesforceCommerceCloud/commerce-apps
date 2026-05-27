# Noibu Commerce App

Loads the Noibu session monitoring script on every storefront page and tracks ecommerce events via the Noibu SDK.

## Prerequisites

- Storefront Next storefront
- A Noibu account with an active site configured at [console.noibu.com](https://console.noibu.com)

## Installation

Install the app through the Checkout Hub in Business Manager. No additional configuration is required — the Noibu script is injected automatically on all storefront pages upon installation.

## Verification

After installation, complete the post-install checklist in the Checkout Hub:

1. **Verify script loads** — Open your storefront in a browser, inspect the page source or Network tab, and confirm `collect-core.js` is present in `<head>`.
2. **Confirm data in Noibu dashboard** — Log in to [console.noibu.com](https://console.noibu.com) and verify that session data is being received from your storefront.

## Tracked Events

| Event | Noibu event |
|---|---|
| Product viewed | `product_viewed` |
| Add to cart | `product_added_to_cart` |
| Search submitted | `search_submitted` |
| Category viewed | `collection_viewed` |
| Checkout started | `checkout_started` |
| Contact info submitted | `checkout_contact_info_submitted` |
| Shipping address submitted | `checkout_address_info_submitted` |
| Shipping method selected | `checkout_shipping_info_submitted` |
| Payment submitted | `payment_info_submitted` + `checkout_completed` |

## Support

For help, contact [support@noibu.com](mailto:support@noibu.com) or visit [noibu.com](https://noibu.com).
