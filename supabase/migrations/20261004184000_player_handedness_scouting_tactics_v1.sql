-- Player handedness + opponent scouting + matchup tactics.
-- Approved design:
--   * Handedness is public identity, not a permanent skill bonus/penalty.
--   * Existing human careers become right-handed.
--   * AI players receive a deterministic ~12.5% left-handed distribution.
--   * Performance Analyst improves information certainty, not hidden player reality.
--   * Tactics use opponent weaknesses, handedness geometry and preparation choices.
--   * Used catalog avatars disappear from creation and return automatically when released.

-- ---------------------------------------------------------------------------
-- 1. Player handedness
-- ---------------------------------------------------------------------------

alter table public.players
  add column if not exists playing_hand text;

update public.players
set playing_hand='right'
where player_type='human';

update public.players
set playing_hand=case
  when mod(coalesce(ai_profile_number::bigint,(hashtext(id::text)::bigint & 2147483647)),8)=0 then 'left'
  else 'right'
end
where player_type='ai';

update public.players
set playing_hand='right'
where playing_hand is null;

alter table public.players
  alter column playing_hand set default 'right',
  alter column playing_hand set not null;

alter table public.players
  drop constraint if exists players_playing_hand_check;

alter table public.players
  add constraint players_playing_hand_check
  check (playing_hand in ('right','left'));

create or replace function public.assign_player_handedness_v1()
returns trigger
language plpgsql
set search_path to public,pg_temp
as $$
begin
  if new.player_type='human' then
    new.playing_hand:=coalesce(nullif(new.playing_hand,''),'right');
  elsif new.player_type='ai' then
    -- On insert/reclassification, AI handedness is deterministic. The column
    -- default is right-handed for human/backward compatibility, so AI cannot
    -- rely on NULL detection here.
    if tg_op='INSERT'
       or old.player_type is distinct from new.player_type
       or old.ai_profile_number is distinct from new.ai_profile_number then
      new.playing_hand:=case
        when mod(coalesce(new.ai_profile_number::bigint,(hashtext(new.id::text)::bigint & 2147483647)),8)=0 then 'left'
        else 'right'
      end;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists assign_player_handedness_v1 on public.players;
create trigger assign_player_handedness_v1
before insert or update of player_type,ai_profile_number
on public.players
for each row
execute function public.assign_player_handedness_v1();

-- ---------------------------------------------------------------------------
-- 2. Avatar catalog: used portraits are omitted, not greyed out.
-- Existing sync_player_avatar_reservation already releases the old catalog
-- avatar when image_path changes to a custom approved image or another avatar.
-- ---------------------------------------------------------------------------

create or replace function public.get_player_avatar_catalog(p_world text)
returns table(path text,is_available boolean)
language sql
stable
set search_path to 'pg_catalog','public','storage'
as $$
  select o.name::text,true
  from storage.objects o
  where p_world in ('ATP','WTA')
    and o.bucket_id='Admin'
    and o.name like case when p_world='ATP' then 'ATP Avatars/%' else 'WTA Avatars/%' end
    and lower(o.name) ~ '\.(png|jpg|jpeg|webp)$'
    and not exists(
      select 1
      from public.player_avatar_reservations r
      where r.avatar_path=o.name
    )
  order by o.name;
$$;

-- ---------------------------------------------------------------------------
-- 3. Public profile + match detail expose handedness.
-- ---------------------------------------------------------------------------

drop function if exists public.get_player_profile_v2(uuid);

create function public.get_player_profile_v2(p_player_id uuid)
returns table(
  player_id uuid,
  first_name text,
  last_name text,
  world text,
  country_code text,
  home_city text,
  image_path text,
  preferred_surface text,
  playing_style text,
  playing_hand text,
  ranking_points integer,
  rank_position bigint,
  is_own_player boolean,
  is_ai boolean
)
language sql
stable
security definer
set search_path to 'public'
as $$
  with target as(
    select p.*
    from public.players p
    where p.id=p_player_id
      and p.moderation_status<>'rejected'
  ),
  ranked as(
    select p.id,row_number() over(
      order by coalesce(r.ranking_points,0) desc,
               coalesce(r.seed_rating,0) desc,
               p.created_at asc,p.id asc
    ) rank_position
    from public.players p
    left join public.player_rankings r on r.player_id=p.id
    where p.world=(select world from target)
      and p.moderation_status<>'rejected'
  )
  select
    t.id,t.first_name,t.last_name,t.world,t.country_code,t.home_city,t.image_path,
    t.preferred_surface,t.playing_style,t.playing_hand,
    coalesce(pr.ranking_points,0)::integer,
    ranked.rank_position,
    coalesce(t.owner_user_id=auth.uid(),false),
    (t.player_type='ai')
  from target t
  left join public.player_rankings pr on pr.player_id=t.id
  left join ranked on ranked.id=t.id;
$$;

grant execute on function public.get_player_profile_v2(uuid) to authenticated;

create or replace function public.get_tournament_match_detail_v1(p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select jsonb_build_object(
    'match_id',m.id,
    'competition_id',m.competition_id,
    'tournament_name',s.name,
    'city',s.city,
    'country_code',s.country_code,
    'round_label',m.round_label,
    'match_number',m.match_number,
    'scheduled_season_week',m.scheduled_season_week,
    'scheduled_day',m.scheduled_day,
    'scheduled_start_minute',m.scheduled_start_minute,
    'court_number',m.court_number,
    'schedule_reason',m.schedule_reason,
    'status',m.status,
    'winner_id',m.winner_id,
    'started_at',m.started_at,
    'completed_at',m.completed_at,
    'player1',case when p1.id is null then null else jsonb_build_object(
      'id',p1.id,'first_name',p1.first_name,'last_name',p1.last_name,
      'country_code',p1.country_code,'image_path',p1.image_path,
      'ranking_position',e1.ranking_position_snapshot,'seed',e1.seed_number,
      'playing_hand',p1.playing_hand,'preferred_surface',p1.preferred_surface,
      'playing_style',p1.playing_style
    ) end,
    'player2',case when p2.id is null then null else jsonb_build_object(
      'id',p2.id,'first_name',p2.first_name,'last_name',p2.last_name,
      'country_code',p2.country_code,'image_path',p2.image_path,
      'ranking_position',e2.ranking_position_snapshot,'seed',e2.seed_number,
      'playing_hand',p2.playing_hand,'preferred_surface',p2.preferred_surface,
      'playing_style',p2.playing_style
    ) end,
    'sets',coalesce((
      select jsonb_agg(jsonb_build_object(
        'set_number',ms.set_number,
        'player1_games',ms.player1_games,
        'player2_games',ms.player2_games,
        'player1_tiebreak_points',ms.player1_tiebreak_points,
        'player2_tiebreak_points',ms.player2_tiebreak_points,
        'status',ms.status
      ) order by ms.set_number)
      from public.tournament_match_sets ms
      where ms.match_id=m.id
    ),'[]'::jsonb),
    'player1_stats',coalesce((
      select to_jsonb(st)-'id'-'match_id'-'player_id'-'updated_at'
      from public.tournament_match_player_stats st
      where st.match_id=m.id and st.player_id=m.player1_id
    ),'{}'::jsonb),
    'player2_stats',coalesce((
      select to_jsonb(st)-'id'-'match_id'-'player_id'-'updated_at'
      from public.tournament_match_player_stats st
      where st.match_id=m.id and st.player_id=m.player2_id
    ),'{}'::jsonb)
  )
  into v_result
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  left join public.players p1 on p1.id=m.player1_id
  left join public.players p2 on p2.id=m.player2_id
  left join public.tournament_entries e1 on e1.competition_id=m.competition_id and e1.player_id=m.player1_id
  left join public.tournament_entries e2 on e2.competition_id=m.competition_id and e2.player_id=m.player2_id
  where m.id=p_match_id;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Performance Analyst scouting lifecycle.
-- ---------------------------------------------------------------------------

create table if not exists public.player_opponent_scouting_tasks(
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  target_player_id uuid not null references public.players(id) on delete cascade,
  match_id uuid not null references public.tournament_matches(id) on delete cascade,
  analyst_staff_id uuid references public.staff_members(id) on delete set null,
  started_game_second bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(player_id,match_id)
);

create index if not exists player_opponent_scouting_tasks_target_idx
on public.player_opponent_scouting_tasks(player_id,target_player_id,match_id);

alter table public.player_opponent_scouting_tasks enable row level security;

drop policy if exists player_opponent_scouting_tasks_owner_read on public.player_opponent_scouting_tasks;
create policy player_opponent_scouting_tasks_owner_read
on public.player_opponent_scouting_tasks
for select
to authenticated
using (
  exists(
    select 1 from public.players p
    where p.id=player_id and p.owner_user_id=auth.uid()
  )
);

create or replace function public.ensure_due_opponent_scouting_tasks_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_now bigint:=public.current_game_second_v1();
  v_inserted integer:=0;
begin
  with due as(
    select
      hp.id as player_id,
      case when m.player1_id=hp.id then m.player2_id else m.player1_id end as target_player_id,
      m.id as match_id,
      sm.id as analyst_staff_id
    from public.tournament_matches m
    join public.players hp
      on hp.id in (m.player1_id,m.player2_id)
     and hp.player_type='human'
     and hp.owner_user_id is not null
    join public.player_staff_contracts c
      on c.player_id=hp.id
     and c.role='performance_analyst'
     and c.status='active'
    join public.staff_members sm on sm.id=c.staff_id
    where m.status='scheduled'
      and m.player1_id is not null
      and m.player2_id is not null
      and public.tournament_match_game_second_v1(m.id)>v_now
  ),
  inserted as(
    insert into public.player_opponent_scouting_tasks(
      player_id,target_player_id,match_id,analyst_staff_id,started_game_second
    )
    select player_id,target_player_id,match_id,analyst_staff_id,v_now
    from due
    on conflict(player_id,match_id) do update
      set analyst_staff_id=excluded.analyst_staff_id,
          target_player_id=excluded.target_player_id,
          updated_at=now()
    returning (xmax=0) as was_inserted
  )
  select count(*) filter(where was_inserted)
  into v_inserted
  from inserted;

  return jsonb_build_object('status','processed','new_tasks',coalesce(v_inserted,0));
end;
$$;

create or replace function public.get_player_scouting_report_v1(p_target_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_me public.players%rowtype;
  v_target public.players%rowtype;
  sk public.player_skills%rowtype;
  mysk public.player_skills%rowtype;
  v_staff public.staff_members%rowtype;
  v_contract public.player_staff_contracts%rowtype;
  v_effects jsonb;
  v_base_margin integer:=10;
  v_margin integer:=10;
  v_attrs jsonb:='{}'::jsonb;
  v_observations jsonb:='[]'::jsonb;
  v_recommendations jsonb:='[]'::jsonb;
  v_strength text;
  v_weakness text;
  v_match_id uuid;
  v_task public.player_opponent_scouting_tasks%rowtype;
  v_now bigint:=public.current_game_second_v1();
  v_prep_hours numeric:=0;
  v_time_factor numeric:=0.70;
  v_stage text:='general';
  v_confidence integer:=0;
  k text;
  v integer;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select * into v_me
  from public.players
  where owner_user_id=auth.uid()
    and player_type='human'
  limit 1;

  if v_me.id is null then raise exception 'Player not found.'; end if;

  select * into v_target
  from public.players
  where id=p_target_player_id
    and moderation_status<>'rejected';

  if v_target.id is null then raise exception 'Target player not found.'; end if;

  if v_target.id=v_me.id then
    return jsonb_build_object(
      'available',false,
      'reason','Use your Skills page for exact personal attributes.',
      'playing_hand',v_target.playing_hand,
      'preferred_surface',v_target.preferred_surface,
      'playing_style',v_target.playing_style
    );
  end if;

  select c.*
  into v_contract
  from public.player_staff_contracts c
  where c.player_id=v_me.id
    and c.role='performance_analyst'
    and c.status='active'
  order by c.signed_at desc
  limit 1;

  if v_contract.id is not null then
    select s.*
    into v_staff
    from public.staff_members s
    where s.id=v_contract.staff_id;
  end if;

  if v_contract.id is null then
    return jsonb_build_object(
      'available',false,
      'reason','Hire a Performance Analyst to unlock opponent estimates.',
      'playing_hand',v_target.playing_hand,
      'preferred_surface',v_target.preferred_surface,
      'playing_style',v_target.playing_style
    );
  end if;

  select m.id
  into v_match_id
  from public.tournament_matches m
  where m.status='scheduled'
    and (
      (m.player1_id=v_me.id and m.player2_id=v_target.id)
      or (m.player2_id=v_me.id and m.player1_id=v_target.id)
    )
    and public.tournament_match_game_second_v1(m.id)>v_now
  order by public.tournament_match_game_second_v1(m.id)
  limit 1;

  if v_match_id is not null then
    insert into public.player_opponent_scouting_tasks(
      player_id,target_player_id,match_id,analyst_staff_id,started_game_second
    ) values(
      v_me.id,v_target.id,v_match_id,v_staff.id,v_now
    )
    on conflict(player_id,match_id) do update
      set analyst_staff_id=excluded.analyst_staff_id,
          target_player_id=excluded.target_player_id,
          updated_at=now();

    select * into v_task
    from public.player_opponent_scouting_tasks
    where player_id=v_me.id and match_id=v_match_id;

    v_prep_hours:=greatest(0,(v_now-v_task.started_game_second)::numeric/3600.0);

    if v_prep_hours<6 then
      v_stage:='quick';
      v_time_factor:=0.55;
    elsif v_prep_hours<12 then
      v_stage:='partial';
      v_time_factor:=0.70;
    elsif v_prep_hours<24 then
      v_stage:='normal';
      v_time_factor:=0.85;
    else
      v_stage:='full';
      v_time_factor:=1.00;
    end if;
  else
    v_stage:='general';
    v_time_factor:=0.70;
  end if;

  v_effects:=public.get_player_staff_effects_v1(v_me.id);
  v_base_margin:=coalesce((v_effects->>'scouting_margin')::integer,10);
  v_margin:=greatest(1,least(14,ceil(v_base_margin/greatest(0.45,v_time_factor))::integer));
  v_confidence:=greatest(25,least(98,round(v_staff.overall_rating*v_time_factor)::integer));

  select * into sk from public.player_skills where player_id=v_target.id;
  select * into mysk from public.player_skills where player_id=v_me.id;

  foreach k in array array[
    'serve','forehand','backhand','return_skill','volley','slice',
    'drop_shot','lob','smash','fitness','stamina','recovery','movement'
  ] loop
    v:=(to_jsonb(sk)->>k)::integer;
    v_attrs:=v_attrs||jsonb_build_object(
      k,jsonb_build_object(
        'min',greatest(1,v-v_margin),
        'max',least(100,v+v_margin)
      )
    );
  end loop;

  select key into v_strength
  from jsonb_each_text(jsonb_build_object(
    'serve',sk.serve,'forehand',sk.forehand,'backhand',sk.backhand,
    'return_skill',sk.return_skill,'volley',sk.volley,'slice',sk.slice,
    'drop_shot',sk.drop_shot,'lob',sk.lob,'smash',sk.smash
  ))
  order by value::integer desc,key
  limit 1;

  select key into v_weakness
  from jsonb_each_text(jsonb_build_object(
    'serve',sk.serve,'forehand',sk.forehand,'backhand',sk.backhand,
    'return_skill',sk.return_skill,'volley',sk.volley,'slice',sk.slice,
    'drop_shot',sk.drop_shot,'lob',sk.lob,'smash',sk.smash
  ))
  order by value::integer asc,key
  limit 1;

  if sk.backhand+5<=sk.forehand then
    v_observations:=v_observations||jsonb_build_array('Backhand is meaningfully weaker than the forehand.');
    v_recommendations:=v_recommendations||jsonb_build_array('Consider directing sustained rally pressure toward the backhand.');
  elsif sk.forehand+5<=sk.backhand then
    v_observations:=v_observations||jsonb_build_array('Forehand is the weaker groundstroke side.');
    v_recommendations:=v_recommendations||jsonb_build_array('Consider testing the forehand rather than feeding the stronger backhand.');
  end if;

  if sk.serve>=75 then
    v_observations:=v_observations||jsonb_build_array('First-strike serving is a major strength.');
    v_recommendations:=v_recommendations||jsonb_build_array('A deeper return position can improve stability against the first serve.');
  elsif sk.serve<=60 then
    v_observations:=v_observations||jsonb_build_array('Serve pressure is below the opponent''s stronger technical areas.');
    v_recommendations:=v_recommendations||jsonb_build_array('Stepping closer and attacking second serves may create pressure.');
  end if;

  if sk.stamina<=60 then
    v_observations:=v_observations||jsonb_build_array('Stamina may become vulnerable in long exchanges.');
    if mysk.stamina>sk.stamina then
      v_recommendations:=v_recommendations||jsonb_build_array('Extending rallies can be useful if your own stamina is stronger.');
    end if;
  end if;

  if sk.movement<=60 then
    v_observations:=v_observations||jsonb_build_array('Movement is a possible pressure point.');
    v_recommendations:=v_recommendations||jsonb_build_array('Wide patterns and changes of direction may stretch court coverage.');
  end if;

  if v_me.playing_hand<>v_target.playing_hand then
    v_observations:=v_observations||jsonb_build_array(
      'This is an opposite-handed matchup, creating natural forehand-to-backhand cross-court patterns.'
    );
  else
    v_observations:=v_observations||jsonb_build_array(
      'Both players use the same playing hand; cross-court forehand and backhand exchanges are more symmetrical.'
    );
  end if;

  return jsonb_build_object(
    'available',true,
    'analyst_rating',v_staff.overall_rating,
    'analyst_name',v_staff.first_name||' '||v_staff.last_name,
    'estimate_margin',v_margin,
    'confidence_percent',v_confidence,
    'report_stage',v_stage,
    'preparation_hours',round(v_prep_hours,1),
    'match_id',v_match_id,
    'attributes',v_attrs,
    'identified_strength',v_strength,
    'identified_weakness',v_weakness,
    'preferred_surface',v_target.preferred_surface,
    'playing_style',v_target.playing_style,
    'playing_hand',v_target.playing_hand,
    'tactical_observations',v_observations,
    'recommendations',v_recommendations
  );
end;
$$;

-- Performance Analyst changes certainty, not the hidden player reality.
create or replace function public.get_player_staff_effects_v3(p_player_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public','pg_temp'
as $$
declare
  b jsonb;
  v_clean_match numeric;
begin
  b:=public.get_player_staff_effects_v2(p_player_id);
  v_clean_match:=1+least(
    0.02,
    greatest(
      0,
      coalesce((b->>'coach_match_preparation_multiplier')::numeric,1)-1
      +coalesce((b->>'pressure_bonus')::numeric,0)
    )
  );

  return jsonb_set(
    jsonb_set(b,'{analyst_match_preparation_multiplier}',to_jsonb(1.0000::numeric)),
    '{match_staff_multiplier}',to_jsonb(round(v_clean_match,4))
  );
end;
$$;

create or replace function public.get_player_staff_effects_v1(p_player_id uuid)
returns jsonb
language sql
stable
security definer
set search_path to 'public','pg_temp'
as $$
  select public.get_player_staff_effects_v3(p_player_id);
$$;

update public.staff_role_catalog
set main_responsibility='Turns scouting and tactical analysis into more accurate opponent reports and matchup recommendations.',
    vacancy_behavior='Public opponent identity remains visible, but detailed attribute estimates, confidence and analyst recommendations are locked.',
    stacking_rule='Only one Performance Analyst may be active. Analyst quality changes information certainty; it does not directly increase hidden match ratings.',
    effects=jsonb_build_array(
      jsonb_build_object(
        'key','scouting',
        'label','Opponent estimate accuracy',
        'cadence','Whenever an opponent report is opened',
        'maximum','±1 attribute point',
        'note','Quality and preparation time narrow the estimate band. Exact private skills are never returned.'
      ),
      jsonb_build_object(
        'key','match_preparation',
        'label','Opponent preparation intelligence',
        'cadence','From the moment the next opponent is known',
        'maximum','Full report after 24 game-hours',
        'note','The analyst supplies better information and recommendations rather than a direct rating bonus.'
      )
    ),
    review_note='Opponent intelligence role. Scouting certainty and preparation time are the gameplay value; no hidden direct match-strength bonus.'
where role='performance_analyst';

-- ---------------------------------------------------------------------------
-- 5. Expanded tactic model.
-- ---------------------------------------------------------------------------

alter table public.player_tournament_match_tactics
  add column if not exists tactic_serve_placement text not null default 'Automatic',
  add column if not exists tactic_return_position text not null default 'Normal';

alter table public.player_tournament_preparation_plans
  add column if not exists tactic_serve_placement text not null default 'Automatic',
  add column if not exists tactic_return_position text not null default 'Normal';

create or replace function public.get_automatic_singles_tactic_v1(p_player_id uuid,p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  m public.tournament_matches%rowtype;
  me public.players%rowtype;
  opp public.players%rowtype;
  sk public.player_skills%rowtype;
  osk public.player_skills%rowtype;
  v_target text:='Automatic';
  v_rally text:='Balanced rallies';
  v_serve text:='Balanced';
  v_return text:='Balanced';
  v_court text:='Normal baseline';
  v_risk text:='Balanced';
  v_placement text:='Automatic';
  v_return_position text:='Normal';
  v_preset text:='Balanced';
begin
  select * into m from public.tournament_matches where id=p_match_id;
  select * into me from public.players where id=p_player_id;
  if m.id is null or me.id is null then
    return jsonb_build_object(
      'source','automatic_default','preset','Balanced','approach','Balanced',
      'rally','Balanced rallies','serve','Balanced','servePlacement','Automatic',
      'returnGame','Balanced','returnPosition','Normal','courtPosition','Normal baseline',
      'target','Automatic','risk','Balanced'
    );
  end if;

  select * into opp
  from public.players
  where id=case when m.player1_id=p_player_id then m.player2_id else m.player1_id end;

  select * into sk from public.player_skills where player_id=me.id;
  select * into osk from public.player_skills where player_id=opp.id;

  if osk.backhand+5<=osk.forehand then v_target:='Backhand';
  elsif osk.forehand+5<=osk.backhand then v_target:='Forehand';
  elsif osk.movement<=60 then v_target:='Movement';
  elsif osk.stamina<=60 then v_target:='Stamina';
  elsif osk.serve<=60 then v_target:='Second serve';
  end if;

  if sk.stamina+sk.movement>=osk.stamina+osk.movement+12 then
    v_rally:='Extend rallies';
    v_preset:='Counterpunch';
  elsif sk.serve>=72 and greatest(sk.forehand,sk.volley)>=70 then
    v_rally:='Shorten points';
    v_preset:='Serve + 1';
  end if;

  if sk.serve>=78 then v_serve:='Power serving';
  elsif sk.serve>=70 and sk.forehand>=68 then v_serve:='Serve + 1';
  elsif sk.serve<=58 then v_serve:='Safe first serve';
  end if;

  if osk.movement<=62 then v_placement:='Wide';
  elsif osk.return_skill>=75 then v_placement:='Body';
  else v_placement:='T';
  end if;

  if osk.serve>=75 then
    v_return_position:='Deeper';
    v_return:='Safe return';
  elsif osk.serve<=62 then
    v_return_position:='Closer';
    v_return:='Attack second serve';
  end if;

  if me.playing_style='Serve & Volley' then v_court:='Net attack';
  elsif me.playing_style='Aggressive Baseliner' then v_court:='Inside baseline';
  elsif me.playing_style='Defensive Baseliner' then v_court:='Deep baseline';
  end if;

  if sk.focus>=75 and sk.forehand>=75 then v_risk:='Aggressive';
  elsif sk.focus<=55 then v_risk:='Safe';
  end if;

  return jsonb_build_object(
    'source','ai_automatic',
    'preset',v_preset,
    'approach',case when v_rally='Shorten points' then 'Aggressive'
                    when v_rally='Extend rallies' then 'Defensive'
                    else 'Balanced' end,
    'rally',v_rally,
    'serve',v_serve,
    'servePlacement',v_placement,
    'returnGame',v_return,
    'returnPosition',v_return_position,
    'courtPosition',v_court,
    'target',v_target,
    'risk',v_risk
  );
end;
$$;

create or replace function public.get_effective_match_tactic_internal_v2(p_player_id uuid,p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  m public.tournament_matches%rowtype;
  me public.players%rowtype;
  o public.player_tournament_match_tactics%rowtype;
  p public.player_tournament_preparation_plans%rowtype;
begin
  select * into m from public.tournament_matches where id=p_match_id;
  select * into me from public.players where id=p_player_id;

  select * into o
  from public.player_tournament_match_tactics
  where player_id=p_player_id and match_id=p_match_id;

  if o.id is not null then
    return jsonb_build_object(
      'source','match_override',
      'preset',o.tactic_preset,
      'approach',o.tactic_approach,
      'rally',o.tactic_rally,
      'serve',o.tactic_serve,
      'servePlacement',o.tactic_serve_placement,
      'returnGame',o.tactic_return,
      'returnPosition',o.tactic_return_position,
      'courtPosition',o.tactic_court_position,
      'target',o.tactic_target,
      'risk',o.tactic_risk
    );
  end if;

  select * into p
  from public.player_tournament_preparation_plans
  where player_id=p_player_id and competition_id=m.competition_id;

  if p.id is not null then
    return jsonb_build_object(
      'source','tournament_default',
      'preset',p.tactic_preset,
      'approach',p.tactic_approach,
      'rally',p.tactic_rally,
      'serve',p.tactic_serve,
      'servePlacement',p.tactic_serve_placement,
      'returnGame',p.tactic_return,
      'returnPosition',p.tactic_return_position,
      'courtPosition',p.tactic_court_position,
      'target',p.tactic_target,
      'risk',p.tactic_risk
    );
  end if;

  if me.player_type='ai' then
    return public.get_automatic_singles_tactic_v1(p_player_id,p_match_id);
  end if;

  return jsonb_build_object(
    'source','automatic_default',
    'preset','Balanced',
    'approach','Balanced',
    'rally','Balanced rallies',
    'serve','Balanced',
    'servePlacement','Automatic',
    'returnGame','Balanced',
    'returnPosition','Normal',
    'courtPosition','Normal baseline',
    'target','Automatic',
    'risk','Balanced'
  );
end;
$$;

drop function if exists public.save_tournament_match_tactic_v1(uuid,uuid,text,text,text,text,text,text,text,text);

create function public.save_tournament_match_tactic_v1(
  p_player_id uuid,
  p_match_id uuid,
  p_tactic_preset text,
  p_tactic_approach text,
  p_tactic_rally text,
  p_tactic_serve text,
  p_tactic_return text,
  p_tactic_court_position text,
  p_tactic_target text,
  p_tactic_risk text,
  p_tactic_serve_placement text default 'Automatic',
  p_tactic_return_position text default 'Normal'
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_match public.tournament_matches%rowtype;
  v_lock bigint;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then
    raise exception 'Player access denied.';
  end if;

  select * into v_match from public.tournament_matches m where m.id=p_match_id;
  if not found then raise exception 'Match not found.'; end if;
  if p_player_id is distinct from v_match.player1_id and p_player_id is distinct from v_match.player2_id then
    raise exception 'This player is not in the selected match.';
  end if;
  if v_match.status<>'scheduled' then
    raise exception 'Match tactic can only be changed before the match starts.';
  end if;

  v_lock:=public.tournament_match_game_second_v1(p_match_id)-3600;
  if v_lock is not null and public.current_game_second_v1()>=v_lock then
    raise exception 'Match-specific tactics lock 60 minutes before the scheduled match start.';
  end if;

  if p_tactic_serve_placement not in ('Automatic','Wide','Body','T') then
    raise exception 'Invalid serve placement.';
  end if;
  if p_tactic_return_position not in ('Normal','Closer','Deeper') then
    raise exception 'Invalid return position.';
  end if;

  insert into public.player_tournament_match_tactics(
    owner_user_id,player_id,match_id,
    tactic_preset,tactic_approach,tactic_rally,tactic_serve,
    tactic_return,tactic_court_position,tactic_target,tactic_risk,
    tactic_serve_placement,tactic_return_position,updated_at
  )
  values(
    v_uid,p_player_id,p_match_id,
    p_tactic_preset,p_tactic_approach,p_tactic_rally,p_tactic_serve,
    p_tactic_return,p_tactic_court_position,p_tactic_target,p_tactic_risk,
    p_tactic_serve_placement,p_tactic_return_position,now()
  )
  on conflict(player_id,match_id) do update set
    owner_user_id=excluded.owner_user_id,
    tactic_preset=excluded.tactic_preset,
    tactic_approach=excluded.tactic_approach,
    tactic_rally=excluded.tactic_rally,
    tactic_serve=excluded.tactic_serve,
    tactic_return=excluded.tactic_return,
    tactic_court_position=excluded.tactic_court_position,
    tactic_target=excluded.tactic_target,
    tactic_risk=excluded.tactic_risk,
    tactic_serve_placement=excluded.tactic_serve_placement,
    tactic_return_position=excluded.tactic_return_position,
    updated_at=now();

  return public.get_tournament_match_tactic_v1(p_player_id,p_match_id);
end;
$$;

grant execute on function public.save_tournament_match_tactic_v1(uuid,uuid,text,text,text,text,text,text,text,text,text,text) to authenticated;

create or replace function public.get_tournament_match_tactic_v1(p_player_id uuid,p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_match public.tournament_matches%rowtype;
  v_override public.player_tournament_match_tactics%rowtype;
  v_plan public.player_tournament_preparation_plans%rowtype;
  v_tournament jsonb;
  v_effective jsonb;
  v_override_json jsonb:=null;
  v_source text:='automatic_default';
  v_match_second bigint;
  v_lock bigint;
  v_now bigint:=public.current_game_second_v1();
  v_editable boolean;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then
    raise exception 'Player access denied.';
  end if;

  select * into v_match from public.tournament_matches where id=p_match_id;
  if not found then raise exception 'Match not found.'; end if;
  if p_player_id is distinct from v_match.player1_id and p_player_id is distinct from v_match.player2_id then
    raise exception 'This player is not in the selected match.';
  end if;

  v_match_second:=public.tournament_match_game_second_v1(p_match_id);
  v_lock:=case when v_match_second is null then null else v_match_second-3600 end;
  v_editable:=v_match.status='scheduled' and (v_lock is null or v_now<v_lock);

  select * into v_plan
  from public.player_tournament_preparation_plans
  where player_id=p_player_id and competition_id=v_match.competition_id;

  if found then
    v_tournament:=jsonb_build_object(
      'preset',v_plan.tactic_preset,
      'approach',v_plan.tactic_approach,
      'rally',v_plan.tactic_rally,
      'serve',v_plan.tactic_serve,
      'servePlacement',v_plan.tactic_serve_placement,
      'returnGame',v_plan.tactic_return,
      'returnPosition',v_plan.tactic_return_position,
      'courtPosition',v_plan.tactic_court_position,
      'target',v_plan.tactic_target,
      'risk',v_plan.tactic_risk
    );
    v_source:='tournament_default';
  else
    v_tournament:=jsonb_build_object(
      'preset','Balanced','approach','Balanced','rally','Balanced rallies',
      'serve','Balanced','servePlacement','Automatic',
      'returnGame','Balanced','returnPosition','Normal',
      'courtPosition','Normal baseline','target','Automatic','risk','Balanced'
    );
  end if;

  select * into v_override
  from public.player_tournament_match_tactics
  where player_id=p_player_id and match_id=p_match_id;

  if found then
    v_override_json:=jsonb_build_object(
      'preset',v_override.tactic_preset,
      'approach',v_override.tactic_approach,
      'rally',v_override.tactic_rally,
      'serve',v_override.tactic_serve,
      'servePlacement',v_override.tactic_serve_placement,
      'returnGame',v_override.tactic_return,
      'returnPosition',v_override.tactic_return_position,
      'courtPosition',v_override.tactic_court_position,
      'target',v_override.tactic_target,
      'risk',v_override.tactic_risk
    );
    v_effective:=v_override_json;
    v_source:='match_override';
  else
    v_effective:=v_tournament;
  end if;

  return jsonb_build_object(
    'match_status',v_match.status,
    'editable',v_editable,
    'source',v_source,
    'tournament_default',v_tournament,
    'override',v_override_json,
    'effective',v_effective,
    'scheduled_game_second',v_match_second,
    'tactic_lock_game_second',v_lock,
    'current_game_second',v_now,
    'lock_minutes_before_start',60
  );
end;
$$;

drop function if exists public.save_tournament_preparation_v1(uuid,uuid,text,text,text,uuid[],text,text,text,text,text,text,text,text);

create function public.save_tournament_preparation_v1(
  p_player_id uuid,
  p_competition_id uuid,
  p_player_travel_class text,
  p_staff_travel_class text,
  p_hotel_tier text,
  p_selected_staff_contract_ids uuid[],
  p_tactic_preset text,
  p_tactic_approach text,
  p_tactic_rally text,
  p_tactic_serve text,
  p_tactic_return text,
  p_tactic_court_position text,
  p_tactic_target text,
  p_tactic_risk text,
  p_tactic_serve_placement text default 'Automatic',
  p_tactic_return_position text default 'Normal'
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_staff uuid[]:=coalesce(p_selected_staff_contract_ids,'{}'::uuid[]);
  v_quote jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then
    raise exception 'Player access denied.';
  end if;
  if not exists(select 1 from public.tournament_entries e where e.player_id=p_player_id and e.competition_id=p_competition_id) then
    raise exception 'Player is not entered in this tournament.';
  end if;
  if p_player_travel_class not in ('Economy','Premium Economy','Business','First Class') then raise exception 'Invalid player travel class.'; end if;
  if p_staff_travel_class not in ('Economy','Premium Economy','Business','First Class') then raise exception 'Invalid staff travel class.'; end if;
  if p_hotel_tier not in ('Budget','Standard','Premium','Luxury') then raise exception 'Invalid hotel tier.'; end if;
  if p_tactic_serve_placement not in ('Automatic','Wide','Body','T') then raise exception 'Invalid serve placement.'; end if;
  if p_tactic_return_position not in ('Normal','Closer','Deeper') then raise exception 'Invalid return position.'; end if;

  if exists(
    select 1
    from unnest(v_staff) u(contract_id)
    left join public.player_staff_contracts c
      on c.id=u.contract_id and c.player_id=p_player_id and c.status='active'
    where c.id is null
  ) then
    raise exception 'One or more selected staff contracts are not active for this player.';
  end if;

  select coalesce(array_agg(distinct x order by x),'{}'::uuid[])
  into v_staff
  from unnest(v_staff) x;

  v_quote:=public.quote_tournament_preparation_v1(
    p_player_id,p_competition_id,p_player_travel_class,p_staff_travel_class,p_hotel_tier,v_staff
  );

  insert into public.player_tournament_preparation_plans(
    owner_user_id,player_id,competition_id,
    player_travel_class,staff_travel_class,hotel_tier,selected_staff_contract_ids,
    tactic_preset,tactic_approach,tactic_rally,tactic_serve,tactic_return,
    tactic_court_position,tactic_target,tactic_risk,
    tactic_serve_placement,tactic_return_position,
    quote_snapshot,updated_at
  )
  values(
    v_uid,p_player_id,p_competition_id,
    p_player_travel_class,p_staff_travel_class,p_hotel_tier,v_staff,
    p_tactic_preset,p_tactic_approach,p_tactic_rally,p_tactic_serve,p_tactic_return,
    p_tactic_court_position,p_tactic_target,p_tactic_risk,
    p_tactic_serve_placement,p_tactic_return_position,
    v_quote,now()
  )
  on conflict(player_id,competition_id) do update set
    owner_user_id=excluded.owner_user_id,
    player_travel_class=excluded.player_travel_class,
    staff_travel_class=excluded.staff_travel_class,
    hotel_tier=excluded.hotel_tier,
    selected_staff_contract_ids=excluded.selected_staff_contract_ids,
    tactic_preset=excluded.tactic_preset,
    tactic_approach=excluded.tactic_approach,
    tactic_rally=excluded.tactic_rally,
    tactic_serve=excluded.tactic_serve,
    tactic_return=excluded.tactic_return,
    tactic_court_position=excluded.tactic_court_position,
    tactic_target=excluded.tactic_target,
    tactic_risk=excluded.tactic_risk,
    tactic_serve_placement=excluded.tactic_serve_placement,
    tactic_return_position=excluded.tactic_return_position,
    quote_snapshot=excluded.quote_snapshot,
    updated_at=now();

  perform public.rebuild_player_travel_plan_v1(p_player_id);
  return public.get_tournament_preparation_v1(p_player_id,p_competition_id);
end;
$$;

grant execute on function public.save_tournament_preparation_v1(uuid,uuid,text,text,text,uuid[],text,text,text,text,text,text,text,text,text,text) to authenticated;

create or replace function public.get_tournament_preparation_v1(p_player_id uuid,p_competition_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_plan public.player_tournament_preparation_plans%rowtype;
  v_quote jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then
    raise exception 'Player access denied.';
  end if;

  select * into v_plan
  from public.player_tournament_preparation_plans
  where player_id=p_player_id and competition_id=p_competition_id;

  if not found then
    v_quote:=public.quote_tournament_preparation_v1(p_player_id,p_competition_id,'Economy','Economy','Standard','{}'::uuid[]);
    return jsonb_build_object(
      'saved',false,
      'player_travel_class','Economy',
      'staff_travel_class','Economy',
      'hotel_tier','Standard',
      'selected_staff_contract_ids','[]'::jsonb,
      'tactic',jsonb_build_object(
        'preset','Balanced','approach','Balanced','rally','Balanced rallies',
        'serve','Balanced','servePlacement','Automatic',
        'returnGame','Balanced','returnPosition','Normal',
        'courtPosition','Normal baseline','target','Automatic','risk','Balanced'
      ),
      'quote',v_quote
    );
  end if;

  v_quote:=public.quote_tournament_preparation_v1(
    p_player_id,p_competition_id,
    v_plan.player_travel_class,v_plan.staff_travel_class,v_plan.hotel_tier,
    v_plan.selected_staff_contract_ids
  );

  return jsonb_build_object(
    'saved',true,
    'player_travel_class',v_plan.player_travel_class,
    'staff_travel_class',v_plan.staff_travel_class,
    'hotel_tier',v_plan.hotel_tier,
    'selected_staff_contract_ids',to_jsonb(v_plan.selected_staff_contract_ids),
    'tactic',jsonb_build_object(
      'preset',v_plan.tactic_preset,
      'approach',v_plan.tactic_approach,
      'rally',v_plan.tactic_rally,
      'serve',v_plan.tactic_serve,
      'servePlacement',v_plan.tactic_serve_placement,
      'returnGame',v_plan.tactic_return,
      'returnPosition',v_plan.tactic_return_position,
      'courtPosition',v_plan.tactic_court_position,
      'target',v_plan.tactic_target,
      'risk',v_plan.tactic_risk
    ),
    'quote',v_quote,
    'saved_quote_snapshot',v_plan.quote_snapshot,
    'updated_at',v_plan.updated_at
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Match-engine handedness + opponent-specific tactic suitability.
-- Preserve the existing v2 engine as the core, then add a matchup layer.
-- ---------------------------------------------------------------------------

alter function public.get_match_engine_profile_for_match_base_v2(uuid,text,uuid)
rename to get_match_engine_profile_for_match_core_v2;

create function public.get_match_engine_profile_for_match_base_v2(
  p_player_id uuid,
  p_surface text,
  p_match_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  b jsonb;
  t jsonb;
  m public.tournament_matches%rowtype;
  me public.players%rowtype;
  opp public.players%rowtype;
  sk public.player_skills%rowtype;
  osk public.player_skills%rowtype;
  v_target text;
  v_rally text;
  v_placement text;
  v_return_position text;
  v_delta numeric:=0;
  v_target_delta numeric:=0;
  v_rally_delta numeric:=0;
  v_hand_delta numeric:=0;
  v_serve_delta numeric:=0;
  v_return_delta numeric:=0;
  v_serve numeric;
  v_ret numeric;
  v_rally_rating numeric;
  v_net numeric;
  v_expr numeric;
  v_mod jsonb;
  v_ace_delta numeric;
  v_ue_delta numeric;
begin
  b:=public.get_match_engine_profile_for_match_core_v2(p_player_id,p_surface,p_match_id);
  t:=public.get_effective_match_tactic_internal_v2(p_player_id,p_match_id);

  select * into m from public.tournament_matches where id=p_match_id;
  select * into me from public.players where id=p_player_id;
  select * into opp
  from public.players
  where id=case when m.player1_id=p_player_id then m.player2_id else m.player1_id end;

  select * into sk from public.player_skills where player_id=me.id;
  select * into osk from public.player_skills where player_id=opp.id;

  if opp.id is null or sk.player_id is null or osk.player_id is null then
    return b||jsonb_build_object('playing_hand',me.playing_hand);
  end if;

  v_target:=coalesce(t->>'target','Automatic');
  v_rally:=coalesce(t->>'rally','Balanced rallies');
  v_placement:=coalesce(t->>'servePlacement','Automatic');
  v_return_position:=coalesce(t->>'returnPosition','Normal');

  if v_target='Backhand' then
    v_target_delta:=greatest(-0.012,least(0.018,(osk.forehand-osk.backhand)*0.0009));
    if me.playing_hand<>opp.playing_hand then v_hand_delta:=0.004; end if;
  elsif v_target='Forehand' then
    v_target_delta:=greatest(-0.012,least(0.018,(osk.backhand-osk.forehand)*0.0009));
  elsif v_target='Movement' then
    v_target_delta:=greatest(-0.008,least(0.012,(66-osk.movement)*0.00055));
  elsif v_target='Stamina' then
    v_target_delta:=greatest(-0.008,least(0.012,(66-osk.stamina)*0.00055));
  elsif v_target='Second serve' then
    v_target_delta:=greatest(-0.006,least(0.010,(65-osk.serve)*0.00045));
  end if;

  if v_rally='Extend rallies' then
    v_rally_delta:=greatest(
      -0.010,
      least(0.012,((sk.stamina+sk.movement)-(osk.stamina+osk.movement))*0.00035)
    );
  elsif v_rally='Shorten points' then
    v_rally_delta:=greatest(
      -0.010,
      least(0.012,((sk.serve+greatest(sk.forehand,sk.volley))-(osk.return_skill+osk.movement))*0.00028)
    );
  end if;

  if v_placement='Wide' then
    v_serve_delta:=greatest(-0.004,least(0.008,(66-osk.movement)*0.00035));
    if me.playing_hand<>opp.playing_hand then v_serve_delta:=v_serve_delta+0.002; end if;
  elsif v_placement='Body' then
    v_serve_delta:=greatest(0,least(0.006,(osk.return_skill-62)*0.00025));
  elsif v_placement='T' then
    v_serve_delta:=greatest(-0.003,least(0.005,(sk.serve-62)*0.00020));
  end if;

  if v_return_position='Deeper' then
    v_return_delta:=greatest(-0.005,least(0.008,(osk.serve-65)*0.00035));
  elsif v_return_position='Closer' then
    v_return_delta:=greatest(-0.006,least(0.008,(66-osk.serve)*0.00035));
  end if;

  v_delta:=greatest(
    -0.030,
    least(0.035,v_target_delta+v_rally_delta+v_hand_delta)
  );

  v_serve:=(b->'ratings'->>'serve')::numeric*(1+v_serve_delta);
  v_ret:=(b->'ratings'->>'return')::numeric*(1+v_delta*0.70+v_return_delta);
  v_rally_rating:=(b->'ratings'->>'rally')::numeric*(1+v_delta);
  v_net:=(b->'ratings'->>'net')::numeric*(1+v_delta*0.25);
  v_expr:=(b->'condition'->>'expression_multiplier')::numeric;

  b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round(v_serve,2)));
  b:=jsonb_set(b,'{ratings,return}',to_jsonb(round(v_ret,2)));
  b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round(v_rally_rating,2)));
  b:=jsonb_set(b,'{ratings,net}',to_jsonb(round(v_net,2)));
  b:=jsonb_set(
    b,'{ratings,effective_overall}',
    to_jsonb(round(((v_serve+v_ret+v_rally_rating+v_net)/4)*v_expr,2))
  );

  v_mod:=coalesce(b->'match_modifiers','{}'::jsonb);
  v_ace_delta:=coalesce((v_mod->>'ace_delta')::numeric,0);
  v_ue_delta:=coalesce((v_mod->>'ue_delta')::numeric,0);

  -- Compatibility for the actual frontend tactic labels. The older engine
  -- core used legacy names for several choices, which meant valid UI choices
  -- could be visually saved without fully changing match execution.
  if coalesce(t->>'approach','Balanced')='Defensive' then
    v_serve:=v_serve-0.25;
    v_rally_rating:=v_rally_rating+0.25;
    v_ret:=v_ret+0.30;
    v_ue_delta:=v_ue_delta-0.010;
  end if;

  if coalesce(t->>'rally','Balanced rallies')='Shorten points' then
    v_serve:=v_serve+0.35;
    v_net:=v_net+0.45;
    v_rally_rating:=v_rally_rating-0.15;
    v_ue_delta:=v_ue_delta+0.008;
  elsif coalesce(t->>'rally','Balanced rallies')='Extend rallies' then
    v_rally_rating:=v_rally_rating+0.45
      +greatest(-0.25,least(0.35,(sk.stamina+sk.movement-100)*0.008));
    v_ret:=v_ret+0.25;
    v_serve:=v_serve-0.15;
    v_ue_delta:=v_ue_delta-0.004;
  end if;

  if coalesce(t->>'serve','Balanced')='Power serving' then
    v_serve:=v_serve+0.65;
    v_mod:=v_mod||jsonb_build_object(
      'first_serve_delta',coalesce((v_mod->>'first_serve_delta')::numeric,0)-0.035,
      'double_fault_delta',coalesce((v_mod->>'double_fault_delta')::numeric,0)+0.010
    );
    v_ace_delta:=v_ace_delta+0.018;
  elsif coalesce(t->>'serve','Balanced')='Safe first serve' then
    v_serve:=v_serve-0.30;
    v_mod:=v_mod||jsonb_build_object(
      'first_serve_delta',coalesce((v_mod->>'first_serve_delta')::numeric,0)+0.040,
      'double_fault_delta',coalesce((v_mod->>'double_fault_delta')::numeric,0)-0.008
    );
    v_ace_delta:=v_ace_delta-0.010;
  elsif coalesce(t->>'serve','Balanced')='Serve + 1' then
    v_serve:=v_serve+0.35;
    v_rally_rating:=v_rally_rating+0.30;
    v_ue_delta:=v_ue_delta+0.005;
  end if;

  if coalesce(t->>'returnGame','Balanced')='Aggressive return' then
    v_ret:=v_ret+0.45;
    v_ue_delta:=v_ue_delta+0.006;
  elsif coalesce(t->>'returnGame','Balanced')='Safe return' then
    v_ret:=v_ret+0.18;
    v_ue_delta:=v_ue_delta-0.005;
  end if;

  if coalesce(t->>'courtPosition','Normal baseline')='Inside baseline' then
    v_ret:=v_ret+0.18;
    v_net:=v_net+0.30;
    v_ue_delta:=v_ue_delta+0.005;
  elsif coalesce(t->>'courtPosition','Normal baseline')='Net attack' then
    v_net:=v_net+0.55;
    v_serve:=v_serve+0.15;
    v_rally_rating:=v_rally_rating-0.12;
    v_ue_delta:=v_ue_delta+0.008;
  end if;

  if coalesce(t->>'risk','Balanced')='Aggressive' then
    v_serve:=v_serve+0.20;
    v_rally_rating:=v_rally_rating+0.25;
    v_ret:=v_ret+0.15;
    v_ue_delta:=v_ue_delta+0.022;
  elsif coalesce(t->>'risk','Balanced')='Safe' then
    v_serve:=v_serve-0.15;
    v_rally_rating:=v_rally_rating+0.05;
    v_ret:=v_ret+0.08;
    v_ue_delta:=v_ue_delta-0.020;
  end if;

  if v_placement='Wide' then v_ace_delta:=v_ace_delta+0.004;
  elsif v_placement='T' then v_ace_delta:=v_ace_delta+0.003;
  elsif v_placement='Body' then v_ue_delta:=v_ue_delta-0.002;
  end if;

  if v_return_position='Closer' then v_ue_delta:=v_ue_delta+0.003;
  elsif v_return_position='Deeper' then v_ue_delta:=v_ue_delta-0.002;
  end if;

  -- Persist any compatibility adjustments added above.
  b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round(v_serve,2)));
  b:=jsonb_set(b,'{ratings,return}',to_jsonb(round(v_ret,2)));
  b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round(v_rally_rating,2)));
  b:=jsonb_set(b,'{ratings,net}',to_jsonb(round(v_net,2)));
  b:=jsonb_set(
    b,'{ratings,effective_overall}',
    to_jsonb(round(((v_serve+v_ret+v_rally_rating+v_net)/4)*v_expr,2))
  );

  b:=jsonb_set(
    b,'{match_modifiers}',
    v_mod||jsonb_build_object(
      'ace_delta',round(v_ace_delta,4),
      'ue_delta',round(v_ue_delta,4),
      'tactical_matchup_delta',round(v_delta,4),
      'target_weakness_delta',round(v_target_delta,4),
      'rally_matchup_delta',round(v_rally_delta,4),
      'handedness_geometry_delta',round(v_hand_delta,4),
      'serve_placement_delta',round(v_serve_delta,4),
      'return_position_delta',round(v_return_delta,4),
      'playing_hand',me.playing_hand,
      'opponent_playing_hand',opp.playing_hand,
      'serve_placement',v_placement,
      'return_position',v_return_position
    )
  );

  return b||jsonb_build_object(
    'playing_hand',me.playing_hand,
    'opponent_playing_hand',opp.playing_hand,
    'match_tactic',t
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. System Health / Control Center
-- ---------------------------------------------------------------------------

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
(
  'cron:tennis-opponent-scouting-v1',
  'Opponent scouting preparation',
  'Players & Tactics',
  'Starts Performance Analyst preparation tasks when a human player''s next opponent becomes known.',
  'cron',
  'tennis-opponent-scouting-v1',
  false,
  'high',
  5,
  20,
  true,
  46
),
(
  'check:player_identity_tactics',
  'Player identity and tactical integrity',
  'Players & Tactics',
  'Checks handedness coverage, AI left-handed distribution, avatar reservation integrity and opponent scouting task coverage.',
  'business_check',
  null,
  false,
  'high',
  15,
  45,
  true,
  220
)
on conflict(process_key) do update set
  label=excluded.label,
  category=excluded.category,
  description=excluded.description,
  source_kind=excluded.source_kind,
  source_ref=excluded.source_ref,
  user_sensitive=excluded.user_sensitive,
  incident_severity=excluded.incident_severity,
  expected_interval_minutes=excluded.expected_interval_minutes,
  stale_after_minutes=excluded.stale_after_minutes,
  email_alerts_enabled=excluded.email_alerts_enabled,
  is_enabled=true,
  sort_order=excluded.sort_order,
  updated_at=now();

create or replace function public.check_player_identity_tactics_health_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_catalog','pg_temp'
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_invalid_hands integer:=0;
  v_ai_total integer:=0;
  v_ai_left integer:=0;
  v_ai_left_pct numeric:=0;
  v_bad_reservations integer:=0;
  v_missing_scout_tasks integer:=0;
  v_problem_count integer:=0;
  v_details jsonb;
begin
  perform public.ensure_due_opponent_scouting_tasks_v1();

  select count(*) into v_invalid_hands
  from public.players
  where playing_hand not in ('right','left') or playing_hand is null;

  select count(*),count(*) filter(where playing_hand='left')
  into v_ai_total,v_ai_left
  from public.players
  where player_type='ai';

  if v_ai_total>0 then
    v_ai_left_pct:=round(v_ai_left::numeric/v_ai_total*100,2);
  end if;

  select count(*) into v_bad_reservations
  from public.player_avatar_reservations r
  left join public.players p on p.id=r.player_id
  where p.id is null
     or p.image_path is distinct from r.avatar_path;

  select count(*) into v_missing_scout_tasks
  from public.tournament_matches m
  join public.players hp
    on hp.id in (m.player1_id,m.player2_id)
   and hp.player_type='human'
   and hp.owner_user_id is not null
  join public.player_staff_contracts c
    on c.player_id=hp.id
   and c.role='performance_analyst'
   and c.status='active'
  where m.status='scheduled'
    and m.player1_id is not null
    and m.player2_id is not null
    and public.tournament_match_game_second_v1(m.id)>public.current_game_second_v1()
    and not exists(
      select 1 from public.player_opponent_scouting_tasks st
      where st.player_id=hp.id and st.match_id=m.id
    );

  v_problem_count:=v_invalid_hands+v_bad_reservations+v_missing_scout_tasks;
  if v_ai_total>0 and (v_ai_left_pct<8 or v_ai_left_pct>18) then
    v_problem_count:=v_problem_count+1;
  end if;

  v_details:=jsonb_build_object(
    'invalid_handedness_rows',v_invalid_hands,
    'ai_players',v_ai_total,
    'ai_left_handed',v_ai_left,
    'ai_left_handed_percent',v_ai_left_pct,
    'stale_avatar_reservations',v_bad_reservations,
    'scheduled_human_matches_missing_scout_task',v_missing_scout_tasks
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:player_identity_tactics',
      'high',
      'Player identity or tactical preparation requires attention',
      format('%s player identity/tactical integrity issue(s) detected.',v_problem_count),
      'business:player-identity-tactics',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:player-identity-tactics',
      'Player handedness, avatar reservations and scouting preparation are healthy.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  ) values(
    'check:player_identity_tactics',
    case when v_problem_count>0 then 'warning' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_problem_count>0
      then format('%s player identity/tactical issue(s).',v_problem_count)
      else 'Player identity and tactical preparation are healthy.'
    end,
    v_details
  );

  return jsonb_build_object(
    'status',case when v_problem_count>0 then 'warning' else 'success' end,
    'problems',v_problem_count,
    'details',v_details
  );
end;
$$;

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname='tennis-opponent-scouting-v1'
  limit 1;
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
end;
$$;

select cron.schedule(
  'tennis-opponent-scouting-v1',
  '*/5 * * * *',
  $cron$
    select public.ensure_due_opponent_scouting_tasks_v1();
    select public.check_player_identity_tactics_health_v1();
  $cron$
);

select public.ensure_due_opponent_scouting_tasks_v1();
select public.check_player_identity_tactics_health_v1();


-- Preserve the complete pre-existing match-tactic response contract (game-date
-- and lock-date metadata) while exposing the two new tactical dimensions.
create or replace function public.get_tournament_match_tactic_v1(p_player_id uuid,p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_match public.tournament_matches%rowtype;
  v_override public.player_tournament_match_tactics%rowtype;
  v_plan public.player_tournament_preparation_plans%rowtype;
  v_tournament jsonb;
  v_effective jsonb;
  v_override_json jsonb:=null;
  v_source text:='automatic_default';
  v_match_second bigint;
  v_lock bigint;
  v_now bigint:=public.current_game_second_v1();
  v_editable boolean;
  v_match_day record;
  v_lock_day record;
  v_match_minute integer;
  v_lock_minute integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then
    raise exception 'Player access denied.';
  end if;

  select * into v_match from public.tournament_matches where id=p_match_id;
  if not found then raise exception 'Match not found.'; end if;
  if p_player_id is distinct from v_match.player1_id and p_player_id is distinct from v_match.player2_id then
    raise exception 'This player is not in the selected match.';
  end if;

  v_match_second:=public.tournament_match_game_second_v1(p_match_id);
  v_lock:=case when v_match_second is null then null else v_match_second-3600 end;
  v_editable:=v_match.status='scheduled' and (v_lock is null or v_now<v_lock);

  if v_match_second is not null then
    select * into v_match_day
    from public.absolute_game_day_v1(floor(v_match_second::numeric/86400)::integer);
    v_match_minute:=((v_match_second%86400)/60)::integer;
  end if;

  if v_lock is not null then
    select * into v_lock_day
    from public.absolute_game_day_v1(floor(v_lock::numeric/86400)::integer);
    v_lock_minute:=((v_lock%86400)/60)::integer;
  end if;

  select * into v_plan
  from public.player_tournament_preparation_plans
  where player_id=p_player_id and competition_id=v_match.competition_id;

  if found then
    v_tournament:=jsonb_build_object(
      'preset',v_plan.tactic_preset,
      'approach',v_plan.tactic_approach,
      'rally',v_plan.tactic_rally,
      'serve',v_plan.tactic_serve,
      'servePlacement',v_plan.tactic_serve_placement,
      'returnGame',v_plan.tactic_return,
      'returnPosition',v_plan.tactic_return_position,
      'courtPosition',v_plan.tactic_court_position,
      'target',v_plan.tactic_target,
      'risk',v_plan.tactic_risk
    );
    v_source:='tournament_default';
  else
    v_tournament:=jsonb_build_object(
      'preset','Balanced','approach','Balanced','rally','Balanced rallies',
      'serve','Balanced','servePlacement','Automatic',
      'returnGame','Balanced','returnPosition','Normal',
      'courtPosition','Normal baseline','target','Automatic','risk','Balanced'
    );
  end if;

  select * into v_override
  from public.player_tournament_match_tactics
  where player_id=p_player_id and match_id=p_match_id;

  if found then
    v_override_json:=jsonb_build_object(
      'preset',v_override.tactic_preset,
      'approach',v_override.tactic_approach,
      'rally',v_override.tactic_rally,
      'serve',v_override.tactic_serve,
      'servePlacement',v_override.tactic_serve_placement,
      'returnGame',v_override.tactic_return,
      'returnPosition',v_override.tactic_return_position,
      'courtPosition',v_override.tactic_court_position,
      'target',v_override.tactic_target,
      'risk',v_override.tactic_risk
    );
    v_effective:=v_override_json;
    v_source:='match_override';
  else
    v_effective:=v_tournament;
  end if;

  return jsonb_build_object(
    'match_status',v_match.status,
    'editable',v_editable,
    'source',v_source,
    'tournament_default',v_tournament,
    'override',v_override_json,
    'effective',v_effective,
    'scheduled_game_second',v_match_second,
    'scheduled_start_minute',v_match.scheduled_start_minute,
    'scheduled_game_date',case when v_match_second is null then null else jsonb_build_object(
      'season',v_match_day.season,'month',v_match_day.month,'day',v_match_day.day,'season_week',v_match_day.season_week
    ) end,
    'tactic_lock_game_second',v_lock,
    'tactic_lock_game_date',case when v_lock is null then null else jsonb_build_object(
      'season',v_lock_day.season,'month',v_lock_day.month,'day',v_lock_day.day,'season_week',v_lock_day.season_week
    ) end,
    'tactic_lock_minute_of_day',v_lock_minute,
    'current_game_second',v_now,
    'lock_minutes_before_start',60
  );
end;
$$;
