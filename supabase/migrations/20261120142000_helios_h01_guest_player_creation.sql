-- Helios H01: only a valid, enrolled Supabase anonymous guest can omit a home city.
-- Registered players retain their existing mandatory home-city validation.
-- Feature remains disabled; guest enrollment must be enabled separately after H02/H08.
CREATE OR REPLACE FUNCTION public.is_my_active_tennis_guest_v1()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','auth','control_center_private','pg_temp'
AS $fn$
  SELECT auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM auth.users u
      JOIN control_center_private.tennis_guest_trials_v1 g ON g.user_id=u.id
      WHERE u.id=auth.uid() AND u.is_anonymous
        AND g.expires_at>now()
    )
$fn$;
REVOKE ALL ON FUNCTION public.is_my_active_tennis_guest_v1() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.is_my_active_tennis_guest_v1() TO authenticated;

CREATE OR REPLACE FUNCTION public.validate_player_home_city_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.home_city is null or btrim(new.home_city) = '' then
    if tg_op = 'INSERT' and not public.is_my_active_tennis_guest_v1() then
      raise exception 'Choose a home city before creating the player.';
    end if;
    return new;
  end if;

  if not exists (
    select 1
    from public.player_home_city_options h
    where h.country_code = upper(new.country_code)
      and lower(h.city) = lower(btrim(new.home_city))
      and h.is_active
  ) then
    raise exception 'The selected home city is not available for this country.';
  end if;

  select h.city into new.home_city
  from public.player_home_city_options h
  where h.country_code = upper(new.country_code)
    and lower(h.city) = lower(btrim(new.home_city))
    and h.is_active
  order by h.sort_order
  limit 1;

  return new;
end;
$function$
;

-- The guest can have exactly one owner-linked human player.
-- Guard executes before ranking/finance/asset creation triggers.
CREATE OR REPLACE FUNCTION public.guard_tennis_guest_player_creation_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','auth','control_center_private','pg_temp'
AS $fn$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=auth.uid() AND is_anonymous) THEN
    RETURN NEW;
  END IF;
  PERFORM public.assert_my_tennis_guest_access_v1();
  IF NEW.owner_user_id IS DISTINCT FROM auth.uid() OR NEW.player_type<>'human' THEN
    RAISE EXCEPTION 'Guest must create an owned human player.' USING errcode='42501';
  END IF;
  IF EXISTS(SELECT 1 FROM public.players p WHERE p.owner_user_id=auth.uid() AND p.player_type='human') THEN
    RAISE EXCEPTION 'Guest player already created.' USING errcode='23505';
  END IF;
  IF NEW.home_city IS NOT NULL AND btrim(NEW.home_city)<>'' THEN
    RAISE EXCEPTION 'Guest player home city must be omitted.' USING errcode='22023';
  END IF;
  IF coalesce(btrim(NEW.first_name),'')='' OR coalesce(btrim(NEW.last_name),'')=''
    OR length(NEW.country_code)<>2 OR coalesce(btrim(NEW.image_path),'')='' THEN
    RAISE EXCEPTION 'Guest requires first and last name, country and appearance.' USING errcode='22023';
  END IF;
  RETURN NEW;
END;
$fn$;
REVOKE ALL ON FUNCTION public.guard_tennis_guest_player_creation_v1() FROM PUBLIC,anon;
DROP TRIGGER IF EXISTS aa_guard_tennis_guest_player_creation_v1 ON public.players;
CREATE TRIGGER aa_guard_tennis_guest_player_creation_v1
BEFORE INSERT ON public.players FOR EACH ROW
EXECUTE FUNCTION public.guard_tennis_guest_player_creation_v1();
