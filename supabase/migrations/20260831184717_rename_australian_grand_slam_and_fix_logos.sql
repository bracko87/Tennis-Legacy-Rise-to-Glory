update public.tournament_series
set
  name = 'Australian Grand Slam',
  slug = 'australian-grand-slam',
  logo_url = 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Australian%20Grand%20slem.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvQXVzdHJhbGlhbiBHcmFuZCBzbGVtLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgyMDEzODgsImV4cCI6NDkxMDI2NTM4OH0.31RPD-AkdCNcRPRFhGTN9JA6gYwRChduCv6Myv4L8OgWptSOAuIzQWxczY8BQBegm8uFOX19uZwH2a9eG6BR6w'
where name = 'Melbourne Grand Championship';

update public.tournament_series
set logo_url = 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Tournament%20Logos/January/Lima%20Challenger.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9Ub3VybmFtZW50IExvZ29zL0phbnVhcnkvTGltYSBDaGFsbGVuZ2VyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODgyMDEzMjksImV4cCI6NDkxMDI2NTMyOX0.I7ecryuqqXQ9aJZs9cr7GjrPamGxJYJODD2RC1v2lBRKhZ9N09bR8UnmBJ2MZOKswqL_Q8EDU87Nl-l_0rwrnA'
where name = 'Lima Challenger';

do $$
begin
  if not exists (select 1 from public.tournament_series where name = 'Australian Grand Slam') then
    raise exception 'Australian Grand Slam rename failed';
  end if;
  if not exists (select 1 from public.tournament_series where name = 'Lima Challenger' and logo_url is not null) then
    raise exception 'Lima Challenger logo assignment failed';
  end if;
end $$;
