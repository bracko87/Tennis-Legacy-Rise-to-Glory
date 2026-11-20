-- H08 additional guest-expiry coverage discovered by explicit
-- secondary audit of authenticated, writable security-definer RPCs.
-- Account deletion, permanent linking, notification preferences, telemetry,
-- customer support and admin functions deliberately remain available.
DO $h08_more_guards$
DECLARE
  v_name text;
  v_oid oid;
  v_ddl text;
  v_count integer;
  v_pos integer;
  v_anchor text := E'\nbegin\n';
  v_guard text := E'  PERFORM public.assert_my_tennis_guest_access_v1();\n';
BEGIN
  FOREACH v_name IN ARRAY ARRAY[
    'approve_avatar_replacement_v1',
    'cancel_avatar_replacement_request_v1',
    'cancel_doubles_partner_invitation_v1',
    'cancel_private_life_asset_sale_v1',
    'confirm_avatar_reference_deleted_v1',
    'create_commerce_checkout_intent_v1',
    'list_private_life_asset_for_sale_v1',
    'mark_tennis_club_chat_read_v1',
    'request_avatar_replacement_revision_v1',
    'send_national_team_callup_v1',
    'send_national_team_friendly_invitation_v1',
    'set_private_life_home_base_v1',
    'set_private_life_tournament_travel_v1',
    'set_private_life_travel_preference_v1',
    'submit_avatar_replacement_request_v2',
    'touch_my_national_team_chat_v1'
  ] LOOP
    SELECT count(*),max(p.oid)::oid INTO v_count,v_oid
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid=p.pronamespace
      JOIN pg_language l ON l.oid=p.prolang
      WHERE n.nspname='public' AND p.proname=v_name
        AND p.prosecdef AND p.provolatile='v' AND l.lanname='plpgsql';
    IF v_count<>1 THEN
      RAISE EXCEPTION 'Unexpected signature for protected gameplay RPC: %',v_name;
    END IF;
    SELECT pg_get_functiondef(v_oid) INTO v_ddl;
    IF position(lower(v_guard) in lower(v_ddl))>0 THEN CONTINUE; END IF;
    v_pos:=position(v_anchor in lower(v_ddl));
    IF v_pos=0 THEN RAISE EXCEPTION 'Function BEGIN anchor missing: %',v_name; END IF;
    EXECUTE substr(v_ddl,1,v_pos+length(v_anchor)-1)
      ||v_guard||substr(v_ddl,v_pos+length(v_anchor));
  END LOOP;
END
$h08_more_guards$;
