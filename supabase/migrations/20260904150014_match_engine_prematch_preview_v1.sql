create or replace function public.get_tournament_match_engine_preview_v1(p_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare
  m public.tournament_matches%rowtype;
  sim public.tournament_match_simulations%rowtype;
  ts public.tournament_series%rowtype;
  wc public.tournament_world_competitions%rowtype;
  p1 jsonb;p2 jsonb;v_snapshot jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.';end if;
  select * into m from public.tournament_matches where id=p_match_id;
  if m.id is null then return jsonb_build_object('status','unavailable');end if;
  select wc0.* into wc from public.tournament_world_competitions wc0 where wc0.id=m.competition_id;
  select s.* into ts from public.tournament_world_competitions wc0 join public.tournament_editions ed on ed.id=wc0.tournament_edition_id join public.tournament_series s on s.id=ed.tournament_series_id where wc0.id=m.competition_id;
  select * into sim from public.tournament_match_simulations where match_id=p_match_id;
  if sim.match_id is not null and sim.metadata ? 'profile_snapshot' then
    v_snapshot:=sim.metadata->'profile_snapshot';p1:=v_snapshot->'player1';p2:=v_snapshot->'player2';
  elsif m.player1_id is not null and m.player2_id is not null then
    p1:=public.get_match_engine_profile_v1(m.player1_id,ts.surface);p2:=public.get_match_engine_profile_v1(m.player2_id,ts.surface);
  else return jsonb_build_object('status','waiting_for_players','match_status',m.status);end if;
  return jsonb_build_object(
    'status','ready','match_status',m.status,'surface',lower(ts.surface),'world',wc.world,'category',ts.category_code,
    'player1',p1,'player2',p2,
    'comparison',jsonb_build_object(
      'player1_effective_level',(p1->'ratings'->>'effective_overall')::numeric,
      'player2_effective_level',(p2->'ratings'->>'effective_overall')::numeric,
      'difference',round((p1->'ratings'->>'effective_overall')::numeric-(p2->'ratings'->>'effective_overall')::numeric,2)
    ),
    'attribute_reference',jsonb_build_object(
      'serve','Primary service quality. Drives first/second-serve point strength, ace chance and indirectly double-fault control.',
      'forehand','Primary attacking and rally skill from the forehand wing.',
      'backhand','Primary attacking and rally skill from the backhand wing.',
      'return_skill','Ability to neutralise or attack the opponent serve; central to break probability.',
      'volley','Net finishing and transition quality; more relevant on faster surfaces and for net-oriented play.',
      'slice','Variety, low-ball control and defensive/transition value; slightly more relevant on grass.',
      'drop_shot','Situational attacking variety; slightly more relevant on clay.',
      'lob','Defensive/transition option against net pressure.',
      'smash','Overhead finishing quality and part of net-point strength.',
      'fitness','General physical capacity. Contributes to rally quality and reduces long-match performance decline.',
      'stamina','Ability to sustain level as points and sets accumulate; increasingly important late in long matches.',
      'recovery','Does not directly win points in v1. It reduces the fatigue retained after a completed match and therefore matters for the next round.',
      'movement','Court coverage and defensive positioning. Important to return and rally strength on every surface, especially clay.',
      'fatigue','Current negative condition. High fatigue reduces how much of the long-term skill ceiling is expressed.',
      'sharpness','Current timing/match-readiness. Higher sharpness improves skill expression.',
      'focus','Current concentration and consistency; contributes strongly to mental expression and first-serve reliability.',
      'confidence','Current belief/decisiveness; contributes to mental expression and changes after wins/losses.',
      'morale','Broader emotional state; a smaller but persistent mental modifier.',
      'preferred_surface','Small matchup modifier only: preferred surface receives +1.5% expression; a non-preferred surface uses -0.5% in v1.'
    ),
    'v1_scope',jsonb_build_object('equipment',false,'staff',false,'weather',false,'injuries',false,'match_tactics',false,'playing_style_outcome_modifier',false,'playing_style_replay_flavour',true)
  );
end;$$;
revoke all on function public.get_tournament_match_engine_preview_v1(uuid) from public,anon;
grant execute on function public.get_tournament_match_engine_preview_v1(uuid) to authenticated;