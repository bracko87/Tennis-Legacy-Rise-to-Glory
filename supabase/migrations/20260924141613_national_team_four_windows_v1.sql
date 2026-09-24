
alter table public.national_team_windows
  add column if not exists window_number smallint,
  add column if not exists window_mode text not null default 'official_mixed',
  add column if not exists competition_phase text not null default 'National competition',
  add column if not exists official_from_season integer not null default 2,
  add column if not exists allows_friendlies boolean not null default true;

alter table public.national_team_windows
  drop constraint if exists national_team_windows_window_mode_check;
alter table public.national_team_windows
  add constraint national_team_windows_window_mode_check
  check(window_mode in ('friendly_only','official_mixed'));

alter table public.national_team_windows
  drop constraint if exists national_team_windows_window_number_check;
alter table public.national_team_windows
  add constraint national_team_windows_window_number_check
  check(window_number is null or window_number between 1 and 4);

create or replace function public.ensure_national_team_windows_v1(p_season_number integer)
returns integer
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_cfg public.national_team_competition_config%rowtype;
  v_world text;
  v_num integer;
  v_week integer;
  v_start integer;
  v_base integer:=(p_season_number-1)*366;
  v_count integer:=0;
  v_code text;
  v_label text;
  v_phase text;
  v_mode text;
  v_status text;
  v_now integer:=public.national_team_current_abs_day_v1();
begin
  if p_season_number<1 then raise exception 'Invalid season.'; end if;
  select * into v_cfg from public.national_team_competition_config where id=1;

  foreach v_world in array array['ATP'::text,'WTA'::text] loop
    for v_num in 1..4 loop
      v_week:=case v_num when 1 then 7 when 2 then 22 when 3 then 36 else 47 end;
      v_code:='national_window_'||v_num::text;
      v_label:=case v_num
        when 1 then 'National Team Window I · Spring'
        when 2 then 'National Team Window II · Regional'
        when 3 then 'National Team Window III · Autumn'
        else 'National Team Window IV · Finals'
      end;
      v_phase:=case
        when p_season_number<v_cfg.official_launch_season then 'Friendly matches'
        when v_num=1 then 'Qualifiers Round 1 · World Groups'
        when v_num=2 then 'Regional Groups'
        when v_num=3 then 'Qualifiers Round 2 · World Groups'
        else 'Final 8 · Season Finals'
      end;
      v_mode:=case when p_season_number<v_cfg.official_launch_season then 'friendly_only' else 'official_mixed' end;
      v_start:=v_base+2+(v_week-1)*7;

      v_status:=case
        when v_now>v_start+6 then 'completed'
        when v_now>=v_start then 'in_progress'
        when v_now>=greatest(0,v_start-v_cfg.announcement_lead_days) then 'announced'
        else 'planned'
      end;

      insert into public.national_team_windows(
        world,season_number,window_code,label,season_week,start_absolute_day,end_absolute_day,
        announcement_absolute_day,callup_deadline_absolute_day,squad_deadline_absolute_day,
        max_ties_per_association,status,window_number,window_mode,competition_phase,
        official_from_season,allows_friendlies
      )
      values(
        v_world,p_season_number,v_code,v_label,v_week,v_start,v_start+6,
        greatest(0,v_start-v_cfg.announcement_lead_days),
        greatest(v_base,v_start-v_cfg.callup_deadline_days_before_window),
        greatest(v_base,v_start-v_cfg.squad_deadline_days_before_window),
        2,v_status,v_num,v_mode,v_phase,v_cfg.official_launch_season,true
      )
      on conflict(world,season_number,window_code) do update
      set label=excluded.label,
          season_week=excluded.season_week,
          start_absolute_day=excluded.start_absolute_day,
          end_absolute_day=excluded.end_absolute_day,
          announcement_absolute_day=excluded.announcement_absolute_day,
          callup_deadline_absolute_day=excluded.callup_deadline_absolute_day,
          squad_deadline_absolute_day=excluded.squad_deadline_absolute_day,
          max_ties_per_association=excluded.max_ties_per_association,
          window_number=excluded.window_number,
          window_mode=excluded.window_mode,
          competition_phase=excluded.competition_phase,
          official_from_season=excluded.official_from_season,
          allows_friendlies=excluded.allows_friendlies,
          status=case when public.national_team_windows.status='cancelled' then 'cancelled' else excluded.status end,
          updated_at=now();

      if found then v_count:=v_count+1; end if;
    end loop;
  end loop;

  return v_count;
end;
$$;

delete from public.national_team_windows w
where w.window_code in ('national_week_1','national_week_2')
  and not exists(select 1 from public.national_team_fixtures f where f.window_id=w.id);

select public.ensure_national_team_windows_v1(1);
select public.ensure_national_team_windows_v1(2);
select public.ensure_national_team_windows_v1(3);

alter table public.national_team_fixtures
  add column if not exists fixture_kind text not null default 'official';

alter table public.national_team_fixtures
  drop constraint if exists national_team_fixtures_fixture_kind_check;
alter table public.national_team_fixtures
  add constraint national_team_fixtures_fixture_kind_check
  check(fixture_kind in ('official','friendly'));

revoke all on function public.ensure_national_team_windows_v1(integer) from public,anon,authenticated;
