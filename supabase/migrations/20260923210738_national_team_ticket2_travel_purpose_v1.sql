
alter table public.player_travel_legs
  drop constraint if exists player_travel_legs_purpose_check;

alter table public.player_travel_legs
  add constraint player_travel_legs_purpose_check
  check (purpose = any(array[
    'training_camp'::text,
    'tournament'::text,
    'national_team'::text,
    'return_home'::text,
    'other'::text
  ]));
