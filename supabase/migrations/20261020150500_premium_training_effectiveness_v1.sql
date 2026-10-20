-- Premium Player Development Intelligence — slice 2, evidence-based training effectiveness.
-- Read-only analysis of persisted regular training and camp-day effects.
-- Does not change Free training, match outcomes, experience or player attributes.
create or replace function public.get_premium_training_effectiveness_v1(p_player_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_total bigint;
  v_window jsonb;
  v_window_count integer;
  v_regular integer;
  v_camps integer;
  v_avg_efficiency numeric;
  v_fractional_total numeric;
  v_whole_levels integer;
begin
  if v_uid is null then
    raise exception 'Authentication required for training effectiveness' using errcode='42501';
  end if;
  if not public.has_active_premium_v1() then
    raise exception 'Premium membership required for training effectiveness' using errcode='42501';
  end if;
  if p_player_id is null or not exists (
    select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid
  ) then
    raise exception 'Training effectiveness unavailable for this career' using errcode='42501';
  end if;

  -- Count only sessions that actually attempted skill development, not day off
  -- or active recovery. The latter continue to be accounted for in Free training.
  select
    (select count(*) from public.player_training_sessions r
     where r.player_id=p_player_id and r.session_role='planned_training')
    +
    (select count(*) from public.player_training_camp_days c
     where c.player_id=p_player_id and c.day_role='development')
  into v_total;

  with events as (
    select
      r.id, 'regular'::text as source, r.season,r.month,r.day,
      r.training_type as activity, r.focus_attribute,
      r.efficiency,
      coalesce(r.development_gains,'{}'::jsonb) as gains,
      coalesce(r.level_ups,'{}'::jsonb) as levels,
      public.game_day_absolute_v1(r.season,r.month,r.day) as absolute_day
    from public.player_training_sessions r
    where r.player_id=p_player_id and r.session_role='planned_training'
    union all
    select
      c.id, 'camp'::text, c.season,c.month,c.day,
      'camp_development'::text, null::text,
      c.efficiency,
      coalesce(c.development_gains,'{}'::jsonb),
      coalesce(c.level_ups,'{}'::jsonb),
      c.absolute_day
    from public.player_training_camp_days c
    where c.player_id=p_player_id and c.day_role='development'
  ),
  recent as (
    select * from events order by absolute_day desc,source,id desc limit 120
  ),
  decorated as (
    select e.*,
      (select g.season_week from public.absolute_game_day_v1(e.absolute_day) g) as game_week,
      coalesce((select sum(value::numeric) from jsonb_each_text(e.gains)),0)::numeric as progress_total,
      coalesce((select sum(value::integer) from jsonb_each_text(e.levels)),0)::integer as levels_total
    from recent e
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id',e.id,'source',e.source,'season',e.season,
      'game_week',e.game_week,'activity',e.activity,
      'focus_attribute',e.focus_attribute,'efficiency',e.efficiency,
      'gains',e.gains,'level_ups',e.levels,
      'progress_total',round(e.progress_total,4),'levels_total',e.levels_total
    ) order by e.absolute_day desc,e.source,e.id desc),'[]'::jsonb),
    count(*)::integer,
    count(*) filter (where e.source='regular')::integer,
    count(*) filter (where e.source='camp')::integer,
    round(avg(e.efficiency),4),
    round(coalesce(sum(e.progress_total),0),4),
    coalesce(sum(e.levels_total),0)::integer
  into v_window,v_window_count,v_regular,v_camps,v_avg_efficiency,v_fractional_total,v_whole_levels
  from decorated e;

  return jsonb_build_object(
    'player_id',p_player_id,
    'events',v_window,
    'total_events',v_total,
    'window_limited',v_total>120,
    'window_events',v_window_count,
    'regular_sessions',v_regular,
    'camp_days',v_camps,
    'average_efficiency',v_avg_efficiency,
    'fractional_progress_total',v_fractional_total,
    'whole_level_ups',v_whole_levels,
    'scope','most_recent_120_development_sessions',
    'metric_note','Progress is the recorded effective fractional gain before the next whole skill level. Efficiency is a recorded engine multiplier, not a percentage of a skill level. Rest days are excluded.'
  );
end;
$function$;

revoke all on function public.get_premium_training_effectiveness_v1(uuid)
  from public,anon,authenticated;
grant execute on function public.get_premium_training_effectiveness_v1(uuid)
  to authenticated;
comment on function public.get_premium_training_effectiveness_v1(uuid) is
  'Owned-player Premium training effectiveness from up to 120 recorded regular/camp development sessions. Read-only, game-week dated; ignores rest days and does not attribute unrecorded causes.';
