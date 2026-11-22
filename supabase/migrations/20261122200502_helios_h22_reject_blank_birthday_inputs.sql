CREATE OR REPLACE FUNCTION public.set_my_tennis_converted_birthday_v1(p_month integer, p_day integer, p_year integer DEFAULT NULL::integer, p_timezone text DEFAULT 'UTC'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid:=auth.uid(); v_birth date; v_tz text:=coalesce(nullif(p_timezone,''),'UTC');
begin
  if v_id is null or not exists (
    select 1 from control_center_private.tennis_guest_trials_v1 t
    join auth.users u on u.id=t.user_id
    where t.user_id=v_id and t.converted_at is not null and u.is_anonymous is false and u.deleted_at is null
  ) then raise exception 'Only a converted permanent account can add a missing birthday.' using errcode='42501'; end if;
  if p_month is null or p_day is null or p_month not between 1 and 12 or p_day not between 1 and 31 or p_year is not null and p_year not between 1900 and extract(year from current_date)::integer then
    raise exception 'Invalid birthday.' using errcode='22023'; end if;
  begin v_birth:=pg_catalog.make_date(coalesce(p_year,2000),p_month,p_day);
  exception when others then raise exception 'Invalid birthday date.' using errcode='22023'; end;
  if p_year is not null and v_birth>current_date then raise exception 'Birthday cannot be in the future.' using errcode='22023'; end if;
  if not exists(select 1 from pg_catalog.pg_timezone_names where name=v_tz) then
    raise exception 'Invalid timezone.' using errcode='22023'; end if;
  update public.profiles set birthday_month=p_month,birthday_day=p_day,birthday_year=p_year,birthday_timezone=v_tz
  where id=v_id and birthday_month is null and birthday_day is null and birthday_year is null;
  if not found then raise exception 'Birthday was already saved and cannot be changed.' using errcode='42501'; end if;
  return jsonb_build_object('status','saved','birthday_set',true);
end;
$function$
