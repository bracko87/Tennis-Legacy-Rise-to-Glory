-- Staff hiring is budget-driven only. World ranking must never gate staff hiring.
update public.staff_members
set required_rank_position = null
where required_rank_position is not null;

create or replace function public.force_staff_open_hiring_v1()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  new.required_rank_position := null;
  return new;
end;
$$;

drop trigger if exists trg_staff_open_hiring on public.staff_members;
create trigger trg_staff_open_hiring
before insert or update of required_rank_position on public.staff_members
for each row execute function public.force_staff_open_hiring_v1();

create or replace function public.hire_staff_v1(p_staff_id uuid, p_duration_weeks smallint)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_player public.players%rowtype;
  s public.staff_members%rowtype;
  v_abs integer;
  v_salary integer;
  v_contract uuid;
  f public.player_career_finance_accounts%rowtype;
  v_fin_status text := 'pending';
  v_discount numeric;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if p_duration_weeks not in (13,26,52) then raise exception 'Contract duration must be 13, 26 or 52 weeks.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=auth.uid() and player_type='human';
  if v_player.id is null then raise exception 'Player not found.'; end if;

  select * into s from public.staff_members where id=p_staff_id for update;
  if s.id is null then raise exception 'Staff member not found.'; end if;
  if s.status<>'available' or s.current_player_id is not null then
    raise exception 'This staff member has just accepted another position.';
  end if;
  if exists(
    select 1 from public.player_staff_contracts
    where player_id=v_player.id and role=s.role and status='active'
  ) then
    raise exception 'You already employ a staff member in this role.';
  end if;

  -- No ranking/reputation gate: any available staff member can be hired if affordable.
  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_abs
  from public.get_current_game_day_internal_v1() d;

  v_discount := case p_duration_weeks when 13 then 1.00 when 26 then 0.93 else 0.86 end;
  v_salary := greatest(100,round((s.base_weekly_salary*v_discount)/10.0)*10)::integer;

  insert into public.player_career_finance_accounts(player_id)
  values(v_player.id)
  on conflict(player_id) do nothing;
  select * into f from public.player_career_finance_accounts where player_id=v_player.id for update;

  if f.is_live then
    if f.balance is null or f.balance<s.signing_fee then
      raise exception 'Insufficient career funds for the signing fee.';
    end if;
    update public.player_career_finance_accounts
    set balance=balance-s.signing_fee
    where player_id=v_player.id;
    v_fin_status:='posted';
  end if;

  insert into public.player_staff_contracts(
    player_id,staff_id,role,start_absolute_day,end_absolute_day,duration_weeks,
    weekly_salary,signing_fee,finance_status
  ) values(
    v_player.id,s.id,s.role,v_abs,v_abs+p_duration_weeks*7-1,p_duration_weeks,
    v_salary,s.signing_fee,v_fin_status
  ) returning id into v_contract;

  update public.staff_members
  set status='employed',current_player_id=v_player.id
  where id=s.id;

  insert into public.staff_financial_events(
    player_id,contract_id,event_type,amount,status,game_absolute_day,posted_at
  ) values(
    v_player.id,v_contract,'signing_fee',s.signing_fee,v_fin_status,v_abs,
    case when v_fin_status='posted' then now() else null end
  );

  return jsonb_build_object(
    'status','hired','contract_id',v_contract,'staff_id',s.id,'role',s.role,
    'duration_weeks',p_duration_weeks,'weekly_salary',v_salary,'signing_fee',s.signing_fee,
    'finance_status',v_fin_status,'finance_live',f.is_live
  );
end;
$$;
