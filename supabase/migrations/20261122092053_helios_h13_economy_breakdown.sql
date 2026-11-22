CREATE FUNCTION control_center_private.build_tennis_economy_v2(p_start date,p_end date) RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $function$
DECLARE
 v_today date := p_end;
 v_start date := p_start;
 v_start_ts timestamptz;
 v_end_ts timestamptz;
 v_coin jsonb;
 v_finance jsonb;
 v_billing jsonb;
 v_sponsors jsonb;
 v_wallet jsonb;
BEGIN
 IF p_start IS NULL OR p_end IS NULL OR p_start>p_end THEN RAISE EXCEPTION 'Invalid reporting dates' USING errcode='22023'; END IF;
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
  'paid_transactions',count(*) FILTER(WHERE status='paid' AND kind IN ('coin_pack_purchase','premium_invoice')),
  'paid_eur_cents',COALESCE(sum(amount_eur_cents) FILTER(WHERE status='paid' AND kind IN ('coin_pack_purchase','premium_invoice')),0),
  'paid_coin_packs',count(*) FILTER(WHERE status='paid' AND kind='coin_pack_purchase'),
  'paid_premium',count(*) FILTER(WHERE status='paid' AND kind='premium_invoice'),
  'pending_transactions',count(*) FILTER(WHERE status='pending'),
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
  'coin_sources',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.entry_type),'[]'::jsonb) FROM (SELECT entry_type,count(*) AS entries,coalesce(sum(amount) FILTER(WHERE amount>0),0) AS credits,coalesce(-sum(amount) FILTER(WHERE amount<0),0) AS debits FROM public.coin_ledger WHERE created_at>=v_start_ts AND created_at<v_end_ts GROUP BY entry_type) x),
  'birthday_rewards',(SELECT jsonb_build_object('awards',count(*),'coins_awarded',coalesce(sum(reward_amount),0)) FROM public.birthday_rewards WHERE awarded_at>=v_start_ts AND awarded_at<v_end_ts),
  'premium',jsonb_build_object(
    'active_paid_memberships',(SELECT count(*) FROM public.premium_memberships m JOIN auth.users u ON u.id=m.user_id AND u.deleted_at IS NULL WHERE m.plan_code='premium' AND m.status='active' AND m.stripe_subscription_id IS NOT NULL AND m.billing_amount_eur_cents>0 AND m.current_period_end>now()),
    'active_free_trials',(SELECT count(*) FROM public.tennis_premium_trials_v1 t JOIN auth.users u ON u.id=t.user_id AND u.deleted_at IS NULL WHERE NOT t.reserved_for_launch AND t.started_at<=now() AND t.expires_at>now()),
    'reserved_trials',(SELECT count(*) FROM public.tennis_premium_trials_v1 t JOIN auth.users u ON u.id=t.user_id AND u.deleted_at IS NULL WHERE t.reserved_for_launch),
    'expired_trials',(SELECT count(*) FROM public.tennis_premium_trials_v1 t JOIN auth.users u ON u.id=t.user_id AND u.deleted_at IS NULL WHERE NOT t.reserved_for_launch AND t.expires_at<=now()),
    'expiring_paid_memberships_7d',(SELECT count(*) FROM public.premium_memberships m JOIN auth.users u ON u.id=m.user_id AND u.deleted_at IS NULL WHERE m.plan_code='premium' AND m.status='active' AND m.stripe_subscription_id IS NOT NULL AND m.billing_amount_eur_cents>0 AND m.current_period_end>now() AND m.current_period_end<=now()+interval '7 days' AND m.cancel_at_period_end)
  ),
  'guest_integrity',jsonb_build_object(
    'guest_wallets',(SELECT count(*) FROM public.user_wallets w JOIN auth.users u ON u.id=w.user_id WHERE u.is_anonymous AND u.deleted_at IS NULL),
    'guest_nonzero_wallets',(SELECT count(*) FROM public.user_wallets w JOIN auth.users u ON u.id=w.user_id WHERE u.is_anonymous AND u.deleted_at IS NULL AND w.coins_balance<>0),
    'guest_coin_balance',(SELECT coalesce(sum(w.coins_balance),0) FROM public.user_wallets w JOIN auth.users u ON u.id=w.user_id WHERE u.is_anonymous AND u.deleted_at IS NULL),
    'positive_wallets_without_ledger',(SELECT count(*) FROM public.user_wallets w WHERE w.coins_balance>0 AND NOT EXISTS(SELECT 1 FROM public.coin_ledger l WHERE l.user_id=w.user_id))
  ),
  'career_by_current_account_type',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.account_type,x.currency),'[]'::jsonb) FROM (
    SELECT CASE WHEN u.is_anonymous THEN 'guest' WHEN u.is_anonymous IS FALSE THEN 'permanent' ELSE 'unlinked' END AS account_type,f.currency,count(*) AS careers,coalesce(sum(f.balance),0) AS balance,
    coalesce(sum(t.opening_funds),0) AS opening_funds,coalesce(sum(t.income),0) AS operational_income,coalesce(sum(t.expenses),0) AS operational_expenses
    FROM public.player_career_finance_accounts f JOIN public.players p ON p.id=f.player_id AND p.player_type='human' LEFT JOIN auth.users u ON u.id=p.owner_user_id AND u.deleted_at IS NULL
    LEFT JOIN LATERAL (SELECT sum(amount) FILTER(WHERE category='career' AND subcategory='opening_balance') AS opening_funds,sum(amount) FILTER(WHERE amount>0 AND NOT(category='career' AND subcategory='opening_balance')) AS income,-sum(amount) FILTER(WHERE amount<0) AS expenses FROM public.career_finance_transactions WHERE player_id=p.id AND created_at>=v_start_ts AND created_at<v_end_ts) t ON true
    GROUP BY 1,2) x),
  'billing_notes','Paid purchase and invoice totals are gross recorded amounts by transaction creation date, not Stripe payout or settlement time. Free trials are not revenue. Refund records require separate reconciliation.',
  'definition','Period totals use retained transaction records. Wallets, Premium and current career balances are snapshots. Career categories reflect current account status, not event-time status. Ledger discrepancies are investigation signals, not confirmed fraud.'
 );
END;
$function$;

REVOKE ALL ON FUNCTION control_center_private.build_tennis_economy_v2(date,date) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.get_admin_tennis_economy_v1(p_days integer DEFAULT 30) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $admin$
DECLARE v_days integer:=coalesce(p_days,30); v_end date:=(now() AT TIME ZONE 'Europe/Berlin')::date;
BEGIN
 IF NOT public.is_app_admin_v1(auth.uid()) THEN RAISE EXCEPTION 'Administrator access required' USING errcode='42501'; END IF;
 IF v_days NOT IN (0,7,30,90,365) THEN RAISE EXCEPTION 'Unsupported analytics period' USING errcode='22023'; END IF;
 RETURN control_center_private.build_tennis_economy_v2(CASE WHEN v_days=0 THEN date '2000-01-01' ELSE v_end-v_days+1 END,v_end);
END;
$admin$;
REVOKE ALL ON FUNCTION public.get_admin_tennis_economy_v1(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_admin_tennis_economy_v1(integer) TO authenticated;
