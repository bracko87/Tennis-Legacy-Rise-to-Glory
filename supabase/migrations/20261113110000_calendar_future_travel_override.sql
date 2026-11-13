-- Future-only calendar travel override; no retroactive changes to completed legs.
-- Route selection is shared with the Tournament Preparation page.
CREATE OR REPLACE FUNCTION public.save_tournament_transfer_preference_v1(p_player_id uuid, p_competition_id uuid, p_route_choice text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_context jsonb; v_source_id uuid;v_now integer;v_choice text;
 v_refund_total bigint:=0;v_count integer:=0;r record;v_posted jsonb;v_rebuild jsonb;
begin
 if p_route_choice not in ('home','direct') or p_route_choice is null then
   raise exception 'Invalid transfer choice.'; end if;
 v_context:=public.get_tournament_transfer_preference_v1(p_player_id,p_competition_id);
 if not coalesce((v_context->>'available')::boolean,false) then
   raise exception 'Tournament transfer can no longer be changed.'; end if;
 v_source_id:=(v_context->>'source_competition_id')::uuid;
 v_choice:=v_context->>'route_choice';
 if v_choice=p_route_choice then
   return jsonb_build_object('saved',true,'changed',false,'route_choice',p_route_choice,
      'refunded_amount',0,'refunded_transactions',0,'source_competition_id',v_source_id);
 end if;
 select public.game_day_absolute_v1(season,month,day) into v_now
 from public.get_current_game_day_internal_v1();
 -- Never modify flights already due today or in the past.
 if exists(
  select 1 from public.player_travel_legs l where l.player_id=p_player_id
    and l.status='planned' and l.departure_absolute_day<=v_now
    and (
      (l.source_location_type='tournament' and l.source_reference_id=v_source_id::text
        and (l.purpose='return_home' or l.destination_reference_id=p_competition_id::text))
      or (l.destination_location_type='tournament' and l.destination_reference_id=p_competition_id::text)
    )
 ) then raise exception 'The flight is due or has started. Only future flights may be changed.'; end if;
 -- The usual game flow charges on completion. This handles any genuine
 -- prepayment on an UNUSED planned leg, with exactly-once refund keys.
 for r in
  select distinct t.id,t.amount,t.description,l.id as leg_id
  from public.player_travel_legs l
  join public.career_finance_transactions t
    on t.player_id=l.player_id and t.source_type='travel_leg'
    and t.source_id=l.id::text and t.amount<0 and t.category='travel'
  where l.player_id=p_player_id and l.status='planned'
    and l.departure_absolute_day>v_now
    and (
      (l.source_location_type='tournament' and l.source_reference_id=v_source_id::text
        and (l.purpose='return_home' or l.destination_reference_id=p_competition_id::text))
      or (l.destination_location_type='tournament' and l.destination_reference_id=p_competition_id::text)
    )
    and not exists (
      select 1 from public.career_finance_transactions prior
      where prior.player_id=p_player_id
        and prior.idempotency_key='unused-travel-rebook-refund:'||t.id::text
    )
  order by t.id,t.amount,t.description,l.id
 loop
  v_posted:=public.post_career_finance_transaction_v1(
   p_player_id,-r.amount,'refund','unused_travel_rebooking',
   format('Unused flight rebooking refund — %s',r.description),
   'travel_rebooking',r.leg_id::text,
   'unused-travel-rebook-refund:'||r.id::text,
   jsonb_build_object('original_transaction_id',r.id,'original_travel_leg_id',r.leg_id,
    'source_competition_id',v_source_id,'destination_competition_id',p_competition_id),
   false,v_now
  );
  if v_posted->>'status'='posted' then
    v_refund_total:=v_refund_total-r.amount;v_count:=v_count+1;
  end if;
 end loop;
 insert into public.player_tournament_transfer_preferences
 (player_id,competition_id,source_competition_id,route_choice,updated_at)
 values(p_player_id,p_competition_id,v_source_id,p_route_choice,now())
 on conflict(player_id,competition_id) do update
 set source_competition_id=excluded.source_competition_id,
 route_choice=excluded.route_choice,updated_at=excluded.updated_at;
 v_rebuild:=public.rebuild_player_travel_plan_v1(p_player_id);
 return jsonb_build_object('saved',true,'changed',true,'route_choice',p_route_choice,
 'refunded_amount',v_refund_total,'refunded_transactions',v_count,
 'source_competition_id',v_source_id,'competition_id',p_competition_id);
end;
$function$
;
create or replace function public.get_calendar_transfer_options_v1(
 p_season integer,p_month smallint
) returns jsonb language plpgsql stable security definer
set search_path='public','pg_temp'
as $function$
declare v_player uuid;v_now integer;v_result jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required.'; end if;
 if p_month not between 1 and 12 or p_season<1 then raise exception 'Invalid month or season.'; end if;
 select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human' limit 1;
 if v_player is null then raise exception 'Player not found.'; end if;
 select public.game_day_absolute_v1(season,month,day) into v_now
 from public.get_current_game_day_internal_v1();
 select coalesce(jsonb_agg(jsonb_build_object(
  'departure_absolute_day',row.depart_day,
  'destination_competition_id',row.dest_id,
  'source_competition_id',row.source_id,
  'source_tournament_name',row.source_name,
  'destination_tournament_name',row.dest_name,
  'source_city',row.source_city,
  'destination_city',row.dest_city,
  'route_choice',row.choice,
  'has_planned_flight',row.planned_flight,
  'has_existing_payment',row.refundable_paid_cost>0,
  'refundable_paid_cost',row.refundable_paid_cost
 ) order by row.depart_day,row.dest_name),'[]'::jsonb)
 into v_result
 from (
  select destination.reference_id::uuid dest_id,
   prior.reference_id::uuid source_id,
   coalesce(source_name.name,prior.city) source_name,
   coalesce(destination_name.name,destination.city) dest_name,
   prior.city source_city,destination.city dest_city,
   ctx.context->>'route_choice' choice,
   coalesce(leg.departure_absolute_day,greatest(v_now+1,prior.end_absolute_day+1)) depart_day,
   leg.id is not null planned_flight,
   coalesce((
    select sum(-t.amount)
    from public.player_travel_legs paid_leg
    join public.career_finance_transactions t
     on t.player_id=paid_leg.player_id and t.source_type='travel_leg'
       and t.source_id=paid_leg.id::text and t.amount<0 and t.category='travel'
    where paid_leg.player_id=v_player and paid_leg.status='planned'
      and paid_leg.departure_absolute_day>v_now
      and (
        (paid_leg.source_reference_id=prior.reference_id and paid_leg.source_location_type='tournament'
         and (paid_leg.purpose='return_home' or paid_leg.destination_reference_id=destination.reference_id))
        or (paid_leg.destination_reference_id=destination.reference_id and paid_leg.destination_location_type='tournament')
      )
      and not exists (
       select 1 from public.career_finance_transactions refund
       where refund.player_id=v_player and refund.idempotency_key='unused-travel-rebook-refund:'||t.id::text
      )
   ),0)::bigint refundable_paid_cost
  from public.player_commitment_locations_v1(v_player) destination
  join public.tournament_entries entry on entry.player_id=v_player
     and entry.competition_id::text=destination.reference_id and entry.entry_status='active'
  cross join lateral (
    select public.get_tournament_transfer_preference_v1(v_player,destination.reference_id::uuid) context
  ) ctx
  join lateral (
    select * from public.player_commitment_locations_v1(v_player) src
     where src.reference_id=ctx.context->>'source_competition_id'
       and src.commitment_type='tournament' limit 1
  ) prior on true
  left join lateral (
    select l.id,l.departure_absolute_day from public.player_travel_legs l
    where l.player_id=v_player and l.status='planned'
      and l.departure_absolute_day>v_now
      and (
        (l.source_reference_id=prior.reference_id and l.source_location_type='tournament'
         and (l.purpose='return_home' or l.destination_reference_id=destination.reference_id))
        or (l.destination_reference_id=destination.reference_id and l.destination_location_type='tournament')
      )
    order by l.departure_absolute_day limit 1
  ) leg on true
  left join lateral (
    select s.name from public.tournament_world_competitions w
    join public.tournament_editions e on e.id=w.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    where w.id=destination.reference_id::uuid
  ) destination_name on true
  left join lateral (
    select s.name from public.tournament_world_competitions w
    join public.tournament_editions e on e.id=w.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    where w.id=prior.reference_id::uuid
  ) source_name on true
  where destination.commitment_type='tournament'
   and destination.start_absolute_day>v_now
   and coalesce((ctx.context->>'available')::boolean,false)
 ) row
 where row.depart_day>v_now
   and exists(
     select 1 from public.absolute_game_day_v1(row.depart_day) d
      where d.season=p_season and d.month=p_month
   );
 return v_result;
end;
$function$;
revoke all on function public.get_calendar_transfer_options_v1(integer,smallint) from public,anon;
grant execute on function public.get_calendar_transfer_options_v1(integer,smallint) to authenticated;
