-- SOURCE ARCHIVE ONLY. Recovered from Tennis Legacy Supabase migration history.
-- Migration 20260903072608, staff_market_contracts_effects_and_scouting_foundation.
-- Original SQL MD5: d510f7741eb0959317c9534d1a7a5c14
-- NOT an auto-applied migration; never replay this alone against production.
-- Archive intentionally lives outside supabase/migrations.

create table if not exists public.player_career_finance_accounts (
  player_id uuid primary key references public.players(id) on delete cascade,
  balance bigint,
  currency text not null default 'USD',
  is_live boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (balance is null or balance >= 0),
  check (currency='USD')
);

insert into public.player_career_finance_accounts(player_id)
select id from public.players where player_type='human'
on conflict(player_id) do nothing;

create table if not exists public.staff_members (
  id uuid primary key default gen_random_uuid(),
  market_serial bigint not null unique,
  role text not null,
  gender text not null,
  first_name text not null,
  last_name text not null,
  country_code text not null references public.countries(code) on update restrict on delete restrict,
  overall_rating smallint not null,
  quality_tier text not null,
  specialty text not null,
  attributes jsonb not null default '{}'::jsonb,
  base_weekly_salary integer not null,
  signing_fee integer not null,
  required_rank_position integer,
  status text not null default 'available',
  current_player_id uuid references public.players(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (role in ('head_coach','fitness_coach','physiotherapist','sports_psychologist','performance_analyst','agent_manager')),
  check (gender in ('male','female')),
  check (overall_rating between 40 and 100),
  check (quality_tier in ('developing','professional','advanced','elite','world_class')),
  check (base_weekly_salary between 100 and 50000),
  check (signing_fee between 0 and 250000),
  check (required_rank_position is null or required_rank_position > 0),
  check (status in ('available','employed')),
  check ((status='available' and current_player_id is null) or (status='employed' and current_player_id is not null))
);

create index if not exists staff_members_market_idx on public.staff_members(role,status,quality_tier,base_weekly_salary,overall_rating desc);
create index if not exists staff_members_country_idx on public.staff_members(country_code,status);
create index if not exists staff_members_specialty_idx on public.staff_members(role,specialty,status);

create table if not exists public.player_staff_contracts (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  staff_id uuid not null references public.staff_members(id) on delete restrict,
  role text not null,
  start_absolute_day integer not null,
  end_absolute_day integer not null,
  duration_weeks smallint not null,
  weekly_salary integer not null,
  signing_fee integer not null,
  finance_status text not null default 'pending',
  status text not null default 'active',
  signed_at timestamptz not null default now(),
  terminated_at timestamptz,
  expired_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (role in ('head_coach','fitness_coach','physiotherapist','sports_psychologist','performance_analyst','agent_manager')),
  check (duration_weeks in (13,26,52)),
  check (end_absolute_day >= start_absolute_day),
  check (weekly_salary > 0),
  check (signing_fee >= 0),
  check (finance_status in ('pending','posted')),
  check (status in ('active','terminated','expired'))
);

create unique index if not exists player_staff_one_active_role_uidx on public.player_staff_contracts(player_id,role) where status='active';
create unique index if not exists staff_one_active_contract_uidx on public.player_staff_contracts(staff_id) where status='active';
create index if not exists player_staff_contracts_player_idx on public.player_staff_contracts(player_id,status,end_absolute_day);

create table if not exists public.staff_financial_events (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  contract_id uuid references public.player_staff_contracts(id) on delete cascade,
  event_type text not null,
  amount integer not null,
  status text not null default 'pending',
  game_absolute_day integer not null,
  created_at timestamptz not null default now(),
  posted_at timestamptz,
  check (event_type in ('signing_fee','weekly_salary','termination_fee')),
  check (amount >= 0),
  check (status in ('pending','posted'))
);

create index if not exists staff_financial_events_player_idx on public.staff_financial_events(player_id,status,game_absolute_day desc);

alter table public.staff_members enable row level security;
alter table public.player_staff_contracts enable row level security;
alter table public.staff_financial_events enable row level security;
alter table public.player_career_finance_accounts enable row level security;
revoke all on public.staff_members from anon, authenticated;
revoke all on public.player_staff_contracts from anon, authenticated;
revoke all on public.staff_financial_events from anon, authenticated;
revoke all on public.player_career_finance_accounts from anon, authenticated;

drop trigger if exists staff_members_set_updated_at on public.staff_members;
create trigger staff_members_set_updated_at before update on public.staff_members for each row execute function public.set_updated_at();
drop trigger if exists player_staff_contracts_set_updated_at on public.player_staff_contracts;
create trigger player_staff_contracts_set_updated_at before update on public.player_staff_contracts for each row execute function public.set_updated_at();
drop trigger if exists career_finance_set_updated_at on public.player_career_finance_accounts;
create trigger career_finance_set_updated_at before update on public.player_career_finance_accounts for each row execute function public.set_updated_at();

create or replace function public.staff_role_label_v1(p_role text)
returns text language sql immutable set search_path=public as $$
  select case p_role
    when 'head_coach' then 'Head Coach'
    when 'fitness_coach' then 'Fitness Coach'
    when 'physiotherapist' then 'Physiotherapist'
    when 'sports_psychologist' then 'Sports Psychologist'
    when 'performance_analyst' then 'Performance Analyst'
    when 'agent_manager' then 'Agent / Manager'
    else p_role end;
$$;

create or replace function public.staff_quality_label_v1(p_tier text)
returns text language sql immutable set search_path=public as $$
  select case p_tier when 'world_class' then 'World Class' else initcap(replace(p_tier,'_',' ')) end;
$$;

create or replace function public.player_current_rank_position_v1(p_player_id uuid)
returns bigint language sql stable security definer set search_path=public as $$
  with target as (select world from public.players where id=p_player_id), ranked as (
    select p.id,row_number() over(order by coalesce(r.ranking_points,0) desc,coalesce(r.seed_rating,0) desc,p.created_at asc,p.id asc) pos
    from public.players p left join public.player_rankings r on r.player_id=p.id
    where p.world=(select world from target) and p.moderation_status<>'rejected'
  ) select pos from ranked where id=p_player_id;
$$;

create or replace function public.get_player_staff_effects_v1(p_player_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare
  v_pref text;
  v_tech numeric:=1; v_tech_camp numeric:=1; v_match numeric:=1;
  v_phys numeric:=1; v_phys_camp numeric:=1; v_fatigue_red numeric:=0;
  v_recovery numeric:=1; v_injury numeric:=0; v_rehab numeric:=1;
  v_morale numeric:=1; v_conf numeric:=1; v_focus numeric:=1; v_pressure numeric:=0;
  v_scout_margin integer:=10; v_analyst_match numeric:=1;
  v_sponsor numeric:=1; v_negotiation numeric:=1;
  r record; a numeric; v_bonus numeric;
begin
  select preferred_surface into v_pref from public.players where id=p_player_id;
  for r in
    select c.role,s.overall_rating,s.specialty,s.attributes
    from public.player_staff_contracts c join public.staff_members s on s.id=c.staff_id
    where c.player_id=p_player_id and c.status='active'
  loop
    if r.role='head_coach' then
      a:=coalesce((r.attributes->>'technical_coaching')::numeric,r.overall_rating);
      v_bonus:=greatest(0,least(1,(a-40)/60));
      v_tech:=1+0.12*v_bonus;
      a:=coalesce((r.attributes->>'player_development')::numeric,r.overall_rating);
      v_tech_camp:=1+0.08*greatest(0,least(1,(a-40)/60));
      a:=coalesce((r.attributes->>'tactical_knowledge')::numeric,r.overall_rating);
      v_match:=1+0.05*greatest(0,least(1,(a-40)/60));
      if (v_pref='Clay' and r.specialty='Clay Development') or (v_pref='Hard' and r.specialty='Hard Court Development') or (v_pref='Grass' and r.specialty='Grass Development') then
        v_tech:=v_tech+0.02; v_tech_camp:=v_tech_camp+0.02;
      end if;
    elsif r.role='fitness_coach' then
      a:=coalesce((r.attributes->>'physical_development')::numeric,r.overall_rating);
      v_phys:=1+0.12*greatest(0,least(1,(a-40)/60));
      a:=coalesce((r.attributes->>'conditioning')::numeric,r.overall_rating);
      v_phys_camp:=1+0.08*greatest(0,least(1,(a-40)/60));
      a:=coalesce((r.attributes->>'workload_management')::numeric,r.overall_rating);
      v_fatigue_red:=0.10*greatest(0,least(1,(a-40)/60));
    elsif r.role='physiotherapist' then
      a:=coalesce((r.attributes->>'recovery')::numeric,r.overall_rating);
      v_recovery:=1+0.20*greatest(0,least(1,(a-40)/60));
      a:=coalesce((r.attributes->>'injury_prevention')::numeric,r.overall_rating);
      v_injury:=0.15*greatest(0,least(1,(a-40)/60));
      a:=coalesce((r.attributes->>'rehabilitation')::numeric,r.overall_rating);
      v_rehab:=1+0.20*greatest(0,least(1,(a-40)/60));
    elsif r.role='sports_psychologist' then
      a:=coalesce((r.attributes->>'morale')::numeric,r.overall_rating); v_morale:=1+0.15*greatest(0,least(1,(a-40)/60));
      a:=coalesce((r.attributes->>'confidence')::numeric,r.overall_rating); v_conf:=1+0.15*greatest(0,least(1,(a-40)/60));
      a:=coalesce((r.attributes->>'focus')::numeric,r.overall_rating); v_focus:=1+0.15*greatest(0,least(1,(a-40)/60));
      a:=coalesce((r.attributes->>'pressure_management')::numeric,r.overall_rating); v_pressure:=0.05*greatest(0,least(1,(a-40)/60));
    elsif r.role='performance_analyst' then
      a:=coalesce((r.attributes->>'opponent_analysis')::numeric,r.overall_rating);
      v_scout_margin:=greatest(1,round(10-9*greatest(0,least(1,(a-40)/60)))::integer);
      a:=coalesce((r.attributes->>'match_preparation')::numeric,r.overall_rating);
      v_analyst_match:=1+0.04*greatest(0,least(1,(a-40)/60));
    elsif r.role='agent_manager' then
      a:=coalesce((r.attributes->>'sponsorship_network')::numeric,r.overall_rating);
      v_sponsor:=1+0.10*greatest(0,least(1,(a-40)/60));
      a:=coalesce((r.attributes->>'negotiation')::numeric,r.overall_rating);
      v_negotiation:=1+0.10*greatest(0,least(1,(a-40)/60));
    end if;
  end loop;
  return jsonb_build_object(
    'technical_training_multiplier',round(v_tech,4),'technical_camp_multiplier',round(v_tech_camp,4),'coach_match_preparation_multiplier',round(v_match,4),
    'physical_training_multiplier',round(v_phys,4),'physical_camp_multiplier',round(v_phys_camp,4),'training_fatigue_reduction',round(v_fatigue_red,4),
    'recovery_multiplier',round(v_recovery,4),'injury_prevention_reduction',round(v_injury,4),'rehabilitation_multiplier',round(v_rehab,4),
    'morale_recovery_multiplier',round(v_morale,4),'confidence_recovery_multiplier',round(v_conf,4),'focus_recovery_multiplier',round(v_focus,4),'pressure_bonus',round(v_pressure,4),
    'scouting_margin',v_scout_margin,'analyst_match_preparation_multiplier',round(v_analyst_match,4),
    'sponsorship_multiplier',round(v_sponsor,4),'negotiation_multiplier',round(v_negotiation,4)
  );
end;
$$;

create or replace function public.get_staff_dashboard_v1()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_player uuid; v_abs integer; v_contracts jsonb; v_fin jsonb; v_count integer; v_weekly integer; v_exp integer;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  select coalesce(jsonb_agg(jsonb_build_object(
    'contract_id',c.id,'role',c.role,'role_label',public.staff_role_label_v1(c.role),'start_absolute_day',c.start_absolute_day,'end_absolute_day',c.end_absolute_day,
    'duration_weeks',c.duration_weeks,'weekly_salary',c.weekly_salary,'signing_fee',c.signing_fee,'status',c.status,'finance_status',c.finance_status,
    'weeks_remaining',greatest(0,ceil((c.end_absolute_day-v_abs+1)::numeric/7)::integer),
    'staff',jsonb_build_object('id',s.id,'first_name',s.first_name,'last_name',s.last_name,'country_code',s.country_code,'overall_rating',s.overall_rating,
      'quality_tier',s.quality_tier,'quality_label',public.staff_quality_label_v1(s.quality_tier),'specialty',s.specialty,'attributes',s.attributes,
      'base_weekly_salary',s.base_weekly_salary,'signing_fee',s.signing_fee,'required_rank_position',s.required_rank_position)
  ) order by c.role),'[]'::jsonb),count(*),coalesce(sum(c.weekly_salary),0),count(*) filter(where c.end_absolute_day-v_abs<=28)
  into v_contracts,v_count,v_weekly,v_exp
  from public.player_staff_contracts c join public.staff_members s on s.id=c.staff_id
  where c.player_id=v_player and c.status='active';
  select jsonb_build_object('is_live',coalesce(f.is_live,false),'balance',f.balance,'currency',coalesce(f.currency,'USD')) into v_fin from public.player_career_finance_accounts f where f.player_id=v_player;
  return jsonb_build_object('current_absolute_day',v_abs,'employed_count',coalesce(v_count,0),'max_staff',6,'weekly_cost',coalesce(v_weekly,0),'contracts_expiring_4_weeks',coalesce(v_exp,0),'contracts',v_contracts,'effects',public.get_player_staff_effects_v1(v_player),'finance',coalesce(v_fin,jsonb_build_object('is_live',false,'balance',null,'currency','USD')));
end;
$$;

create or replace function public.get_staff_market_v1(
  p_role text default null,p_country_code text default null,p_quality_tier text default null,p_max_weekly_salary integer default null,p_specialty text default null,p_offset integer default 0,p_limit integer default 25
)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_total integer; v_items jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select count(*) into v_total from public.staff_members s where s.status='available'
    and (p_role is null or p_role='' or s.role=p_role)
    and (p_country_code is null or p_country_code='' or s.country_code=upper(p_country_code))
    and (p_quality_tier is null or p_quality_tier='' or s.quality_tier=p_quality_tier)
    and (p_max_weekly_salary is null or s.base_weekly_salary<=p_max_weekly_salary)
    and (p_specialty is null or p_specialty='' or s.specialty=p_specialty);
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',x.id,'role',x.role,'role_label',public.staff_role_label_v1(x.role),'first_name',x.first_name,'last_name',x.last_name,'country_code',x.country_code,
    'overall_rating',x.overall_rating,'quality_tier',x.quality_tier,'quality_label',public.staff_quality_label_v1(x.quality_tier),'specialty',x.specialty,'attributes',x.attributes,
    'base_weekly_salary',x.base_weekly_salary,'signing_fee',x.signing_fee,'required_rank_position',x.required_rank_position
  ) order by x.overall_rating desc,x.base_weekly_salary,x.last_name,x.first_name),'[]'::jsonb) into v_items
  from (
    select * from public.staff_members s where s.status='available'
      and (p_role is null or p_role='' or s.role=p_role)
      and (p_country_code is null or p_country_code='' or s.country_code=upper(p_country_code))
      and (p_quality_tier is null or p_quality_tier='' or s.quality_tier=p_quality_tier)
      and (p_max_weekly_salary is null or s.base_weekly_salary<=p_max_weekly_salary)
      and (p_specialty is null or p_specialty='' or s.specialty=p_specialty)
    order by s.overall_rating desc,s.base_weekly_salary,s.last_name,s.first_name
    offset greatest(coalesce(p_offset,0),0) limit least(greatest(coalesce(p_limit,25),1),100)
  ) x;
  return jsonb_build_object('total',v_total,'items',v_items,'offset',greatest(coalesce(p_offset,0),0),'limit',least(greatest(coalesce(p_limit,25),1),100));
end;
$$;

create or replace function public.hire_staff_v1(p_staff_id uuid,p_duration_weeks smallint)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_player public.players%rowtype; s public.staff_members%rowtype; v_rank bigint; v_abs integer; v_salary integer; v_contract uuid; f public.player_career_finance_accounts%rowtype; v_fin_status text:='pending'; v_discount numeric;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if p_duration_weeks not in (13,26,52) then raise exception 'Contract duration must be 13, 26 or 52 weeks.'; end if;
  select * into v_player from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player.id is null then raise exception 'Player not found.'; end if;
  select * into s from public.staff_members where id=p_staff_id for update;
  if s.id is null then raise exception 'Staff member not found.'; end if;
  if s.status<>'available' or s.current_player_id is not null then raise exception 'This staff member has just accepted another position.'; end if;
  if exists(select 1 from public.player_staff_contracts where player_id=v_player.id and role=s.role and status='active') then raise exception 'You already employ a staff member in this role.'; end if;
  v_rank:=public.player_current_rank_position_v1(v_player.id);
  if s.required_rank_position is not null and (v_rank is null or v_rank>s.required_rank_position) then raise exception 'This staff member requires a ranking of % or better.',s.required_rank_position; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  v_discount:=case p_duration_weeks when 13 then 1.00 when 26 then 0.93 else 0.86 end;
  v_salary:=greatest(100,round((s.base_weekly_salary*v_discount)/10.0)*10)::integer;
  insert into public.player_career_finance_accounts(player_id) values(v_player.id) on conflict(player_id) do nothing;
  select * into f from public.player_career_finance_accounts where player_id=v_player.id for update;
  if f.is_live then
    if f.balance is null or f.balance<s.signing_fee then raise exception 'Insufficient career funds for the signing fee.'; end if;
    update public.player_career_finance_accounts set balance=balance-s.signing_fee where player_id=v_player.id;
    v_fin_status:='posted';
  end if;
  insert into public.player_staff_contracts(player_id,staff_id,role,start_absolute_day,end_absolute_day,duration_weeks,weekly_salary,signing_fee,finance_status)
  values(v_player.id,s.id,s.role,v_abs,v_abs+p_duration_weeks*7-1,p_duration_weeks,v_salary,s.signing_fee,v_fin_status) returning id into v_contract;
  update public.staff_members set status='employed',current_player_id=v_player.id where id=s.id;
  insert into public.staff_financial_events(player_id,contract_id,event_type,amount,status,game_absolute_day,posted_at)
  values(v_player.id,v_contract,'signing_fee',s.signing_fee,v_fin_status,v_abs,case when v_fin_status='posted' then now() else null end);
  return jsonb_build_object('status','hired','contract_id',v_contract,'staff_id',s.id,'role',s.role,'duration_weeks',p_duration_weeks,'weekly_salary',v_salary,'signing_fee',s.signing_fee,'finance_status',v_fin_status,'finance_live',f.is_live);
end;
$$;

create or replace function public.terminate_staff_contract_v1(p_contract_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_player uuid; c public.player_staff_contracts%rowtype; v_abs integer; v_weeks integer; v_fee integer; f public.player_career_finance_accounts%rowtype; v_status text:='pending';
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;
  select * into c from public.player_staff_contracts where id=p_contract_id and player_id=v_player for update;
  if c.id is null or c.status<>'active' then raise exception 'Active contract not found.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  v_weeks:=least(4,greatest(1,ceil((c.end_absolute_day-v_abs+1)::numeric/7)::integer));
  v_fee:=c.weekly_salary*v_weeks;
  select * into f from public.player_career_finance_accounts where player_id=v_player for update;
  if coalesce(f.is_live,false) and f.balance is not null and f.balance>=v_fee then
    update public.player_career_finance_accounts set balance=balance-v_fee where player_id=v_player; v_status:='posted';
  end if;
  update public.player_staff_contracts set status='terminated',terminated_at=now() where id=c.id;
  update public.staff_members set status='available',current_player_id=null where id=c.staff_id;
  insert into public.staff_financial_events(player_id,contract_id,event_type,amount,status,game_absolute_day,posted_at)
  values(v_player,c.id,'termination_fee',v_fee,v_status,v_abs,case when v_status='posted' then now() else null end);
  return jsonb_build_object('status','terminated','contract_id',c.id,'termination_fee',v_fee,'finance_status',v_status);
end;
$$;

create or replace function public.process_staff_contract_expiry_v1()
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_abs integer; v_count integer;
begin
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  with expired as (
    update public.player_staff_contracts set status='expired',expired_at=now()
    where status='active' and end_absolute_day<v_abs returning staff_id
  ), released as (
    update public.staff_members s set status='available',current_player_id=null from expired e where s.id=e.staff_id returning s.id
  ) select count(*) into v_count from released;
  return jsonb_build_object('status','processed','released_staff',coalesce(v_count,0),'current_absolute_day',v_abs);
end;
$$;

create or replace function public.get_player_scouting_report_v1(p_target_player_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_me uuid; v_target public.players%rowtype; s public.player_skills%rowtype; a record; v_margin integer; v_attrs jsonb:='{}'::jsonb; k text; v integer; v_strength text; v_weakness text;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_me from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_me is null then raise exception 'Player not found.'; end if;
  select * into v_target from public.players where id=p_target_player_id and moderation_status<>'rejected';
  if v_target.id is null then raise exception 'Target player not found.'; end if;
  if v_target.id=v_me then return jsonb_build_object('available',false,'reason','Use your Skills page for exact personal attributes.'); end if;
  select s.overall_rating,s.attributes into a from public.player_staff_contracts c join public.staff_members s on s.id=c.staff_id where c.player_id=v_me and c.role='performance_analyst' and c.status='active';
  if a.overall_rating is null then return jsonb_build_object('available',false,'reason','Hire a Performance Analyst to unlock opponent estimates.'); end if;
  v_margin:=greatest(1,round(10-9*greatest(0,least(1,(coalesce((a.attributes->>'opponent_analysis')::numeric,a.overall_rating)-40)/60)))::integer);
  select * into s from public.player_skills where player_id=v_target.id;
  foreach k in array array['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash','fitness','stamina','recovery','movement'] loop
    v:=(to_jsonb(s)->>k)::integer;
    v_attrs:=v_attrs||jsonb_build_object(k,jsonb_build_object('min',greatest(1,v-v_margin),'max',least(100,v+v_margin)));
  end loop;
  select key into v_strength from jsonb_each_text(jsonb_build_object('serve',s.serve,'forehand',s.forehand,'backhand',s.backhand,'return_skill',s.return_skill,'volley',s.volley,'slice',s.slice,'drop_shot',s.drop_shot,'lob',s.lob,'smash',s.smash)) order by value::integer desc,key limit 1;
  select key into v_weakness from jsonb_each_text(jsonb_build_object('serve',s.serve,'forehand',s.forehand,'backhand',s.backhand,'return_skill',s.return_skill,'volley',s.volley,'slice',s.slice,'drop_shot',s.drop_shot,'lob',s.lob,'smash',s.smash)) order by value::integer asc,key limit 1;
  return jsonb_build_object('available',true,'analyst_rating',a.overall_rating,'estimate_margin',v_margin,'attributes',v_attrs,'identified_strength',v_strength,'identified_weakness',v_weakness,'preferred_surface',v_target.preferred_surface,'playing_style',v_target.playing_style);
end;
$$;

grant execute on function public.get_staff_dashboard_v1() to authenticated;
grant execute on function public.get_staff_market_v1(text,text,text,integer,text,integer,integer) to authenticated;
grant execute on function public.hire_staff_v1(uuid,smallint) to authenticated;
grant execute on function public.terminate_staff_contract_v1(uuid) to authenticated;
grant execute on function public.get_player_scouting_report_v1(uuid) to authenticated;