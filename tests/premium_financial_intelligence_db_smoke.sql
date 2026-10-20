-- Read-only Premium Financial Intelligence smoke test.
-- Run after deployment, or prepend migration inside the BEGIN transaction.
begin;
do $qa$
declare
 v_world text;v_user uuid;v_player uuid;v_other uuid;
 v_report jsonb;v_row jsonb;v_balance bigint;v_income bigint;v_expenses bigint;
 v_sponsors bigint;v_staff bigint;v_travel bigint;v_denied boolean;
begin
 foreach v_world in array array['ATP','WTA'] loop
   select p.owner_user_id,p.id into v_user,v_player
   from public.players p
   join public.player_career_finance_accounts a on a.player_id=p.id
   where p.world=v_world and p.player_type='human' and p.owner_user_id is not null
   and (exists(select 1 from public.premium_memberships m
     where m.user_id=p.owner_user_id and m.plan_code='premium'
       and m.status='active' and (m.current_period_end is null or m.current_period_end>now()))
    or exists(select 1 from public.tennis_premium_trials_v1 t
     where t.user_id=p.owner_user_id and t.expires_at>now()))
   limit 1;
   if v_player is null then raise exception 'No eligible finance account for %',v_world;end if;
   perform set_config('request.jwt.claim.sub',v_user::text,true);
   v_report:=public.get_premium_financial_intelligence_v1(v_player);
   select a.balance into v_balance from public.player_career_finance_accounts a
    where a.player_id=v_player;
   if v_report->>'player_id'<>v_player::text
    or (v_report->>'opening_cash')::bigint<>v_balance
    or jsonb_array_length(v_report->'historic_weeks')<>13
    or jsonb_array_length(v_report->'future_weeks')<>13
   then raise exception 'Invalid % reporting payload',v_world;end if;

   select coalesce(sum((j->>'income')::bigint),0),
     coalesce(sum((j->>'expenses')::bigint),0)
   into v_income,v_expenses from jsonb_array_elements(v_report->'historic_weeks') j;
   if (v_report->>'historic_13_week_income')::bigint<>v_income
     or (v_report->>'historic_13_week_expenses')::bigint<>v_expenses
   then raise exception 'Historical % 13-week sums differ',v_world;end if;

   select coalesce(sum((j->>'scheduled_sponsor_income')::bigint),0),
     coalesce(sum((j->>'contracted_staff_cost')::bigint),0),
     coalesce(sum((j->>'planned_travel_cost')::bigint),0)
   into v_sponsors,v_staff,v_travel from jsonb_array_elements(v_report->'future_weeks') j;
   if v_sponsors<>(v_report->>'scheduled_13_week_sponsor_income')::bigint
      or v_staff<>(v_report->>'contracted_13_week_staff_cost')::bigint
      or v_travel<>(v_report->>'planned_13_week_travel_cost')::bigint
     then raise exception 'Forward % sums differ',v_world;end if;
   for v_row in select value from jsonb_array_elements(v_report->'future_weeks') x(value) loop
     if (v_row->>'week')::integer not between 1 and 13
       or (v_row->>'through_day')::integer<=(v_report->>'current_absolute_day')::integer
       or (v_row->>'known_net')::bigint<>
       ((v_row->>'scheduled_sponsor_income')::bigint-
         (v_row->>'contracted_staff_cost')::bigint-
         (v_row->>'planned_travel_cost')::bigint)
     then raise exception 'Invalid % weekly planning row',v_world;end if;
   end loop;
 end loop;

 select id into v_other from public.players p
 where p.owner_user_id<>v_user and p.owner_user_id is not null limit 1;
 v_denied:=false;
 begin perform public.get_premium_financial_intelligence_v1(v_other);
 exception when sqlstate '42501' then v_denied:=true;end;
 if not v_denied then raise exception 'Cross-owner finance access permitted';end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 v_denied:=false;
 begin perform public.get_premium_financial_intelligence_v1(v_player);
 exception when sqlstate '42501' then v_denied:=true;end;
 if not v_denied then raise exception 'Free account finance access permitted';end if;
 perform set_config('request.jwt.claim.sub','',true);
 v_denied:=false;
 begin perform public.get_premium_financial_intelligence_v1(v_player);
 exception when sqlstate '42501' then v_denied:=true;end;
 if not v_denied then raise exception 'Anonymous finance access permitted';end if;
 if has_function_privilege('anon'::regrole,
    'public.get_premium_financial_intelligence_v1(uuid)','EXECUTE')
   then raise exception 'Anon role has RPC EXECUTE privilege';end if;
end
$qa$;
rollback;
