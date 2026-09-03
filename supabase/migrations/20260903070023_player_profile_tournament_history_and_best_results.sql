create table if not exists public.player_tournament_results (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  result_code text not null,
  ranking_points_earned integer not null default 0 check (ranking_points_earned >= 0),
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(player_id, competition_id),
  check (result_code in ('champion','runner_up','semifinal','quarterfinal','round_16','round_32','round_64','round_128','qualifying','other'))
);

create index if not exists player_tournament_results_player_completed_idx
  on public.player_tournament_results(player_id, completed_at desc);

alter table public.player_tournament_results enable row level security;
revoke all on public.player_tournament_results from anon, authenticated;

drop trigger if exists player_tournament_results_set_updated_at on public.player_tournament_results;
create trigger player_tournament_results_set_updated_at
before update on public.player_tournament_results
for each row execute function public.set_updated_at();

create or replace function public.tournament_result_label_v1(p_code text)
returns text language sql immutable set search_path=public as $$
  select case p_code
    when 'champion' then 'Champion'
    when 'runner_up' then 'Runner-up'
    when 'semifinal' then 'Semifinal'
    when 'quarterfinal' then 'Quarterfinal'
    when 'round_16' then 'Round of 16'
    when 'round_32' then 'Round of 32'
    when 'round_64' then 'Round of 64'
    when 'round_128' then 'Round of 128'
    when 'qualifying' then 'Qualifying'
    else 'Completed'
  end;
$$;

create or replace function public.tournament_result_weight_v1(p_code text)
returns numeric language sql immutable set search_path=public as $$
  select case p_code
    when 'champion' then 1.00::numeric
    when 'runner_up' then 0.62::numeric
    when 'semifinal' then 0.38::numeric
    when 'quarterfinal' then 0.22::numeric
    when 'round_16' then 0.12::numeric
    when 'round_32' then 0.07::numeric
    when 'round_64' then 0.04::numeric
    when 'round_128' then 0.02::numeric
    when 'qualifying' then 0.01::numeric
    else 0.005::numeric
  end;
$$;

create or replace function public.get_player_tournament_summary_v1(p_player_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_player public.players%rowtype;
  v_current_abs integer;
  v_next jsonb;
  v_recent jsonb;
  v_best jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select * into v_player from public.players where id=p_player_id and moderation_status <> 'rejected';
  if v_player.id is null then raise exception 'Player not found.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_current_abs
  from public.get_current_game_day_internal_v1() d;

  with competition_windows as (
    select wc.id competition_id, e.season_number,
      min(ss.season_week)::smallint start_week,
      max(ss.season_week)::smallint end_week,
      s.name tournament_name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,
      c.label category_label
    from public.tournament_world_competitions wc
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    join public.tournament_categories c on c.code=s.category_code
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
    where wc.world=v_player.world
    group by wc.id,e.season_number,s.name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,c.label
  ), upcoming as (
    select cw.*,
      public.training_camp_week_start_absolute_v1(cw.season_number,cw.start_week) start_abs
    from public.tournament_applications a
    join competition_windows cw on cw.competition_id=a.competition_id
    where a.player_id=p_player_id and a.status='applied'
      and public.training_camp_week_start_absolute_v1(cw.season_number,cw.end_week)+6 >= v_current_abs
    order by start_abs,cw.tournament_name
    limit 5
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'competition_id',u.competition_id,'season',u.season_number,'start_week',u.start_week,'end_week',u.end_week,
    'tournament_name',u.tournament_name,'city',u.city,'country_code',u.country_code,
    'category_code',u.category_code,'category_label',u.category_label,'surface',u.surface,'logo_url',u.logo_url
  ) order by u.start_abs,u.tournament_name),'[]'::jsonb) into v_next from upcoming u;

  with result_rows as (
    select r.id,r.competition_id,r.result_code,r.ranking_points_earned,r.completed_at,
      e.season_number,min(ss.season_week)::smallint start_week,max(ss.season_week)::smallint end_week,
      s.name tournament_name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,
      c.label category_label,c.winner_points,
      public.tournament_result_label_v1(r.result_code) result_label,
      (c.winner_points::numeric*public.tournament_result_weight_v1(r.result_code)) performance_score
    from public.player_tournament_results r
    join public.tournament_world_competitions wc on wc.id=r.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    join public.tournament_categories c on c.code=s.category_code
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
    where r.player_id=p_player_id
    group by r.id,r.competition_id,r.result_code,r.ranking_points_earned,r.completed_at,e.season_number,
      s.name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,c.label,c.winner_points
  ), recent as (
    select * from result_rows order by season_number desc,end_week desc,completed_at desc limit 5
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'result_id',r.id,'competition_id',r.competition_id,'season',r.season_number,'start_week',r.start_week,'end_week',r.end_week,
    'tournament_name',r.tournament_name,'city',r.city,'country_code',r.country_code,
    'category_code',r.category_code,'category_label',r.category_label,'surface',r.surface,'logo_url',r.logo_url,
    'result_code',r.result_code,'result_label',r.result_label,'ranking_points_earned',r.ranking_points_earned
  ) order by r.season_number desc,r.end_week desc,r.completed_at desc),'[]'::jsonb) into v_recent from recent r;

  with result_rows as (
    select r.id,r.competition_id,r.result_code,r.ranking_points_earned,r.completed_at,
      e.season_number,min(ss.season_week)::smallint start_week,max(ss.season_week)::smallint end_week,
      s.name tournament_name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,
      c.label category_label,c.winner_points,
      public.tournament_result_label_v1(r.result_code) result_label,
      (c.winner_points::numeric*public.tournament_result_weight_v1(r.result_code)) performance_score
    from public.player_tournament_results r
    join public.tournament_world_competitions wc on wc.id=r.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    join public.tournament_categories c on c.code=s.category_code
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
    where r.player_id=p_player_id
    group by r.id,r.competition_id,r.result_code,r.ranking_points_earned,r.completed_at,e.season_number,
      s.name,s.city,s.country_code,s.category_code,s.surface,s.logo_url,c.label,c.winner_points
  ), best as (
    select * from result_rows order by performance_score desc,winner_points desc,season_number desc,end_week desc limit 5
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'result_id',b.id,'competition_id',b.competition_id,'season',b.season_number,'start_week',b.start_week,'end_week',b.end_week,
    'tournament_name',b.tournament_name,'city',b.city,'country_code',b.country_code,
    'category_code',b.category_code,'category_label',b.category_label,'surface',b.surface,'logo_url',b.logo_url,
    'result_code',b.result_code,'result_label',b.result_label,'ranking_points_earned',b.ranking_points_earned
  ) order by b.performance_score desc,b.winner_points desc,b.season_number desc,b.end_week desc),'[]'::jsonb) into v_best from best b;

  return jsonb_build_object('next_tournaments',v_next,'recent_tournaments',v_recent,'best_results',v_best);
end;
$$;

grant execute on function public.get_player_tournament_summary_v1(uuid) to authenticated;
