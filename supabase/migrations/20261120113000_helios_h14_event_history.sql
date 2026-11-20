-- Helios H14: searchable, read-only unified history from authoritative existing tables.
-- This is a searchable historical index, NOT a claim that all edits or deletions
-- are already audited. No raw payment tokens, emails, private JSON or IP data.
-- Access is guarded server-side by is_app_admin_v1().
CREATE OR REPLACE FUNCTION public.get_admin_tennis_event_history_v1(
  p_days integer DEFAULT 30,
  p_category text DEFAULT 'all',
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 25,
  p_offset integer DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  v_today date := (now() AT TIME ZONE 'Europe/Berlin')::date;
  v_start timestamptz;
  v_end timestamptz := ((now() AT TIME ZONE 'Europe/Berlin')::date + 1)::timestamp AT TIME ZONE 'Europe/Berlin';
  v_days integer := coalesce(p_days,30);
  v_cat text := lower(coalesce(nullif(trim(p_category),''),'all'));
  v_search text := nullif(left(trim(coalesce(p_search,'')),80),'');
  v_limit integer := greatest(1,least(coalesce(p_limit,25),50));
  v_offset integer := greatest(0,least(coalesce(p_offset,0),5000));
  v_result jsonb;
BEGIN
  IF NOT public.is_app_admin_v1(auth.uid()) THEN
    RAISE EXCEPTION 'Administrator access required' USING errcode='42501';
  END IF;
  IF v_days NOT IN (0,7,30,90,365) THEN
    RAISE EXCEPTION 'Unsupported reporting period' USING errcode='22023';
  END IF;
  IF v_cat NOT IN ('all','system','admin','coins','billing','career','training','tournament','staff','sponsor') THEN
    RAISE EXCEPTION 'Unsupported event category' USING errcode='22023';
  END IF;
  v_start := (CASE WHEN v_days=0 THEN date '2000-01-01' ELSE v_today-v_days+1 END)::timestamp AT TIME ZONE 'Europe/Berlin';

  WITH events AS (
    SELECT 'system'::text category,'system_incident'::text event_type,
      i.id::text event_id,i.id::text entity_id,NULL::text subject_id,
      i.created_at occurred_at, left(coalesce(i.title,'System incident'),120)::text summary,
      coalesce(i.severity,'unknown')::text status
      FROM public.system_incidents i WHERE i.created_at>=v_start AND i.created_at<v_end
      AND v_cat IN ('all','system')
    UNION ALL
    SELECT 'admin','referral_admin_action',a.id::text,a.target_id,a.admin_user_id::text,
      a.created_at,left(coalesce(a.action,'Admin action') || ' · ' || coalesce(a.target_type,'record'),120),
      'recorded'::text
      FROM public.referral_admin_audit a WHERE a.created_at>=v_start AND a.created_at<v_end
      AND v_cat IN ('all','admin')
    UNION ALL
    SELECT 'coins','coin_ledger',l.id::text,l.id::text,l.user_id::text,
      l.created_at,left(coalesce(l.entry_type,'Coin movement') || ' · ' || l.amount::text || ' coins',120),
      case when l.amount<0 then 'debit' else 'credit' end
      FROM public.coin_ledger l WHERE l.created_at>=v_start AND l.created_at<v_end
      AND v_cat IN ('all','coins')
    UNION ALL
    SELECT 'billing','billing_transaction',b.id::text,b.id::text,b.user_id::text,
      b.created_at,left(coalesce(b.kind,'Billing') || ' · ' || coalesce(b.amount_eur_cents,0)::text || ' EUR cents',120),
      coalesce(b.status,'unknown')::text
      FROM public.billing_transactions b WHERE b.created_at>=v_start AND b.created_at<v_end
      AND v_cat IN ('all','billing')
    UNION ALL
    SELECT 'career','career_transaction',f.id::text,f.id::text,f.player_id::text,
      f.created_at,left(coalesce(f.category,'Career') || ' · ' || f.amount::text || ' game dollars',120),
      coalesce(f.subcategory,'recorded')::text
      FROM public.career_finance_transactions f
      JOIN public.players p ON p.id=f.player_id AND p.player_type='human'
      WHERE f.created_at>=v_start AND f.created_at<v_end
      AND v_cat IN ('all','career')
    UNION ALL
    SELECT 'training','training_session',t.id::text,t.id::text,t.player_id::text,
      t.created_at,left(coalesce(t.training_type,'Training') || ' · ' || coalesce(t.focus_attribute,'general'),120),
      'recorded'::text
      FROM public.player_training_sessions t JOIN public.players p ON p.id=t.player_id AND p.player_type='human'
      WHERE t.created_at>=v_start AND t.created_at<v_end
      AND v_cat IN ('all','training')
    UNION ALL
    SELECT 'tournament','tournament_application',a.id::text,a.competition_id::text,a.player_id::text,
      a.created_at,left('Tournament application · ' || coalesce(a.world,'tennis'),120),
      coalesce(a.status,'unknown')::text
      FROM public.tournament_applications a JOIN public.players p ON p.id=a.player_id AND p.player_type='human'
      WHERE a.created_at>=v_start AND a.created_at<v_end
      AND v_cat IN ('all','tournament')
    UNION ALL
    SELECT 'staff','staff_contract',s.id::text,s.id::text,s.player_id::text,
      s.created_at,left('Staff contract · ' || coalesce(s.role,'staff'),120),
      coalesce(s.status,'unknown')::text
      FROM public.player_staff_contracts s JOIN public.players p ON p.id=s.player_id AND p.player_type='human'
      WHERE s.created_at>=v_start AND s.created_at<v_end
      AND v_cat IN ('all','staff')
    UNION ALL
    SELECT 'sponsor','sponsor_contract',s.id::text,s.id::text,s.player_id::text,
      s.created_at,'Sponsorship contract'::text,
      coalesce(s.status,'unknown')::text
      FROM public.player_sponsor_contracts s JOIN public.players p ON p.id=s.player_id AND p.player_type='human'
      WHERE s.created_at>=v_start AND s.created_at<v_end
      AND v_cat IN ('all','sponsor')
  ), filtered AS (
    SELECT * FROM events e
    WHERE v_search IS NULL
      OR e.event_id ILIKE '%'||v_search||'%'
      OR coalesce(e.entity_id,'') ILIKE '%'||v_search||'%'
      OR coalesce(e.subject_id,'') ILIKE '%'||v_search||'%'
      OR e.event_type ILIKE '%'||v_search||'%'
      OR e.summary ILIKE '%'||v_search||'%'
      OR e.status ILIKE '%'||v_search||'%'
  )
  SELECT jsonb_build_object(
    'generated_at',now(),
    'start_date', (v_start AT TIME ZONE 'Europe/Berlin')::date,
    'end_date',v_today,
    'category',v_cat,
    'search',coalesce(v_search,''),
    'total', (SELECT count(*) FROM filtered),
    'limit',v_limit,
    'offset',v_offset,
    'events',coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id',q.category||':'||q.event_id,
        'category',q.category,
        'type',q.event_type,
        'entity_id',q.entity_id,
        'subject_id',q.subject_id,
        'occurred_at',q.occurred_at,
        'summary',q.summary,
        'status',q.status
      ) ORDER BY q.occurred_at DESC,q.category,q.event_id)
      FROM (SELECT * FROM filtered ORDER BY occurred_at DESC,category,event_id LIMIT v_limit OFFSET v_offset) q
    ),'[]'::jsonb),
    'definition','Admin-only history of selected source records, not an exhaustive or immutable change log. Creation timestamps represent recorded events; updates and deletions may not be captured. No raw user emails, payment tokens, or sensitive details are returned.',
    'retention','Uses retention of source tables; no new retention or deletion policy is created by this view.'
  ) INTO v_result;

  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_admin_tennis_event_history_v1(integer,text,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_admin_tennis_event_history_v1(integer,text,text,integer,integer) TO authenticated;
