create table if not exists public.tournament_cancellations (
  competition_id uuid primary key references public.tournament_world_competitions(id) on delete cascade,
  reason_code text not null,
  reason_message text not null,
  accepted_players integer,
  minimum_players integer,
  metadata jsonb not null default '{}'::jsonb,
  canceled_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

revoke all on table public.tournament_cancellations from anon, authenticated;

insert into public.notification_catalog (
  code, category, label, reason, trigger_event, trigger_condition, trigger_mechanism,
  source_name, title_template, message_template, default_route, severity,
  default_in_app, default_email, default_push, is_user_configurable, is_active,
  created_at, updated_at
)
values (
  'tournament.canceled',
  'tournament',
  'Tournament canceled',
  'Inform an entered player that a tournament was canceled and report any automatic refund.',
  'tournament_canceled',
  'A tournament containing a human player is canceled.',
  'Tournament cancellation flow',
  'Tournament Calendar',
  'Tournament canceled',
  'The tournament was canceled. Tournament-related costs are refunded automatically.',
  '/game/calendar?tab=tournament-calendar',
  'warning',
  true,
  false,
  false,
  true,
  true,
  now(),
  now()
)
on conflict (code) do update set
  category=excluded.category,
  label=excluded.label,
  reason=excluded.reason,
  trigger_event=excluded.trigger_event,
  trigger_condition=excluded.trigger_condition,
  trigger_mechanism=excluded.trigger_mechanism,
  source_name=excluded.source_name,
  title_template=excluded.title_template,
  message_template=excluded.message_template,
  default_route=excluded.default_route,
  severity=excluded.severity,
  default_in_app=excluded.default_in_app,
  is_user_configurable=excluded.is_user_configurable,
  is_active=true,
  updated_at=now();

create or replace function public.refund_tournament_cancellation_costs_v1(
  p_player_id uuid,
  p_competition_id uuid,
  p_reason_code text default 'tournament_canceled'
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  r record;
  v_result jsonb;
  v_total bigint:=0;
  v_count integer:=0;
begin
  for r in
    select distinct t.id,t.amount,t.description,t.game_absolute_day
    from public.career_finance_transactions t
    where t.player_id=p_player_id
      and t.amount<0
      and (
        t.source_id=p_competition_id::text
        or t.metadata->>'competition_id'=p_competition_id::text
        or (
          t.source_type='travel_leg'
          and exists(
            select 1
            from public.player_travel_legs l
            where l.player_id=p_player_id
              and l.id::text=t.source_id
              and (
                l.destination_reference_id=p_competition_id::text
                or l.source_reference_id=p_competition_id::text
              )
          )
        )
      )
      and not exists(
        select 1
        from public.career_finance_transactions refund
        where refund.player_id=p_player_id
          and refund.idempotency_key='tournament-cancel-refund:'||p_competition_id::text||':'||t.id::text
      )
    order by t.game_absolute_day,t.id
  loop
    v_result:=public.post_career_finance_transaction_v1(
      p_player_id,
      -r.amount,
      'refund',
      'tournament_cancellation',
      format('Tournament cancellation refund — %s',r.description),
      'tournament_cancellation',
      p_competition_id::text,
      'tournament-cancel-refund:'||p_competition_id::text||':'||r.id::text,
      jsonb_build_object(
        'competition_id',p_competition_id,
        'original_transaction_id',r.id,
        'reason_code',p_reason_code,
        'original_amount',r.amount
      ),
      false,
      null
    );
    v_total:=v_total+(-r.amount);
    v_count:=v_count+1;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'refunded_amount',v_total,
    'refunded_transactions',v_count
  );
end;
$$;

revoke all on function public.refund_tournament_cancellation_costs_v1(uuid,uuid,text) from public, anon, authenticated;

create or replace function public.finalize_tournament_cancellation_v1(
  p_competition_id uuid,
  p_reason_code text,
  p_reason_message text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_name text;
  v_count integer:=0;
  v_minimum integer:=nullif(p_metadata->>'minimum_players','')::integer;
  r record;
  v_refund jsonb;
  v_refunded bigint;
  v_notified integer:=0;
begin
  select ts.name
  into v_name
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=p_competition_id;

  if v_name is null then raise exception 'Tournament competition not found.'; end if;

  select count(*) into v_count
  from public.tournament_entries
  where competition_id=p_competition_id and entry_status='active';

  update public.tournament_world_competitions
  set status='canceled'
  where id=p_competition_id and status<>'canceled';

  insert into public.tournament_cancellations(
    competition_id,reason_code,reason_message,accepted_players,minimum_players,metadata,canceled_at,updated_at
  ) values(
    p_competition_id,p_reason_code,p_reason_message,v_count,v_minimum,coalesce(p_metadata,'{}'::jsonb),now(),now()
  )
  on conflict(competition_id) do update set
    reason_code=excluded.reason_code,
    reason_message=excluded.reason_message,
    accepted_players=excluded.accepted_players,
    minimum_players=excluded.minimum_players,
    metadata=public.tournament_cancellations.metadata||excluded.metadata,
    updated_at=now();

  for r in
    select distinct p.id player_id,p.owner_user_id
    from public.tournament_entries te
    join public.players p on p.id=te.player_id
    where te.competition_id=p_competition_id
      and p.player_type='human'
      and p.owner_user_id is not null
  loop
    v_refund:=public.refund_tournament_cancellation_costs_v1(r.player_id,p_competition_id,p_reason_code);
    v_refunded:=coalesce((v_refund->>'refunded_amount')::bigint,0);

    begin
      perform public.rebuild_player_travel_plan_v1(r.player_id);
    exception when others then
      null;
    end;

    perform public.emit_notification_v1(
      r.owner_user_id,
      r.player_id,
      'tournament.canceled',
      format('Tournament canceled · %s',v_name),
      p_reason_message || case
        when v_refunded>0 then format(' $%s in tournament-related costs has been refunded automatically.',v_refunded)
        else ' No tournament-related costs had been charged, so no refund was required.'
      end,
      '/game/calendar?tab=tournament-calendar',
      jsonb_build_object(
        'competition_id',p_competition_id,
        'tournament_name',v_name,
        'reason_code',p_reason_code,
        'reason_message',p_reason_message,
        'accepted_players',v_count,
        'minimum_players',v_minimum,
        'refunded_amount',v_refunded,
        'refund',v_refund
      ) || coalesce(p_metadata,'{}'::jsonb),
      'tournament-canceled:'||p_competition_id::text
    );
    v_notified:=v_notified+1;
  end loop;

  return jsonb_build_object(
    'status','canceled',
    'competition_id',p_competition_id,
    'tournament_name',v_name,
    'reason_code',p_reason_code,
    'accepted_players',v_count,
    'minimum_players',v_minimum,
    'human_players_notified',v_notified
  );
end;
$$;

revoke all on function public.finalize_tournament_cancellation_v1(uuid,text,text,jsonb) from public, anon, authenticated;

create or replace function public.cancel_tournament_for_minimum_field_v1(p_competition_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_count integer;
  v_result jsonb;
  v_message text;
begin
  select count(*) into v_count
  from public.tournament_entries
  where competition_id=p_competition_id and entry_status='active';

  if v_count>=8 then
    return jsonb_build_object('status','field_valid','accepted_players',v_count,'minimum_players',8);
  end if;

  v_message:=format(
    'The tournament was canceled because the final field contained only %s accepted player%s; at least 8 are required.',
    v_count,
    case when v_count=1 then '' else 's' end
  );

  v_result:=public.finalize_tournament_cancellation_v1(
    p_competition_id,
    'minimum_field_not_met',
    v_message,
    jsonb_build_object('accepted_players',v_count,'minimum_players',8)
  );

  return jsonb_build_object(
    'status','canceled_minimum_field',
    'accepted_players',v_count,
    'minimum_players',8,
    'cancellation',v_result
  );
end;
$$;

create or replace function public.get_tournament_status_v1(p_competition_id uuid)
returns table(
  tournament_status text,
  tournament_status_label text,
  applications_open boolean,
  application_open_day bigint,
  application_close_day bigint,
  tournament_start_day bigint,
  tournament_end_day bigint,
  user_status text,
  user_status_label text,
  user_entry_projection text
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  j jsonb;
  tl jsonb;
  u jsonb;
  v_phase text;
  v_app text;
  v_draw text;
  v_entry text;
  v_canceled boolean:=false;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select (wc.status='canceled' or e.status='canceled')
  into v_canceled
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  where wc.id=p_competition_id;

  j:=public.get_tournament_entry_lifecycle_v2(p_competition_id);
  tl:=j->'timeline';
  u:=j->'user';
  v_phase:=j->>'phase';
  v_app:=u->>'application_status';
  v_draw:=u->>'entry_draw_type';
  v_entry:=u->>'entry_status';

  application_open_day:=floor((tl->>'applications_open_game_second')::bigint::numeric/86400)::bigint;
  application_close_day:=floor((tl->>'normal_close_game_second')::bigint::numeric/86400)::bigint;
  tournament_start_day:=(tl->'tournament_start'->>'absolute_day')::bigint;

  select max(public.training_camp_week_start_absolute_v1(e.season_number,sl.season_week::smallint)+6)::bigint
  into tournament_end_day
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
  where wc.id=p_competition_id
  group by e.season_number;

  if v_canceled then
    tournament_status:='canceled';
    tournament_status_label:='Canceled';
    applications_open:=false;

    if v_entry is not null or v_app in ('accepted_main_draw','accepted_qualification','applied') then
      user_status:='canceled';
      user_status_label:='Entry canceled · Tournament canceled';
      user_entry_projection:=coalesce(v_draw,case
        when v_app='accepted_main_draw' then 'main_draw'
        when v_app='accepted_qualification' then 'qualification'
        else null end);
    else
      user_status:='not_applied';
      user_status_label:='Not applied';
      user_entry_projection:=null;
    end if;
    return next;
    return;
  end if;

  tournament_status:=v_phase;
  tournament_status_label:=case v_phase
    when 'applications_not_open' then 'Applications not open'
    when 'applications_open' then 'Applications open'
    when 'selection_complete' then 'Selection complete'
    when 'final_vacancies_open' then 'Final vacancies open'
    when 'field_locked' then 'Final field locked'
    when 'draw_published' then 'Draw published'
    when 'in_progress' then 'Tournament in progress'
    when 'completed' then 'Completed'
    else initcap(replace(v_phase,'_',' ')) end;
  applications_open:=v_phase='applications_open';

  if v_entry='eliminated' then user_status:='eliminated';user_status_label:='Eliminated';
  elsif v_phase='in_progress' and v_entry='active' then user_status:='competing';user_status_label:='Competing';
  elsif v_draw='main_draw' and v_entry='active' then user_status:='accepted_main_draw';user_status_label:='Accepted · Main Draw';
  elsif v_draw='qualification' and v_entry='active' then user_status:='accepted_qualification';user_status_label:='Accepted · Qualification';
  elsif v_app='accepted_main_draw' then user_status:='accepted_main_draw';user_status_label:='Accepted · Main Draw';
  elsif v_app='accepted_qualification' then user_status:='accepted_qualification';user_status_label:='Accepted · Qualification';
  elsif v_app='rejected' then user_status:='rejected';user_status_label:='Application rejected';
  elsif v_app='superseded' then user_status:='withdrawn';user_status_label:='Application replaced';
  elsif v_app='withdrawn' then user_status:='withdrawn';user_status_label:='Application withdrawn';
  elsif v_app='applied' then user_status:='pending';user_status_label:='Application pending';
  elsif v_phase in ('selection_complete','final_vacancies_open','field_locked','draw_published','in_progress','completed') then user_status:='did_not_apply';user_status_label:='Did not apply';
  else user_status:='not_applied';user_status_label:='Not applied'; end if;

  user_entry_projection:=case
    when v_draw in ('main_draw','qualification') then v_draw
    when v_app='accepted_main_draw' then 'main_draw'
    when v_app='accepted_qualification' then 'qualification'
    when v_app='rejected' then 'rejected'
    else null end;
  return next;
end;
$$;

create or replace function public.get_tournament_calendar_v2(
  p_season_number integer,
  p_calendar_month integer,
  p_world text
)
returns table(
  competition_id uuid,
  tournament_id uuid,
  edition_id uuid,
  schedule_slot_id uuid,
  world text,
  season_number integer,
  season_week smallint,
  calendar_month smallint,
  month_week smallint,
  phase text,
  tournament_name text,
  city text,
  country_code text,
  country_name text,
  category_code text,
  category_label text,
  winner_points integer,
  main_draw_capacity integer,
  qualifying_capacity_max integer,
  default_qualifier_slots integer,
  surface text,
  environment text,
  tournament_status text,
  tournament_status_label text,
  applications_open boolean,
  application_open_day bigint,
  application_close_day bigint,
  tournament_start_day bigint,
  tournament_end_day bigint,
  user_status text,
  user_status_label text,
  user_entry_projection text
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    wc.id,
    s.id,
    e.id,
    sl.id,
    wc.world,
    e.season_number,
    sl.season_week,
    sl.calendar_month,
    sl.month_week,
    sl.phase,
    s.name,
    s.city,
    s.country_code,
    co.name,
    c.code,
    c.label,
    c.winner_points,
    c.main_draw_capacity,
    c.qualifying_capacity_max,
    c.default_qualifier_slots,
    s.surface,
    s.environment,
    st.tournament_status,
    st.tournament_status_label,
    st.applications_open,
    st.application_open_day,
    st.application_close_day,
    st.tournament_start_day,
    st.tournament_end_day,
    st.user_status,
    st.user_status_label,
    st.user_entry_projection
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id=sl.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id and s.is_active
  join public.tournament_categories c on c.code=s.category_code
  join public.countries co on co.code=s.country_code
  join public.tournament_world_competitions wc on wc.tournament_edition_id=e.id
  cross join lateral public.get_tournament_status_v1(wc.id) st
  where e.season_number=p_season_number
    and sl.calendar_month=p_calendar_month
    and wc.world=upper(p_world)
  order by sl.month_week,c.sort_order,s.name,sl.slot_order;
$$;

-- Backfill cancellation handling for any already-canceled competition containing a human player.
do $$
declare
  r record;
  v_count integer;
  v_message text;
begin
  for r in
    select distinct wc.id
    from public.tournament_world_competitions wc
    join public.tournament_entries te on te.competition_id=wc.id
    join public.players p on p.id=te.player_id
    where wc.status='canceled'
      and p.player_type='human'
      and p.owner_user_id is not null
  loop
    select count(*) into v_count
    from public.tournament_entries
    where competition_id=r.id and entry_status='active';

    if v_count<8 then
      v_message:=format(
        'The tournament was canceled because the final field contained only %s accepted player%s; at least 8 are required.',
        v_count,
        case when v_count=1 then '' else 's' end
      );
      perform public.finalize_tournament_cancellation_v1(
        r.id,
        'minimum_field_not_met',
        v_message,
        jsonb_build_object('accepted_players',v_count,'minimum_players',8,'backfilled',true)
      );
    else
      perform public.finalize_tournament_cancellation_v1(
        r.id,
        'tournament_canceled',
        'The tournament was canceled.',
        jsonb_build_object('backfilled',true)
      );
    end if;
  end loop;
end $$;