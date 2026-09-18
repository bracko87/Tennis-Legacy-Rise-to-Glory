alter table public.player_sponsor_offers
  add column if not exists performance_bonus_pool bigint not null default 0 check (performance_bonus_pool >= 0),
  add column if not exists objective_plan jsonb not null default '[]'::jsonb,
  add column if not exists objective_plan_version smallint not null default 2;

alter table public.player_sponsor_contracts
  add column if not exists performance_bonus_pool bigint not null default 0 check (performance_bonus_pool >= 0),
  add column if not exists objective_plan_version smallint not null default 2;

alter table public.player_sponsor_objectives
  add column if not exists objective_key text,
  add column if not exists competition_id uuid references public.tournament_world_competitions(id) on delete set null,
  add column if not exists tournament_series_id uuid references public.tournament_series(id) on delete set null,
  add column if not exists tournament_name text,
  add column if not exists requirement_label text,
  add column if not exists start_absolute_day integer,
  add column if not exists deadline_absolute_day integer;

alter table public.player_sponsor_objectives
  drop constraint if exists player_sponsor_objectives_contract_id_objective_code_key,
  drop constraint if exists player_sponsor_objectives_objective_code_check,
  drop constraint if exists player_sponsor_objectives_status_check;

update public.player_sponsor_objectives
set objective_key=coalesce(objective_key,objective_code),
    status=case when status='achieved' then 'completed' else status end;

alter table public.player_sponsor_objectives
  alter column objective_key set not null;

alter table public.player_sponsor_objectives
  add constraint player_sponsor_objectives_objective_code_check
  check (objective_code in (
    'tournament_appearance',
    'tournament_result',
    'ranking_peak',
    'season_finish_rank',
    'match_wins_period',
    'appearances',
    'match_wins',
    'performance_result'
  )),
  add constraint player_sponsor_objectives_status_check
  check (status in ('upcoming','active','completed','failed','expired'));

create unique index if not exists player_sponsor_objectives_contract_key_uidx
  on public.player_sponsor_objectives(contract_id,objective_key);

create index if not exists player_sponsor_objectives_competition_idx
  on public.player_sponsor_objectives(competition_id)
  where competition_id is not null;

update public.player_sponsor_contracts c
set performance_bonus_pool=coalesce((
  select sum(o.reward_amount)::bigint
  from public.player_sponsor_objectives o
  where o.contract_id=c.id
),0)
where c.performance_bonus_pool=0;

create or replace function public.sponsor_result_requirement_label_v2(p_level integer)
returns text
language sql
immutable
as $function$
  select case greatest(1,least(8,coalesce(p_level,1)))
    when 8 then 'Win tournament'
    when 7 then 'Reach Final'
    when 6 then 'Reach Semifinal'
    when 5 then 'Reach Quarterfinal'
    when 4 then 'Reach Round of 16'
    when 3 then 'Reach Round of 32'
    when 2 then 'Reach Round of 64'
    else 'Reach Main Draw'
  end;
$function$;

create or replace function public.sponsor_category_strength_v2(p_category text)
returns integer
language sql
immutable
as $function$
  select case lower(coalesce(p_category,''))
    when 'grand_slam_2000' then 10
    when 'masters_1000' then 9
    when 'tour_500' then 8
    when 'tour_250' then 7
    when 'challenger_125' then 6
    when 'challenger_100' then 5
    when 'challenger_75' then 4
    when 'challenger_50' then 3
    when 'futures_25' then 2
    when 'futures_15' then 1
    else 0
  end;
$function$;

create or replace function public.sponsor_category_realistic_for_rank_v2(p_rank integer,p_category text)
returns boolean
language sql
immutable
as $function$
  select case
    when coalesce(p_rank,9999)<=30 then lower(coalesce(p_category,'')) in ('grand_slam_2000','masters_1000','tour_500','tour_250')
    when p_rank<=100 then lower(coalesce(p_category,'')) in ('grand_slam_2000','masters_1000','tour_500','tour_250','challenger_125')
    when p_rank<=300 then lower(coalesce(p_category,'')) in ('tour_250','challenger_125','challenger_100','challenger_75','futures_25')
    when p_rank<=1000 then lower(coalesce(p_category,'')) in ('challenger_125','challenger_100','challenger_75','challenger_50','futures_25','futures_15')
    else lower(coalesce(p_category,'')) in ('challenger_75','challenger_50','futures_25','futures_15')
  end;
$function$;

create or replace function public.sponsor_result_target_level_v2(
  p_rank integer,
  p_category text,
  p_reputation integer,
  p_sponsor_strength numeric,
  p_seed text
)
returns smallint
language plpgsql
immutable
as $function$
declare
  v_level integer;
  v_cat text:=lower(coalesce(p_category,''));
  v_bump integer:=0;
begin
  v_level:=case
    when p_rank<=10 then case
      when v_cat='grand_slam_2000' then 6
      when v_cat='masters_1000' then 6
      when v_cat='tour_500' then 7
      else 8 end
    when p_rank<=30 then case
      when v_cat='grand_slam_2000' then 5
      when v_cat='masters_1000' then 5
      when v_cat='tour_500' then 6
      else 7 end
    when p_rank<=100 then case
      when v_cat='grand_slam_2000' then 3
      when v_cat='masters_1000' then 4
      when v_cat='tour_500' then 5
      when v_cat='tour_250' then 5
      else 6 end
    when p_rank<=300 then case
      when v_cat='tour_250' then 4
      when v_cat='challenger_125' then 5
      when v_cat in ('challenger_100','challenger_75') then 5
      else 6 end
    when p_rank<=1000 then case
      when v_cat in ('challenger_125','challenger_100') then 4
      when v_cat in ('challenger_75','challenger_50') then 5
      else 6 end
    else case
      when v_cat in ('challenger_75','challenger_50') then 4
      else 5 end
  end;

  if coalesce(p_reputation,50)>=85 and coalesce(p_sponsor_strength,0)>=0.70 then
    v_bump:=1;
  elsif coalesce(p_reputation,50)<=30 and coalesce(p_sponsor_strength,0)<=0.30 then
    v_bump:=-1;
  end if;

  if public.sponsor_hash_unit_v1(coalesce(p_seed,''))>0.82 then
    v_bump:=v_bump+1;
  end if;

  return greatest(2,least(8,v_level+v_bump))::smallint;
end;
$function$;

create or replace function public.build_sponsor_objective_plan_v2(p_offer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $function$
declare
  o public.player_sponsor_offers%rowtype;
  p public.players%rowtype;
  s public.sponsor_companies%rowtype;
  r public.sponsor_offer_rules%rowtype;
  v_profile jsonb;
  v_reputation integer:=50;
  v_player_group text;
  v_sponsor_group text;
  v_player_macro text;
  v_sponsor_macro text;
  v_abs integer;
  gd record;
  v_end integer;
  v_fraction numeric;
  v_sponsor_strength numeric:=0;
  v_pool_pct numeric;
  v_bonus_pool bigint;
  v_target_count integer;
  v_tournament_target integer;
  v_general_target integer;
  v_plan jsonb:='[]'::jsonb;
  v_used uuid[]:='{}'::uuid[];
  v_i integer;
  v_target_group text;
  v_target_country text;
  t record;
  v_level integer;
  v_weight numeric;
  v_target_rank integer;
  v_match_target integer;
  v_current_count integer;
  v_total_weight numeric;
  v_final_plan jsonb;
begin
  select * into o from public.player_sponsor_offers where id=p_offer_id;
  if o.id is null then raise exception 'Sponsor offer not found.'; end if;

  select * into p from public.players where id=o.player_id;
  select * into s from public.sponsor_companies where id=o.sponsor_company_id;
  select * into r from public.sponsor_offer_rules where code=o.offer_rule_code;

  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_end:=public.game_day_absolute_v1(o.season,12::smallint,31::smallint);

  begin
    v_profile:=public.technical_sponsor_player_profile_v1(o.player_id);
    v_reputation:=coalesce((v_profile->>'reputation')::integer,50);
  exception when others then
    v_reputation:=50;
  end;

  select gm.group_code,g.macro_region into v_player_group,v_player_macro
  from public.sponsor_market_group_members gm
  join public.sponsor_market_groups g on g.code=gm.group_code
  where gm.country_code=p.country_code;

  select gm.group_code,g.macro_region into v_sponsor_group,v_sponsor_macro
  from public.sponsor_market_group_members gm
  join public.sponsor_market_groups g on g.code=gm.group_code
  where gm.country_code=s.country_code;

  if r.full_season_value_max>r.full_season_value_min then
    v_sponsor_strength:=least(1::numeric,greatest(0::numeric,
      (o.full_season_value-r.full_season_value_min)::numeric
      /(r.full_season_value_max-r.full_season_value_min)::numeric
    ));
  end if;

  v_pool_pct:=case
    when o.player_rank<=10 then 0.38
    when o.player_rank<=30 then 0.34
    when o.player_rank<=100 then 0.30
    when o.player_rank<=300 then 0.25
    else 0.20
  end;
  v_pool_pct:=least(0.45::numeric,greatest(0.18::numeric,
    v_pool_pct + (v_sponsor_strength-0.50)*0.04 + (v_reputation-50)*0.0004
  ));

  v_bonus_pool:=greatest(300::bigint,
    (round((o.total_contract_value::numeric*v_pool_pct)/100::numeric)*100)::bigint
  );

  v_target_count:=case
    when o.player_rank<=30 then 8
    when o.player_rank<=100 then 7
    when o.player_rank<=300 then 6
    when o.player_rank<=1000 then 5
    else 4
  end;
  v_tournament_target:=case
    when o.player_rank<=30 then 5
    when o.player_rank<=100 then 5
    when o.player_rank<=300 then 4
    when o.player_rank<=1000 then 3
    else 2
  end;

  for v_i in 1..v_tournament_target loop
    if o.player_rank<=30 then
      v_target_group:=null;
      v_target_country:=null;
    elsif v_player_group is not distinct from v_sponsor_group then
      v_target_group:=v_player_group;
      v_target_country:=p.country_code;
    elsif mod(v_i,2)=1 then
      v_target_group:=v_player_group;
      v_target_country:=p.country_code;
    else
      v_target_group:=v_sponsor_group;
      v_target_country:=s.country_code;
    end if;

    select q.* into t
    from (
      select
        wc.id competition_id,
        e.tournament_series_id,
        ts.name tournament_name,
        ts.country_code,
        ts.category_code,
        ts.surface,
        tgm.group_code tournament_group,
        tg.macro_region tournament_macro,
        public.training_camp_week_start_absolute_v1(e.season_number,min(ss.season_week)::smallint) start_day,
        public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+6 deadline_day,
        public.sponsor_category_strength_v2(ts.category_code) category_strength
      from public.tournament_world_competitions wc
      join public.tournament_editions e on e.id=wc.tournament_edition_id
      join public.tournament_series ts on ts.id=e.tournament_series_id
      join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
      left join public.sponsor_market_group_members tgm on tgm.country_code=ts.country_code
      left join public.sponsor_market_groups tg on tg.code=tgm.group_code
      where e.season_number=o.season
        and wc.world=p.world
        and wc.status<>'canceled'
        and e.status<>'canceled'
        and ts.is_active
        and wc.id<>all(v_used)
        and not exists(select 1 from public.tournament_cancellations tc where tc.competition_id=wc.id)
        and public.sponsor_category_realistic_for_rank_v2(o.player_rank,ts.category_code)
      group by wc.id,e.tournament_series_id,e.season_number,ts.name,ts.country_code,ts.category_code,ts.surface,tgm.group_code,tg.macro_region
    ) q
    where q.start_day>v_abs
      and q.deadline_day<=v_end
    order by
      case
        when o.player_rank<=30 then 0
        when q.country_code=v_target_country then 0
        when q.tournament_group=v_target_group then 1
        when q.tournament_group in (v_player_group,v_sponsor_group) then 2
        when q.tournament_macro in (v_player_macro,v_sponsor_macro) then 3
        else 4
      end,
      case when o.player_rank<=30 then q.category_strength else 0 end desc,
      case when p.preferred_surface is not null and lower(q.surface)=lower(p.preferred_surface) then 0 else 1 end,
      public.sponsor_hash_unit_v1(concat_ws(':','objective-event',p_offer_id::text,v_i::text,q.competition_id::text))
    limit 1;

    if t.competition_id is null then
      exit;
    end if;

    v_used:=array_append(v_used,t.competition_id);

    if v_i=1 then
      v_weight:=0.65 + t.category_strength*0.035;
      v_plan:=v_plan || jsonb_build_array(jsonb_build_object(
        'objective_key',format('tournament:%s:appearance',t.competition_id),
        'objective_code','tournament_appearance',
        'title',format('%s appearance',t.tournament_name),
        'description',format('Compete in %s for %s.',t.tournament_name,s.name),
        'tournament_name',t.tournament_name,
        'competition_id',t.competition_id,
        'tournament_series_id',t.tournament_series_id,
        'country_code',t.country_code,
        'category_code',t.category_code,
        'surface',t.surface,
        'requirement_label','Participate in tournament',
        'target_value',1,
        'start_absolute_day',t.start_day,
        'deadline_absolute_day',t.deadline_day,
        'weight',v_weight,
        'geography_basis',case
          when o.player_rank<=30 then 'global_prestige'
          when t.country_code=p.country_code then 'player_country'
          when t.country_code=s.country_code then 'sponsor_country'
          when t.tournament_group=v_player_group then 'player_region'
          when t.tournament_group=v_sponsor_group then 'sponsor_region'
          else 'extended_region' end
      ));
    else
      v_level:=public.sponsor_result_target_level_v2(
        o.player_rank,t.category_code,v_reputation,v_sponsor_strength,
        concat_ws(':',p_offer_id::text,t.competition_id::text)
      );
      v_weight:=0.85 + t.category_strength*0.07 + v_level*0.09;
      v_plan:=v_plan || jsonb_build_array(jsonb_build_object(
        'objective_key',format('tournament:%s:result',t.competition_id),
        'objective_code','tournament_result',
        'title',format('%s performance',t.tournament_name),
        'description',format('%s at %s.',public.sponsor_result_requirement_label_v2(v_level),t.tournament_name),
        'tournament_name',t.tournament_name,
        'competition_id',t.competition_id,
        'tournament_series_id',t.tournament_series_id,
        'country_code',t.country_code,
        'category_code',t.category_code,
        'surface',t.surface,
        'requirement_label',public.sponsor_result_requirement_label_v2(v_level),
        'target_value',v_level,
        'start_absolute_day',t.start_day,
        'deadline_absolute_day',t.deadline_day,
        'weight',v_weight,
        'geography_basis',case
          when o.player_rank<=30 then 'global_prestige'
          when t.country_code=p.country_code then 'player_country'
          when t.country_code=s.country_code then 'sponsor_country'
          when t.tournament_group=v_player_group then 'player_region'
          when t.tournament_group=v_sponsor_group then 'sponsor_region'
          else 'extended_region' end
      ));
    end if;
  end loop;

  v_current_count:=jsonb_array_length(v_plan);
  v_general_target:=greatest(3-v_current_count,v_target_count-v_current_count);
  v_fraction:=least(1::numeric,greatest(0.05::numeric,(v_end-v_abs+1)::numeric/366::numeric));

  if v_general_target>=1 then
    v_target_rank:=case
      when o.player_rank<=10 then greatest(1,o.player_rank-2)
      when o.player_rank<=30 then greatest(1,ceil(o.player_rank*0.82)::integer)
      when o.player_rank<=100 then greatest(15,ceil(o.player_rank*0.80)::integer)
      when o.player_rank<=300 then greatest(75,ceil(o.player_rank*0.80)::integer)
      when o.player_rank<=1000 then greatest(250,ceil(o.player_rank*0.82)::integer)
      else greatest(750,ceil(o.player_rank*0.85)::integer)
    end;
    if v_target_rank>=o.player_rank then v_target_rank:=greatest(1,o.player_rank-1); end if;

    v_plan:=v_plan || jsonb_build_array(jsonb_build_object(
      'objective_key','ranking:peak',
      'objective_code','ranking_peak',
      'title',format('Reach Top %s',v_target_rank),
      'description',format('Reach world ranking #%s or better before the sponsor agreement ends.',v_target_rank),
      'requirement_label',format('Reach Top %s',v_target_rank),
      'target_value',1,
      'target_rank',v_target_rank,
      'start_absolute_day',v_abs,
      'deadline_absolute_day',v_end,
      'weight',1.10
    ));
  end if;

  if v_general_target>=2 then
    v_match_target:=greatest(2,ceil((case
      when o.player_rank<=10 then 34
      when o.player_rank<=30 then 30
      when o.player_rank<=100 then 22
      when o.player_rank<=300 then 15
      when o.player_rank<=1000 then 10
      else 7 end)*v_fraction)::integer);

    v_plan:=v_plan || jsonb_build_array(jsonb_build_object(
      'objective_key','season:match-wins',
      'objective_code','match_wins_period',
      'title',format('%s match wins',v_match_target),
      'description',format('Win %s tournament matches while the sponsor agreement is active.',v_match_target),
      'requirement_label',format('Win %s matches',v_match_target),
      'target_value',v_match_target,
      'start_absolute_day',v_abs,
      'deadline_absolute_day',v_end,
      'weight',1.00
    ));
  end if;

  if v_general_target>=3 then
    v_target_rank:=case
      when o.player_rank<=10 then greatest(1,o.player_rank)
      when o.player_rank<=30 then greatest(1,ceil(o.player_rank*0.90)::integer)
      when o.player_rank<=100 then greatest(20,ceil(o.player_rank*0.90)::integer)
      when o.player_rank<=300 then greatest(100,ceil(o.player_rank*0.92)::integer)
      else greatest(300,ceil(o.player_rank*0.94)::integer)
    end;

    v_plan:=v_plan || jsonb_build_array(jsonb_build_object(
      'objective_key','season:finish-rank',
      'objective_code','season_finish_rank',
      'title',format('Finish season Top %s',v_target_rank),
      'description',format('Finish Season %s ranked #%s or better.',o.season,v_target_rank),
      'requirement_label',format('Finish Top %s',v_target_rank),
      'target_value',1,
      'target_rank',v_target_rank,
      'start_absolute_day',v_abs,
      'deadline_absolute_day',v_end,
      'weight',1.30
    ));
  end if;

  select coalesce(sum((x.value->>'weight')::numeric),0)
  into v_total_weight
  from jsonb_array_elements(v_plan) x(value);

  if v_total_weight<=0 then
    return jsonb_build_object(
      'bonus_pool',v_bonus_pool,
      'reputation',v_reputation,
      'sponsor_strength',v_sponsor_strength,
      'objectives','[]'::jsonb
    );
  end if;

  with e as (
    select value elem, ord,
           count(*) over() n,
           (value->>'weight')::numeric weight
    from jsonb_array_elements(v_plan) with ordinality a(value,ord)
  ), b as (
    select elem,ord,n,
      case when ord<n
        then floor((v_bonus_pool::numeric*weight/v_total_weight)/100::numeric)*100
        else null end::bigint base_reward
    from e
  ), f as (
    select elem,ord,n,
      case when ord=n
        then greatest(0::bigint,v_bonus_pool-coalesce(sum(base_reward) filter(where ord<n) over(),0))
        else greatest(0::bigint,base_reward) end reward_amount
    from b
  )
  select coalesce(jsonb_agg(
    (elem-'weight') || jsonb_build_object('reward_amount',reward_amount)
    order by ord
  ),'[]'::jsonb)
  into v_final_plan
  from f;

  return jsonb_build_object(
    'bonus_pool',v_bonus_pool,
    'reputation',v_reputation,
    'sponsor_strength',round(v_sponsor_strength,3),
    'player_group',v_player_group,
    'sponsor_group',v_sponsor_group,
    'objectives',v_final_plan
  );
end;
$function$;

create or replace function public.refresh_player_sponsor_offer_plans_v2(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $function$
declare
  x record;
  v_plan jsonb;
  v_count integer:=0;
begin
  for x in
    select id
    from public.player_sponsor_offers
    where player_id=p_player_id and status='open'
    order by created_at,id
  loop
    v_plan:=public.build_sponsor_objective_plan_v2(x.id);
    update public.player_sponsor_offers
    set performance_bonus_pool=coalesce((v_plan->>'bonus_pool')::bigint,0),
        objective_plan=coalesce(v_plan->'objectives','[]'::jsonb),
        objective_plan_version=2,
        updated_at=now()
    where id=x.id;
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('status','ready','offers_updated',v_count);
end;
$function$;

create or replace function public.create_player_sponsor_objectives_v1(p_contract_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $function$
declare
  c public.player_sponsor_contracts%rowtype;
  o public.player_sponsor_offers%rowtype;
  item jsonb;
  v_count integer:=0;
  v_status text;
begin
  select * into c from public.player_sponsor_contracts where id=p_contract_id;
  if c.id is null then raise exception 'Sponsor contract not found.'; end if;

  select * into o from public.player_sponsor_offers where id=c.offer_id;
  if o.id is null then raise exception 'Sponsor offer not found.'; end if;

  if jsonb_array_length(coalesce(o.objective_plan,'[]'::jsonb))=0 then
    perform public.refresh_player_sponsor_offer_plans_v2(c.player_id);
    select * into o from public.player_sponsor_offers where id=c.offer_id;
  end if;

  for item in select value from jsonb_array_elements(coalesce(o.objective_plan,'[]'::jsonb))
  loop
    v_status:=case
      when nullif(item->>'start_absolute_day','')::integer>c.signed_absolute_day then 'upcoming'
      else 'active'
    end;

    insert into public.player_sponsor_objectives(
      contract_id,player_id,sponsor_company_id,season,
      objective_key,objective_code,title,description,
      target_value,current_value,reward_amount,status,
      competition_id,tournament_series_id,tournament_name,requirement_label,
      start_absolute_day,deadline_absolute_day,metadata
    ) values (
      c.id,c.player_id,c.sponsor_company_id,c.season,
      item->>'objective_key',item->>'objective_code',item->>'title',item->>'description',
      greatest(1,coalesce((item->>'target_value')::integer,1)),0,
      greatest(0,coalesce((item->>'reward_amount')::bigint,0)),v_status,
      nullif(item->>'competition_id','')::uuid,
      nullif(item->>'tournament_series_id','')::uuid,
      nullif(item->>'tournament_name',''),
      nullif(item->>'requirement_label',''),
      nullif(item->>'start_absolute_day','')::integer,
      coalesce(nullif(item->>'deadline_absolute_day','')::integer,c.end_absolute_day),
      (item - array[
        'objective_key','objective_code','title','description','target_value','reward_amount',
        'competition_id','tournament_series_id','tournament_name','requirement_label',
        'start_absolute_day','deadline_absolute_day'
      ]::text[])
    )
    on conflict(contract_id,objective_key) do nothing;
    v_count:=v_count+1;
  end loop;

  update public.player_sponsor_contracts
  set performance_bonus_pool=o.performance_bonus_pool,
      objective_plan_version=2,
      updated_at=now()
  where id=c.id;

  return jsonb_build_object(
    'status','ready',
    'created',v_count,
    'bonus_pool',o.performance_bonus_pool,
    'objective_plan_version',2
  );
end;
$function$;

create or replace function public.sponsor_refresh_player_objectives_v1(
  p_player_id uuid,
  p_through_absolute_day integer default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $function$
declare
  v_uid uuid:=auth.uid();
  v_owner uuid;
  gd record;
  v_through integer;
  v_rank integer;
  obj record;
  v_current integer:=0;
  v_target_rank integer;
  v_result_level integer:=0;
  v_has_result boolean:=false;
  v_should_complete boolean;
  v_terminal_status text;
  v_post jsonb;
  v_tx uuid;
  v_sponsor_name text;
  v_checked integer:=0;
  v_completed integer:=0;
begin
  select owner_user_id into v_owner
  from public.players
  where id=p_player_id and player_type='human';

  if v_owner is null then raise exception 'Human player not found.'; end if;
  if v_uid is not null and v_uid<>v_owner then raise exception 'Not authorized for this player.'; end if;

  select * into gd from public.get_current_game_day_internal_v1();
  v_through:=coalesce(p_through_absolute_day,public.game_day_absolute_v1(gd.season,gd.month,gd.day));
  v_rank:=greatest(1,coalesce(public.player_current_rank_position_v1(p_player_id),9999)::integer);

  for obj in
    select o.*,c.signed_absolute_day,c.end_absolute_day
    from public.player_sponsor_objectives o
    join public.player_sponsor_contracts c on c.id=o.contract_id
    where o.player_id=p_player_id
      and o.status in ('upcoming','active')
    order by coalesce(o.deadline_absolute_day,c.end_absolute_day),o.created_at,o.id
  loop
    v_checked:=v_checked+1;
    v_current:=0;
    v_result_level:=0;
    v_has_result:=false;
    v_should_complete:=false;
    v_terminal_status:=null;
    v_target_rank:=coalesce((obj.metadata->>'target_rank')::integer,999999);

    if obj.objective_code='tournament_appearance' then
      select case when exists(
        select 1 from public.statistics_player_match_facts_v1 f
        where f.player_id=p_player_id and f.competition_id=obj.competition_id
      ) or exists(
        select 1 from public.player_tournament_results tr
        where tr.player_id=p_player_id and tr.competition_id=obj.competition_id
      ) then 1 else 0 end
      into v_current;

      v_should_complete:=v_current>=1;
      if not v_should_complete then
        if v_through>coalesce(obj.deadline_absolute_day,obj.end_absolute_day) then
          v_terminal_status:='expired';
        elsif v_through>=coalesce(obj.start_absolute_day,obj.signed_absolute_day) then
          v_terminal_status:='active';
        else
          v_terminal_status:='upcoming';
        end if;
      end if;

    elsif obj.objective_code='tournament_result' then
      select public.sponsor_result_level_v1(tr.result_code),true
      into v_result_level,v_has_result
      from public.player_tournament_results tr
      where tr.player_id=p_player_id and tr.competition_id=obj.competition_id
      limit 1;

      v_result_level:=coalesce(v_result_level,0);
      v_has_result:=coalesce(v_has_result,false);
      v_current:=v_result_level;
      v_should_complete:=v_result_level>=obj.target_value;

      if not v_should_complete then
        if v_has_result and v_result_level>0 then
          v_terminal_status:='failed';
        elsif v_through>coalesce(obj.deadline_absolute_day,obj.end_absolute_day) then
          v_terminal_status:='expired';
        elsif v_through>=coalesce(obj.start_absolute_day,obj.signed_absolute_day) then
          v_terminal_status:='active';
        else
          v_terminal_status:='upcoming';
        end if;
      end if;

    elsif obj.objective_code='ranking_peak' then
      v_current:=case when v_rank<=v_target_rank then 1 else 0 end;
      v_should_complete:=v_current=1;
      if not v_should_complete then
        v_terminal_status:=case
          when v_through>coalesce(obj.deadline_absolute_day,obj.end_absolute_day) then 'expired'
          else 'active' end;
      end if;
      update public.player_sponsor_objectives
      set metadata=jsonb_set(coalesce(metadata,'{}'::jsonb),'{current_rank}',to_jsonb(v_rank),true)
      where id=obj.id;

    elsif obj.objective_code='season_finish_rank' then
      v_current:=case when v_rank<=v_target_rank then 1 else 0 end;
      if v_through>=coalesce(obj.deadline_absolute_day,obj.end_absolute_day) then
        v_should_complete:=v_current=1;
        if not v_should_complete then v_terminal_status:='failed'; end if;
      else
        v_terminal_status:='active';
      end if;
      update public.player_sponsor_objectives
      set metadata=jsonb_set(coalesce(metadata,'{}'::jsonb),'{current_rank}',to_jsonb(v_rank),true)
      where id=obj.id;

    elsif obj.objective_code in ('match_wins_period','match_wins') then
      select count(*)::integer into v_current
      from public.statistics_player_match_facts_v1 f
      where f.player_id=p_player_id and f.won
        and (public.training_camp_week_start_absolute_v1(f.season,f.scheduled_season_week::smallint)+f.scheduled_day-1)
          between obj.signed_absolute_day and least(v_through,obj.end_absolute_day);
      v_should_complete:=v_current>=obj.target_value;
      if not v_should_complete then
        v_terminal_status:=case
          when v_through>coalesce(obj.deadline_absolute_day,obj.end_absolute_day) then 'expired'
          else 'active' end;
      end if;

    elsif obj.objective_code='appearances' then
      select count(distinct f.competition_id)::integer into v_current
      from public.statistics_player_match_facts_v1 f
      where f.player_id=p_player_id
        and (public.training_camp_week_start_absolute_v1(f.season,f.scheduled_season_week::smallint)+f.scheduled_day-1)
          between obj.signed_absolute_day and least(v_through,obj.end_absolute_day);
      v_should_complete:=v_current>=obj.target_value;
      if not v_should_complete then
        v_terminal_status:=case when v_through>obj.end_absolute_day then 'expired' else 'active' end;
      end if;

    else
      select count(distinct tr.competition_id)::integer into v_current
      from public.player_tournament_results tr
      where tr.player_id=p_player_id
        and public.sponsor_result_level_v1(tr.result_code)>=coalesce((obj.metadata->>'min_result_level')::smallint,8)
        and exists(
          select 1 from public.statistics_player_match_facts_v1 f
          where f.player_id=p_player_id and f.competition_id=tr.competition_id
            and (public.training_camp_week_start_absolute_v1(f.season,f.scheduled_season_week::smallint)+f.scheduled_day-1)
              between obj.signed_absolute_day and least(v_through,obj.end_absolute_day)
        );
      v_should_complete:=v_current>=obj.target_value;
      if not v_should_complete then
        v_terminal_status:=case when v_through>obj.end_absolute_day then 'expired' else 'active' end;
      end if;
    end if;

    update public.player_sponsor_objectives
    set current_value=greatest(0,coalesce(v_current,0)),
        status=case when v_should_complete then status else coalesce(v_terminal_status,status) end,
        updated_at=now()
    where id=obj.id;

    if v_should_complete then
      select name into v_sponsor_name
      from public.sponsor_companies
      where id=obj.sponsor_company_id;

      v_post:=public.post_career_finance_transaction_v1(
        p_player_id,
        obj.reward_amount,
        'performance_bonus',
        obj.objective_code,
        format('%s — %s sponsor bonus',v_sponsor_name,obj.title),
        'sponsor_objective',
        obj.id::text,
        format('sponsor-objective:%s:bonus',obj.id),
        jsonb_build_object(
          'taxable',true,
          'contract_id',obj.contract_id,
          'sponsor_company_id',obj.sponsor_company_id,
          'sponsor_name',v_sponsor_name,
          'objective_code',obj.objective_code,
          'objective_title',obj.title,
          'tournament_name',obj.tournament_name,
          'competition_id',obj.competition_id,
          'reward_amount',obj.reward_amount
        ),
        false,
        v_through
      );

      v_tx:=nullif(v_post->>'transaction_id','')::uuid;

      update public.player_sponsor_objectives
      set status='completed',
          achieved_absolute_day=coalesce(achieved_absolute_day,v_through),
          payout_transaction_id=coalesce(payout_transaction_id,v_tx),
          current_value=greatest(target_value,coalesce(v_current,0)),
          updated_at=now()
      where id=obj.id
        and status in ('upcoming','active');

      if found then v_completed:=v_completed+1; end if;
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'through_absolute_day',v_through,
    'checked',v_checked,
    'newly_completed',v_completed
  );
end;
$function$;

create or replace function public.sign_player_sponsor_offer_v1(p_offer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $function$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_offer public.player_sponsor_offers%rowtype;
  v_contract public.player_sponsor_contracts%rowtype;
  gd record;
  v_abs integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select id into v_player
  from public.players
  where owner_user_id=v_uid and player_type='human';

  if v_player is null then raise exception 'Player not found.'; end if;

  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);

  perform public.reprice_player_sponsor_open_offers_v1(v_player);
  perform public.refresh_player_sponsor_offer_plans_v2(v_player);

  select * into v_offer
  from public.player_sponsor_offers
  where id=p_offer_id and player_id=v_player
  for update;

  if v_offer.id is null then raise exception 'Sponsor offer not found.'; end if;
  if v_offer.status<>'open' then raise exception 'This sponsor offer is no longer open.'; end if;

  if v_offer.expires_absolute_day<v_abs then
    update public.player_sponsor_offers set status='expired',updated_at=now() where id=v_offer.id;
    raise exception 'This sponsor offer has expired.';
  end if;

  if v_offer.season<>gd.season then raise exception 'This sponsor offer belongs to another season.'; end if;

  if exists(
    select 1 from public.player_sponsor_contracts
    where player_id=v_player and season=gd.season
  ) then
    raise exception 'A main sponsor agreement already exists for this season.';
  end if;

  insert into public.player_sponsor_contracts(
    player_id,sponsor_company_id,offer_id,season,
    signed_absolute_day,start_absolute_day,first_payment_absolute_day,end_absolute_day,
    player_rank_at_sign,player_market_group_code,source_pool,
    full_season_value,weekly_payment_amount,scheduled_payment_count,total_contract_value,
    performance_bonus_pool,objective_plan_version,status
  ) values (
    v_player,v_offer.sponsor_company_id,v_offer.id,v_offer.season,
    v_abs,v_abs,v_offer.first_payment_absolute_day,
    public.game_day_absolute_v1(v_offer.season,12::smallint,31::smallint),
    v_offer.player_rank,v_offer.player_market_group_code,v_offer.source_pool,
    v_offer.full_season_value,v_offer.weekly_payment_amount,v_offer.scheduled_payment_count,v_offer.total_contract_value,
    v_offer.performance_bonus_pool,2,'active'
  )
  returning * into v_contract;

  update public.player_sponsor_offers set status='accepted',updated_at=now() where id=v_offer.id;
  update public.player_sponsor_offers
  set status='expired',updated_at=now()
  where player_id=v_player and season=v_offer.season and status='open' and id<>v_offer.id;

  perform public.process_player_sponsor_payments_v1(v_player,v_abs);

  return jsonb_build_object(
    'status','signed',
    'contract_id',v_contract.id,
    'sponsor_company_id',v_contract.sponsor_company_id,
    'player_rank_at_sign',v_contract.player_rank_at_sign,
    'weekly_payment_amount',v_contract.weekly_payment_amount,
    'total_contract_value',v_contract.total_contract_value,
    'performance_bonus_pool',v_contract.performance_bonus_pool,
    'end_absolute_day',v_contract.end_absolute_day
  );
end;
$function$;

create or replace function public.get_player_sponsor_dashboard_v2()
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $function$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_base jsonb;
  v_contract uuid;
  v_objectives jsonb:='[]'::jsonb;
  v_offers jsonb:='[]'::jsonb;
  v_bonus_total bigint:=0;
  v_bonus_earned bigint:=0;
  v_bonus_available bigint:=0;
  v_bonus_missed bigint:=0;
  v_first_payment integer;
  v_last_payment integer;
  v_week_start integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select id into v_player
  from public.players
  where owner_user_id=v_uid and player_type='human';

  if v_player is null then raise exception 'Player not found.'; end if;

  perform public.reprice_player_sponsor_open_offers_v1(v_player);
  v_base:=public.get_player_sponsor_dashboard_v1();
  perform public.refresh_player_sponsor_offer_plans_v2(v_player);

  v_week_start:=coalesce((v_base->>'offer_week_start_absolute_day')::integer,0);

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,
    'sponsor_company_id',o.sponsor_company_id,
    'sponsor_name',s.name,
    'sponsor_country_code',s.country_code,
    'logo_url',s.logo_url,
    'is_worldwide',s.is_worldwide,
    'source_pool',o.source_pool,
    'market_group_code',o.player_market_group_code,
    'player_rank',o.player_rank,
    'generated_absolute_day',o.generated_absolute_day,
    'expires_absolute_day',o.expires_absolute_day,
    'first_payment_absolute_day',o.first_payment_absolute_day,
    'full_season_value',o.full_season_value,
    'weekly_payment_amount',o.weekly_payment_amount,
    'scheduled_payment_count',o.scheduled_payment_count,
    'total_contract_value',o.total_contract_value,
    'performance_bonus_pool',o.performance_bonus_pool,
    'maximum_total_value',o.total_contract_value+o.performance_bonus_pool,
    'objective_plan',o.objective_plan,
    'status',o.status
  ) order by o.total_contract_value+o.performance_bonus_pool desc,s.name),'[]'::jsonb)
  into v_offers
  from public.player_sponsor_offers o
  join public.sponsor_companies s on s.id=o.sponsor_company_id
  where o.player_id=v_player
    and o.season=(v_base->>'season')::integer
    and o.offer_week_start_absolute_day=v_week_start
    and o.status='open';

  v_base:=jsonb_set(v_base,'{offers}',v_offers,true);
  v_contract:=nullif(v_base#>>'{active_contract,id}','')::uuid;

  if v_contract is null then
    return v_base;
  end if;

  perform public.sponsor_refresh_player_objectives_v1(
    v_player,
    (v_base->>'current_absolute_day')::integer
  );

  select first_payment_absolute_day,
         first_payment_absolute_day+greatest(0,scheduled_payment_count::integer-1)*7
  into v_first_payment,v_last_payment
  from public.player_sponsor_contracts
  where id=v_contract;

  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id',o.id,
      'objective_key',o.objective_key,
      'objective_code',o.objective_code,
      'title',o.title,
      'description',o.description,
      'target_value',o.target_value,
      'current_value',o.current_value,
      'reward_amount',o.reward_amount,
      'status',o.status,
      'achieved_absolute_day',o.achieved_absolute_day,
      'competition_id',o.competition_id,
      'tournament_series_id',o.tournament_series_id,
      'tournament_name',o.tournament_name,
      'requirement_label',o.requirement_label,
      'start_absolute_day',o.start_absolute_day,
      'deadline_absolute_day',o.deadline_absolute_day,
      'metadata',o.metadata
    ) order by coalesce(o.start_absolute_day,o.deadline_absolute_day),o.created_at,o.id),'[]'::jsonb),
    coalesce(sum(o.reward_amount),0),
    coalesce(sum(o.reward_amount) filter(where o.status='completed'),0),
    coalesce(sum(o.reward_amount) filter(where o.status in ('upcoming','active')),0),
    coalesce(sum(o.reward_amount) filter(where o.status in ('failed','expired')),0)
  into v_objectives,v_bonus_total,v_bonus_earned,v_bonus_available,v_bonus_missed
  from public.player_sponsor_objectives o
  where o.contract_id=v_contract;

  v_base:=jsonb_set(v_base,'{active_contract,first_payment_absolute_day}',to_jsonb(v_first_payment),true);
  v_base:=jsonb_set(v_base,'{active_contract,last_payment_absolute_day}',to_jsonb(v_last_payment),true);
  v_base:=jsonb_set(v_base,'{active_contract,payment_frequency_days}',to_jsonb(7),true);
  v_base:=jsonb_set(v_base,'{active_contract,objectives}',v_objectives,true);
  v_base:=jsonb_set(v_base,'{active_contract,bonus_pool_total}',to_jsonb(v_bonus_total),true);
  v_base:=jsonb_set(v_base,'{active_contract,bonus_earned}',to_jsonb(v_bonus_earned),true);
  v_base:=jsonb_set(v_base,'{active_contract,bonus_available}',to_jsonb(v_bonus_available),true);
  v_base:=jsonb_set(v_base,'{active_contract,bonus_missed}',to_jsonb(v_bonus_missed),true);
  v_base:=jsonb_set(v_base,'{active_contract,maximum_total_value}',
    to_jsonb(coalesce((v_base#>>'{active_contract,total_contract_value}')::bigint,0)+v_bonus_total),true);

  return v_base;
end;
$function$;

revoke all on function public.sponsor_result_requirement_label_v2(integer) from public,anon,authenticated;
revoke all on function public.sponsor_category_strength_v2(text) from public,anon,authenticated;
revoke all on function public.sponsor_category_realistic_for_rank_v2(integer,text) from public,anon,authenticated;
revoke all on function public.sponsor_result_target_level_v2(integer,text,integer,numeric,text) from public,anon,authenticated;
revoke all on function public.build_sponsor_objective_plan_v2(uuid) from public,anon,authenticated;
revoke all on function public.refresh_player_sponsor_offer_plans_v2(uuid) from public,anon,authenticated;
revoke all on function public.create_player_sponsor_objectives_v1(uuid) from public,anon,authenticated;
revoke all on function public.sponsor_refresh_player_objectives_v1(uuid,integer) from public,anon,authenticated;

grant execute on function public.get_player_sponsor_dashboard_v2() to authenticated;
grant execute on function public.sign_player_sponsor_offer_v1(uuid) to authenticated;

select public.refresh_player_sponsor_offer_plans_v2(p.id)
from public.players p
where p.player_type='human'
  and exists(select 1 from public.player_sponsor_offers o where o.player_id=p.id and o.status='open');

do $$
declare
  v_bad integer;
begin
  select count(*) into v_bad
  from public.player_sponsor_offers
  where status='open'
    and performance_bonus_pool<0;
  if v_bad>0 then raise exception 'Invalid sponsor bonus pools found.'; end if;

  select count(*) into v_bad
  from public.player_sponsor_objectives
  where status not in ('upcoming','active','completed','failed','expired');
  if v_bad>0 then raise exception 'Invalid sponsor objective statuses found.'; end if;
end $$;
