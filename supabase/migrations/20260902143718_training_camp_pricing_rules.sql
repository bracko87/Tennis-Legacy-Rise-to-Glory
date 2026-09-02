create table if not exists public.training_camp_pricing_rules (
  quality_tier text not null check (quality_tier in ('standard','advanced','elite')),
  category text not null check (category in ('tennis_skills','physical','recovery_mindset')),
  weekly_training_fee integer not null check (weekly_training_fee>=0),
  facility_rating numeric(2,1) not null,
  quality_multiplier numeric(5,3) not null,
  description text not null,
  primary key(quality_tier,category)
);

insert into public.training_camp_pricing_rules(quality_tier,category,weekly_training_fee,facility_rating,quality_multiplier,description)
values
 ('standard','recovery_mindset',1200,4.1,1.000,'Entry-level recovery program with the standard camp recovery profile.'),
 ('standard','physical',1400,4.1,1.000,'Entry-level physical development program.'),
 ('standard','tennis_skills',1500,4.1,1.000,'Entry-level surface-specific technical program.'),
 ('advanced','recovery_mindset',1800,4.5,1.150,'Advanced recovery program with stronger recovery efficiency.'),
 ('advanced','physical',2100,4.5,1.150,'Advanced physical development program.'),
 ('advanced','tennis_skills',2300,4.5,1.150,'Advanced surface-specific technical program.'),
 ('elite','recovery_mindset',2700,4.8,1.300,'Elite recovery program with the strongest recovery efficiency.'),
 ('elite','physical',3200,4.8,1.300,'Elite physical development program.'),
 ('elite','tennis_skills',3400,4.8,1.300,'Elite surface-specific technical program.')
on conflict(quality_tier,category) do update set weekly_training_fee=excluded.weekly_training_fee,facility_rating=excluded.facility_rating,quality_multiplier=excluded.quality_multiplier,description=excluded.description;

alter table public.training_camp_pricing_rules enable row level security;
drop policy if exists training_camp_pricing_rules_read on public.training_camp_pricing_rules;
create policy training_camp_pricing_rules_read on public.training_camp_pricing_rules for select to authenticated using (true);
grant select on public.training_camp_pricing_rules to authenticated;

update public.training_camp_programs p
set weekly_cost=r.weekly_training_fee,rating=r.facility_rating,quality_multiplier=r.quality_multiplier,updated_at=now()
from public.training_camp_pricing_rules r
where r.quality_tier=p.quality_tier and r.category=p.category;
