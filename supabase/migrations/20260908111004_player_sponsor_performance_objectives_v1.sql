create table public.sponsor_objective_rules (
  offer_rule_code text primary key references public.sponsor_offer_rules(code) on update cascade on delete restrict,
  appearance_full_season_target smallint not null check (appearance_full_season_target >= 1),
  match_win_full_season_target smallint not null check (match_win_full_season_target >= 1),
  performance_code text not null check (performance_code in ('tournament_win','final_or_better','semifinal_or_better','quarterfinal_or_better')),
  performance_title text not null,
  performance_min_result_level smallint not null check (performance_min_result_level between 1 and 8),
  bonus_pool_pct numeric(5,4) not null default 0.2000 check (bonus_pool_pct between 0 and 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.sponsor_objective_rules(
  offer_rule_code,appearance_full_season_target,match_win_full_season_target,
  performance_code,performance_title,performance_min_result_level,bonus_pool_pct
) values
('rank_001_030',14,30,'tournament_win','Win a tournament',8,0.2000),
('rank_031_100',12,22,'final_or_better','Reach a tournament final',7,0.2000),
('rank_101_300',10,14,'semifinal_or_better','Reach a tournament semifinal',6,0.2000),
('rank_301_plus',8,8,'quarterfinal_or_better','Reach a tournament quarterfinal',5,0.2000)
on conflict (offer_rule_code) do update set
  appearance_full_season_target=excluded.appearance_full_season_target,
  match_win_full_season_target=excluded.match_win_full_season_target,
  performance_code=excluded.performance_code,
  performance_title=excluded.performance_title,
  performance_min_result_level=excluded.performance_min_result_level,
  bonus_pool_pct=excluded.bonus_pool_pct,
  updated_at=now();

create table public.player_sponsor_objectives (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.player_sponsor_contracts(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  sponsor_company_id uuid not null references public.sponsor_companies(id) on delete restrict,
  season integer not null,
  objective_code text not null check (objective_code in ('appearances','match_wins','performance_result')),
  title text not null,
  description text not null,
  target_value integer not null check (target_value >= 1),
  current_value integer not null default 0 check (current_value >= 0),
  reward_amount bigint not null check (reward_amount >= 0),
  status text not null default 'active' check (status in ('active','achieved','failed')),
  achieved_absolute_day integer,
  payout_transaction_id uuid references public.career_finance_transactions(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(contract_id,objective_code)
);

create index player_sponsor_objectives_player_status_idx
  on public.player_sponsor_objectives(player_id,season,status);

alter table public.sponsor_objective_rules enable row level security;
alter table public.player_sponsor_objectives enable row level security;

create policy sponsor_objective_rules_authenticated_read
  on public.sponsor_objective_rules for select to authenticated using (true);
create policy player_sponsor_objectives_owner_read
  on public.player_sponsor_objectives for select to authenticated
  using (exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=auth.uid() and p.player_type='human'));

grant select on public.sponsor_objective_rules to authenticated;
grant select on public.player_sponsor_objectives to authenticated;

create or replace function public.sponsor_result_level_v1(p_result_code text)
returns smallint
language sql
immutable
as $$
  select case lower(coalesce(p_result_code,''))
    when 'champion' then 8
    when 'runner_up' then 7
    when 'semifinal' then 6
    when 'quarterfinal' then 5
    when 'round_16' then 4
    when 'round_32' then 3
    when 'round_64' then 2
    when 'round_128' then 1
    else 0 end::smallint;
$$;

create or replace function public.create_player_sponsor_objectives_v1(p_contract_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  c public.player_sponsor_contracts%rowtype;
  v_offer_rule text;
  r public.sponsor_objective_rules%rowtype;
  v_fraction numeric;
  v_appearance integer;
  v_wins integer;
  v_bonus_pool bigint;
  v_appearance_reward bigint;
  v_wins_reward bigint;
  v_performance_reward bigint;
  v_count integer;
begin
  select * into c from public.player_sponsor_contracts where id=p_contract_id;
  if c.id is null then raise exception 'Sponsor contract not found.'; end if;

  select o.offer_rule_code into v_offer_rule from public.player_sponsor_offers o where o.id=c.offer_id;
  select * into r from public.sponsor_objective_rules where offer_rule_code=v_offer_rule;
  if r.offer_rule_code is null then raise exception 'Sponsor objective rule not found for %.',v_offer_rule; end if;

  v_fraction:=least(1::numeric,greatest(1::numeric/52::numeric,(c.end_absolute_day-c.signed_absolute_day+1)::numeric/366::numeric));
  v_appearance:=greatest(1,ceil(r.appearance_full_season_target*v_fraction)::integer);
  v_wins:=greatest(1,ceil(r.match_win_full_season_target*v_fraction)::integer);
  v_bonus_pool:=greatest(100::bigint,(round((c.total_contract_value::numeric*r.bonus_pool_pct)/100::numeric)*100)::bigint);
  v_appearance_reward:=(round((v_bonus_pool*0.25::numeric)/10::numeric)*10)::bigint;
  v_wins_reward:=(round((v_bonus_pool*0.30::numeric)/10::numeric)*10)::bigint;
  v_performance_reward:=greatest(0::bigint,v_bonus_pool-v_appearance_reward-v_wins_reward);

  insert into public.player_sponsor_objectives(
    contract_id,player_id,sponsor_company_id,season,objective_code,title,description,target_value,reward_amount,metadata
  ) values
  (c.id,c.player_id,c.sponsor_company_id,c.season,'appearances','Tournament appearances',
   format('Compete in %s tournament%s before the sponsor agreement ends.',v_appearance,case when v_appearance=1 then '' else 's' end),
   v_appearance,v_appearance_reward,jsonb_build_object('objective_family','appearance','season_fraction',v_fraction)),
  (c.id,c.player_id,c.sponsor_company_id,c.season,'match_wins','Match wins',
   format('Win %s tournament match%s while this sponsor agreement is active.',v_wins,case when v_wins=1 then '' else 'es' end),
   v_wins,v_wins_reward,jsonb_build_object('objective_family','match_wins','season_fraction',v_fraction)),
  (c.id,c.player_id,c.sponsor_company_id,c.season,'performance_result',r.performance_title,
   case r.performance_code
     when 'tournament_win' then 'Win at least one tournament while this sponsor agreement is active.'
     when 'final_or_better' then 'Reach at least one tournament final while this sponsor agreement is active.'
     when 'semifinal_or_better' then 'Reach at least one tournament semifinal while this sponsor agreement is active.'
     else 'Reach at least one tournament quarterfinal while this sponsor agreement is active.' end,
   1,v_performance_reward,jsonb_build_object('objective_family','performance','performance_code',r.performance_code,'min_result_level',r.performance_min_result_level))
  on conflict (contract_id,objective_code) do nothing;

  get diagnostics v_count=row_count;
  return jsonb_build_object('status','ready','created',v_count,'bonus_pool',v_bonus_pool,'season_fraction',v_fraction);
end;
$$;

create or replace function public.sponsor_refresh_player_objectives_v1(p_player_id uuid, p_through_absolute_day integer default null)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_owner uuid;
  gd record;
  v_through integer;
  o record;
  v_current integer;
  v_post jsonb;
  v_tx uuid;
  v_achieved integer:=0;
  v_checked integer:=0;
  v_sponsor_name text;
begin
  select owner_user_id into v_owner from public.players where id=p_player_id and player_type='human';
  if v_owner is null then raise exception 'Human player not found.'; end if;
  if v_uid is not null and v_uid<>v_owner then raise exception 'Not authorized for this player.'; end if;

  select * into gd from public.get_current_game_day_internal_v1();
  v_through:=coalesce(p_through_absolute_day,public.game_day_absolute_v1(gd.season,gd.month,gd.day));

  for o in
    select obj.*,c.signed_absolute_day,c.end_absolute_day
    from public.player_sponsor_objectives obj
    join public.player_sponsor_contracts c on c.id=obj.contract_id
    where obj.player_id=p_player_id and obj.status='active'
    order by obj.created_at,obj.id
  loop
    v_checked:=v_checked+1;
    if o.objective_code='appearances' then
      select count(distinct f.competition_id)::integer into v_current
      from public.statistics_player_match_facts_v1 f
      where f.player_id=p_player_id
        and (public.training_camp_week_start_absolute_v1(f.season,f.scheduled_season_week::smallint)+f.scheduled_day-1)
          between o.signed_absolute_day and least(v_through,o.end_absolute_day);
    elsif o.objective_code='match_wins' then
      select count(*)::integer into v_current
      from public.statistics_player_match_facts_v1 f
      where f.player_id=p_player_id and f.won
        and (public.training_camp_week_start_absolute_v1(f.season,f.scheduled_season_week::smallint)+f.scheduled_day-1)
          between o.signed_absolute_day and least(v_through,o.end_absolute_day);
    else
      select count(distinct r.competition_id)::integer into v_current
      from public.player_tournament_results r
      where r.player_id=p_player_id
        and public.sponsor_result_level_v1(r.result_code) >= coalesce((o.metadata->>'min_result_level')::smallint,8)
        and exists(
          select 1 from public.statistics_player_match_facts_v1 f
          where f.player_id=p_player_id and f.competition_id=r.competition_id
            and (public.training_camp_week_start_absolute_v1(f.season,f.scheduled_season_week::smallint)+f.scheduled_day-1)
              between o.signed_absolute_day and least(v_through,o.end_absolute_day)
        );
    end if;

    update public.player_sponsor_objectives set current_value=greatest(0,coalesce(v_current,0)),updated_at=now() where id=o.id;

    if coalesce(v_current,0)>=o.target_value then
      select name into v_sponsor_name from public.sponsor_companies where id=o.sponsor_company_id;
      v_post:=public.post_career_finance_transaction_v1(
        p_player_id,o.reward_amount,'performance_bonus',o.objective_code,
        format('%s — %s sponsor bonus',v_sponsor_name,o.title),
        'sponsor_objective',o.id::text,format('sponsor-objective:%s:bonus',o.id),
        jsonb_build_object('taxable',true,'contract_id',o.contract_id,'sponsor_company_id',o.sponsor_company_id,
          'sponsor_name',v_sponsor_name,'objective_code',o.objective_code,'objective_title',o.title,
          'target_value',o.target_value,'reward_amount',o.reward_amount),false,v_through
      );
      v_tx:=nullif(v_post->>'transaction_id','')::uuid;
      update public.player_sponsor_objectives
      set status='achieved',achieved_absolute_day=v_through,payout_transaction_id=v_tx,current_value=greatest(target_value,coalesce(v_current,0)),updated_at=now()
      where id=o.id;
      v_achieved:=v_achieved+1;
    elsif v_through>o.end_absolute_day then
      update public.player_sponsor_objectives set status='failed',updated_at=now() where id=o.id;
    end if;
  end loop;

  return jsonb_build_object('status','processed','through_absolute_day',v_through,'checked',v_checked,'newly_achieved',v_achieved);
end;
$$;

create or replace function public.trg_create_player_sponsor_objectives_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
begin
  perform public.create_player_sponsor_objectives_v1(new.id);
  return new;
end;
$$;

drop trigger if exists trg_player_sponsor_contract_objectives_v1 on public.player_sponsor_contracts;
create trigger trg_player_sponsor_contract_objectives_v1
after insert on public.player_sponsor_contracts
for each row execute function public.trg_create_player_sponsor_objectives_v1();

create or replace function public.process_all_human_sponsor_objectives_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  p record;
  v_players integer:=0;
  v_achieved integer:=0;
  v_result jsonb;
begin
  for p in select distinct c.player_id from public.player_sponsor_contracts c where c.status in ('active','completed') loop
    v_result:=public.sponsor_refresh_player_objectives_v1(p.player_id,null);
    v_players:=v_players+1;
    v_achieved:=v_achieved+coalesce((v_result->>'newly_achieved')::integer,0);
  end loop;
  return jsonb_build_object('status','processed','players',v_players,'newly_achieved',v_achieved);
end;
$$;

create or replace function public.get_player_sponsor_dashboard_v2()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_base jsonb;
  v_player uuid;
  v_contract uuid;
  v_objectives jsonb;
  v_bonus_total bigint:=0;
  v_bonus_earned bigint:=0;
begin
  v_base:=public.get_player_sponsor_dashboard_v1();
  v_player:=nullif(v_base->>'player_id','')::uuid;
  if v_player is null then return v_base; end if;

  perform public.sponsor_refresh_player_objectives_v1(v_player,(v_base->>'current_absolute_day')::integer);
  v_contract:=nullif(v_base#>>'{active_contract,id}','')::uuid;
  if v_contract is null then
    return v_base || jsonb_build_object('objectives','[]'::jsonb,'bonus_pool_total',0,'bonus_earned',0);
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'objective_code',o.objective_code,'title',o.title,'description',o.description,
    'target_value',o.target_value,'current_value',o.current_value,'reward_amount',o.reward_amount,
    'status',o.status,'achieved_absolute_day',o.achieved_absolute_day
  ) order by case o.objective_code when 'appearances' then 1 when 'match_wins' then 2 else 3 end),'[]'::jsonb),
  coalesce(sum(o.reward_amount),0),coalesce(sum(o.reward_amount) filter(where o.status='achieved'),0)
  into v_objectives,v_bonus_total,v_bonus_earned
  from public.player_sponsor_objectives o where o.contract_id=v_contract;

  return jsonb_set(
    jsonb_set(
      jsonb_set(v_base,'{active_contract,objectives}',v_objectives,true),
      '{active_contract,bonus_pool_total}',to_jsonb(v_bonus_total),true
    ),
    '{active_contract,bonus_earned}',to_jsonb(v_bonus_earned),true
  );
end;
$$;

revoke execute on function public.create_player_sponsor_objectives_v1(uuid) from public,anon,authenticated;
revoke execute on function public.sponsor_refresh_player_objectives_v1(uuid,integer) from public,anon,authenticated;
revoke execute on function public.process_all_human_sponsor_objectives_v1() from public,anon,authenticated;
revoke execute on function public.sponsor_result_level_v1(text) from public,anon,authenticated;
grant execute on function public.get_player_sponsor_dashboard_v2() to authenticated;

select cron.unschedule(jobid) from cron.job where jobname='process-sponsor-objectives-hourly-v1';
select cron.schedule('process-sponsor-objectives-hourly-v1','41 * * * *','select public.process_all_human_sponsor_objectives_v1();');

do $$
declare v_rules integer; begin
  select count(*) into v_rules from public.sponsor_objective_rules;
  if v_rules<>4 then raise exception 'Expected 4 sponsor objective rules, got %.',v_rules; end if;
  if not has_function_privilege('authenticated','public.get_player_sponsor_dashboard_v2()','EXECUTE') then
    raise exception 'Authenticated sponsor dashboard v2 access is missing.';
  end if;
  if has_function_privilege('authenticated','public.sponsor_refresh_player_objectives_v1(uuid,integer)','EXECUTE') then
    raise exception 'Internal sponsor objective refresh must not be directly executable by authenticated clients.';
  end if;
end $$;
