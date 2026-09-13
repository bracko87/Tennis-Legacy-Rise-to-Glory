create or replace function public.process_private_life_running_costs_for_player_v1(p_player_id uuid, p_through_absolute_day integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_user_id uuid;
  m record;
  r record;
  v_total bigint;
  v_count integer;
  v_all_events integer := 0;
  v_all_total bigint := 0;
  v_breakdown jsonb;
  v_fin jsonb;
  v_tx uuid;
  v_month_name text;
begin
  select owner_user_id into v_user_id from public.players where id=p_player_id;
  if v_user_id is null then
    return jsonb_build_object('status','skipped','reason','player_not_found_or_not_human','events',0,'total_cost',0);
  end if;

  for m in
    select distinct due.absolute_day,due.season,due.month
    from public.private_life_player_assets o
    join public.private_life_asset_catalog c on c.code=o.catalog_code
    cross join lateral (
      select gs::integer as absolute_day,gd.season,gd.month
      from generate_series(
        o.purchase_absolute_day+1,
        least(p_through_absolute_day,coalesce(o.sold_absolute_day-1,p_through_absolute_day))
      ) gs
      cross join lateral public.absolute_game_day_v1(gs::integer) gd
      where gd.day=1
    ) due
    where o.player_id=p_player_id
      and coalesce(o.annual_running_cost_override,c.annual_running_cost)>0
      and o.purchase_absolute_day<p_through_absolute_day
      and not exists (
        select 1 from public.private_life_asset_events e
        where e.player_asset_id=o.id
          and e.event_key='running_cost:'||due.season::text||':'||due.month::text
      )
    order by due.absolute_day
  loop
    select
      coalesce(sum(greatest(1,round(coalesce(o.annual_running_cost_override,c.annual_running_cost)::numeric/12)::bigint)),0)::bigint,
      count(*)::integer,
      coalesce(jsonb_agg(jsonb_build_object(
        'player_asset_id',o.id,
        'catalog_code',o.catalog_code,
        'category',c.category,
        'name',c.name,
        'monthly_cost',greatest(1,round(coalesce(o.annual_running_cost_override,c.annual_running_cost)::numeric/12)::bigint)
      ) order by o.created_at,o.id),'[]'::jsonb)
    into v_total,v_count,v_breakdown
    from public.private_life_player_assets o
    join public.private_life_asset_catalog c on c.code=o.catalog_code
    where o.player_id=p_player_id
      and coalesce(o.annual_running_cost_override,c.annual_running_cost)>0
      and o.purchase_absolute_day<m.absolute_day
      and (o.sold_absolute_day is null or o.sold_absolute_day>m.absolute_day)
      and not exists (
        select 1 from public.private_life_asset_events e
        where e.player_asset_id=o.id
          and e.event_key='running_cost:'||m.season::text||':'||m.month::text
      );

    if v_total<=0 or v_count<=0 then
      continue;
    end if;

    v_month_name:=to_char(make_date(2000,m.month,1),'FMMonth');
    v_fin:=public.post_career_finance_transaction_v1(
      p_player_id,
      -v_total,
      'private_life',
      'monthly_costs',
      'Private Life monthly costs · '||v_month_name,
      'private_life_monthly_costs',
      p_player_id::text||':'||m.season::text||':'||m.month::text,
      'private-life-monthly-costs:'||p_player_id::text||':'||m.season::text||':'||m.month::text,
      jsonb_build_object(
        'season',m.season,
        'month',m.month,
        'month_name',v_month_name,
        'total_cost',v_total,
        'asset_count',v_count,
        'breakdown',v_breakdown
      ),
      true,
      m.absolute_day
    );
    v_tx:=(v_fin->>'transaction_id')::uuid;

    for r in
      select o.id as player_asset_id,o.catalog_code,c.category,c.name,
             coalesce(o.annual_running_cost_override,c.annual_running_cost) as annual_running_cost,
             greatest(1,round(coalesce(o.annual_running_cost_override,c.annual_running_cost)::numeric/12)::bigint) as monthly_cost
      from public.private_life_player_assets o
      join public.private_life_asset_catalog c on c.code=o.catalog_code
      where o.player_id=p_player_id
        and coalesce(o.annual_running_cost_override,c.annual_running_cost)>0
        and o.purchase_absolute_day<m.absolute_day
        and (o.sold_absolute_day is null or o.sold_absolute_day>m.absolute_day)
        and not exists (
          select 1 from public.private_life_asset_events e
          where e.player_asset_id=o.id
            and e.event_key='running_cost:'||m.season::text||':'||m.month::text
        )
      order by o.created_at,o.id
    loop
      insert into public.private_life_asset_events(
        player_id,player_asset_id,event_type,event_absolute_day,amount,finance_transaction_id,event_key,title,description,metadata
      ) values(
        p_player_id,r.player_asset_id,'running_cost',m.absolute_day,-r.monthly_cost,v_tx,
        'running_cost:'||m.season::text||':'||m.month::text,
        'Monthly Private Life cost',
        v_month_name||' living / maintenance cost for '||r.name||'.',
        jsonb_build_object(
          'catalog_code',r.catalog_code,
          'category',r.category,
          'season',m.season,
          'month',m.month,
          'annual_running_cost',r.annual_running_cost,
          'monthly_cost',r.monthly_cost,
          'aggregated_finance_transaction',true
        )
      ) on conflict(player_asset_id,event_key) do nothing;
    end loop;

    perform public.emit_notification_v1(
      v_user_id,
      p_player_id,
      'player.private_life.running_costs',
      'Private Life monthly costs',
      '$'||to_char(v_total,'FM999G999G999G990')||' was deducted from your Finance balance for '||v_month_name||' living and maintenance costs.',
      '/game/private-life',
      jsonb_build_object(
        'total_cost',v_total,
        'asset_count',v_count,
        'season',m.season,
        'month',m.month,
        'month_name',v_month_name,
        'finance_transaction_id',v_tx,
        'breakdown',v_breakdown
      ),
      'private-life-monthly-costs:'||p_player_id::text||':'||m.season::text||':'||m.month::text
    );

    v_all_events:=v_all_events+v_count;
    v_all_total:=v_all_total+v_total;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'events',v_all_events,
    'total_cost',v_all_total,
    'through_absolute_day',p_through_absolute_day
  );
end;
$function$;

update public.notification_catalog
set label='Private Life monthly costs',
    reason='Inform players when their combined monthly Private Life living and maintenance costs reduce career Finance.',
    trigger_event='Combined monthly Private Life costs are processed on the first game day of a month.',
    trigger_condition='At least one owned Private Life asset has a monthly living or maintenance charge due.',
    trigger_mechanism='Private Life monthly-cost processor',
    title_template='Private Life monthly costs',
    message_template='Your combined Private Life living and maintenance costs were deducted from your career Finance balance.',
    updated_at=now()
where code='player.private_life.running_costs';