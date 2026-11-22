CREATE OR REPLACE FUNCTION public.create_commerce_checkout_intent_v1(p_catalog_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_user uuid:=auth.uid();
  v_item public.commerce_catalog_items%rowtype;
  v_intent uuid;
  v_email text;
begin
  PERFORM public.assert_my_tennis_guest_access_v1();
  if v_user is null then raise exception 'Authentication required.'; end if;
  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=v_user AND u.is_anonymous IS FALSE AND u.deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Register a permanent account before making a purchase.' USING ERRCODE='42501';
  END IF;

  select * into v_item
  from public.commerce_catalog_items
  where code=p_catalog_code and is_active;

  if v_item.code is null then raise exception 'Commerce item is unavailable.'; end if;

  if v_item.kind='premium'
     and exists(
       select 1 from public.premium_memberships
       where user_id=v_user
         and plan_code='premium'
         and status='active'
         and (current_period_end is null or current_period_end>now())
     )
  then
    return jsonb_build_object(
      'status','already_premium',
      'catalog_code',v_item.code,
      'portal_url',(select stripe_customer_portal_url from public.commerce_runtime_settings where id=true)
    );
  end if;

  update public.commerce_checkout_intents
  set status='expired'
  where user_id=v_user and status='open' and expires_at<=now();

  insert into public.commerce_checkout_intents(user_id,catalog_code)
  values(v_user,v_item.code)
  returning id into v_intent;

  select email into v_email from auth.users where id=v_user;

  return jsonb_build_object(
    'status','ready',
    'intent_id',v_intent,
    'catalog_code',v_item.code,
    'payment_link_url',v_item.stripe_payment_link_url,
    'prefilled_email',v_email,
    'expires_at',now()+interval '2 hours'
  );
end;
$function$;
