
-- Complete doubles notifications beyond entry/draw: match schedule/reschedule + match result.

insert into public.notification_catalog(
  code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,source_name,
  title_template,message_template,default_route,severity,
  default_in_app,default_email,default_push,is_user_configurable,is_active
)
values
(
  'doubles.match.scheduled','tournament','Doubles Match Scheduled',
  'A doubles match received a confirmed or updated time and court.',
  'doubles_match_scheduled',
  'A doubles match for the player is scheduled or rescheduled.',
  'Doubles unified match scheduler','Doubles',
  'Doubles match scheduled',
  'Your doubles match has a confirmed time and court.',
  '/game/calendar?tab=tournament-calendar','info',
  true,false,false,true,true
),
(
  'doubles.match.result','tournament','Doubles Match Result',
  'A doubles match involving the player finished.',
  'doubles_match_completed',
  'A doubles match finishes by play or walkover.',
  'Doubles match engine','Doubles',
  'Doubles match result',
  'Your doubles match has finished.',
  '/game/calendar?tab=tournament-calendar','info',
  true,false,false,true,true
)
on conflict(code) do update set
  category=excluded.category,
  label=excluded.label,
  reason=excluded.reason,
  trigger_event=excluded.trigger_event,
  trigger_condition=excluded.trigger_condition,
  trigger_mechanism=excluded.trigger_mechanism,
  source_name=excluded.source_name,
  title_template=excluded.title_template,
  message_template=excluded.message_template,
  severity=excluded.severity,
  default_in_app=excluded.default_in_app,
  is_user_configurable=excluded.is_user_configurable,
  is_active=true,
  updated_at=now();

create or replace function public.notify_doubles_match_scheduled_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_t1 public.tournament_doubles_teams%rowtype;
  v_t2 public.tournament_doubles_teams%rowtype;
  v_tournament text;
  v_city text;
  v_route text;
  v_hour integer;
  v_minute integer;
  v_schedule text;
  v_partner_name text;
  v_opponents text;
  v_team_id uuid;
  v_partner_id uuid;
  r record;
begin
  if new.status<>'scheduled'
     or new.team1_id is null
     or new.team2_id is null
     or new.scheduled_start_minute is null then
    return new;
  end if;

  if tg_op='UPDATE'
     and old.scheduled_start_minute is not distinct from new.scheduled_start_minute
     and old.scheduled_season_week is not distinct from new.scheduled_season_week
     and old.scheduled_day is not distinct from new.scheduled_day
     and old.court_number is not distinct from new.court_number then
    return new;
  end if;

  select * into v_t1 from public.tournament_doubles_teams where id=new.team1_id;
  select * into v_t2 from public.tournament_doubles_teams where id=new.team2_id;

  select ts.name,ts.city
  into v_tournament,v_city
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=new.competition_id;

  v_route:=format('/game/tournaments/%s/doubles',new.competition_id);
  v_hour:=floor(new.scheduled_start_minute/60.0)::integer;
  v_minute:=mod(new.scheduled_start_minute,60);
  v_schedule:=format(
    'Season Week %s · Day %s · %s:%s%s',
    new.scheduled_season_week,
    new.scheduled_day,
    lpad(v_hour::text,2,'0'),
    lpad(v_minute::text,2,'0'),
    case when new.court_number is null then '' else format(' · Court %s',new.court_number) end
  );

  for r in
    select p.id,p.owner_user_id
    from public.players p
    where p.id in (
      v_t1.player1_id,v_t1.player2_id,
      v_t2.player1_id,v_t2.player2_id
    )
      and p.owner_user_id is not null
  loop
    if r.id in (v_t1.player1_id,v_t1.player2_id) then
      v_team_id:=v_t1.id;
      v_partner_id:=case when r.id=v_t1.player1_id then v_t1.player2_id else v_t1.player1_id end;
      select
        trim(p1.first_name||' '||p1.last_name)||' & '||
        trim(p2.first_name||' '||p2.last_name)
      into v_opponents
      from public.players p1,public.players p2
      where p1.id=v_t2.player1_id and p2.id=v_t2.player2_id;
    else
      v_team_id:=v_t2.id;
      v_partner_id:=case when r.id=v_t2.player1_id then v_t2.player2_id else v_t2.player1_id end;
      select
        trim(p1.first_name||' '||p1.last_name)||' & '||
        trim(p2.first_name||' '||p2.last_name)
      into v_opponents
      from public.players p1,public.players p2
      where p1.id=v_t1.player1_id and p2.id=v_t1.player2_id;
    end if;

    select trim(first_name||' '||last_name)
    into v_partner_name
    from public.players
    where id=v_partner_id;

    perform public.emit_notification_v1(
      r.owner_user_id,
      r.id,
      'doubles.match.scheduled',
      case
        when tg_op='UPDATE' and old.scheduled_start_minute is not null
          then 'Doubles match rescheduled · '||v_tournament
        else 'Doubles match scheduled · '||v_tournament
      end,
      format(
        'Your %s match with %s against %s is scheduled for %s. Your tactic locks one game hour before the match.',
        new.round_label,v_partner_name,v_opponents,v_schedule
      ),
      v_route,
      jsonb_build_object(
        'competition_id',new.competition_id,
        'tournament_name',v_tournament,
        'city',v_city,
        'match_id',new.id,
        'team_id',v_team_id,
        'partner_name',v_partner_name,
        'opponents',v_opponents,
        'round_label',new.round_label,
        'season_week',new.scheduled_season_week,
        'day',new.scheduled_day,
        'start_minute',new.scheduled_start_minute,
        'court_number',new.court_number,
        'tactic_lock_game_second',public.doubles_match_game_second_v1(new.id)-3600,
        'action_url',v_route
      ),
      format(
        'doubles-match:%s:schedule:%s:%s:%s:%s:%s',
        new.id,new.scheduled_season_week,new.scheduled_day,new.scheduled_start_minute,
        coalesce(new.court_number,0),r.id
      )
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_doubles_match_scheduled_v1
on public.tournament_doubles_matches;

create trigger trg_notify_doubles_match_scheduled_v1
after update of scheduled_season_week,scheduled_day,scheduled_start_minute,court_number
on public.tournament_doubles_matches
for each row
execute function public.notify_doubles_match_scheduled_v1();

create or replace function public.notify_doubles_match_result_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_t1 public.tournament_doubles_teams%rowtype;
  v_t2 public.tournament_doubles_teams%rowtype;
  v_tournament text;
  v_city text;
  v_route text;
  v_partner_name text;
  v_opponents text;
  v_own_team uuid;
  v_partner_id uuid;
  v_won boolean;
  v_reason text;
  r record;
begin
  if new.status not in ('completed','walkover')
     or new.winner_team_id is null then
    return new;
  end if;

  if old.status is not distinct from new.status
     and old.winner_team_id is not distinct from new.winner_team_id then
    return new;
  end if;

  select * into v_t1 from public.tournament_doubles_teams where id=new.team1_id;
  select * into v_t2 from public.tournament_doubles_teams where id=new.team2_id;

  select ts.name,ts.city
  into v_tournament,v_city
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=new.competition_id;

  v_route:=format('/game/tournaments/%s/doubles',new.competition_id);
  v_reason:=case
    when new.status='walkover' then ' by walkover'
    else ''
  end;

  for r in
    select p.id,p.owner_user_id
    from public.players p
    where p.id in (
      v_t1.player1_id,v_t1.player2_id,
      v_t2.player1_id,v_t2.player2_id
    )
      and p.owner_user_id is not null
  loop
    if r.id in (v_t1.player1_id,v_t1.player2_id) then
      v_own_team:=v_t1.id;
      v_partner_id:=case when r.id=v_t1.player1_id then v_t1.player2_id else v_t1.player1_id end;
      select
        trim(p1.first_name||' '||p1.last_name)||' & '||
        trim(p2.first_name||' '||p2.last_name)
      into v_opponents
      from public.players p1,public.players p2
      where p1.id=v_t2.player1_id and p2.id=v_t2.player2_id;
    else
      v_own_team:=v_t2.id;
      v_partner_id:=case when r.id=v_t2.player1_id then v_t2.player2_id else v_t2.player1_id end;
      select
        trim(p1.first_name||' '||p1.last_name)||' & '||
        trim(p2.first_name||' '||p2.last_name)
      into v_opponents
      from public.players p1,public.players p2
      where p1.id=v_t1.player1_id and p2.id=v_t1.player2_id;
    end if;

    select trim(first_name||' '||last_name)
    into v_partner_name
    from public.players
    where id=v_partner_id;

    v_won:=v_own_team=new.winner_team_id;

    perform public.emit_notification_v1(
      r.owner_user_id,
      r.id,
      'doubles.match.result',
      case when v_won
        then 'Doubles win · '||v_tournament
        else 'Doubles result · '||v_tournament
      end,
      format(
        'You and %s %s against %s in the %s%s.',
        v_partner_name,
        case when v_won then 'won' else 'lost' end,
        v_opponents,
        new.round_label,
        v_reason
      ),
      v_route,
      jsonb_build_object(
        'competition_id',new.competition_id,
        'tournament_name',v_tournament,
        'city',v_city,
        'match_id',new.id,
        'team_id',v_own_team,
        'partner_name',v_partner_name,
        'opponents',v_opponents,
        'round_label',new.round_label,
        'result',case when v_won then 'win' else 'loss' end,
        'completion_reason',new.completion_reason,
        'sets_played',new.sets_played,
        'games_played',new.games_played,
        'action_url',v_route
      ),
      format('doubles-match:%s:result:%s',new.id,r.id)
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_doubles_match_result_v1
on public.tournament_doubles_matches;

create trigger trg_notify_doubles_match_result_v1
after update of status,winner_team_id
on public.tournament_doubles_matches
for each row
execute function public.notify_doubles_match_result_v1();

