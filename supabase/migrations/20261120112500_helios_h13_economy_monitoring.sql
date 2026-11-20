-- Project Helios H13 — read-only finance, coin, Premium and sponsor monitoring.
-- All financial values are derived from settled database rows, not checkout attempts.
-- Never expose user IDs, invoice identifiers or personal financial details.
CREATE OR REPLACE FUNCTION public.get_admin_tennis_economy_v1(p_days integer DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','auth','pg_temp'
AS $economy$
DECLARE
 v_days integer := coalesce(p_days,30);
 v_today date := (now() AT TIME ZONE 'Europe/Berlin')::date;
 v_start date;
 v_start_ts timestamptz;
 v_end_ts timestamptz;
 v_coin jsonb;
 v_finance jsonb;
 v_billing jsonb;
 v_sponsors jsonb;
 v_wallet jsonb;
BEGIN
 IF NOT public.is_app_admin_v1(auth.uid()) THEN
   RAISE EXCEPTION 'Administrator access required' USING errcode='42501';
 END IF;
 IF v_days NOT IN (0,7,30,90,365) THEN
   RAISE EXCEPTION 'Unsupported analytics period' USING errcode='22023';
 END IF;
 v_start := CASE WHEN v_days=0 THEN DATE '2000-01-01' ELSE v_today-v_days+1 END;
 v_start_ts := v_start::timestamp AT TIME ZONE 'Europe/Berlin';
 v_end_ts := (v_today+1)::timestamp AT TIME ZONE 'Europe/Berlin';

 SELECT jsonb_build_object(
  'credits',COALESCE(sum(amount) FILTER (WHERE amount>0),0),
  'debits',COALESCE(-sum(amount) FILTER (WHERE amount<0),0),
  'entries',count(*),
  'signup_grants',COALESCE(sum(amount) FILTER (WHERE entry_type='signup_reward'),0),
  'other_credits',COALESCE(sum(amount) FILTER (WHERE amount>0 AND entry_type<>'signup_reward'),0)
 ) INTO v_coin FROM public.coin_ledger
 WHERE created_at>=v_start_ts AND created_at<v_end_ts;

 SELECT jsonb_build_object(
  'opening_funds',COALESCE(sum(t.amount) FILTER (WHERE t.category='career' AND t.subcategory='opening_balance'),0),
  'operational_income',COALESCE(sum(t.amount) FILTER (WHERE t.amount>0 AND NOT (t.category='career' AND t.subcategory='opening_balance')),0),
  'operational_expenses',COALESCE(-sum(t.amount) FILTER (WHERE t.amount<0),0),
  'transaction_entries',count(*),
  'sponsor_related_entries',count(*) FILTER (WHERE t.category ILIKE '%sponsor%' OR t.subcategory ILIKE '%sponsor%'),
  'sponsor_related_net',COALESCE(sum(t.amount) FILTER (WHERE t.category ILIKE '%sponsor%' OR t.subcategory ILIKE '%sponsor%'),0)
 ) INTO v_finance
 FROM public.career_finance_transactions t
 JOIN public.players p ON p.id=t.player_id AND p.player_type='human'
 WHERE t.created_at>=v_start_ts AND t.created_at<v_end_ts;

 SELECT jsonb_build_object(
  'paid_transactions',count(*) FILTER(WHERE status='paid'),
  'paid_eur_cents',COALESCE(sum(amount_eur_cents) FILTER(WHERE status='paid'),0),
  'paid_coin_packs',count(*) FILTER(WHERE status='paid' AND kind ILIKE '%coin%'),
  'paid_premium',count(*) FILTER(WHERE status='paid' AND kind ILIKE '%premium%'),
  'pending_transactions',count(*) FILTER(WHERE status NOT IN('paid','failed','canceled','cancelled')),
  'failed_transactions',count(*) FILTER(WHERE status='failed')
 ) INTO v_billing FROM public.billing_transactions
 WHERE created_at>=v_start_ts AND created_at<v_end_ts;

 SELECT jsonb_build_object(
  'sponsor_contracts_signed',count(*),
  'active_sponsor_contracts_now', (SELECT count(*) FROM public.player_sponsor_contracts c
                                   JOIN public.players p ON p.id=c.player_id AND p.player_type='human'
                                   WHERE c.status='active'),
  'objective_rewards_recorded',(SELECT count(*) FROM public.player_sponsor_objectives o
                                   JOIN public.players p ON p.id=o.player_id AND p.player_type='human'
                                   WHERE o.payout_transaction_id IS NOT NULL
                                     AND o.updated_at>=v_start_ts AND o.updated_at<v_end_ts)
 ) INTO v_sponsors FROM public.player_sponsor_contracts c
 JOIN public.players p ON p.id=c.player_id AND p.player_type='human'
 WHERE c.created_at>=v_start_ts AND c.created_at<v_end_ts;

 SELECT jsonb_build_object(
  'wallet_count',count(*),
  'wallet_coin_balance',COALESCE(sum(coins_balance),0),
  'wallet_negative_balances',count(*) FILTER(WHERE coins_balance<0),
  'wallet_vs_latest_ledger_discrepancies',(
     SELECT count(*) FROM public.user_wallets w
     JOIN LATERAL (SELECT l.balance_after FROM public.coin_ledger l
         WHERE l.user_id=w.user_id ORDER BY l.created_at DESC,l.id DESC LIMIT 1) last_ledger ON true
     WHERE w.coins_balance IS DISTINCT FROM last_ledger.balance_after
  ),
  'human_career_balances',(
      SELECT COALESCE(sum(f.balance),0) FROM public.player_career_finance_accounts f
      JOIN public.players p ON p.id=f.player_id AND p.player_type='human'
  )
 ) INTO v_wallet FROM public.user_wallets;

 RETURN jsonb_build_object(
  'generated_at',now(),
  'timezone','Europe/Berlin',
  'start_date',v_start,
  'end_date',v_today,
  'coin_movements',v_coin,
  'career_finance',v_finance,
  'billing',v_billing,
  'sponsorships',v_sponsors,
  'current_balances',v_wallet,
  'definition','Period totals use actual recorded transactions. Paid revenue includes only billing status paid, not free Premium or starting funds. Wallet and active-contract snapshots are current, independent of selected period; ledger discrepancies are investigation signals, not confirmed fraud.'
 );
END;
$economy$;
REVOKE ALL ON FUNCTION public.get_admin_tennis_economy_v1(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_admin_tennis_economy_v1(integer) TO authenticated;
