create table public.private_life_asset_events (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  player_asset_id uuid not null references public.private_life_player_assets(id) on delete cascade,
  event_type text not null,
  event_absolute_day integer not null,
  amount bigint not null default 0,
  finance_transaction_id uuid references public.career_finance_transactions(id),
  event_key text not null,
  title text not null,
  description text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(player_asset_id,event_key)
);

create index private_life_asset_events_player_day_idx
  on public.private_life_asset_events(player_id,event_absolute_day desc,created_at desc);

alter table public.private_life_asset_events enable row level security;
revoke all on public.private_life_asset_events from public,anon,authenticated;

create or replace function public.record_private_life_asset_lifecycle_event_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
begin
  if tg_op='INSERT' then
    insert into public.private_life_asset_events(
      player_id,player_asset_id,event_type,event_absolute_day,amount,event_key,title,description,metadata
    ) values (
      new.player_id,new.id,'purchase',new.purchase_absolute_day,-new.purchase_price,
      'purchase',
      'Asset purchased',
      'Purchased '||(select name from public.private_life_asset_catalog where code=new.catalog_code)||'.',
      jsonb_build_object('catalog_code',new.catalog_code,'purchase_price',new.purchase_price)
    ) on conflict(player_asset_id,event_key) do nothing;
  elsif tg_op='UPDATE' and old.sold_absolute_day is null and new.sold_absolute_day is not null then
    insert into public.private_life_asset_events(
      player_id,player_asset_id,event_type,event_absolute_day,amount,finance_transaction_id,event_key,title,description,metadata
    ) values (
      new.player_id,new.id,'sale',new.sold_absolute_day,coalesce(new.sold_price,0),new.sale_transaction_id,
      'sale',
      'Asset sold',
      'Sold '||(select name from public.private_life_asset_catalog where code=new.catalog_code)||'.',
      jsonb_build_object('catalog_code',new.catalog_code,'purchase_price',new.purchase_price,'sale_price',new.sold_price,'gain_loss',coalesce(new.sold_price,0)-new.purchase_price)
    ) on conflict(player_asset_id,event_key) do nothing;
  end if;
  return new;
end;
$function$;
revoke all on function public.record_private_life_asset_lifecycle_event_v1() from public,anon,authenticated;

drop trigger if exists trg_private_life_asset_lifecycle_event_v1 on public.private_life_player_assets;
create trigger trg_private_life_asset_lifecycle_event_v1
after insert or update on public.private_life_player_assets
for each row execute function public.record_private_life_asset_lifecycle_event_v1();

insert into public.notification_catalog(
  code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,source_name,
  title_template,message_template,default_route,severity,default_in_app,default_email,default_push,is_user_configurable,is_active
) values (
  'player.private_life.running_costs','private_life','Private Life ownership costs',
  'Keep players informed when recurring personal-asset costs reduce their career Finance balance.',
  'Recurring Private Life ownership costs are processed.',
  'At least one owned Private Life asset has a monthly ownership charge due.',
  'Private Life recurring-cost processor','Private Life',
  'Private Life ownership costs paid','Recurring ownership costs were charged to your career Finance balance.',
  '/game/private-life','info',true,false,false,true,true
)
on conflict(code) do update set
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
  default_email=excluded.default_email,
  default_push=excluded.default_push,
  is_user_configurable=excluded.is_user_configurable,
  is_active=excluded.is_active,
  updated_at=now();

create or replace function public.process_private_life_running_costs_for_player_v1(
  p_player_id uuid,
  p_through_absolute_day integer
) returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  r record;
  v_cost bigint;
  v_fin jsonb;
  v_tx uuid;
  v_count integer:=0;
  v_total bigint:=0;
  v_user_id uuid;
  v_event_key text;
begin
  select owner_user_id into v_user_id from public.players where id=p_player_id;
  if v_user_id is null then
    return jsonb_build_object('status','skipped','reason','player_not_found_or_not_human','events',0,'total_cost',0);
  end if;

  for r in
    select
      o.id as player_asset_id,
      o.catalog_code,
      c.category,
      c.name,
      c.annual_running_cost,
      due.absolute_day,
      due.season,
      due.month
    from public.private_life_player_assets o
    join public.private_life_asset_catalog c on c.code=o.catalog_code
    cross join lateral (
      select gs::integer as absolute_day, gd.season, gd.month
      from generate_series(o.purchase_absolute_day+1, least(p_through_absolute_day,coalesce(o.sold_absolute_day-1,p_through_absolute_day))) gs
      cross join lateral public.absolute_game_day_v1(gs::integer) gd
      where gd.day=1
    ) due
    where o.player_id=p_player_id
      and c.annual_running_cost>0
      and o.purchase_absolute_day<p_through_absolute_day
    order by due.absolute_day,o.created_at,o.id
  loop
    v_event_key:='running_cost:'||r.season::text||':'||r.month::text;
    if exists(
      select 1 from public.private_life_asset_events e
      where e.player_asset_id=r.player_asset_id and e.event_key=v_event_key
    ) then
      continue;
    end if;

    v_cost:=greatest(1,round(r.annual_running_cost::numeric/12)::bigint);
    v_fin:=public.post_career_finance_transaction_v1(
      p_player_id,
      -v_cost,
      'private_life',
      'running_cost_'||r.category,
      'Private Life ownership cost: '||r.name,
      'private_life_asset',
      r.player_asset_id::text||':'||r.season::text||':'||r.month::text,
      'private-life-running:'||r.player_asset_id::text||':'||r.season::text||':'||r.month::text,
      jsonb_build_object(
        'player_asset_id',r.player_asset_id,
        'catalog_code',r.catalog_code,
        'category',r.category,
        'annual_running_cost',r.annual_running_cost,
        'season',r.season,
        'month',r.month
      ),
      true,
      r.absolute_day
    );
    v_tx:=(v_fin->>'transaction_id')::uuid;

    insert into public.private_life_asset_events(
      player_id,player_asset_id,event_type,event_absolute_day,amount,finance_transaction_id,event_key,title,description,metadata
    ) values (
      p_player_id,r.player_asset_id,'running_cost',r.absolute_day,-v_cost,v_tx,v_event_key,
      'Ownership cost paid',
      'Monthly ownership cost for '||r.name||'.',
      jsonb_build_object('catalog_code',r.catalog_code,'category',r.category,'season',r.season,'month',r.month,'annual_running_cost',r.annual_running_cost)
    ) on conflict(player_asset_id,event_key) do nothing;

    v_count:=v_count+1;
    v_total:=v_total+v_cost;
  end loop;

  if v_total>0 then
    perform public.emit_notification_v1(
      v_user_id,
      p_player_id,
      'player.private_life.running_costs',
      'Private Life ownership costs paid',
      'Recurring ownership costs of $'||to_char(v_total,'FM999G999G999G990')||' were charged to your career Finance balance.',
      '/game/private-life',
      jsonb_build_object('total_cost',v_total,'cost_events',v_count,'through_absolute_day',p_through_absolute_day),
      'private-life-running-costs:'||p_player_id::text||':'||p_through_absolute_day::text
    );
  end if;

  return jsonb_build_object('status','processed','events',v_count,'total_cost',v_total,'through_absolute_day',p_through_absolute_day);
end;
$function$;
revoke all on function public.process_private_life_running_costs_for_player_v1(uuid,integer) from public,anon,authenticated;

create or replace function public.process_private_life_running_costs_to_current_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  d record;
  p record;
  v_abs integer;
  v_result jsonb;
  v_players integer:=0;
  v_events integer:=0;
  v_total bigint:=0;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);

  for p in
    select distinct pl.id
    from public.players pl
    join public.premium_memberships pm on pm.user_id=pl.owner_user_id
    join public.private_life_player_assets a on a.player_id=pl.id
    where pl.player_type='human'
      and pl.owner_user_id is not null
      and pm.plan_code='premium'
      and pm.status='active'
      and (pm.current_period_end is null or pm.current_period_end>now())
  loop
    v_players:=v_players+1;
    v_result:=public.process_private_life_running_costs_for_player_v1(p.id,v_abs);
    v_events:=v_events+coalesce((v_result->>'events')::integer,0);
    v_total:=v_total+coalesce((v_result->>'total_cost')::bigint,0);
  end loop;

  return jsonb_build_object(
    'status','completed',
    'current_absolute_day',v_abs,
    'players_processed',v_players,
    'cost_events',v_events,
    'total_cost',v_total
  );
end;
$function$;
revoke all on function public.process_private_life_running_costs_to_current_v1() from public,anon,authenticated;

create extension if not exists pg_cron;
do $$
declare j record;
begin
  for j in select jobid from cron.job where jobname='tennis-private-life-costs-v1' loop
    perform cron.unschedule(j.jobid);
  end loop;
end $$;
select cron.schedule(
  'tennis-private-life-costs-v1',
  '*/5 * * * *',
  $cron$select public.process_private_life_running_costs_to_current_v1();$cron$
);
