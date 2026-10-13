-- Withdrawn applicants with no draw slot or match did not participate.
-- Keep them in the historical entries table but exclude them from the
-- expected finalized-result count. Count withdrawn players who did compete.
CREATE OR REPLACE FUNCTION public.tournament_operations_rows_v1(p_view text DEFAULT 'today'::text, p_days integer DEFAULT 7)
 RETURNS TABLE(competition_id uuid, tournament_name text, world text, category_code text, city text, season_number integer, start_absolute_day integer, end_absolute_day integer, application_open_absolute_day integer, application_close_absolute_day integer, draw_due_absolute_day integer, ranking_publish_absolute_day integer, phase text, entry_status text, draw_status text, matches_status text, rewards_status text, closure_status text, application_count integer, entry_count integer, human_entry_count integer, match_count integer, completed_matches integer, bye_matches integer, cancelled_matches integer, scheduled_matches integer, in_progress_matches integer, playable_unresolved_matches integer, result_rows integer, pending_ranking_rows integer, ranking_contribution_rows integer, human_prize_results integer, human_prize_payments integer, stale_calendar_commitments integer, main_final_completed boolean, champion_id uuid, champion_name text, has_problem boolean, issue_key text, issue_severity text, issue_message text, incident_id uuid, incident_status text, incident_first_seen_at timestamp with time zone, incident_last_seen_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
with current_day as (
  select
    public.game_day_absolute_v1(d.season,d.month,d.day) as abs_day,
    public.current_game_second_v1() as game_second,
    public.tournament_draw_health_grace_game_seconds_v1() as draw_grace_game_seconds
  from public.get_current_game_day_internal_v1() d
),
base_raw as (
  select
    wc.id as comp_id,
    ts.name as t_name,
    wc.world as comp_world,
    ts.category_code as cat_code,
    ts.city as t_city,
    ed.season_number as season_no,
    min(public.training_camp_week_start_absolute_v1(ed.season_number,ss.season_week::smallint))::integer as start_day,
    max(public.training_camp_week_start_absolute_v1(ed.season_number,ss.season_week::smallint)+6)::integer as end_day,
    (
      wc.status='canceled'
      or ed.status='canceled'
      or exists(select 1 from public.tournament_cancellations cx where cx.competition_id=wc.id)
    ) as is_cancelled
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=ed.id
  group by wc.id,ts.name,wc.world,ts.category_code,ts.city,ed.season_number,wc.status,ed.status
),
base as (
  select b.*
  from base_raw b
  cross join current_day cd
  where b.start_day <= cd.abs_day+35
    and (
      b.end_day >= cd.abs_day-greatest(14,least(coalesce(p_days,7),60))
      or exists(
        select 1
        from public.system_incidents si
        where si.dedupe_key='tournament-ops:'||b.comp_id::text
          and si.status in ('open','acknowledged')
      )
    )
),
app_agg as (
  select a.competition_id as comp_id,count(*)::integer as applications
  from public.tournament_applications a
  join base b on b.comp_id=a.competition_id
  group by a.competition_id
),
entry_agg as (
  select
    e.competition_id as comp_id,
    count(*) filter(where (
      e.entry_status is distinct from 'withdrawn'
      or e.bracket_slot is not null
      or exists (
        select 1 from public.tournament_matches played
        where played.competition_id=e.competition_id
          and (played.player1_id=e.player_id or played.player2_id=e.player_id)
          and played.status in ('completed','walkover','bye')
      )
    ))::integer as entries,
    count(*) filter(where p.player_type='human' and (
      e.entry_status is distinct from 'withdrawn'
      or e.bracket_slot is not null
      or exists (
        select 1 from public.tournament_matches played
        where played.competition_id=e.competition_id
          and (played.player1_id=e.player_id or played.player2_id=e.player_id)
          and played.status in ('completed','walkover','bye')
      )
    ))::integer as human_entries
  from public.tournament_entries e
  join base b on b.comp_id=e.competition_id
  join public.players p on p.id=e.player_id
  group by e.competition_id
),
match_agg as (
  select
    m.competition_id as comp_id,
    count(*)::integer as matches,
    count(*) filter(where m.status='completed')::integer as completed_count,
    count(*) filter(where m.status='bye')::integer as bye_count,
    count(*) filter(where m.status in ('cancelled','canceled'))::integer as cancelled_count,
    count(*) filter(where m.status='scheduled')::integer as scheduled_count,
    count(*) filter(where m.status='in_progress')::integer as in_progress_count,
    count(*) filter(
      where m.status not in ('completed','bye','walkover','cancelled','canceled')
        and m.player1_id is not null
        and m.player2_id is not null
    )::integer as playable_unresolved,
    coalesce(bool_or(
      m.draw_type='main_draw'
      and lower(m.round_label)='final'
      and m.status in ('completed','walkover')
      and m.winner_id is not null
    ),false) as final_completed,
    (
      array_agg(m.winner_id order by m.completed_at desc nulls last)
      filter(
        where m.draw_type='main_draw'
          and lower(m.round_label)='final'
          and m.status in ('completed','walkover')
          and m.winner_id is not null
      )
    )[1] as champion
  from public.tournament_matches m
  join base b on b.comp_id=m.competition_id
  group by m.competition_id
),
result_agg as (
  select
    r.competition_id as comp_id,
    count(*)::integer as results_count,
    count(*) filter(where r.ranking_publish_status<>'published')::integer as pending_rankings,
    count(*) filter(where p.player_type='human' and r.prize_money_earned>0)::integer as human_prize_result_count
  from public.player_tournament_results r
  join base b on b.comp_id=r.competition_id
  join public.players p on p.id=r.player_id
  group by r.competition_id
),
ranking_agg as (
  select rc.competition_id as comp_id,count(*)::integer as ranking_contributions
  from public.player_ranking_contributions rc
  join base b on b.comp_id=rc.competition_id
  group by rc.competition_id
),
payment_agg as (
  select
    r.competition_id as comp_id,
    count(*)::integer as human_prize_payment_count
  from public.player_tournament_results r
  join base b on b.comp_id=r.competition_id
  join public.players p on p.id=r.player_id and p.player_type='human'
  join public.career_finance_transactions ft
    on ft.player_id=r.player_id
   and ft.source_type='tournament_result'
   and ft.source_id=r.competition_id::text
   and ft.idempotency_key='tournament-prize:'||r.competition_id::text||':'||r.player_id::text
   and ft.amount=r.prize_money_earned
  where r.prize_money_earned>0
  group by r.competition_id
),
calendar_agg as (
  select cc.competition_id as comp_id,count(*)::integer as stale_calendar_count
  from public.player_calendar_commitments cc
  join base b on b.comp_id=cc.competition_id
  cross join current_day cd
  where cc.status in ('confirmed','active')
    and cc.ends_absolute_day<cd.abs_day
  group by cc.competition_id
),
counts as (
  select
    b.comp_id,
    coalesce(a.applications,0) as applications,
    coalesce(e.entries,0) as entries,
    coalesce(e.human_entries,0) as human_entries,
    coalesce(m.matches,0) as matches,
    coalesce(m.completed_count,0) as completed_count,
    coalesce(m.bye_count,0) as bye_count,
    coalesce(m.cancelled_count,0) as cancelled_count,
    coalesce(m.scheduled_count,0) as scheduled_count,
    coalesce(m.in_progress_count,0) as in_progress_count,
    coalesce(m.playable_unresolved,0) as playable_unresolved,
    coalesce(r.results_count,0) as results_count,
    coalesce(r.pending_rankings,0) as pending_rankings,
    coalesce(ra.ranking_contributions,0) as ranking_contributions,
    coalesce(r.human_prize_result_count,0) as human_prize_result_count,
    coalesce(pa.human_prize_payment_count,0) as human_prize_payment_count,
    coalesce(ca.stale_calendar_count,0) as stale_calendar_count,
    coalesce(m.final_completed,false) as final_completed,
    m.champion
  from base b
  left join app_agg a on a.comp_id=b.comp_id
  left join entry_agg e on e.comp_id=b.comp_id
  left join match_agg m on m.comp_id=b.comp_id
  left join result_agg r on r.comp_id=b.comp_id
  left join ranking_agg ra on ra.comp_id=b.comp_id
  left join payment_agg pa on pa.comp_id=b.comp_id
  left join calendar_agg ca on ca.comp_id=b.comp_id
),
timelines as (
  select b.comp_id,public.get_tournament_entry_timeline_v1(b.comp_id) as tl
  from base b
  where not b.is_cancelled
),
lifecycle as (
  select
    b.comp_id,b.t_name,b.comp_world,b.cat_code,b.t_city,b.season_no,b.start_day,b.end_day,b.is_cancelled,
    c.applications,c.entries,c.human_entries,c.matches,c.completed_count,c.bye_count,c.cancelled_count,
    c.scheduled_count,c.in_progress_count,c.playable_unresolved,c.results_count,c.pending_rankings,
    c.ranking_contributions,c.human_prize_result_count,c.human_prize_payment_count,c.stale_calendar_count,
    c.final_completed,c.champion,
    coalesce((t.tl->'applications_open'->>'absolute_day')::integer,b.start_day-21) as app_open_day,
    coalesce((t.tl->'normal_applications_close'->>'absolute_day')::integer,b.start_day-14) as app_close_day,
    coalesce((t.tl->'draw_publish'->>'absolute_day')::integer,b.start_day-3) as draw_day,
    b.end_day+1 as rank_publish_day,
    exists(
      select 1 from public.tournament_competition_entry_cycles ec
      where ec.competition_id=b.comp_id and ec.field_locked_at is not null
    ) as field_locked,
    exists(
      select 1 from public.tournament_draw_publications dp
      where dp.competition_id=b.comp_id
    ) as draw_published,
    cd.abs_day as current_abs,
    cd.game_second as current_game_second,
    coalesce(
      (t.tl->>'applications_open_game_second')::bigint,
      (coalesce((t.tl->'applications_open'->>'absolute_day')::integer,b.start_day-21)::bigint*86400)
        + coalesce((t.tl->'applications_open'->>'minute_of_day')::bigint,0)*60
    ) as app_open_game_second,
    coalesce(
      (t.tl->>'late_close_game_second')::bigint,
      (t.tl->>'normal_close_game_second')::bigint,
      (coalesce((t.tl->'normal_applications_close'->>'absolute_day')::integer,b.start_day-14)::bigint*86400)
        + coalesce((t.tl->'normal_applications_close'->>'minute_of_day')::bigint,0)*60
    ) as application_close_game_second,
    coalesce(
      (t.tl->'tournament_start'->>'game_second')::bigint,
      b.start_day::bigint*86400
    ) as tournament_start_game_second,
    coalesce(
      (t.tl->>'draw_publish_game_second')::bigint,
      (coalesce((t.tl->'draw_publish'->>'absolute_day')::integer,b.start_day-3)::bigint*86400)
        + coalesce((t.tl->'draw_publish'->>'minute_of_day')::bigint,0)*60
    ) as draw_game_second,
    cd.draw_grace_game_seconds as draw_grace_game_seconds
  from base b
  join counts c on c.comp_id=b.comp_id
  cross join current_day cd
  left join timelines t on t.comp_id=b.comp_id
),
statused as (
  select
    l.*,
    case
      when l.is_cancelled then 'cancelled'
      when l.entries>0 and (l.draw_published or l.matches>0 or l.current_game_second>=l.tournament_start_game_second) then 'done'
      when l.entries=0 and l.current_abs>l.end_day then 'done'
      when l.current_game_second<l.app_open_game_second then 'waiting'
      when l.current_game_second<=l.application_close_game_second then 'running'
      when l.field_locked then 'done'
      when l.current_game_second<l.tournament_start_game_second then 'running'
      else 'overdue'
    end as s_entry,
    case
      when l.is_cancelled then 'cancelled'
      when l.draw_published or l.matches>0 or l.final_completed then 'done'
      when l.entries<=1 and l.current_abs>l.end_day then 'done'
      when not l.field_locked then 'waiting'
      when l.current_game_second<l.draw_game_second then 'waiting'
      when l.current_game_second<l.draw_game_second+l.draw_grace_game_seconds then 'running'
      else 'overdue'
    end as s_draw,
    case
      when l.is_cancelled then 'cancelled'
      when l.entries=0 and l.current_abs>l.end_day then 'done'
      when l.final_completed then 'done'
      when l.current_game_second<l.tournament_start_game_second then 'waiting'
      when l.current_abs<=l.end_day then 'running'
      else 'overdue'
    end as s_matches,
    case
      when l.is_cancelled then 'cancelled'
      when l.entries=0 and l.current_abs>l.end_day then 'done'
      when not l.final_completed then case when l.current_abs>l.end_day then 'overdue' else 'waiting' end
      when l.results_count<l.entries then 'overdue'
      when l.human_prize_result_count>l.human_prize_payment_count then 'overdue'
      when l.current_abs>=l.rank_publish_day
        and (l.pending_rankings>0 or l.ranking_contributions<l.results_count) then 'overdue'
      when l.current_abs<l.rank_publish_day and l.pending_rankings>0 then 'running'
      else 'done'
    end as s_rewards
  from lifecycle l
),
finalized as (
  select
    s.*,
    case
      when s.is_cancelled then 'cancelled'
      when s.entries=0 and s.current_abs>s.end_day then 'done'
      when s.final_completed
        and s.results_count>=s.entries
        and s.human_prize_result_count=s.human_prize_payment_count
        and (s.current_abs<s.rank_publish_day or (s.pending_rankings=0 and s.ranking_contributions>=s.results_count))
        and s.stale_calendar_count=0
      then 'done'
      when s.current_abs<=s.end_day then case when s.current_abs<s.start_day then 'waiting' else 'running' end
      else 'overdue'
    end as s_closure
  from statused s
),
issues as (
  select
    f.*,
    (f.s_entry='overdue' or f.s_draw='overdue' or f.s_matches='overdue' or f.s_rewards='overdue' or f.s_closure='overdue' or f.stale_calendar_count>0) as problem,
    case
      when f.s_entry='overdue' then 'entry_lifecycle_overdue'
      when f.s_draw='overdue' then 'draw_overdue'
      when f.s_matches='overdue' then 'tournament_not_finished'
      when f.results_count<f.entries and f.final_completed then 'results_incomplete'
      when f.human_prize_result_count>f.human_prize_payment_count then 'prize_payment_missing'
      when f.current_abs>=f.rank_publish_day and f.pending_rankings>0 then 'ranking_publication_pending'
      when f.current_abs>=f.rank_publish_day and f.ranking_contributions<f.results_count then 'ranking_contribution_missing'
      when f.stale_calendar_count>0 then 'calendar_cleanup_missing'
      when f.s_rewards='overdue' then 'rewards_incomplete'
      when f.s_closure='overdue' then 'closure_incomplete'
      else null
    end as problem_key,
    case
      when f.human_entries>0 then 'critical'
      when f.s_matches='overdue' or f.s_rewards='overdue' or f.s_closure='overdue' then 'high'
      else 'warning'
    end as problem_severity,
    case
      when f.s_entry='overdue' then 'Entry lifecycle did not finish before tournament start.'
      when f.s_draw='overdue' then 'The official draw is overdue.'
      when f.s_matches='overdue' then 'Tournament dates have ended but no completed main-draw final exists.'
      when f.results_count<f.entries and f.final_completed then 'The final is complete but not every entrant has a finalized tournament result.'
      when f.human_prize_result_count>f.human_prize_payment_count then 'At least one human prize result is missing its idempotent Finance payment.'
      when f.current_abs>=f.rank_publish_day and f.pending_rankings>0 then 'Ranking publication is overdue for finalized tournament results.'
      when f.current_abs>=f.rank_publish_day and f.ranking_contributions<f.results_count then 'One or more published results are missing ranking contributions.'
      when f.stale_calendar_count>0 then 'Past tournament calendar commitments are still active.'
      when f.s_rewards='overdue' then 'Tournament rewards are incomplete.'
      when f.s_closure='overdue' then 'Tournament closure is incomplete.'
      else null
    end as problem_message
  from finalized f
),
with_incident as (
  select i.*,si.id as inc_id,si.status as inc_status,si.first_seen_at as inc_first_seen,si.last_seen_at as inc_last_seen
  from issues i
  left join lateral (
    select x.id,x.status,x.first_seen_at,x.last_seen_at
    from public.system_incidents x
    where x.dedupe_key='tournament-ops:'||i.comp_id::text
      and x.status in ('open','acknowledged')
    order by x.created_at desc
    limit 1
  ) si on true
)
select
  w.comp_id,w.t_name,w.comp_world,w.cat_code,w.t_city,w.season_no,w.start_day,w.end_day,
  w.app_open_day,w.app_close_day,w.draw_day,w.rank_publish_day,
  case
    when w.is_cancelled then 'cancelled'
    when w.current_game_second<w.app_open_game_second then 'upcoming'
    when w.current_game_second<w.tournament_start_game_second then 'pre_tournament'
    when w.current_abs<=w.end_day and not w.final_completed then 'in_progress'
    when w.s_closure='done' then 'completed'
    else 'post_tournament'
  end::text,
  w.s_entry::text,w.s_draw::text,w.s_matches::text,w.s_rewards::text,w.s_closure::text,
  w.applications,w.entries,w.human_entries,w.matches,w.completed_count,w.bye_count,w.cancelled_count,
  w.scheduled_count,w.in_progress_count,w.playable_unresolved,w.results_count,w.pending_rankings,
  w.ranking_contributions,w.human_prize_result_count,w.human_prize_payment_count,w.stale_calendar_count,
  w.final_completed,w.champion,
  case when w.champion is null then null else nullif(trim(coalesce(p.first_name,'')||' '||coalesce(p.last_name,'')),'') end::text,
  w.problem,w.problem_key::text,w.problem_severity::text,w.problem_message::text,
  w.inc_id,w.inc_status::text,w.inc_first_seen,w.inc_last_seen
from with_incident w
left join public.players p on p.id=w.champion
where case lower(coalesce(p_view,'today'))
  when 'problems' then w.problem or w.inc_id is not null
  when 'history' then w.end_day between w.current_abs-greatest(1,least(coalesce(p_days,7),60)) and w.current_abs
  else w.current_abs between w.app_open_day and w.rank_publish_day
end
order by w.problem desc,
  case when w.current_abs between w.start_day and w.end_day then 0 else 1 end,
  w.start_day,w.t_name,w.comp_world;
$function$

