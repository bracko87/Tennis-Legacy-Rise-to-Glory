-- Premium Player Development Intelligence, slice 1: skill-history timeline.
-- This is read-only. Never change the existing Free Skills screen or history RLS.
-- Historical snapshots are already stored in player_skill_history.
-- Raw Free history stays accessible as before; only this derived Premium report
-- is entitlement gated. Trials use the same has_active_premium_v1() rules.
create or replace function public.get_premium_player_development_v1(p_player_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_count integer;
  v_history jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required for Player Development Intelligence'
      using errcode='42501';
  end if;
  if not public.has_active_premium_v1() then
    raise exception 'Premium membership required for Player Development Intelligence'
      using errcode='42501';
  end if;
  -- Always validate the specific active player supplied by the client.
  if p_player_id is null or not exists (
    select 1 from public.players p
    where p.id=p_player_id and p.owner_user_id=v_uid
  ) then
    raise exception 'Player development report unavailable for this career'
      using errcode='42501';
  end if;

  select count(*)::integer into v_count
  from public.player_skill_history
  where player_id=p_player_id;

  -- Return the latest 240 snapshots in chronological order, not 240 oldest.
  -- Labels in UI must disclose truncation, and never represent a cropped
  -- window as the player's entire career.
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'recorded_at',h.recorded_at,
      'source',h.source,
      'serve',h.serve,'forehand',h.forehand,'backhand',h.backhand,
      'return_skill',h.return_skill,'volley',h.volley,'slice',h.slice,
      'drop_shot',h.drop_shot,'lob',h.lob,'smash',h.smash,
      'fitness',h.fitness,'stamina',h.stamina,'recovery',h.recovery,
      'movement',h.movement,
      'fatigue',h.fatigue,'sharpness',h.sharpness,'morale',h.morale,
      'confidence',h.confidence,'focus',h.focus
    ) order by h.recorded_at,h.id
  ),'[]'::jsonb)
  into v_history
  from (
    select id,recorded_at,source,
      serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,
      fitness,stamina,recovery,movement,
      fatigue,sharpness,morale,confidence,focus
    from public.player_skill_history
    where player_id=p_player_id
    order by recorded_at desc,id desc
    limit 240
  ) h;

  return jsonb_build_object(
    'player_id',p_player_id,
    'total_snapshots',v_count,
    'window_limited',v_count>240,
    'history',v_history,
    'history_scope','most_recent_240_snapshots'
  );
end;
$function$;

revoke all on function public.get_premium_player_development_v1(uuid)
  from public,anon,authenticated;
grant execute on function public.get_premium_player_development_v1(uuid)
  to authenticated;
comment on function public.get_premium_player_development_v1(uuid) is
  'Premium historical skill comparison of an owned player, limited to 240 latest snapshots. Never changes Free history.';
