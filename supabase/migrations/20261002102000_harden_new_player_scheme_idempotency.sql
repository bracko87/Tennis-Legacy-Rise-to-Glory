-- Harden New Player Starting Scheme v1 orchestration.
-- The master initializer is an INSERT-only career event. Later profile/tour updates
-- must never re-run Day-1 validation against an established career.

create or replace function public.initialize_new_human_career_v1(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_player record;
  v_existing_audit public.new_player_initialization_audit%rowtype;
  v_finance jsonb;
  v_coins jsonb;
  v_home uuid;
  v_equipment_count integer:=0;
  v_accessory_count integer:=0;
  v_staff_count integer:=0;
  v_sponsor_count integer:=0;
  v_technical_sponsor_count integer:=0;
  v_assoc_count integer:=0;
  v_club_count integer:=0;
  v_calendar_count integer:=0;
  v_training_count integer:=0;
  v_skill_count integer:=0;
  v_rank_points bigint:=0;
  v_doubles_points bigint:=0;
  v_validation jsonb;
begin
  select p.id,p.owner_user_id,p.player_type,p.world,p.country_code,p.home_city
  into v_player
  from public.players p
  where p.id=p_player_id;

  if v_player.id is null
     or v_player.player_type<>'human'
     or v_player.owner_user_id is null then
    return jsonb_build_object('status','skipped','reason','not_owned_human_player');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('new-human-career:'||p_player_id::text,0));

  select * into v_existing_audit
  from public.new_player_initialization_audit
  where player_id=p_player_id;

  if v_existing_audit.player_id is not null then
    return jsonb_build_object(
      'status','already_initialized',
      'scheme_version',v_existing_audit.scheme_version,
      'player_id',p_player_id,
      'initialized_at',v_existing_audit.initialized_at,
      'validation',v_existing_audit.validation_result
    );
  end if;

  v_finance:=public.ensure_player_career_finance_v1(p_player_id);
  v_coins:=public.grant_new_career_starting_coins_v1(v_player.owner_user_id);

  perform public.initialize_player_equipment_v1(p_player_id);
  v_home:=public.ensure_private_life_starter_home_v1(p_player_id);

  select count(*) into v_equipment_count
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id
    and i.acquired_source='starter'
    and c.item_type in ('racket','shoes','apparel');

  select count(*) into v_accessory_count
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id
    and i.acquired_source='starter'
    and c.item_type='accessory';

  select count(*) into v_staff_count
  from public.player_staff_contracts
  where player_id=p_player_id and status='active';

  select count(*) into v_sponsor_count
  from public.player_sponsor_contracts
  where player_id=p_player_id and status='active';

  select count(*) into v_technical_sponsor_count
  from public.player_technical_sponsor_contracts
  where player_id=p_player_id and status='active';

  select count(*) into v_assoc_count
  from public.national_association_memberships
  where player_id=p_player_id and status='active';

  select count(*) into v_club_count
  from public.tennis_club_memberships
  where player_id=p_player_id;

  select count(*) into v_calendar_count
  from public.player_calendar_commitments
  where player_id=p_player_id and status='committed';

  select count(*) into v_training_count
  from public.player_training_plans
  where player_id=p_player_id;

  select count(*) into v_skill_count
  from public.player_skills
  where player_id=p_player_id;

  select coalesce(r.ranking_points,0)
  into v_rank_points
  from public.player_rankings r
  where r.player_id=p_player_id;

  select coalesce(r.ranking_points,0)
  into v_doubles_points
  from public.player_doubles_rankings r
  where r.player_id=p_player_id;

  v_validation:=jsonb_build_object(
    'starter_equipment_count',v_equipment_count,
    'starter_accessory_count',v_accessory_count,
    'active_staff_count',v_staff_count,
    'active_regular_sponsors',v_sponsor_count,
    'active_technical_sponsors',v_technical_sponsor_count,
    'active_association_memberships',v_assoc_count,
    'club_memberships',v_club_count,
    'calendar_commitments',v_calendar_count,
    'configured_training_plans',v_training_count,
    'skill_rows',v_skill_count,
    'singles_ranking_points',coalesce(v_rank_points,0),
    'doubles_ranking_points',coalesce(v_doubles_points,0)
  );

  if v_equipment_count<>3
     or v_accessory_count<>0
     or v_staff_count<>0
     or v_sponsor_count<>0
     or v_technical_sponsor_count<>0
     or v_assoc_count<>0
     or v_club_count<>0
     or v_calendar_count<>0
     or v_training_count<>0
     or v_skill_count<>1
     or coalesce(v_rank_points,0)<>0
     or coalesce(v_doubles_points,0)<>0 then
    raise exception 'New Player Starting Scheme validation failed for player %: %',p_player_id,v_validation;
  end if;

  insert into public.new_player_initialization_audit(
    player_id,user_id,scheme_version,finance_result,coins_result,
    equipment_result,private_life_result,validation_result,updated_at
  ) values(
    p_player_id,v_player.owner_user_id,'v1',coalesce(v_finance,'{}'::jsonb),coalesce(v_coins,'{}'::jsonb),
    jsonb_build_object('starter_items',v_equipment_count,'starter_accessories',v_accessory_count),
    jsonb_build_object('starter_home_id',v_home),
    v_validation,now()
  );

  return jsonb_build_object(
    'status','initialized',
    'scheme_version','v1',
    'player_id',p_player_id,
    'finance',v_finance,
    'coins',v_coins,
    'starter_home_id',v_home,
    'validation',v_validation
  );
end;
$$;

-- Restore INSERT behavior for AI private-life setup; the function itself gates
-- human starter homes behind Premium. Human INSERT remains safe/idempotent
-- because the master initializer sees the same starter-home entitlement.
drop trigger if exists ensure_private_life_starter_home_v1 on public.players;
create trigger ensure_private_life_starter_home_v1
after insert or update of owner_user_id,country_code,home_city,player_type
on public.players
for each row
execute function public.trg_ensure_private_life_starter_home_v1();

drop trigger if exists zz_initialize_new_human_career_v1 on public.players;
create trigger zz_initialize_new_human_career_v1
after insert
on public.players
for each row
when (new.player_type='human' and new.owner_user_id is not null)
execute function public.trg_initialize_new_human_career_v1();
