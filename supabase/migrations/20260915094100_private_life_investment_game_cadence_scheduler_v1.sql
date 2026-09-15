do $do$
declare
  v_token text;
  v_url text := 'https://cwfznmroiqcyhfkfcrow.supabase.co/functions/v1/refresh-private-life-investment-quotes';
begin
  select cron_token into v_token from public.private_life_quote_refresh_control where id=1;
  if v_token is null or v_token='' then raise exception 'Private Life quote scheduler token missing'; end if;

  if exists(select 1 from cron.job where jobname='tennis-private-life-stock-quotes-v1') then
    perform cron.unschedule('tennis-private-life-stock-quotes-v1');
  end if;
  if exists(select 1 from cron.job where jobname='tennis-private-life-crypto-quotes-v1') then
    perform cron.unschedule('tennis-private-life-crypto-quotes-v1');
  end if;

  perform cron.schedule(
    'tennis-private-life-stock-quotes-v1',
    '* 12-22 * * 1-5',
    format($cmd$select net.http_post(url := %L, headers := '{"Content-Type":"application/json"}'::jsonb, body := %L::jsonb);$cmd$,
      v_url,
      jsonb_build_object('mode','stocks','cron_token',v_token)::text)
  );

  perform cron.schedule(
    'tennis-private-life-crypto-quotes-v1',
    '* * * * *',
    format($cmd$select net.http_post(url := %L, headers := '{"Content-Type":"application/json"}'::jsonb, body := %L::jsonb);$cmd$,
      v_url,
      jsonb_build_object('mode','crypto','cron_token',v_token)::text)
  );
end
$do$;
