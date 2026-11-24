# SFNext Appointment Scheduling (Salesforce Scheduler)

Backend-only Commerce App that lets a Storefront Next storefront book **boutique / store appointments** against **Salesforce Scheduler** on a separate Core Salesforce org.

## Architecture

- **Custom SCAPI** (`/custom/sfnext-appointment/v1/appointment-availability`, `/appointments`) served by this app's site cartridge.
- The cartridge reaches the Core org's **Data API** (`sobjects/ServiceTerritory`, `sobjects/ServiceAppointment`, `sobjects/AssignedResource`) and **Connect REST** (`available-territory-slots`) through the B2C **Service Framework** using OAuth **client-credentials**. The Core credential lives on the B2C instance (Service Framework), never in storefront env.
- Shopper correlation is `ServiceAppointment.b2cCustomerId__c` — **no Core Contact**. Confirmation emails are sent by a Core-side record-triggered Flow.
- **Provider only** — the booking UX is intentionally NOT in this CAP; it is vertical-specific. Luxury uses the `boutique-appointment` wizard; other verticals can build their own slot picker on top of the same endpoints. Shipping one UI here would force all verticals to use the same "boutique" experience.

## Storefront integration

The storefront template components that call these endpoints are in the luxury vertical overlay:

- `resource.appointment-availability.ts` — fetches available slots
- `resource.appointment-book.ts` — submits the booking

**Required:** Storefront Next W-24664601 or later.

## Capacity model

Boutique appointments use a **person ServiceResource** → an intrinsic **hard cap of one appointment per advisor per slot**.

## Install (private)

`b2c cap validate <this dir>` then `b2c cap install <this dir> --site-id <SITE>`, then complete the steps in `app-configuration/tasksList.json`.

> **Upgrade note — services.xml:** Re-importing `services.xml` during an upgrade resets the `scheduler.core.token.credential` URL and client id to their install-time placeholders. Skip the services impex on upgrades and reconfigure the credential in Business Manager only when initially installing.

## Prerequisites (Core org, one-time)

A provisioned Salesforce Scheduler Core org: ServiceTerritory + WorkType/WorkTypeGroup + OperatingHours, a person ServiceResource, the `b2cCustomerId__c` field, the confirmation Flow + verified Org-Wide Email Address, an External Client App (client-credentials) + integration user with the Scheduler PSL. See the HLD (W-24428182).
