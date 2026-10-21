# Tennis Legacy — Refunded referral purchase Coins (2026-10-21)

## Status
- **Implemented in source on `main`; NOT deployed to Supabase or Stripe.**
- The change is in `supabase/migrations/20261021090000_referral_purchase_refund_recovery_v1.sql`.
- The rollback-only integration regression is in `tests/referral_purchase_refund_rollback_smoke.sql`. The regression passed with the migration included in the **same rolled-back transaction**, against the actual database schema. All tables/functions/triggers/test entries were rolled back. Production remains unchanged.
- Netlify builds remain stopped, in accordance with `AGENTS.md` and `docs/RELEASE_PROCESS.md`.

## Rules preserved
- The current configured referral awards remain **3 Coins per validated referral**, **15 Coins after the first confirmed paid Coin-pack purchase**, and **30 Coins after the first confirmed paid Premium invoice**. Rewards are paid to the referrer, not the buyer, and once per referral + reward type.
- Refunded purchases are **not eligible for retained purchase-referral rewards**. When a *confirmed full refund* is recorded against the original paid billing transaction, the original reward is reversed exactly once. **Partial refunds** do not reverse the referral payout until the purchase is fully refunded.
- A later separate purchase does **not** re-award the same one-time reward type; that preserves the existing “first purchase only” configuration. This rule should be reviewed with product before changing it.
- Refund processing never awards Coins and never requires the user’s browser.

## Mechanism
1. The existing `stripe-tennis-webhook` Edge Function verifies the Stripe HMAC signature and 5-minute timestamp window, then invokes the backend `process_tennis_stripe_webhook_v1` RPC under service role.
2. The new `try_process_tennis_stripe_event_v3` delegates old event types to the original v2 processor; adds **`charge.refunded`** handling and **`invoice_payment.paid`** invoice↔PaymentIntent association. Invoice events that include a PaymentIntent also populate that association.
3. A `charge.refunded` event must be a **fully refunded EUR charge** with a unique verified payment-to-billing match by PaymentIntent or invoice. Ambiguous/unmatched refunds remain in the Stripe event inbox for investigation/retry; **no approximate matching by customer/amount alone**. Duplicate Stripe event IDs and duplicate refund records are idempotent.
4. Updating the original paid `billing_transactions` row to `refunded` triggers a one-time `referral_reward_reversals` record for any associated 15/30-Coin reward. The original `referral_rewards` row stays intact for audit; a unique original-reward constraint prevents multiple reversals.
5. Available referrer Coins are deducted immediately, with **negative `referral_reward` Coin-ledger entries**, never below a zero balance. If Coins have been spent, a pending recovery balance is recorded and recovered automatically **after subsequent positive Coin ledger credits**, with exact balance-after ordering.
6. The Invite Friends `get_referral_dashboard_v1` shows refunded rewards as reversed, provides outstanding recovery totals, and calculates **net** earned referral Coins. The existing admin dashboard includes payout/linked bill/recipient/referred user/refund/recovery fields for each recent referral. A non-API `referral_purchase_refund_audit_v1` view supports privileged investigations.
7. Functions and tables have NO direct anonymous/authenticated mutation permissions beyond the existing server-owned processing path. No new client-side payout capability.

## What was tested — full transaction ROLLBACK
- Pending, failed, cancelled: no reward.
- First eligible paid Coin pack: 15 Coins; first paid Premium invoice: 30 Coins, correct recipient/ledger.
- Subsequent purchases and repeated processing: no duplicate award.
- Partial charge refund: no premature reversal.
- Fully refunded Coin charge: billing becomes refunded; precisely one reversal and -15 ledger entry.
- Replay of identical webhook and new webhook for same refunded payment: no duplicate reversal.
- Premium invoice lacks initial PaymentIntent; signed invoice-payment event adds association; full charge refund reverses 30.
- Spent reward: pending recovery of 30, then earnings +7 and +23 recover in two ledger entries without negative wallet or corrupted credit balance-after.
- Invite Friends net and reward-status flags, admin recovery summary (if an admin fixture is available).
- The test always ends with ROLLBACK; verified no reward records or altered referral status remained.

## Release gate and remaining external checks
- **Owner must explicitly authorize the production Supabase migration.** Do not apply automatically from GitHub.
- Review migration against most recent Supabase schema; use staging/test database if available. Running full DDL inside an uncommitted production transaction can briefly take locks; prefer nonproduction for repeated runs.
- The Stripe webhook endpoint must be subscribed to **`charge.refunded`** and **`invoice_payment.paid`** (or invoices must expose a trusted invoice↔PaymentIntent mapping). This has **not been verified/modified** in Stripe.
- Validate real Stripe test-mode checkout → signed webhook → first payout → full refund → duplicate webhook → recovery, including an invoice-subscription case. **No real payment or Stripe end-to-end HTTP delivery has been tested**.
- Confirm the original purchase’s own coins/benefits are handled by the separate existing refund policy; this ticket changes the **referrer reward only**.
- Test signed-in browser wallet, Coin ledger and Invite Friends after a deliberately authorized test-environment deployment. Normal builds/CI still require `npm run check:pt`, `npm run check:preferences`, `npm run check:seo`, `npm run build`.
