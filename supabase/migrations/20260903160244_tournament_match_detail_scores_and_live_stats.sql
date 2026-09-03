alter table public.tournament_matches drop constraint if exists tournament_matches_status_check;
alter table public.tournament_matches
  add constraint tournament_matches_status_check
  check (status in ('scheduled','in_progress','bye','completed','walkover','cancelled'));

alter table public.tournament_matches
  add column if not exists started_at timestamptz,
  add column if not exists completed_at timestamptz;

create table if not exists public.tournament_match_sets (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.tournament_matches(id) on delete cascade,
  set_number smallint not null check (set_number between 1 and 5),
  player1_games smallint not null default 0 check (player1_games between 0 and 99),
  player2_games smallint not null default 0 check (player2_games between 0 and 99),
  player1_tiebreak_points smallint,
  player2_tiebreak_points smallint,
  status text not null default 'in_progress' check (status in ('in_progress','completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (match_id, set_number)
);

create table if not exists public.tournament_match_player_stats (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.tournament_matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  aces integer not null default 0 check (aces >= 0),
  double_faults integer not null default 0 check (double_faults >= 0),
  first_serves_in integer not null default 0 check (first_serves_in >= 0),
  first_serves_total integer not null default 0 check (first_serves_total >= 0),
  first_serve_points_won integer not null default 0 check (first_serve_points_won >= 0),
  first_serve_points_played integer not null default 0 check (first_serve_points_played >= 0),
  second_serve_points_won integer not null default 0 check (second_serve_points_won >= 0),
  second_serve_points_played integer not null default 0 check (second_serve_points_played >= 0),
  break_points_won integer not null default 0 check (break_points_won >= 0),
  break_points_total integer not null default 0 check (break_points_total >= 0),
  winners integer not null default 0 check (winners >= 0),
  unforced_errors integer not null default 0 check (unforced_errors >= 0),
  total_points_won integer not null default 0 check (total_points_won >= 0),
  updated_at timestamptz not null default now(),
  unique (match_id, player_id)
);

create index if not exists tournament_match_sets_match_idx on public.tournament_match_sets(match_id, set_number);
create index if not exists tournament_match_player_stats_match_idx on public.tournament_match_player_stats(match_id, player_id);

alter table public.tournament_match_sets enable row level security;
alter table public.tournament_match_player_stats enable row level security;

drop policy if exists tournament_match_sets_authenticated_read on public.tournament_match_sets;
create policy tournament_match_sets_authenticated_read on public.tournament_match_sets for select to authenticated using (true);
drop policy if exists tournament_match_player_stats_authenticated_read on public.tournament_match_player_stats;
create policy tournament_match_player_stats_authenticated_read on public.tournament_match_player_stats for select to authenticated using (true);

revoke all on public.tournament_match_sets from anon;
revoke all on public.tournament_match_player_stats from anon;
revoke insert, update, delete on public.tournament_match_sets from authenticated;
revoke insert, update, delete on public.tournament_match_player_stats from authenticated;
grant select on public.tournament_match_sets to authenticated;
grant select on public.tournament_match_player_stats to authenticated;

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='tournament_match_sets') then
    alter publication supabase_realtime add table public.tournament_match_sets;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='tournament_match_player_stats') then
    alter publication supabase_realtime add table public.tournament_match_player_stats;
  end if;
end $$;

drop function if exists public.get_tournament_draw_v1(uuid);
create function public.get_tournament_draw_v1(p_competition_id uuid)
returns table(
  match_id uuid,
  draw_type text,
  round_number smallint,
  round_label text,
  match_number smallint,
  bracket_size smallint,
  scheduled_season_week integer,
  scheduled_day smallint,
  match_status text,
  player1_id uuid,
  player1_first_name text,
  player1_last_name text,
  player1_country_code text,
  player1_seed smallint,
  player1_set_scores smallint[],
  player2_id uuid,
  player2_first_name text,
  player2_last_name text,
  player2_country_code text,
  player2_seed smallint,
  player2_set_scores smallint[],
  winner_id uuid
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  return query
  select m.id,m.draw_type,m.round_number,m.round_label,m.match_number,m.bracket_size,
    m.scheduled_season_week,m.scheduled_day,m.status,
    p1.id,p1.first_name,p1.last_name,p1.country_code,e1.seed_number,
    coalesce((select array_agg(ms.player1_games order by ms.set_number) from public.tournament_match_sets ms where ms.match_id=m.id),'{}'::smallint[]),
    p2.id,p2.first_name,p2.last_name,p2.country_code,e2.seed_number,
    coalesce((select array_agg(ms.player2_games order by ms.set_number) from public.tournament_match_sets ms where ms.match_id=m.id),'{}'::smallint[]),
    m.winner_id
  from public.tournament_matches m
  left join public.players p1 on p1.id=m.player1_id
  left join public.players p2 on p2.id=m.player2_id
  left join public.tournament_entries e1 on e1.competition_id=m.competition_id and e1.player_id=m.player1_id
  left join public.tournament_entries e2 on e2.competition_id=m.competition_id and e2.player_id=m.player2_id
  where m.competition_id=p_competition_id
  order by m.draw_type,m.round_number,m.match_number;
end;
$$;
revoke all on function public.get_tournament_draw_v1(uuid) from public;
revoke all on function public.get_tournament_draw_v1(uuid) from anon;
grant execute on function public.get_tournament_draw_v1(uuid) to authenticated;

create or replace function public.get_tournament_match_detail_v1(p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select jsonb_build_object(
    'match_id',m.id,
    'competition_id',m.competition_id,
    'tournament_name',s.name,
    'city',s.city,
    'country_code',s.country_code,
    'round_label',m.round_label,
    'match_number',m.match_number,
    'scheduled_season_week',m.scheduled_season_week,
    'scheduled_day',m.scheduled_day,
    'status',m.status,
    'winner_id',m.winner_id,
    'started_at',m.started_at,
    'completed_at',m.completed_at,
    'player1',case when p1.id is null then null else jsonb_build_object(
      'id',p1.id,'first_name',p1.first_name,'last_name',p1.last_name,'country_code',p1.country_code,
      'image_path',p1.image_path,'ranking_position',e1.ranking_position_snapshot,'seed',e1.seed_number
    ) end,
    'player2',case when p2.id is null then null else jsonb_build_object(
      'id',p2.id,'first_name',p2.first_name,'last_name',p2.last_name,'country_code',p2.country_code,
      'image_path',p2.image_path,'ranking_position',e2.ranking_position_snapshot,'seed',e2.seed_number
    ) end,
    'sets',coalesce((select jsonb_agg(jsonb_build_object(
      'set_number',ms.set_number,'player1_games',ms.player1_games,'player2_games',ms.player2_games,
      'player1_tiebreak_points',ms.player1_tiebreak_points,'player2_tiebreak_points',ms.player2_tiebreak_points,'status',ms.status
    ) order by ms.set_number) from public.tournament_match_sets ms where ms.match_id=m.id),'[]'::jsonb),
    'player1_stats',coalesce((select to_jsonb(st)-'id'-'match_id'-'player_id'-'updated_at' from public.tournament_match_player_stats st where st.match_id=m.id and st.player_id=m.player1_id),'{}'::jsonb),
    'player2_stats',coalesce((select to_jsonb(st)-'id'-'match_id'-'player_id'-'updated_at' from public.tournament_match_player_stats st where st.match_id=m.id and st.player_id=m.player2_id),'{}'::jsonb)
  ) into v_result
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  left join public.players p1 on p1.id=m.player1_id
  left join public.players p2 on p2.id=m.player2_id
  left join public.tournament_entries e1 on e1.competition_id=m.competition_id and e1.player_id=m.player1_id
  left join public.tournament_entries e2 on e2.competition_id=m.competition_id and e2.player_id=m.player2_id
  where m.id=p_match_id;

  return v_result;
end;
$$;
revoke all on function public.get_tournament_match_detail_v1(uuid) from public;
revoke all on function public.get_tournament_match_detail_v1(uuid) from anon;
grant execute on function public.get_tournament_match_detail_v1(uuid) to authenticated;