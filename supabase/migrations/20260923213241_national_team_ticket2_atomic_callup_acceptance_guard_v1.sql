
drop trigger if exists trg_guard_national_callup_acceptance_plans_v1
  on public.national_team_callups;
drop function if exists private.guard_national_callup_acceptance_plans_v1();

create or replace function public.respond_national_team_callup_v1(
  p_callup_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  c public.national_team_callups%rowtype;
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  p public.players%rowtype;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_availability jsonb;
  v_location_key text;
  v_pending_plan record;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into c
  from public.national_team_callups
  where id=p_callup_id
  for update;

  if not found then raise exception 'Call-up not found.'; end if;

  select * into p from public.players where id=c.player_id;
  if p.owner_user_id is distinct from v_uid then
    raise exception 'This call-up belongs to another player.';
  end if;
  if c.status<>'pending' then
    raise exception 'This call-up has already been answered.';
  end if;
  if v_day>c.response_deadline_absolute_day then
    update public.national_team_callups
    set status='expired',updated_at=now()
    where id=c.id;
    raise exception 'The call-up response deadline has passed.';
  end if;

  select * into f
  from public.national_team_fixtures
  where id=c.fixture_id;

  select * into w
  from public.national_team_windows
  where id=f.window_id;

  if not p_accept then
    update public.national_team_callups
    set status='declined',responded_game_day=v_day,updated_at=now()
    where id=c.id;

    return jsonb_build_object('status','declined','callup_id',c.id);
  end if;

  select
    a.competition_id,
    ts.name,
    ts.city
  into v_pending_plan
  from public.tournament_applications a
  join public.tournament_world_competitions wc
    on wc.id=a.competition_id
  join public.tournament_editions ed
    on ed.id=wc.tournament_edition_id
  join public.tournament_series ts
    on ts.id=ed.tournament_series_id
  cross join lateral public.get_competition_window_v1(a.competition_id) cw
  where a.player_id=c.player_id
    and a.status='applied'
    and cw.start_absolute_day<=w.end_absolute_day
    and cw.end_absolute_day>=w.start_absolute_day
    and not public.is_national_team_engine_competition_v1(a.competition_id)
  order by cw.start_absolute_day,ts.name
  limit 1;

  if v_pending_plan.competition_id is not null then
    return jsonb_build_object(
      'status','blocked',
      'callup_id',c.id,
      'availability',jsonb_build_object(
        'available',false,
        'reason','pending_tournament_application_overlap',
        'blocking_competition_id',v_pending_plan.competition_id,
        'blocking_tournament',v_pending_plan.name,
        'blocking_city',v_pending_plan.city
      )
    );
  end if;

  v_availability:=public.check_player_national_window_availability_v1(
    c.player_id,c.fixture_id
  );

  if not coalesce((v_availability->>'available')::boolean,false) then
    return jsonb_build_object(
      'status','blocked',
      'callup_id',c.id,
      'availability',v_availability
    );
  end if;

  v_location_key:=v_availability->>'location_key';

  update public.national_team_callups
  set status='accepted',responded_game_day=v_day,updated_at=now()
  where id=c.id;

  insert into public.player_calendar_commitments(
    player_id,source_type,source_id,competition_id,event_key,
    starts_absolute_day,ends_absolute_day,location_key,status
  )
  values(
    c.player_id,'national_team',w.id,null,
    'national-team:'||w.id::text,
    w.start_absolute_day,w.end_absolute_day,v_location_key,'committed'
  )
  on conflict do nothing;

  perform public.rebuild_player_travel_plan_v1(c.player_id);

  return jsonb_build_object(
    'status','accepted',
    'callup_id',c.id,
    'window_id',w.id,
    'commitment_start_absolute_day',w.start_absolute_day,
    'commitment_end_absolute_day',w.end_absolute_day
  );
end;
$$;

revoke execute on function public.respond_national_team_callup_v1(uuid, boolean)
  from anon;
grant execute on function public.respond_national_team_callup_v1(uuid, boolean)
  to authenticated;
