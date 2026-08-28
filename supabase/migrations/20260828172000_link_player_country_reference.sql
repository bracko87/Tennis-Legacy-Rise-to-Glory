alter table public.players
  drop constraint if exists players_country_code_fkey;

alter table public.players
  add constraint players_country_code_fkey
  foreign key (country_code)
  references public.countries(code)
  on update restrict
  on delete restrict;
