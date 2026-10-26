\set ON_ERROR_STOP on
do $permissions$
declare x record; n integer := 0;
begin
 for x in
  select * from (values
   ('insert_planned_travel_leg_v1(uuid,text,text,text,text,double precision,double precision,text,text,text,text,double precision,double precision,text,integer,integer,boolean)'),
   ('process_travel_leg_v1(uuid)'),
   ('rebuild_player_travel_plan_core_v1(uuid)'),
   ('resolve_player_origin_before_day_v1(uuid,integer)'),
   ('rebuild_player_travel_plan_v1(uuid)'),
   ('apply_training_camp_split_travel_v1(uuid)'),
   ('process_due_travel_legs_v1(uuid,integer)')
  ) as funcs(signature)
 loop
  if to_regprocedure('public.'||x.signature) is null then
   raise exception 'Security-critical helper is missing: %',x.signature;
  end if;
  if has_function_privilege('anon','public.'||x.signature,'EXECUTE') or
     has_function_privilege('authenticated','public.'||x.signature,'EXECUTE')
  then
   raise exception 'Public role can call privileged travel helper: %',x.signature;
  end if;
  n:=n+1;
 end loop;
 if n<>7 then raise exception 'Missing privileged helper checks';end if;
 raise notice 'PASS: all seven privileged player-id / travel-id helpers deny anon and authenticated';
end;$permissions$;
