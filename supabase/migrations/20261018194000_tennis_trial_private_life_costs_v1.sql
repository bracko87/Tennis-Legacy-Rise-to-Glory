-- Treat active trial holders the same as paid Premium for Private Life running costs.
-- Costs stop when the trial expires without an active paid plan.
CREATE OR REPLACE FUNCTION public.process_private_life_running_costs_to_current_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  d record;
  p record;
  v_abs integer;
  v_result jsonb;
  v_players integer:=0;
  v_events integer:=0;
  v_total bigint:=0;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);

  for p in
    select distinct pl.id
    from public.players pl
    left join public.premium_memberships pm on pm.user_id=pl.owner_user_id
    join public.private_life_player_assets a on a.player_id=pl.id
    where pl.player_type='human'
      and pl.owner_user_id is not null
      and (
        (pm.plan_code='premium' and pm.status='active'
          and (pm.current_period_end is null or pm.current_period_end>now()))
        or exists (
          select 1 from public.tennis_premium_trials_v1 tr
          where tr.user_id=pl.owner_user_id and tr.expires_at>now()
        )
      )
  loop
    v_players:=v_players+1;
    v_result:=public.process_private_life_running_costs_for_player_v1(p.id,v_abs);
    v_events:=v_events+coalesce((v_result->>'events')::integer,0);
    v_total:=v_total+coalesce((v_result->>'total_cost')::bigint,0);
  end loop;

  return jsonb_build_object(
    'status','completed',
    'current_absolute_day',v_abs,
    'players_processed',v_players,
    'cost_events',v_events,
    'total_cost',v_total
  );
end;
$function$;
