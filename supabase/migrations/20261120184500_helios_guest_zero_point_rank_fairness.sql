-- Project Helios H01: zero-point guest ranks BELOW existing zero-point players.
-- Positive earned points always take priority; after same-ID conversion the
-- player returns to normal ranking tie-breakers without resetting results.
CREATE OR REPLACE FUNCTION public.is_tennis_zero_point_guest_rank_tie_v1(
  p_owner_user_id uuid, p_points integer
) RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','auth','control_center_private','pg_temp'
AS $helper$
  SELECT CASE WHEN coalesce(p_points,0)=0
    AND EXISTS (
      SELECT 1 FROM auth.users u
      JOIN control_center_private.tennis_guest_trials_v1 g ON g.user_id=u.id
      WHERE u.id=p_owner_user_id AND u.is_anonymous
    ) THEN 1 ELSE 0 END;
$helper$;
REVOKE ALL ON FUNCTION public.is_tennis_zero_point_guest_rank_tie_v1(uuid,integer)
  FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.get_world_rankings_v1(p_world text, p_offset integer DEFAULT 0, p_limit integer DEFAULT 50)
 RETURNS TABLE(rank_position bigint, player_id uuid, first_name text, last_name text, country_code text, image_path text, ranking_points integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with ranked as(
    select row_number() over(
      order by coalesce(r.ranking_points,0) desc, public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,coalesce(r.ranking_points,0)) asc,coalesce(r.seed_rating,0) desc,p.created_at asc,p.id asc
    ) rank_position,
    p.id player_id,p.first_name,p.last_name,p.country_code,p.image_path,coalesce(r.ranking_points,0)::integer ranking_points
    from public.players p left join public.player_rankings r on r.player_id=p.id
    where p.world=upper(p_world) and p.moderation_status<>'rejected'
  )
  select * from ranked order by rank_position
  offset greatest(coalesce(p_offset,0),0)
  limit least(greatest(coalesce(p_limit,50),1),100);
$function$
;

CREATE OR REPLACE FUNCTION public.get_world_rankings_v2(p_world text, p_offset integer DEFAULT 0, p_limit integer DEFAULT 50)
 RETURNS TABLE(rank_position bigint, player_id uuid, first_name text, last_name text, country_code text, image_path text, ranking_points integer, previous_week_position integer, rank_change integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with publication_days as (
    select game_absolute_day,
           row_number() over (order by game_absolute_day desc) as rn
    from (
      select distinct game_absolute_day
      from public.ranking_publication_runs
    ) d
  ),
  previous_publication as (
    select game_absolute_day
    from publication_days
    where rn = 2
  ),
  ranked as (
    select
      row_number() over (
        order by coalesce(r.ranking_points,0) desc, public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,coalesce(r.ranking_points,0)) asc,
                 coalesce(r.seed_rating,0) desc,
                 p.created_at asc,
                 p.id asc
      ) as rank_position,
      p.id as player_id,
      p.first_name,
      p.last_name,
      p.country_code,
      p.image_path,
      coalesce(r.ranking_points,0)::integer as ranking_points
    from public.players p
    left join public.player_rankings r on r.player_id = p.id
    where p.world = upper(p_world)
      and p.moderation_status <> 'rejected'
  )
  select
    ranked.rank_position,
    ranked.player_id,
    ranked.first_name,
    ranked.last_name,
    ranked.country_code,
    ranked.image_path,
    ranked.ranking_points,
    previous_snapshot.ranking_position::integer as previous_week_position,
    case
      when previous_snapshot.ranking_position is null then null
      else (previous_snapshot.ranking_position - ranked.rank_position)::integer
    end as rank_change
  from ranked
  left join lateral (
    select s.ranking_position
    from public.player_ranking_snapshots s
    where s.player_id = ranked.player_id
      and s.world = upper(p_world)
      and s.game_absolute_day = (select game_absolute_day from previous_publication)
    order by s.created_at desc
    limit 1
  ) previous_snapshot on true
  order by ranked.rank_position
  offset greatest(coalesce(p_offset,0),0)
  limit least(greatest(coalesce(p_limit,50),1),100);
$function$
;

CREATE OR REPLACE FUNCTION public.get_world_rankings_v3(p_world text, p_offset integer DEFAULT 0, p_limit integer DEFAULT 50)
 RETURNS TABLE(rank_position bigint, player_id uuid, first_name text, last_name text, country_code text, image_path text, ranking_points integer, previous_week_position integer, rank_change integer, previous_week_points integer, points_change integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with publication_days as (
    select game_absolute_day,
           row_number() over (order by game_absolute_day desc) as rn
    from (
      select distinct game_absolute_day
      from public.ranking_publication_runs
    ) d
  ),
  previous_publication as (
    select game_absolute_day
    from publication_days
    where rn=2
  ),
  ranked as (
    select
      row_number() over (
        order by coalesce(r.ranking_points,0) desc, public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,coalesce(r.ranking_points,0)) asc,
                 coalesce(r.seed_rating,0) desc,
                 p.created_at asc,
                 p.id asc
      ) as rank_position,
      p.id as player_id,
      p.first_name,
      p.last_name,
      p.country_code,
      p.image_path,
      coalesce(r.ranking_points,0)::integer as ranking_points
    from public.players p
    left join public.player_rankings r on r.player_id=p.id
    where p.world=upper(p_world)
      and p.moderation_status<>'rejected'
  )
  select
    ranked.rank_position,
    ranked.player_id,
    ranked.first_name,
    ranked.last_name,
    ranked.country_code,
    ranked.image_path,
    ranked.ranking_points,
    previous_snapshot.ranking_position::integer as previous_week_position,
    case
      when previous_snapshot.ranking_position is null then null
      else (previous_snapshot.ranking_position-ranked.rank_position)::integer
    end as rank_change,
    previous_snapshot.ranking_points::integer as previous_week_points,
    case
      when previous_snapshot.ranking_points is null then null
      else (ranked.ranking_points-previous_snapshot.ranking_points)::integer
    end as points_change
  from ranked
  left join lateral (
    select s.ranking_position,s.ranking_points
    from public.player_ranking_snapshots s
    where s.player_id=ranked.player_id
      and s.world=upper(p_world)
      and s.game_absolute_day=(select game_absolute_day from previous_publication)
    order by s.created_at desc
    limit 1
  ) previous_snapshot on true
  order by ranked.rank_position
  offset greatest(coalesce(p_offset,0),0)
  limit least(greatest(coalesce(p_limit,50),1),100);
$function$
;

CREATE OR REPLACE FUNCTION public.player_current_rank_position_v1(p_player_id uuid)
 RETURNS bigint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with target as (select world from public.players where id=p_player_id), ranked as (
    select p.id,row_number() over(order by coalesce(r.ranking_points,0) desc, public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,coalesce(r.ranking_points,0)) asc,coalesce(r.seed_rating,0) desc,p.created_at asc,p.id asc) pos
    from public.players p left join public.player_rankings r on r.player_id=p.id
    where p.world=(select world from target) and p.moderation_status<>'rejected'
  ) select pos from ranked where id=p_player_id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_world_rank_position_v1(p_player_id uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with ranked as (
    select p.id,row_number() over(partition by p.world order by coalesce(r.ranking_points,0) desc, public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,coalesce(r.ranking_points,0)) asc,coalesce(r.seed_rating,0) desc,p.created_at,p.id)::integer pos
    from public.players p left join public.player_rankings r on r.player_id=p.id
    where p.moderation_status<>'rejected'
  ) select pos from ranked where id=p_player_id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_profile_v2(p_player_id uuid)
 RETURNS TABLE(player_id uuid, first_name text, last_name text, world text, country_code text, home_city text, image_path text, preferred_surface text, playing_style text, playing_hand text, ranking_points integer, rank_position bigint, is_own_player boolean, is_ai boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with target as(
    select p.*
    from public.players p
    where p.id=p_player_id
      and p.moderation_status<>'rejected'
  ),
  ranked as(
    select p.id,row_number() over(
      order by coalesce(r.ranking_points,0) desc, public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,coalesce(r.ranking_points,0)) asc,
               coalesce(r.seed_rating,0) desc,
               p.created_at asc,p.id asc
    ) rank_position
    from public.players p
    left join public.player_rankings r on r.player_id=p.id
    where p.world=(select world from target)
      and p.moderation_status<>'rejected'
  )
  select
    t.id,t.first_name,t.last_name,t.world,t.country_code,t.home_city,t.image_path,
    t.preferred_surface,t.playing_style,t.playing_hand,
    coalesce(pr.ranking_points,0)::integer,
    ranked.rank_position,
    coalesce(t.owner_user_id=auth.uid(),false),
    (t.player_type='ai')
  from target t
  left join public.player_rankings pr on pr.player_id=t.id
  left join ranked on ranked.id=t.id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_tournament_application_field_v1(p_competition_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_world text;
  v_name text;
  v_main_capacity integer;
  v_qualifier_slots integer;
  v_direct_slots integer;
  v_qcap integer;
  v_phase text;
  v_rows jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select wc.world,ts.name,c.main_draw_capacity,c.default_qualifier_slots,
         c.main_draw_capacity-c.default_qualifier_slots,c.qualifying_capacity_max
  into v_world,v_name,v_main_capacity,v_qualifier_slots,v_direct_slots,v_qcap
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_categories c on c.code=ts.category_code
  where wc.id=p_competition_id;
  if v_world is null then raise exception 'Tournament not found.'; end if;

  v_phase:=public.get_tournament_entry_lifecycle_v2(p_competition_id)->>'phase';

  with ranked_world as (
    select p.id player_id,
           row_number() over(order by coalesce(pr.ranking_points,0) desc, public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,coalesce(pr.ranking_points,0)) asc,coalesce(pr.seed_rating,0) desc,p.created_at,p.id)::integer current_world_rank
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.world=v_world and p.moderation_status<>'rejected'
  ), base as (
    select a.id application_id,a.player_id,p.first_name,p.last_name,p.country_code,p.player_type,
           a.priority,a.accept_qualification,a.application_source,a.status application_status,a.decision_reason,
           rw.current_world_rank::integer world_rank,
           a.ranking_position_snapshot::integer application_rank_at_submission,
           rw.current_world_rank,
           te.draw_type entry_draw_type,te.entry_status,
           (p.owner_user_id=v_uid) is_user,
           row_number() over(order by rw.current_world_rank,a.created_at,a.id)::integer overall_order
    from public.tournament_applications a
    join public.players p on p.id=a.player_id
    join ranked_world rw on rw.player_id=a.player_id
    left join public.tournament_entries te on te.competition_id=a.competition_id and te.player_id=a.player_id
    where a.competition_id=p_competition_id
      and a.status in ('applied','accepted_main_draw','accepted_qualification')
  ), staged as (
    select b.*,
           count(*) filter(where b.overall_order>v_direct_slots and b.accept_qualification and b.application_status in ('applied','accepted_qualification'))
             over(order by b.overall_order rows between unbounded preceding and current row)::integer as qualification_order
    from base b
  ), projected as (
    select s.*,
      case
        when s.entry_draw_type='main_draw' then 'main_draw'
        when s.entry_draw_type='qualification' then 'qualification'
        when s.application_status='accepted_main_draw' then 'main_draw'
        when s.application_status='accepted_qualification' then 'qualification'
        when s.application_status='applied' and s.overall_order<=v_direct_slots then 'main_draw'
        when s.application_status='applied' and s.overall_order>v_direct_slots and s.accept_qualification and s.qualification_order<=v_qcap then 'qualification'
        else 'outside'
      end projected_group
    from staged s
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'application_id',application_id,'player_id',player_id,'first_name',first_name,'last_name',last_name,
      'country_code',country_code,'player_type',player_type,'world_rank',world_rank,'current_world_rank',current_world_rank,'application_rank_at_submission',application_rank_at_submission,'priority',priority,
      'accept_qualification',accept_qualification,'application_source',application_source,'application_status',application_status,
      'decision_reason',decision_reason,'entry_draw_type',entry_draw_type,'entry_status',entry_status,'is_user',is_user,
      'projected_group',projected_group
    ) order by case projected_group when 'main_draw' then 1 when 'qualification' then 2 else 3 end,world_rank,application_id),'[]'::jsonb)
  into v_rows from projected;

  return jsonb_build_object(
    'competition_id',p_competition_id,'tournament_name',v_name,'world',v_world,'phase',v_phase,
    'main_draw_total_capacity',v_main_capacity,'direct_main_draw_slots',v_direct_slots,'qualifier_slots',v_qualifier_slots,
    'qualification_capacity',v_qcap,'applicant_count',jsonb_array_length(v_rows),'applicants',v_rows
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.capture_world_ranking_snapshot_internal_v1()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_abs integer; v_season integer;
begin
  select public.game_day_absolute_v1(d.season,d.month,d.day), d.season into v_abs,v_season from public.get_current_game_day_internal_v1() d;
  insert into public.player_ranking_snapshots(player_id,world,season,game_absolute_day,ranking_position,ranking_points)
  select p.id,p.world,v_season,v_abs,
         row_number() over(partition by p.world order by coalesce(pr.ranking_points,0) desc, public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,coalesce(pr.ranking_points,0)) asc, coalesce(pr.seed_rating,0) desc, p.created_at asc, p.id)::integer,
         coalesce(pr.ranking_points,0)
  from public.players p
  left join public.player_rankings pr on pr.player_id=p.id
  where p.world in ('ATP','WTA')
  on conflict(player_id,game_absolute_day) do update set
    world=excluded.world,season=excluded.season,ranking_position=excluded.ranking_position,ranking_points=excluded.ranking_points;
end; $function$
;

CREATE OR REPLACE FUNCTION public.get_world_doubles_rankings_v1(p_world text, p_offset integer DEFAULT 0, p_limit integer DEFAULT 50)
 RETURNS TABLE(rank_position bigint, player_id uuid, first_name text, last_name text, country_code text, image_path text, ranking_points integer, previous_week_position integer, rank_change integer, previous_week_points integer, points_change integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with days as (
  select game_absolute_day,row_number() over(order by game_absolute_day desc) rn from public.doubles_ranking_publication_runs
),prev as (select game_absolute_day from days where rn=2),ranked as (
  select row_number() over(order by coalesce(r.ranking_points,0) desc, public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,coalesce(r.ranking_points,0)) asc,coalesce(r.seed_rating,0) desc,p.created_at,p.id) rank_position,
         p.id player_id,p.first_name,p.last_name,p.country_code,p.image_path,coalesce(r.ranking_points,0)::integer ranking_points
  from public.players p left join public.player_doubles_rankings r on r.player_id=p.id
  where p.world=upper(p_world) and p.moderation_status<>'rejected'
)
select ranked.rank_position,ranked.player_id,ranked.first_name,ranked.last_name,ranked.country_code,ranked.image_path,ranked.ranking_points,
       s.ranking_position previous_week_position,
       case when s.ranking_position is null then null else (s.ranking_position-ranked.rank_position)::integer end rank_change,
       s.ranking_points previous_week_points,
       case when s.ranking_points is null then null else (ranked.ranking_points-s.ranking_points)::integer end points_change
from ranked left join public.player_doubles_ranking_snapshots s on s.player_id=ranked.player_id and s.game_absolute_day=(select game_absolute_day from prev)
order by ranked.rank_position offset greatest(coalesce(p_offset,0),0) limit least(greatest(coalesce(p_limit,50),1),100);
$function$
;
