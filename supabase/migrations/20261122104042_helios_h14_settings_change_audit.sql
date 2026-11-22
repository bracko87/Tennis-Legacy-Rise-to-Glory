CREATE TABLE control_center_private.tennis_settings_audit_v1 (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 category text NOT NULL CHECK(category IN ('admin','premium')),
 event_type text NOT NULL,
 target text NOT NULL,
 actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 summary text NOT NULL,
 old_values jsonb NOT NULL,
 new_values jsonb NOT NULL
);
ALTER TABLE control_center_private.tennis_settings_audit_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON control_center_private.tennis_settings_audit_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE INDEX tennis_settings_audit_time_idx ON control_center_private.tennis_settings_audit_v1(occurred_at DESC);
CREATE FUNCTION control_center_private.record_tennis_settings_change_v1() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $audit$
DECLARE a jsonb; b jsonb; k text; cat text:='admin'; target_name text; actor uuid; changed text;
BEGIN
 IF TG_TABLE_SCHEMA<>'public' THEN RAISE EXCEPTION 'Unexpected audit source'; END IF;
 IF TG_TABLE_NAME='registration_control' THEN
  a:=jsonb_build_object('public_signup_enabled',OLD.public_signup_enabled,'google_oauth_enabled',OLD.google_oauth_enabled,'guest_test_enabled',OLD.guest_test_enabled);
  b:=jsonb_build_object('public_signup_enabled',NEW.public_signup_enabled,'google_oauth_enabled',NEW.google_oauth_enabled,'guest_test_enabled',NEW.guest_test_enabled);
  k:='registration_settings_changed';target_name:='registration_control';
 ELSIF TG_TABLE_NAME='game_clock' THEN
  a:=jsonb_build_object('is_paused',OLD.is_paused,'speed_multiplier',OLD.speed_multiplier);
  b:=jsonb_build_object('is_paused',NEW.is_paused,'speed_multiplier',NEW.speed_multiplier);
  k:='game_clock_settings_changed';target_name:='game_clock';
 ELSIF TG_TABLE_NAME='premium_memberships' THEN
  -- No account identifiers or payment identifiers are persisted for membership changes.
  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=NEW.user_id AND NOT u.is_anonymous AND u.deleted_at IS NULL) THEN RETURN NEW; END IF;
  a:=jsonb_build_object('plan',OLD.plan_code,'status',OLD.status,'cancel_at_period_end',OLD.cancel_at_period_end,'period_end',OLD.current_period_end);
  b:=jsonb_build_object('plan',NEW.plan_code,'status',NEW.status,'cancel_at_period_end',NEW.cancel_at_period_end,'period_end',NEW.current_period_end);
  IF OLD.plan_code='free' AND NEW.plan_code='free' THEN RETURN NEW; END IF;
  k:='premium_membership_changed';cat:='premium';target_name:='premium_memberships';
 ELSE RAISE EXCEPTION 'Unexpected audit table'; END IF;
 IF a IS NOT DISTINCT FROM b THEN RETURN NEW; END IF;
 SELECT string_agg(key||': '||coalesce(a->>key,'null')||' → '||coalesce(b->>key,'null'),'; ' ORDER BY key) INTO changed FROM jsonb_object_keys(b) AS keys(key) WHERE a->key IS DISTINCT FROM b->key;
 IF cat='admin' AND public.is_app_admin_v1(auth.uid()) THEN actor:=auth.uid(); END IF;
 INSERT INTO control_center_private.tennis_settings_audit_v1(category,event_type,target,actor_id,summary,old_values,new_values) VALUES(cat,k,target_name,actor,changed,a,b);
 RETURN NEW;
END;
$audit$;
REVOKE ALL ON FUNCTION control_center_private.record_tennis_settings_change_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER tennis_registration_settings_audit_v1 AFTER UPDATE OF public_signup_enabled,google_oauth_enabled,guest_test_enabled ON public.registration_control FOR EACH ROW EXECUTE FUNCTION control_center_private.record_tennis_settings_change_v1();
CREATE TRIGGER tennis_game_clock_settings_audit_v1 AFTER UPDATE OF is_paused,speed_multiplier ON public.game_clock FOR EACH ROW EXECUTE FUNCTION control_center_private.record_tennis_settings_change_v1();
CREATE TRIGGER tennis_premium_settings_audit_v1 AFTER UPDATE OF plan_code,status,cancel_at_period_end,current_period_end ON public.premium_memberships FOR EACH ROW EXECUTE FUNCTION control_center_private.record_tennis_settings_change_v1();
CREATE OR REPLACE FUNCTION public.get_admin_tennis_event_history_v1(p_days integer DEFAULT 30, p_category text DEFAULT 'all'::text, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 25, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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
  IF v_cat NOT IN ('all','system','admin','coins','billing','career','training','tournament','staff','sponsor','account','premium') THEN
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
    UNION ALL
    SELECT 'account','permanent_registration','registration:'||u.id::text,u.id::text,u.id::text,
      u.created_at,'Permanent account registered','registered'
    FROM auth.users u WHERE NOT u.is_anonymous AND u.deleted_at IS NULL
      AND NOT EXISTS(SELECT 1 FROM control_center_private.tennis_guest_trials_v1 g WHERE g.user_id=u.id)
      AND u.created_at>=v_start AND u.created_at<v_end AND v_cat IN ('all','account')
    UNION ALL
    SELECT 'account',e.kind,e.kind||':'||g.user_id::text,g.user_id::text,g.user_id::text,e.at,e.summary,e.status
    FROM control_center_private.tennis_guest_trials_v1 g JOIN auth.users u ON u.id=g.user_id AND u.deleted_at IS NULL
    CROSS JOIN LATERAL (VALUES ('guest_started',g.started_at,'Guest trial started','started'),('guest_converted',g.converted_at,'Guest converted to permanent account','converted'),('guest_retired',g.retired_at,'Guest account retired','retired')) e(kind,at,summary,status)
    WHERE e.at>=v_start AND e.at<v_end AND v_cat IN ('all','account')
    UNION ALL
    SELECT 'account','guest_erasure_daily','guest_erasure:'||d.analytics_date::text,NULL,NULL,
      d.analytics_date::timestamp AT TIME ZONE 'Europe/Berlin',
      'Expired guest accounts erased (daily aggregate): '||d.erased_trials::text,'aggregate'
    FROM control_center_private.tennis_guest_erased_daily_v1 d WHERE d.erased_trials>0
    AND d.analytics_date >= (v_start AT TIME ZONE 'Europe/Berlin')::date AND d.analytics_date < (v_end AT TIME ZONE 'Europe/Berlin')::date AND v_cat IN ('all','account')
    UNION ALL
    SELECT 'premium',e.kind,e.kind||':'||t.user_id::text,t.user_id::text,t.user_id::text,e.at,e.summary,e.status
    FROM public.tennis_premium_trials_v1 t JOIN auth.users u ON u.id=t.user_id AND u.deleted_at IS NULL
    CROSS JOIN LATERAL (VALUES ('trial_started',t.started_at,'Free Premium trial started','started'),('trial_expired',t.expires_at,'Free Premium trial expired','expired')) e(kind,at,summary,status)
    WHERE NOT t.reserved_for_launch AND e.at<=now() AND e.at>=v_start AND e.at<v_end AND v_cat IN ('all','premium')
    UNION ALL
    SELECT 'premium','membership_latest_state','membership:'||m.user_id::text,m.user_id::text,m.user_id::text,
      m.updated_at,'Premium membership latest recorded state',m.status
    FROM public.premium_memberships m JOIN auth.users u ON u.id=m.user_id AND u.deleted_at IS NULL
    WHERE m.plan_code='premium' AND m.updated_at>=v_start AND m.updated_at<v_end AND v_cat IN ('all','premium')
    UNION ALL
    SELECT a.category,a.event_type,a.id::text,a.target,a.actor_id::text,a.occurred_at,
      left(a.summary,120),'changed'
    FROM control_center_private.tennis_settings_audit_v1 a
    WHERE a.occurred_at>=v_start AND a.occurred_at<v_end AND (v_cat='all' OR v_cat=a.category)
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
    'definition','Admin-only history of selected retained source records. Account lifecycle timestamps and Premium trial dates are included; membership latest state is not a full change log. Guest erasure totals are daily aggregates, not individual events. Other source changes and deletions may not be captured. No raw user emails, payment tokens, or sensitive details are returned.',
    'retention','Uses retention of source tables; no new retention or deletion policy is created by this view.'
  ) INTO v_result;

  RETURN v_result;
END;
$function$;
