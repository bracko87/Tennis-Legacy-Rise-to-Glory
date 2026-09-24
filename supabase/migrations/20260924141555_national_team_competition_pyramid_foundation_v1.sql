
alter table public.national_team_competition_config
  add column if not exists official_launch_season integer not null default 2;

update public.national_team_competition_config
set official_launch_season=2,
    updated_at=now()
where id=1;

insert into public.notification_catalog(
  code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,
  source_name,title_template,message_template,default_route,severity,
  default_in_app,default_email,default_push,is_user_configurable,is_active
)
values(
  'national.competition.launch',
  'national_team',
  'National-team competition launch',
  'Explain the Season 1 friendly-only programme and Season 2 official launch.',
  'A national association becomes active before the official launch season.',
  'Association is active while the current season is earlier than the official launch season.',
  'association_activation',
  'public.on_national_association_became_active_v1',
  'National-team programme update',
  'Season 1 is for association building and friendlies; official competition begins in Season 2.',
  '/game/national-team?tab=competition',
  'info',true,false,false,true,true
)
on conflict(code) do update
set category=excluded.category,
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

insert into public.national_team_regions(code,label,sort_order)
values
  ('EUROPE','Europe',10),
  ('AMERICAS','Americas',20),
  ('ASIA_OCEANIA','Asia / Oceania',30),
  ('AFRICA','Africa',40)
on conflict(code) do update
set label=excluded.label,sort_order=excluded.sort_order;

create or replace function public.national_team_region_for_country_v1(p_country_code text)
returns text
language sql
stable
security definer
set search_path=public,pg_temp
as $$
  select case public.country_continent_v1(upper(p_country_code))
    when 'Europe' then 'EUROPE'
    when 'North America' then 'AMERICAS'
    when 'South America' then 'AMERICAS'
    when 'Asia' then 'ASIA_OCEANIA'
    when 'Oceania' then 'ASIA_OCEANIA'
    when 'Africa' then 'AFRICA'
    else 'GLOBAL'
  end;
$$;

update public.national_associations
set region_code=public.national_team_region_for_country_v1(country_code),
    updated_at=now()
where region_code is distinct from public.national_team_region_for_country_v1(country_code);

insert into public.national_team_divisions(
  world,region_code,division_code,label,tier_level,capacity,sort_order,is_active,promotion_slots,relegation_slots
)
select world,region_code,division_code,label,tier_level,capacity,sort_order,true,promotion_slots,relegation_slots
from (
  values
    ('ATP','GLOBAL','final_8','Final 8',1,8,10,0,0),
    ('ATP','GLOBAL','qualifier_r2','Qualifiers · Round 2',2,16,20,8,8),
    ('ATP','GLOBAL','qualifier_r1','Qualifiers · Round 1',3,32,30,16,16),
    ('ATP','GLOBAL','world_group_i','World Group I',4,32,40,8,8),
    ('ATP','GLOBAL','world_group_ii','World Group II',5,32,50,8,8),
    ('WTA','GLOBAL','final_8','Final 8',1,8,10,0,0),
    ('WTA','GLOBAL','qualifier_r2','Qualifiers · Round 2',2,16,20,8,8),
    ('WTA','GLOBAL','qualifier_r1','Qualifiers · Round 1',3,32,30,16,16),
    ('WTA','GLOBAL','world_group_i','World Group I',4,32,40,8,8),
    ('WTA','GLOBAL','world_group_ii','World Group II',5,32,50,8,8)
) v(world,region_code,division_code,label,tier_level,capacity,sort_order,promotion_slots,relegation_slots)
on conflict(world,region_code,division_code) do update
set label=excluded.label,tier_level=excluded.tier_level,capacity=excluded.capacity,
    sort_order=excluded.sort_order,is_active=true,promotion_slots=excluded.promotion_slots,
    relegation_slots=excluded.relegation_slots;

insert into public.national_team_divisions(
  world,region_code,division_code,label,tier_level,capacity,sort_order,is_active,promotion_slots,relegation_slots
)
select
  w.world,
  r.code,
  'regional_group_'||g.group_no::text,
  r.label||' Regional Group '||trim(to_char(g.group_no,'FMRN')),
  g.group_no+5,
  8,
  100+(g.group_no*10)+r.sort_order,
  true,
  2,
  case when g.group_no=3 then 0 else 2 end
from (values ('ATP'::text),('WTA'::text)) w(world)
cross join (
  select code,label,sort_order
  from public.national_team_regions
  where code in ('EUROPE','AMERICAS','ASIA_OCEANIA','AFRICA')
) r
cross join (values (1),(2),(3)) g(group_no)
on conflict(world,region_code,division_code) do update
set label=excluded.label,tier_level=excluded.tier_level,capacity=excluded.capacity,
    sort_order=excluded.sort_order,is_active=true,promotion_slots=excluded.promotion_slots,
    relegation_slots=excluded.relegation_slots;

create or replace function public.ensure_national_team_regional_capacity_v1(
  p_world text,
  p_region_code text
)
returns integer
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_count integer;
  v_required_group integer;
  v_group integer;
  v_inserted integer:=0;
  v_region_label text;
  v_region_sort integer;
begin
  if p_world not in ('ATP','WTA') then raise exception 'Invalid national-team world.'; end if;
  if p_region_code not in ('EUROPE','AMERICAS','ASIA_OCEANIA','AFRICA') then return 0; end if;

  select label,sort_order into v_region_label,v_region_sort
  from public.national_team_regions
  where code=p_region_code;

  select count(*)::integer into v_count
  from public.national_associations
  where world=p_world
    and region_code=p_region_code
    and status in ('active','renewal_required');

  v_required_group:=greatest(3,3+floor(greatest(v_count-1,0)/8.0)::integer);

  if v_required_group>=4 then
    for v_group in 4..v_required_group loop
      insert into public.national_team_divisions(
        world,region_code,division_code,label,tier_level,capacity,sort_order,
        is_active,promotion_slots,relegation_slots
      )
      values(
        p_world,p_region_code,
        'regional_group_'||v_group::text,
        v_region_label||' Regional Group '||trim(to_char(v_group,'FMRN')),
        v_group+5,8,100+(v_group*10)+v_region_sort,
        true,2,0
      )
      on conflict(world,region_code,division_code) do nothing;

      if found then
        v_inserted:=v_inserted+1;
        update public.national_team_divisions
        set relegation_slots=2
        where world=p_world
          and region_code=p_region_code
          and division_code='regional_group_'||(v_group-1)::text;
      end if;
    end loop;
  end if;

  return v_inserted;
end;
$$;

do $$
declare r record;
begin
  for r in
    select distinct world,region_code
    from public.national_associations
    where status in ('active','renewal_required')
      and region_code<>'GLOBAL'
  loop
    perform public.ensure_national_team_regional_capacity_v1(r.world,r.region_code);
  end loop;
end $$;

revoke all on function public.national_team_region_for_country_v1(text) from public,anon,authenticated;
revoke all on function public.ensure_national_team_regional_capacity_v1(text,text) from public,anon,authenticated;
