# Tennis Legacy Commerce & Stripe Manual

Updated: 2026-09-30

## Live pricing

### Premium
- Tennis Legacy Premium: €3.29 per real-life month
- Monthly coin reward: 30 Coins after each successfully paid Premium invoice
- Stripe product: `prod_VM0R9k60mkKmkf`
- Stripe price: `price_1ULIQGRssJyCX9btqG7lkUM3`

### Coin packs
| Coins | EUR | Stripe price |
| ---: | ---: | --- |
| 70 | €2.99 | `price_1ULITFRssJyCX9btTujAaUhg` |
| 130 | €4.99 | `price_1ULITIRssJyCX9btAuacKVge` |
| 270 | €9.99 | `price_1ULITKRssJyCX9btZmEEOp1y` |
| 390 | €13.99 | `price_1ULITMRssJyCX9bttBpoZWYX` |
| 570 | €19.99 | `price_1ULITPRssJyCX9btPN42xOOk` |
| 900 | €29.99 | `price_1ULITSRssJyCX9bt50ZmQPFK` |

### Tennis Club
- Creation cost: 50 Coins
- Source of truth: `public.tennis_club_settings.creation_cost_coins`

## Source of truth

The website reads the live pricing catalog from `public.commerce_catalog_items` through
`public.get_commerce_catalog_v1()`.

Runtime Premium settings and the Stripe customer-portal login URL live in
`public.commerce_runtime_settings`.

Do not hard-code a different production price in the UI, webhook fulfillment, or Stripe.
When prices change, update all three layers together:
1. Stripe Product/Price + Payment Link
2. Supabase commerce catalog/runtime settings
3. UI fallback values and copy

## Checkout flow

The Pro Packages page opens Stripe-hosted Payment Links.

Before redirecting to Stripe, the website calls `public.create_commerce_checkout_intent_v1()`.
The backend creates a short-lived `commerce_checkout_intents` row tied to the authenticated user
and the exact catalog item being purchased.

The browser then appends:
- `client_reference_id=<server-issued checkout intent UUID>`
- `prefilled_email=<authenticated user's email>`

The webhook resolves that opaque checkout-intent ID back to the authenticated Tennis Legacy
account and validates that the Stripe product metadata, Coin quantity and amount match the
catalog item stored on the intent. The frontend never decides who receives Coins.

## Webhook

Production endpoint:

`https://cwfznmroiqcyhfkfcrow.supabase.co/functions/v1/stripe-tennis-webhook`

Stripe webhook endpoint:
`we_1ULIXXRssJyCX9btZWenY4eM`

Events:
- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `invoice.paid`
- `invoice.payment_failed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`

The webhook signing secret is stored privately in Supabase and is not exposed to the client.

## Fulfillment rules

### Coin packs
A coin pack is granted only when:
- Stripe metadata says `game=tennis_legacy`
- the `client_reference_id` maps to a valid server-issued checkout intent
- the intent maps to a real Auth user and the intended catalog item
- Checkout payment status is paid
- the amount and Coin quantity match that active catalog row

Fulfillment writes:
- `user_wallets`
- `coin_ledger`
- `billing_transactions`

Checkout Session IDs are unique in `billing_transactions`, making fulfillment idempotent.

### Premium
A completed Premium Checkout Session binds the Stripe customer/subscription to
`premium_memberships`.

The 30-Coin monthly reward is granted from a successfully paid €3.29 Premium invoice,
not merely from opening Checkout or creating a subscription.

Each paid Stripe invoice can create only one Premium billing transaction and one Coin grant.

Subscription updates/cancellations update the local Premium membership state.
Failed invoices mark the membership `past_due`.

## Customer self-service

Tennis Legacy uses a Stripe-hosted Customer Portal with:
- payment-method updates
- invoice history
- cancellation at period end
- cancellation-reason collection

The Manage Subscription button opens the hosted portal login page. Stripe emails the customer
a secure portal login link.

## Billing history

The Pro Packages page reads:
- `billing_transactions`
- `coin_ledger`
- `premium_memberships`

This keeps Premium invoices, Coin purchases, and wallet activity auditable and separate.

## Tax / legal configuration

The public EUR prices were created as tax-inclusive prices. Automatic Stripe Tax was not
silently enabled because tax registrations and the correct digital-product tax classification
are business/legal configuration and must match Next Quest Studio's actual obligations.

Before expanding sales into additional jurisdictions:
1. Review Stripe Tax registrations.
2. Confirm the exact Stripe tax code for Tennis Legacy Premium and virtual Coins.
3. Ensure Stripe public business information, Terms, Privacy Policy and refund policy are current.

## Operational checks

When changing pricing:
- verify Stripe price amount and interval
- verify Stripe Payment Link uses the intended price
- verify `commerce_catalog_items`
- verify Premium reward in `commerce_runtime_settings`
- verify Tennis Club cost
- verify the Pro Packages UI
- verify webhook endpoint is enabled
- make a test-mode purchase before making unrelated billing architecture changes

Never grant Coins from frontend state or from a redirect URL alone. Successful fulfillment must
come from a verified Stripe webhook.
