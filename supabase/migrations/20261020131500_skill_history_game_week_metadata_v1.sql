-- Skills pages: game time, not wall-clock timestamps.
-- Existing real timestamps stay internal for ordering only.
-- Old snapshots get a season/week only when an exact training event proves it.
alter table public.player_skill_history
  add column if not exists game_season integer,
  add column if not exists game_week smallint;

-- Backfill legacy rows only when the matching logged training-day execution is
-- within 15 seconds of the snapshot. Never approximate historical game dates
-- from today's game clock or from a mutable real-time speed factor.
with matched as (
  select h.id, s.season,
    (select d.season_week from public.absolute_game_day_v1(
      public.game_day_absolute_v1(s.season,s.month,s.day)
    ) d) as week_number,
    row_number() over (partition by h.id order by abs(extract(epoch from(h.recorded_at-s.created_at))),s.id) rn
  from public.player_skill_history h
  join public.player_training_sessions s on s.player_id=h.player_id
    and h.recorded_at between s.created_at-interval '15 seconds'
                          and s.created_at+interval '15 seconds'
  where h.game_season is null and h.game_week is null
)
update public.player_skill_history h
set game_season=m.season,game_week=m.week_number
from matched m
where h.id=m.id and m.rn=1
  and h.game_season is null and h.game_week is null;

create or replace function public.stamp_player_skill_history_game_week_v1()
returns trigger language plpgsql security definer set search_path='public'
as $function$
declare
  d record;
  w record;
begin
  if new.game_season is not null and new.game_week is not null then
    return new;
  end if;
  -- Capture the game's calendar at INSERT time for future history entries.
  select * into d from public.get_current_game_day_internal_v1();
  select * into w from public.absolute_game_day_v1(
    public.game_day_absolute_v1(d.season,d.month,d.day)
  );
  new.game_season:=d.season;
  new.game_week:=w.season_week;
  return new;
end;
$function$;
revoke all on function public.stamp_player_skill_history_game_week_v1() from public,anon,authenticated;
drop trigger if exists trg_stamp_player_skill_history_game_week_v1 on public.player_skill_history;
create trigger trg_stamp_player_skill_history_game_week_v1
before insert on public.player_skill_history
for each row execute function public.stamp_player_skill_history_game_week_v1();

-- Preserve the paid entitlement, owner check and original 240-row limit.
-- Extend the existing report with the actual game week stored on each row.
create or replace function public.get_premium_player_development_v1(p_player_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public'
as $function$
declare
 v_uid uuid:=auth.uid();
 v_count integer;
 v_history jsonb;
 v_dated integer;
begin
 if v_uid is null then
   raise exception 'Authentication required for Player Development Intelligence' using errcode='42501';
 end if;
 if not public.has_active_premium_v1() then
   raise exception 'Premium membership required for Player Development Intelligence' using errcode='42501';
 end if;
 if p_player_id is null or not exists (
   select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid
 ) then
   raise exception 'Player development report unavailable for this career' using errcode='42501';
 end if;

 select count(*)::integer into v_count
 from public.player_skill_history where player_id=p_player_id;

 select coalesce(jsonb_agg(jsonb_build_object(
    'recorded_at',h.recorded_at,'game_season',h.game_season,'game_week',h.game_week,
    'source',h.source,
    'serve',h.serve,'forehand',h.forehand,'backhand',h.backhand,
    'return_skill',h.return_skill,'volley',h.volley,'slice',h.slice,
    'drop_shot',h.drop_shot,'lob',h.lob,'smash',h.smash,
    'fitness',h.fitness,'stamina',h.stamina,'recovery',h.recovery,
    'movement',h.movement,'fatigue',h.fatigue,'sharpness',h.sharpness,
    'morale',h.morale,'confidence',h.confidence,'focus',h.focus
 ) order by h.recorded_at,h.id),'[]'::jsonb),
 count(*) filter(where h.game_season is not null and h.game_week is not null)::integer
 into v_history,v_dated
 from (
    select id,recorded_at,game_season,game_week,source,
       serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,
       fitness,stamina,recovery,movement,fatigue,sharpness,morale,confidence,focus
    from public.player_skill_history
    where player_id=p_player_id
    order by recorded_at desc,id desc limit 240
 ) h;
 return jsonb_build_object(
   'player_id',p_player_id,'total_snapshots',v_count,
   'window_limited',v_count>240,'history',v_history,
   'game_dated_snapshots',v_dated,
   'history_scope','most_recent_240_snapshots'
 );
end;
$function$;
revoke all on function public.get_premium_player_development_v1(uuid) from public,anon;
grant execute on function public.get_premium_player_development_v1(uuid) to authenticated;
