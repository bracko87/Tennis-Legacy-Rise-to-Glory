create table public.tournament_entries (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  world text not null check (world in ('ATP','WTA')),
  draw_type text not null default 'main_draw' check (draw_type in ('main_draw','qualification')),
  entry_status text not null default 'active' check (entry_status in ('active','eliminated','champion','withdrawn')),
  entry_source text not null default 'application',
  ranking_position_snapshot integer,
  seed_number smallint,
  bracket_slot smallint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (competition_id, player_id)
);

create table public.tournament_matches (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  draw_type text not null default 'main_draw' check (draw_type in ('main_draw','qualification')),
  round_number smallint not null check (round_number > 0),
  round_label text not null,
  match_number smallint not null check (match_number > 0),
  bracket_size smallint not null check (bracket_size > 1),
  scheduled_season_week integer not null,
  scheduled_day smallint not null check (scheduled_day between 1 and 7),
  player1_id uuid references public.players(id) on delete set null,
  player2_id uuid references public.players(id) on delete set null,
  winner_id uuid references public.players(id) on delete set null,
  status text not null default 'scheduled' check (status in ('scheduled','bye','completed','walkover','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (competition_id, draw_type, round_number, match_number)
);

create index tournament_entries_player_idx on public.tournament_entries(player_id, competition_id);
create index tournament_matches_player1_idx on public.tournament_matches(player1_id, scheduled_season_week, scheduled_day);
create index tournament_matches_player2_idx on public.tournament_matches(player2_id, scheduled_season_week, scheduled_day);

alter table public.tournament_entries enable row level security;
alter table public.tournament_matches enable row level security;

create policy tournament_entries_authenticated_read
on public.tournament_entries for select to authenticated using (true);

create policy tournament_matches_authenticated_read
on public.tournament_matches for select to authenticated using (true);

revoke all on public.tournament_entries from anon;
revoke all on public.tournament_matches from anon;
revoke insert, update, delete on public.tournament_entries from authenticated;
revoke insert, update, delete on public.tournament_matches from authenticated;
grant select on public.tournament_entries to authenticated;
grant select on public.tournament_matches to authenticated;

create or replace function public.get_tournament_draw_v1(p_competition_id uuid)
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
  player2_id uuid,
  player2_first_name text,
  player2_last_name text,
  player2_country_code text,
  player2_seed smallint,
  winner_id uuid
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  return query
  select m.id,m.draw_type,m.round_number,m.round_label,m.match_number,m.bracket_size,
    m.scheduled_season_week,m.scheduled_day,m.status,
    p1.id,p1.first_name,p1.last_name,p1.country_code,e1.seed_number,
    p2.id,p2.first_name,p2.last_name,p2.country_code,e2.seed_number,m.winner_id
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

create or replace function public.get_player_next_match_v1(p_player_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if not exists(select 1 from public.players p where p.id=p_player_id and p.moderation_status <> 'rejected') then
    raise exception 'Player not found.';
  end if;
  select jsonb_build_object(
    'match_id',m.id,'competition_id',m.competition_id,'tournament_name',s.name,'city',s.city,'country_code',s.country_code,
    'round_label',m.round_label,'season_week',m.scheduled_season_week,'day',m.scheduled_day,'status',m.status,
    'opponent_id',case when m.player1_id=p_player_id then m.player2_id else m.player1_id end,
    'opponent_first_name',case when m.player1_id=p_player_id then p2.first_name else p1.first_name end,
    'opponent_last_name',case when m.player1_id=p_player_id then p2.last_name else p1.last_name end,
    'opponent_country_code',case when m.player1_id=p_player_id then p2.country_code else p1.country_code end
  ) into v_result
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  left join public.players p1 on p1.id=m.player1_id
  left join public.players p2 on p2.id=m.player2_id
  where (m.player1_id=p_player_id or m.player2_id=p_player_id) and m.status='scheduled'
  order by m.scheduled_season_week,m.scheduled_day,m.match_number
  limit 1;
  return v_result;
end;
$$;
revoke all on function public.get_player_next_match_v1(uuid) from public;
revoke all on function public.get_player_next_match_v1(uuid) from anon;
grant execute on function public.get_player_next_match_v1(uuid) to authenticated;
