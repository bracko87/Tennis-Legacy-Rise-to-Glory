
create or replace function public.process_ai_training_day_v1(
  p_player_id uuid,
  p_season integer,
  p_month smallint,
  p_day smallint
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_plan jsonb;
  v_result jsonb;
  v_absolute_day integer;
begin
  if not exists(
    select 1 from public.players
    where id=p_player_id and player_type='ai'
  ) then
    raise exception 'AI player not found.';
  end if;

  v_absolute_day:=public.game_day_absolute_v1(p_season,p_month,p_day);

  if public.player_training_blocked_by_health_v1(p_player_id,v_absolute_day) then
    return jsonb_build_object(
      'plan',null,
      'result',jsonb_build_object(
        'status','blocked_health',
        'reason','Medical restriction'
      )
    );
  end if;

  v_plan:=public.configure_ai_training_plan_v1(p_player_id,p_season,p_month,p_day);
  v_result:=public.process_regular_training_for_player_v1(
    p_player_id,p_season,p_month,p_day,'daily_engine'
  );

  return jsonb_build_object('plan',v_plan,'result',v_result);
end;
$$;
