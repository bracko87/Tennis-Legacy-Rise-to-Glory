create table if not exists public.player_tournament_preparation_plans (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null,
  player_id uuid not null references public.players(id) on delete cascade,
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  player_travel_class text not null default 'Economy' check (player_travel_class in ('Economy','Premium Economy','Business','First Class')),
  staff_travel_class text not null default 'Economy' check (staff_travel_class in ('Economy','Premium Economy','Business','First Class')),
  hotel_tier text not null default 'Standard' check (hotel_tier in ('Budget','Standard','Premium','Luxury')),
  selected_staff_contract_ids uuid[] not null default '{}'::uuid[],
  tactic_preset text not null default 'Balanced',
  tactic_approach text not null default 'Balanced',
  tactic_rally text not null default 'Balanced rallies',
  tactic_serve text not null default 'Balanced',
  tactic_return text not null default 'Balanced',
  tactic_court_position text not null default 'Normal baseline',
  tactic_target text not null default 'Automatic',
  tactic_risk text not null default 'Balanced',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (player_id, competition_id)
);

create index if not exists player_tournament_preparation_owner_idx on public.player_tournament_preparation_plans(owner_user_id, player_id, competition_id);

create table if not exists public.player_tournament_match_tactics (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null,
  player_id uuid not null references public.players(id) on delete cascade,
  match_id uuid not null references public.tournament_matches(id) on delete cascade,
  tactic_preset text not null default 'Balanced',
  tactic_approach text not null default 'Balanced',
  tactic_rally text not null default 'Balanced rallies',
  tactic_serve text not null default 'Balanced',
  tactic_return text not null default 'Balanced',
  tactic_court_position text not null default 'Normal baseline',
  tactic_target text not null default 'Automatic',
  tactic_risk text not null default 'Balanced',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (player_id, match_id)
);

create index if not exists player_tournament_match_tactics_owner_idx on public.player_tournament_match_tactics(owner_user_id, player_id, match_id);

alter table public.player_tournament_preparation_plans enable row level security;
alter table public.player_tournament_match_tactics enable row level security;
revoke all on public.player_tournament_preparation_plans from anon, authenticated;
revoke all on public.player_tournament_match_tactics from anon, authenticated;

create or replace function public.get_tournament_preparation_v1(p_player_id uuid, p_competition_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
  v_plan public.player_tournament_preparation_plans%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists (select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then
    raise exception 'Player access denied.';
  end if;

  select * into v_plan
  from public.player_tournament_preparation_plans p
  where p.player_id=p_player_id and p.competition_id=p_competition_id;

  if not found then
    return jsonb_build_object(
      'saved',false,
      'player_travel_class','Economy',
      'staff_travel_class','Economy',
      'hotel_tier','Standard',
      'selected_staff_contract_ids','[]'::jsonb,
      'tactic',jsonb_build_object(
        'preset','Balanced','approach','Balanced','rally','Balanced rallies','serve','Balanced',
        'returnGame','Balanced','courtPosition','Normal baseline','target','Automatic','risk','Balanced'
      )
    );
  end if;

  return jsonb_build_object(
    'saved',true,
    'player_travel_class',v_plan.player_travel_class,
    'staff_travel_class',v_plan.staff_travel_class,
    'hotel_tier',v_plan.hotel_tier,
    'selected_staff_contract_ids',to_jsonb(v_plan.selected_staff_contract_ids),
    'tactic',jsonb_build_object(
      'preset',v_plan.tactic_preset,'approach',v_plan.tactic_approach,'rally',v_plan.tactic_rally,'serve',v_plan.tactic_serve,
      'returnGame',v_plan.tactic_return,'courtPosition',v_plan.tactic_court_position,'target',v_plan.tactic_target,'risk',v_plan.tactic_risk
    ),
    'updated_at',v_plan.updated_at
  );
end;
$$;

create or replace function public.save_tournament_preparation_v1(
  p_player_id uuid,
  p_competition_id uuid,
  p_player_travel_class text,
  p_staff_travel_class text,
  p_hotel_tier text,
  p_selected_staff_contract_ids uuid[],
  p_tactic_preset text,
  p_tactic_approach text,
  p_tactic_rally text,
  p_tactic_serve text,
  p_tactic_return text,
  p_tactic_court_position text,
  p_tactic_target text,
  p_tactic_risk text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
  v_staff uuid[] := coalesce(p_selected_staff_contract_ids,'{}'::uuid[]);
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists (select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then raise exception 'Player access denied.'; end if;
  if not exists (select 1 from public.tournament_entries e where e.player_id=p_player_id and e.competition_id=p_competition_id) then raise exception 'Player is not entered in this tournament.'; end if;

  if p_player_travel_class not in ('Economy','Premium Economy','Business','First Class') then raise exception 'Invalid player travel class.'; end if;
  if p_staff_travel_class not in ('Economy','Premium Economy','Business','First Class') then raise exception 'Invalid staff travel class.'; end if;
  if p_hotel_tier not in ('Budget','Standard','Premium','Luxury') then raise exception 'Invalid hotel tier.'; end if;

  if exists (
    select 1
    from unnest(v_staff) u(contract_id)
    left join public.player_staff_contracts c on c.id=u.contract_id and c.player_id=p_player_id and c.status='active'
    where c.id is null
  ) then raise exception 'One or more selected staff contracts are not active for this player.'; end if;

  select coalesce(array_agg(distinct x order by x),'{}'::uuid[]) into v_staff from unnest(v_staff) x;

  insert into public.player_tournament_preparation_plans(
    owner_user_id,player_id,competition_id,player_travel_class,staff_travel_class,hotel_tier,selected_staff_contract_ids,
    tactic_preset,tactic_approach,tactic_rally,tactic_serve,tactic_return,tactic_court_position,tactic_target,tactic_risk,updated_at
  ) values (
    v_uid,p_player_id,p_competition_id,p_player_travel_class,p_staff_travel_class,p_hotel_tier,v_staff,
    p_tactic_preset,p_tactic_approach,p_tactic_rally,p_tactic_serve,p_tactic_return,p_tactic_court_position,p_tactic_target,p_tactic_risk,now()
  )
  on conflict (player_id,competition_id) do update set
    owner_user_id=excluded.owner_user_id,
    player_travel_class=excluded.player_travel_class,
    staff_travel_class=excluded.staff_travel_class,
    hotel_tier=excluded.hotel_tier,
    selected_staff_contract_ids=excluded.selected_staff_contract_ids,
    tactic_preset=excluded.tactic_preset,
    tactic_approach=excluded.tactic_approach,
    tactic_rally=excluded.tactic_rally,
    tactic_serve=excluded.tactic_serve,
    tactic_return=excluded.tactic_return,
    tactic_court_position=excluded.tactic_court_position,
    tactic_target=excluded.tactic_target,
    tactic_risk=excluded.tactic_risk,
    updated_at=now();

  return public.get_tournament_preparation_v1(p_player_id,p_competition_id);
end;
$$;

create or replace function public.get_tournament_match_tactic_v1(p_player_id uuid, p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.tournament_matches%rowtype;
  v_override public.player_tournament_match_tactics%rowtype;
  v_plan public.player_tournament_preparation_plans%rowtype;
  v_tournament jsonb;
  v_effective jsonb;
  v_override_json jsonb := null;
  v_source text := 'automatic_default';
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists (select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then raise exception 'Player access denied.'; end if;

  select * into v_match from public.tournament_matches m where m.id=p_match_id;
  if not found then raise exception 'Match not found.'; end if;
  if p_player_id is distinct from v_match.player1_id and p_player_id is distinct from v_match.player2_id then raise exception 'This player is not in the selected match.'; end if;

  select * into v_plan from public.player_tournament_preparation_plans p where p.player_id=p_player_id and p.competition_id=v_match.competition_id;
  if found then
    v_tournament := jsonb_build_object('preset',v_plan.tactic_preset,'approach',v_plan.tactic_approach,'rally',v_plan.tactic_rally,'serve',v_plan.tactic_serve,'returnGame',v_plan.tactic_return,'courtPosition',v_plan.tactic_court_position,'target',v_plan.tactic_target,'risk',v_plan.tactic_risk);
    v_source := 'tournament_default';
  else
    v_tournament := jsonb_build_object('preset','Balanced','approach','Balanced','rally','Balanced rallies','serve','Balanced','returnGame','Balanced','courtPosition','Normal baseline','target','Automatic','risk','Balanced');
  end if;

  select * into v_override from public.player_tournament_match_tactics t where t.player_id=p_player_id and t.match_id=p_match_id;
  if found then
    v_override_json := jsonb_build_object('preset',v_override.tactic_preset,'approach',v_override.tactic_approach,'rally',v_override.tactic_rally,'serve',v_override.tactic_serve,'returnGame',v_override.tactic_return,'courtPosition',v_override.tactic_court_position,'target',v_override.tactic_target,'risk',v_override.tactic_risk);
    v_effective := v_override_json;
    v_source := 'match_override';
  else
    v_effective := v_tournament;
  end if;

  return jsonb_build_object(
    'match_status',v_match.status,
    'editable',(v_match.status='scheduled'),
    'source',v_source,
    'tournament_default',v_tournament,
    'override',v_override_json,
    'effective',v_effective
  );
end;
$$;

create or replace function public.save_tournament_match_tactic_v1(
  p_player_id uuid,
  p_match_id uuid,
  p_tactic_preset text,
  p_tactic_approach text,
  p_tactic_rally text,
  p_tactic_serve text,
  p_tactic_return text,
  p_tactic_court_position text,
  p_tactic_target text,
  p_tactic_risk text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.tournament_matches%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists (select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then raise exception 'Player access denied.'; end if;
  select * into v_match from public.tournament_matches m where m.id=p_match_id;
  if not found then raise exception 'Match not found.'; end if;
  if p_player_id is distinct from v_match.player1_id and p_player_id is distinct from v_match.player2_id then raise exception 'This player is not in the selected match.'; end if;
  if v_match.status <> 'scheduled' then raise exception 'Match tactic can only be changed before the match starts.'; end if;

  insert into public.player_tournament_match_tactics(owner_user_id,player_id,match_id,tactic_preset,tactic_approach,tactic_rally,tactic_serve,tactic_return,tactic_court_position,tactic_target,tactic_risk,updated_at)
  values(v_uid,p_player_id,p_match_id,p_tactic_preset,p_tactic_approach,p_tactic_rally,p_tactic_serve,p_tactic_return,p_tactic_court_position,p_tactic_target,p_tactic_risk,now())
  on conflict (player_id,match_id) do update set
    owner_user_id=excluded.owner_user_id,tactic_preset=excluded.tactic_preset,tactic_approach=excluded.tactic_approach,tactic_rally=excluded.tactic_rally,
    tactic_serve=excluded.tactic_serve,tactic_return=excluded.tactic_return,tactic_court_position=excluded.tactic_court_position,tactic_target=excluded.tactic_target,tactic_risk=excluded.tactic_risk,updated_at=now();

  return public.get_tournament_match_tactic_v1(p_player_id,p_match_id);
end;
$$;

create or replace function public.clear_tournament_match_tactic_v1(p_player_id uuid, p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists (select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then raise exception 'Player access denied.'; end if;
  delete from public.player_tournament_match_tactics t where t.player_id=p_player_id and t.match_id=p_match_id and t.owner_user_id=v_uid;
  return public.get_tournament_match_tactic_v1(p_player_id,p_match_id);
end;
$$;

revoke all on function public.get_tournament_preparation_v1(uuid,uuid) from public, anon;
revoke all on function public.save_tournament_preparation_v1(uuid,uuid,text,text,text,uuid[],text,text,text,text,text,text,text,text) from public, anon;
revoke all on function public.get_tournament_match_tactic_v1(uuid,uuid) from public, anon;
revoke all on function public.save_tournament_match_tactic_v1(uuid,uuid,text,text,text,text,text,text,text,text) from public, anon;
revoke all on function public.clear_tournament_match_tactic_v1(uuid,uuid) from public, anon;
grant execute on function public.get_tournament_preparation_v1(uuid,uuid) to authenticated;
grant execute on function public.save_tournament_preparation_v1(uuid,uuid,text,text,text,uuid[],text,text,text,text,text,text,text,text) to authenticated;
grant execute on function public.get_tournament_match_tactic_v1(uuid,uuid) to authenticated;
grant execute on function public.save_tournament_match_tactic_v1(uuid,uuid,text,text,text,text,text,text,text,text) to authenticated;
grant execute on function public.clear_tournament_match_tactic_v1(uuid,uuid) to authenticated;
