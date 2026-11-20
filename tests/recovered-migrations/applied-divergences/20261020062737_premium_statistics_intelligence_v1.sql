-- Statistics Intelligence: entitlement-gated Premium report from the same
-- completed-match, top-50 leaderboard sample as the existing Free Statistics UI.
-- This does not modify Free statistics, game outcomes or any source match data.
create or replace function public.get_premium_statistics_intelligence_v1(
  p_world text default null,
  p_period text default 'season'
) returns jsonb
language plpgsql
stable
security definer
set search_path = 'public'
as $function$
declare
  v_payload jsonb;
  v_my_id text;
  v_own jsonb;
  v_players integer;
  v_matches numeric;
  v_wins numeric;
  v_aces numeric;
  v_winners numeric;
  v_metrics jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;
  -- The current entitlement recognizes an active paid plan OR an eligible,
  -- unexpired seven-real-day Premium trial.
  if not public.has_active_premium_v1() then
    raise exception 'Premium membership required for Statistics Intelligence.'
      using errcode = '42501';
  end if;

  -- Existing public rankings/stats remain fully accessible to Free players.
  v_payload := public.get_world_statistics_v1(p_world, p_period);
  v_my_id := v_payload #>> '{career,player,player_id}';

  select to_jsonb(s) into v_own
    from jsonb_to_recordset(coalesce(v_payload->'players','[]'::jsonb))
         as s(player_id text,matches numeric,wins numeric,aces numeric,winners numeric)
    where s.player_id=v_my_id and s.matches>0
    limit 1;

  select count(*)::integer,
         coalesce(sum(s.matches),0),
         coalesce(sum(s.wins),0),
         coalesce(sum(s.aces),0),
         coalesce(sum(s.winners),0)
    into v_players,v_matches,v_wins,v_aces,v_winners
    from jsonb_to_recordset(coalesce(v_payload->'players','[]'::jsonb))
         as s(player_id text,matches numeric,wins numeric,aces numeric,winners numeric)
    where s.matches>0 and (v_my_id is null or s.player_id is distinct from v_my_id);

  if v_matches>0 then
    v_metrics := jsonb_build_array(
      jsonb_build_object(
        'key','winRate','suffix','%',
        'own',case when v_own is null then null else round(100*(v_own->>'wins')::numeric / nullif((v_own->>'matches')::numeric,0),1) end,
        'peers',round(100*v_wins/v_matches,1)
      ),
      jsonb_build_object(
        'key','aces','suffix','',
        'own',case when v_own is null then null else round((v_own->>'aces')::numeric / nullif((v_own->>'matches')::numeric,0),1) end,
        'peers',round(v_aces/v_matches,1)
      ),
      jsonb_build_object(
        'key','winners','suffix','',
        'own',case when v_own is null then null else round((v_own->>'winners')::numeric / nullif((v_own->>'matches')::numeric,0),1) end,
        'peers',round(v_winners/v_matches,1)
      )
    );
  end if;

  return jsonb_build_object(
    'world',v_payload->>'world',
    'period',v_payload->>'period',
    'season',(v_payload->>'season')::integer,
    'sample_players',v_players,
    'sample_matches',v_matches,
    'own_in_sample',(v_own is not null),
    'metrics',v_metrics
  );
end;
$function$;

revoke all on function public.get_premium_statistics_intelligence_v1(text,text) from public,anon;
grant execute on function public.get_premium_statistics_intelligence_v1(text,text) to authenticated;
comment on function public.get_premium_statistics_intelligence_v1(text,text) is
'Premium-only report of completed-match leaderboard peer comparisons; Free underlying statistics remain unchanged.';
