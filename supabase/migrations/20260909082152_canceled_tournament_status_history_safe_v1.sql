create or replace function public.get_tournament_status_v1(p_competition_id uuid)
returns table(
  tournament_status text,
  tournament_status_label text,
  applications_open boolean,
  application_open_day bigint,
  application_close_day bigint,
  tournament_start_day bigint,
  tournament_end_day bigint,
  user_status text,
  user_status_label text,
  user_entry_projection text
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  j jsonb;
  tl jsonb;
  u jsonb;
  v_phase text;
  v_app text;
  v_draw text;
  v_entry text;
  v_canceled boolean:=false;
  v_player_id uuid;
  v_season integer;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select (wc.status='canceled' or e.status='canceled'),e.season_number
  into v_canceled,v_season
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  where wc.id=p_competition_id;

  if v_canceled then
    select id into v_player_id
    from public.players
    where owner_user_id=auth.uid() and player_type='human'
    limit 1;

    select te.entry_status,te.draw_type
    into v_entry,v_draw
    from public.tournament_entries te
    where te.competition_id=p_competition_id and te.player_id=v_player_id
    order by te.updated_at desc
    limit 1;

    select ta.status
    into v_app
    from public.tournament_applications ta
    where ta.competition_id=p_competition_id and ta.player_id=v_player_id
    order by ta.updated_at desc
    limit 1;

    application_open_day:=null;
    application_close_day:=null;

    select
      min(public.training_camp_week_start_absolute_v1(e.season_number,sl.season_week::smallint))::bigint,
      max(public.training_camp_week_start_absolute_v1(e.season_number,sl.season_week::smallint)+6)::bigint
    into tournament_start_day,tournament_end_day
    from public.tournament_world_competitions wc
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
    where wc.id=p_competition_id
    group by e.season_number;

    tournament_status:='canceled';
    tournament_status_label:='Canceled';
    applications_open:=false;

    if v_entry is not null or v_app in ('accepted_main_draw','accepted_qualification','applied') then
      user_status:='canceled';
      user_status_label:='Entry canceled · Tournament canceled';
      user_entry_projection:=coalesce(v_draw,case
        when v_app='accepted_main_draw' then 'main_draw'
        when v_app='accepted_qualification' then 'qualification'
        else null end);
    else
      user_status:='not_applied';
      user_status_label:='Not applied';
      user_entry_projection:=null;
    end if;

    return next;
    return;
  end if;

  j:=public.get_tournament_entry_lifecycle_v2(p_competition_id);
  tl:=j->'timeline';
  u:=j->'user';
  v_phase:=j->>'phase';
  v_app:=u->>'application_status';
  v_draw:=u->>'entry_draw_type';
  v_entry:=u->>'entry_status';

  application_open_day:=floor((tl->>'applications_open_game_second')::bigint::numeric/86400)::bigint;
  application_close_day:=floor((tl->>'normal_close_game_second')::bigint::numeric/86400)::bigint;
  tournament_start_day:=(tl->'tournament_start'->>'absolute_day')::bigint;

  select max(public.training_camp_week_start_absolute_v1(e.season_number,sl.season_week::smallint)+6)::bigint
  into tournament_end_day
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
  where wc.id=p_competition_id
  group by e.season_number;

  tournament_status:=v_phase;
  tournament_status_label:=case v_phase
    when 'applications_not_open' then 'Applications not open'
    when 'applications_open' then 'Applications open'
    when 'selection_complete' then 'Selection complete'
    when 'final_vacancies_open' then 'Final vacancies open'
    when 'field_locked' then 'Final field locked'
    when 'draw_published' then 'Draw published'
    when 'in_progress' then 'Tournament in progress'
    when 'completed' then 'Completed'
    else initcap(replace(v_phase,'_',' ')) end;
  applications_open:=v_phase='applications_open';

  if v_entry='eliminated' then user_status:='eliminated';user_status_label:='Eliminated';
  elsif v_phase='in_progress' and v_entry='active' then user_status:='competing';user_status_label:='Competing';
  elsif v_draw='main_draw' and v_entry='active' then user_status:='accepted_main_draw';user_status_label:='Accepted · Main Draw';
  elsif v_draw='qualification' and v_entry='active' then user_status:='accepted_qualification';user_status_label:='Accepted · Qualification';
  elsif v_app='accepted_main_draw' then user_status:='accepted_main_draw';user_status_label:='Accepted · Main Draw';
  elsif v_app='accepted_qualification' then user_status:='accepted_qualification';user_status_label:='Accepted · Qualification';
  elsif v_app='rejected' then user_status:='rejected';user_status_label:='Application rejected';
  elsif v_app='superseded' then user_status:='withdrawn';user_status_label:='Application replaced';
  elsif v_app='withdrawn' then user_status:='withdrawn';user_status_label:='Application withdrawn';
  elsif v_app='applied' then user_status:='pending';user_status_label:='Application pending';
  elsif v_phase in ('selection_complete','final_vacancies_open','field_locked','draw_published','in_progress','completed') then user_status:='did_not_apply';user_status_label:='Did not apply';
  else user_status:='not_applied';user_status_label:='Not applied'; end if;

  user_entry_projection:=case
    when v_draw in ('main_draw','qualification') then v_draw
    when v_app='accepted_main_draw' then 'main_draw'
    when v_app='accepted_qualification' then 'qualification'
    when v_app='rejected' then 'rejected'
    else null end;
  return next;
end;
$$;