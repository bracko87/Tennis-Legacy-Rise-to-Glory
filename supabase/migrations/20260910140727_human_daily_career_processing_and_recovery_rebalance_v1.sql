create table if not exists public.player_career_day_processing_state (
  player_id uuid primary key references public.players(id) on delete cascade,
  last_processed_absolute_day integer not null default -1,
  last_attempt_at timestamptz,
  last_error text,
  updated_at timestamptz not null default now()
);

alter table public.player_career_day_processing_state enable row level security;
revoke all on public.player_career_day_processing_state from anon, authenticated;

-- Rebalance recovery so deliberate rest is meaningful without trivialising fatigue.
do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.process_regular_training_for_player_v2(uuid,integer,smallint,smallint,text)'::regprocedure)
  into v_def;

  if position('v_rest_reduction:=round(8+s.recovery*0.08+s.fitness*0.04);' in v_def)=0 then
    raise exception 'Expected Day Off recovery formula not found.';
  end if;
  if position('v_rest_reduction:=round(6+s.recovery*0.05+s.fitness*0.02);' in v_def)=0 then
    raise exception 'Expected Active Recovery formula not found.';
  end if;
  if position('v_rest_reduction:=round(9+s.recovery*0.06+s.fitness*0.03);' in v_def)=0 then
    raise exception 'Expected Full Rest recovery formula not found.';
  end if;

  v_def := replace(
    v_def,
    'v_rest_reduction:=round(8+s.recovery*0.08+s.fitness*0.04);',
    'v_rest_reduction:=round(12+s.recovery*0.10+s.fitness*0.06+s.fatigue*0.04);'
  );
  v_def := replace(
    v_def,
    'v_rest_reduction:=round(6+s.recovery*0.05+s.fitness*0.02);',
    'v_rest_reduction:=round(8+s.recovery*0.07+s.fitness*0.03+s.fatigue*0.03);'
  );
  v_def := replace(
    v_def,
    'v_rest_reduction:=round(9+s.recovery*0.06+s.fitness*0.03);',
    'v_rest_reduction:=round(15+s.recovery*0.12+s.fitness*0.06+s.fatigue*0.05);'
  );

  execute v_def;
end $$;

comment on function public.process_regular_training_for_player_v2(uuid,integer,smallint,smallint,text)
is 'Processes regular training and recovery. Recovery v2: Day Off, Active Recovery and Full Rest scale with Fitness, Recovery and current fatigue; staff modifiers remain applied by the staff-session trigger.';

-- Surface the fact that human career-day processing is now automatic.
do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.get_training_dashboard_v1()'::regprocedure) into v_def;
  if position('''automatic_scheduler_enabled'', false' in v_def)>0 then
    v_def := replace(v_def, '''automatic_scheduler_enabled'', false', '''automatic_scheduler_enabled'', true');
  elsif position('''automatic_scheduler_enabled'',false' in v_def)>0 then
    v_def := replace(v_def, '''automatic_scheduler_enabled'',false', '''automatic_scheduler_enabled'',true');
  else
    raise exception 'Expected automatic_scheduler_enabled=false flag not found.';
  end if;
  execute v_def;
end $$;

create or replace function public.process_human_career_days_to_current_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  d record;
  gd record;
  p record;
  st public.player_career_day_processing_state%rowtype;
  v_current_abs integer;
  v_abs integer;
  v_players integer:=0;
  v_days integer:=0;
  v_errors integer:=0;
  v_error text;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_current_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);

  for p in
    select id
    from public.players
    where player_type='human' and owner_user_id is not null
    order by created_at,id
  loop
    v_players:=v_players+1;
    begin
      insert into public.player_career_day_processing_state(
        player_id,last_processed_absolute_day,last_attempt_at,updated_at
      ) values (
        p.id,v_current_abs-1,now(),now()
      ) on conflict(player_id) do nothing;

      select * into st
      from public.player_career_day_processing_state
      where player_id=p.id
      for update;

      -- Catch up missed whole days strictly in chronological order. This makes
      -- overdue travel run on its correct date before later career activity.
      if st.last_processed_absolute_day < v_current_abs then
        for v_abs in st.last_processed_absolute_day+1..v_current_abs loop
          select * into gd from public.absolute_game_day_v1(v_abs);
          perform public.process_player_daily_activity_v1(
            p.id,gd.season,gd.month,gd.day,'daily_engine'
          );
          update public.player_career_day_processing_state
          set last_processed_absolute_day=v_abs,
              last_attempt_at=now(),
              last_error=null,
              updated_at=now()
          where player_id=p.id;
          v_days:=v_days+1;
        end loop;
      else
        -- Re-touch the current day because travel/tournament information can be
        -- created after the first processing pass. Underlying processors are idempotent.
        perform public.process_player_daily_activity_v1(
          p.id,d.season,d.month,d.day,'daily_engine'
        );
      end if;
    exception when others then
      v_errors:=v_errors+1;
      v_error:=sqlerrm;
      insert into public.player_career_day_processing_state(
        player_id,last_processed_absolute_day,last_attempt_at,last_error,updated_at
      ) values (
        p.id,v_current_abs-1,now(),left(v_error,1000),now()
      ) on conflict(player_id) do update
        set last_attempt_at=excluded.last_attempt_at,
            last_error=excluded.last_error,
            updated_at=now();
    end;
  end loop;

  return jsonb_build_object(
    'status','completed',
    'current_absolute_day',v_current_abs,
    'human_players',v_players,
    'days_advanced',v_days,
    'errors',v_errors
  );
end;
$function$;

revoke all on function public.process_human_career_days_to_current_v1() from public,anon,authenticated;

create extension if not exists pg_cron;

do $$
declare j record;
begin
  for j in select jobid from cron.job where jobname='tennis-human-career-days-v1' loop
    perform cron.unschedule(j.jobid);
  end loop;
end $$;

select cron.schedule(
  'tennis-human-career-days-v1',
  '*/5 * * * *',
  $cron$select public.process_human_career_days_to_current_v1();$cron$
);

-- Existing human careers start from the current day; we do not replay old
-- activity with today's state because that would rewrite history inaccurately.
insert into public.player_career_day_processing_state(
  player_id,last_processed_absolute_day,last_attempt_at,updated_at
)
select p.id,
       public.game_day_absolute_v1(d.season,d.month,d.day)-1,
       now(),now()
from public.players p
cross join lateral public.get_current_game_day_internal_v1() d
where p.player_type='human' and p.owner_user_id is not null
on conflict(player_id) do nothing;
