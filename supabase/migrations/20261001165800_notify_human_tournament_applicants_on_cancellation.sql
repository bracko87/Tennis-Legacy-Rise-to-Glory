create or replace function public.finalize_tournament_cancellation_v1(
  p_competition_id uuid,
  p_reason_code text,
  p_reason_message text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public
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
    with affected_players as (
      select te.player_id
      from public.tournament_entries te
      where te.competition_id=p_competition_id
      union
      select ta.player_id
      from public.tournament_applications ta
      where ta.competition_id=p_competition_id
        and ta.status in ('applied','accepted_main_draw','accepted_qualification')
    )
    select distinct p.id player_id,p.owner_user_id
    from affected_players ap
    join public.players p on p.id=ap.player_id
    where p.player_type='human'
      and p.owner_user_id is not null
  loop
    v_refund:=public.refund_tournament_cancellation_costs_v1(r.player_id,p_competition_id,p_reason_code);
    v_refunded:=coalesce((v_refund->>'refunded_amount')::bigint,0);

    update public.user_notifications
    set archived_at=coalesce(archived_at,now())
    where user_id=r.owner_user_id
      and player_id=r.player_id
      and notification_code='tournament.preparation.available'
      and payload->>'competition_id'=p_competition_id::text
      and archived_at is null;

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
