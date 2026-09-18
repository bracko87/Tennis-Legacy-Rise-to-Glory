-- Mirror of the production sponsor-objective follow-up applied on 2026-09-18.
-- Keeps main-sponsor reputation independent from the technical-sponsor profile
-- and exposes live tournament-round progress before final result publication.

CREATE OR REPLACE FUNCTION public.main_sponsor_player_reputation_v2(p_player_id uuid)
 RETURNS smallint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_rank integer:=9999;
  v_recent_total integer:=0;
  v_recent_wins integer:=0;
  v_recent_pct numeric:=50;
  v_titles integer:=0;
  v_base integer:=20;
  v_form_bonus integer:=0;
  v_title_bonus integer:=0;
begin
  if not exists(select 1 from public.players where id=p_player_id) then
    raise exception 'Player not found.';
  end if;

  v_rank:=greatest(1,coalesce(public.player_current_rank_position_v1(p_player_id),9999)::integer);

  select count(*),count(*) filter(where won)
  into v_recent_total,v_recent_wins
  from (
    select f.won
    from public.statistics_player_match_facts_v1 f
    where f.player_id=p_player_id
    order by f.season desc,f.scheduled_season_week desc,f.scheduled_day desc,f.match_id desc
    limit 12
  ) recent;

  if v_recent_total>0 then
    v_recent_pct:=(v_recent_wins::numeric/v_recent_total::numeric)*100;
  end if;

  select count(*)::integer
  into v_titles
  from public.player_tournament_results r
  where r.player_id=p_player_id
    and r.result_code='champion';

  v_base:=case
    when v_rank<=10 then 90
    when v_rank<=30 then 82
    when v_rank<=50 then 76
    when v_rank<=100 then 70
    when v_rank<=300 then 58
    when v_rank<=500 then 50
    when v_rank<=1000 then 42
    when v_rank<=2500 then 32
    else 22
  end;

  v_form_bonus:=round(greatest(-8::numeric,least(10::numeric,(v_recent_pct-50)/5)))::integer;
  v_title_bonus:=least(10,greatest(0,v_titles)*2);

  return least(100,greatest(0,v_base+v_form_bonus+v_title_bonus))::smallint;
end;
$function$


CREATE OR REPLACE FUNCTION public.sponsor_match_round_level_v2(p_round_label text)
 RETURNS smallint
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case lower(coalesce(p_round_label,''))
    when 'final' then 7
    when 'semifinal' then 6
    when 'quarterfinal' then 5
    when 'round of 16' then 4
    when 'round of 32' then 3
    when 'round of 64' then 2
    when 'round of 128' then 1
    else 0
  end::smallint;
$function$


CREATE OR REPLACE FUNCTION public.build_sponsor_objective_plan_v2(p_offer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  o public.player_sponsor_offers%rowtype;
  p public.players%rowtype;
  s public.sponsor_companies%rowtype;
  r public.sponsor_offer_rules%rowtype;
  v_profile jsonb;
  v_reputation integer:=50;
  v_player_group text;
  v_sponsor_group text;
  v_player_macro text;
  v_sponsor_macro text;
  v_abs integer;
  gd record;
  v_end integer;
  v_fraction numeric;
  v_sponsor_strength numeric:=0;
  v_pool_pct numeric;
  v_bonus_pool bigint;
  v_target_count integer;
  v_tournament_target integer;
  v_general_target integer;
  v_plan jsonb:='[]'::jsonb;
  v_used uuid[]:='{}'::uuid[];
  v_i integer;
  v_target_group text;
  v_target_country text;
  t record;
  v_level integer;
  v_weight numeric;
  v_target_rank integer;
  v_match_target integer;
  v_current_count integer;
  v_total_weight numeric;
  v_final_plan jsonb;
begin
  select * into o from public.player_sponsor_offers where id=p_offer_id;
  if o.id is null then raise exception 'Sponsor offer not found.'; end if;

  select * into p from public.players where id=o.player_id;
  select * into s from public.sponsor_companies where id=o.sponsor_company_id;
  select * into r from public.sponsor_offer_rules where code=o.offer_rule_code;

  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_end:=public.game_day_absolute_v1(o.season,12::smallint,31::smallint);

  v_reputation:=public.main_sponsor_player_reputation_v2(o.player_id)::integer;

  select gm.group_code,g.macro_region into v_player_group,v_player_macro
  from public.sponsor_market_group_members gm
  join public.sponsor_market_groups g on g.code=gm.group_code
  where gm.country_code=p.country_code;

  select gm.group_code,g.macro_region into v_sponsor_group,v_sponsor_macro
  from public.sponsor_market_group_members gm
  join public.sponsor_market_groups g on g.code=gm.group_code
  where gm.country_code=s.country_code;

  if r.full_season_value_max>r.full_season_value_min then
    v_sponsor_strength:=least(1::numeric,greatest(0::numeric,
      (o.full_season_value-r.full_season_value_min)::numeric
      /(r.full_season_value_max-r.full_season_value_min)::numeric
    ));
  end if;

  v_pool_pct:=case
    when o.player_rank<=10 then 0.38
    when o.player_rank<=30 then 0.34
    when o.player_rank<=100 then 0.30
    when o.player_rank<=300 then 0.25
    else 0.20
  end;
  v_pool_pct:=least(0.45::numeric,greatest(0.18::numeric,
    v_pool_pct + (v_sponsor_strength-0.50)*0.04 + (v_reputation-50)*0.0004
  ));

  v_bonus_pool:=greatest(300::bigint,
    (round((o.total_contract_value::numeric*v_pool_pct)/100::numeric)*100)::bigint
  );

  v_target_count:=case
    when o.player_rank<=30 then 8
    when o.player_rank<=100 then 7
    when o.player_rank<=300 then 6
    when o.player_rank<=1000 then 5
    else 4
  end;
  v_tournament_target:=case
    when o.player_rank<=30 then 5
    when o.player_rank<=100 then 5
    when o.player_rank<=300 then 4
    when o.player_rank<=1000 then 3
    else 2
  end;

  for v_i in 1..v_tournament_target loop
    if o.player_rank<=30 then
      v_target_group:=null;
      v_target_country:=null;
    elsif v_player_group is not distinct from v_sponsor_group then
      v_target_group:=v_player_group;
      v_target_country:=p.country_code;
    elsif mod(v_i,2)=1 then
      v_target_group:=v_player_group;
      v_target_country:=p.country_code;
    else
      v_target_group:=v_sponsor_group;
      v_target_country:=s.country_code;
    end if;

    select q.* into t
    from (
      select
        wc.id competition_id,
        e.tournament_series_id,
        ts.name tournament_name,
        ts.country_code,
        ts.category_code,
        ts.surface,
        tgm.group_code tournament_group,
        tg.macro_region tournament_macro,
        public.training_camp_week_start_absolute_v1(e.season_number,min(ss.season_week)::smallint) start_day,
        public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+6 deadline_day,
        public.sponsor_category_strength_v2(ts.category_code) category_strength
      from public.tournament_world_competitions wc
      join public.tournament_editions e on e.id=wc.tournament_edition_id
      join public.tournament_series ts on ts.id=e.tournament_series_id
      join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
      left join public.sponsor_market_group_members tgm on tgm.country_code=ts.country_code
      left join public.sponsor_market_groups tg on tg.code=tgm.group_code
      where e.season_number=o.season
        and wc.world=p.world
        and wc.status<>'canceled'
        and e.status<>'canceled'
        and ts.is_active
        and wc.id<>all(v_used)
        and not exists(select 1 from public.tournament_cancellations tc where tc.competition_id=wc.id)
        and public.sponsor_category_realistic_for_rank_v2(o.player_rank,ts.category_code)
      group by wc.id,e.tournament_series_id,e.season_number,ts.name,ts.country_code,ts.category_code,ts.surface,tgm.group_code,tg.macro_region
    ) q
    where q.start_day>v_abs
      and q.deadline_day<=v_end
    order by
      case
        when o.player_rank<=30 then 0
        when q.country_code=v_target_country then 0
        when q.tournament_group=v_target_group then 1
        when q.tournament_group in (v_player_group,v_sponsor_group) then 2
        when q.tournament_macro in (v_player_macro,v_sponsor_macro) then 3
        else 4
      end,
      case when o.player_rank<=30 then q.category_strength else 0 end desc,
      case when p.preferred_surface is not null and lower(q.surface)=lower(p.preferred_surface) then 0 else 1 end,
      public.sponsor_hash_unit_v1(concat_ws(':','objective-event',p_offer_id::text,v_i::text,q.competition_id::text))
    limit 1;

    if t.competition_id is null then
      exit;
    end if;

    v_used:=array_append(v_used,t.competition_id);

    if v_i=1 then
      v_weight:=0.65 + t.category_strength*0.035;
      v_plan:=v_plan || jsonb_build_array(jsonb_build_object(
        'objective_key',format('tournament:%s:appearance',t.competition_id),
        'objective_code','tournament_appearance',
        'title',format('%s appearance',t.tournament_name),
        'description',format('Compete in %s for %s.',t.tournament_name,s.name),
        'tournament_name',t.tournament_name,
        'competition_id',t.competition_id,
        'tournament_series_id',t.tournament_series_id,
        'country_code',t.country_code,
        'category_code',t.category_code,
        'surface',t.surface,
        'requirement_label','Participate in tournament',
        'target_value',1,
        'start_absolute_day',t.start_day,
        'deadline_absolute_day',t.deadline_day,
        'weight',v_weight,
        'geography_basis',case
          when o.player_rank<=30 then 'global_prestige'
          when t.country_code=p.country_code then 'player_country'
          when t.country_code=s.country_code then 'sponsor_country'
          when t.tournament_group=v_player_group then 'player_region'
          when t.tournament_group=v_sponsor_group then 'sponsor_region'
          else 'extended_region' end
      ));
    else
      v_level:=public.sponsor_result_target_level_v2(
        o.player_rank,t.category_code,v_reputation,v_sponsor_strength,
        concat_ws(':',p_offer_id::text,t.competition_id::text)
      );
      v_weight:=0.85 + t.category_strength*0.07 + v_level*0.09;
      v_plan:=v_plan || jsonb_build_array(jsonb_build_object(
        'objective_key',format('tournament:%s:result',t.competition_id),
        'objective_code','tournament_result',
        'title',format('%s performance',t.tournament_name),
        'description',format('%s at %s.',public.sponsor_result_requirement_label_v2(v_level),t.tournament_name),
        'tournament_name',t.tournament_name,
        'competition_id',t.competition_id,
        'tournament_series_id',t.tournament_series_id,
        'country_code',t.country_code,
        'category_code',t.category_code,
        'surface',t.surface,
        'requirement_label',public.sponsor_result_requirement_label_v2(v_level),
        'target_value',v_level,
        'start_absolute_day',t.start_day,
        'deadline_absolute_day',t.deadline_day,
        'weight',v_weight,
        'geography_basis',case
          when o.player_rank<=30 then 'global_prestige'
          when t.country_code=p.country_code then 'player_country'
          when t.country_code=s.country_code then 'sponsor_country'
          when t.tournament_group=v_player_group then 'player_region'
          when t.tournament_group=v_sponsor_group then 'sponsor_region'
          else 'extended_region' end
      ));
    end if;
  end loop;

  v_current_count:=jsonb_array_length(v_plan);
  v_general_target:=greatest(3-v_current_count,v_target_count-v_current_count);
  v_fraction:=least(1::numeric,greatest(0.05::numeric,(v_end-v_abs+1)::numeric/366::numeric));

  if v_general_target>=1 then
    v_target_rank:=case
      when o.player_rank<=10 then greatest(1,o.player_rank-2)
      when o.player_rank<=30 then greatest(1,ceil(o.player_rank*0.82)::integer)
      when o.player_rank<=100 then greatest(15,ceil(o.player_rank*0.80)::integer)
      when o.player_rank<=300 then greatest(75,ceil(o.player_rank*0.80)::integer)
      when o.player_rank<=1000 then greatest(250,ceil(o.player_rank*0.82)::integer)
      else greatest(750,ceil(o.player_rank*0.85)::integer)
    end;
    if v_target_rank>=o.player_rank then v_target_rank:=greatest(1,o.player_rank-1); end if;

    v_plan:=v_plan || jsonb_build_array(jsonb_build_object(
      'objective_key','ranking:peak',
      'objective_code','ranking_peak',
      'title',format('Reach Top %s',v_target_rank),
      'description',format('Reach world ranking #%s or better before the sponsor agreement ends.',v_target_rank),
      'requirement_label',format('Reach Top %s',v_target_rank),
      'target_value',1,
      'target_rank',v_target_rank,
      'start_absolute_day',v_abs,
      'deadline_absolute_day',v_end,
      'weight',1.10
    ));
  end if;

  if v_general_target>=2 then
    v_match_target:=greatest(2,ceil((case
      when o.player_rank<=10 then 34
      when o.player_rank<=30 then 30
      when o.player_rank<=100 then 22
      when o.player_rank<=300 then 15
      when o.player_rank<=1000 then 10
      else 7 end)*v_fraction)::integer);

    v_plan:=v_plan || jsonb_build_array(jsonb_build_object(
      'objective_key','season:match-wins',
      'objective_code','match_wins_period',
      'title',format('%s match wins',v_match_target),
      'description',format('Win %s tournament matches while the sponsor agreement is active.',v_match_target),
      'requirement_label',format('Win %s matches',v_match_target),
      'target_value',v_match_target,
      'start_absolute_day',v_abs,
      'deadline_absolute_day',v_end,
      'weight',1.00
    ));
  end if;

  if v_general_target>=3 then
    v_target_rank:=case
      when o.player_rank<=10 then greatest(1,o.player_rank)
      when o.player_rank<=30 then greatest(1,ceil(o.player_rank*0.90)::integer)
      when o.player_rank<=100 then greatest(20,ceil(o.player_rank*0.90)::integer)
      when o.player_rank<=300 then greatest(100,ceil(o.player_rank*0.92)::integer)
      else greatest(300,ceil(o.player_rank*0.94)::integer)
    end;

    v_plan:=v_plan || jsonb_build_array(jsonb_build_object(
      'objective_key','season:finish-rank',
      'objective_code','season_finish_rank',
      'title',format('Finish season Top %s',v_target_rank),
      'description',format('Finish Season %s ranked #%s or better.',o.season,v_target_rank),
      'requirement_label',format('Finish Top %s',v_target_rank),
      'target_value',1,
      'target_rank',v_target_rank,
      'start_absolute_day',v_abs,
      'deadline_absolute_day',v_end,
      'weight',1.30
    ));
  end if;

  select coalesce(sum((x.value->>'weight')::numeric),0)
  into v_total_weight
  from jsonb_array_elements(v_plan) x(value);

  if v_total_weight<=0 then
    return jsonb_build_object(
      'bonus_pool',v_bonus_pool,
      'reputation',v_reputation,
      'sponsor_strength',v_sponsor_strength,
      'objectives','[]'::jsonb
    );
  end if;

  with e as (
    select value elem, ord,
           count(*) over() n,
           (value->>'weight')::numeric weight
    from jsonb_array_elements(v_plan) with ordinality a(value,ord)
  ), b as (
    select elem,ord,n,
      case when ord<n
        then floor((v_bonus_pool::numeric*weight/v_total_weight)/100::numeric)*100
        else null end::bigint base_reward
    from e
  ), f as (
    select elem,ord,n,
      case when ord=n
        then greatest(0::bigint,v_bonus_pool-coalesce(sum(base_reward) filter(where ord<n) over(),0))
        else greatest(0::bigint,base_reward) end reward_amount
    from b
  )
  select coalesce(jsonb_agg(
    (elem-'weight') || jsonb_build_object('reward_amount',reward_amount)
    order by ord
  ),'[]'::jsonb)
  into v_final_plan
  from f;

  return jsonb_build_object(
    'bonus_pool',v_bonus_pool,
    'reputation',v_reputation,
    'sponsor_strength',round(v_sponsor_strength,3),
    'player_group',v_player_group,
    'sponsor_group',v_sponsor_group,
    'objectives',v_final_plan
  );
end;
$function$


CREATE OR REPLACE FUNCTION public.sponsor_refresh_player_objectives_v1(p_player_id uuid, p_through_absolute_day integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_owner uuid;
  gd record;
  v_through integer;
  v_rank integer;
  obj record;
  v_current integer:=0;
  v_target_rank integer;
  v_result_level integer:=0;
  v_round_level integer:=0;
  v_has_result boolean:=false;
  v_should_complete boolean;
  v_terminal_status text;
  v_post jsonb;
  v_tx uuid;
  v_sponsor_name text;
  v_checked integer:=0;
  v_completed integer:=0;
begin
  select owner_user_id into v_owner
  from public.players
  where id=p_player_id and player_type='human';

  if v_owner is null then raise exception 'Human player not found.'; end if;
  if v_uid is not null and v_uid<>v_owner then raise exception 'Not authorized for this player.'; end if;

  select * into gd from public.get_current_game_day_internal_v1();
  v_through:=coalesce(p_through_absolute_day,public.game_day_absolute_v1(gd.season,gd.month,gd.day));
  v_rank:=greatest(1,coalesce(public.player_current_rank_position_v1(p_player_id),9999)::integer);

  for obj in
    select o.*,c.signed_absolute_day,c.end_absolute_day
    from public.player_sponsor_objectives o
    join public.player_sponsor_contracts c on c.id=o.contract_id
    where o.player_id=p_player_id
      and o.status in ('upcoming','active')
    order by coalesce(o.deadline_absolute_day,c.end_absolute_day),o.created_at,o.id
  loop
    v_checked:=v_checked+1;
    v_current:=0;
    v_result_level:=0;
    v_round_level:=0;
    v_has_result:=false;
    v_should_complete:=false;
    v_terminal_status:=null;
    v_target_rank:=coalesce((obj.metadata->>'target_rank')::integer,999999);

    if obj.objective_code='tournament_appearance' then
      select case when
        exists(
          select 1
          from public.statistics_player_match_facts_v1 f
          where f.player_id=p_player_id and f.competition_id=obj.competition_id
        )
        or exists(
          select 1
          from public.player_tournament_results tr
          where tr.player_id=p_player_id and tr.competition_id=obj.competition_id
        )
        or (
          v_through>=coalesce(obj.start_absolute_day,obj.signed_absolute_day)
          and exists(
            select 1
            from public.tournament_matches tm
            where tm.competition_id=obj.competition_id
              and tm.draw_type='main_draw'
              and tm.status<>'cancelled'
              and (tm.player1_id=p_player_id or tm.player2_id=p_player_id)
          )
        )
      then 1 else 0 end
      into v_current;

      v_should_complete:=v_current>=1;
      if not v_should_complete then
        if v_through>coalesce(obj.deadline_absolute_day,obj.end_absolute_day) then
          v_terminal_status:='expired';
        elsif v_through>=coalesce(obj.start_absolute_day,obj.signed_absolute_day) then
          v_terminal_status:='active';
        else
          v_terminal_status:='upcoming';
        end if;
      end if;

    elsif obj.objective_code='tournament_result' then
      select public.sponsor_result_level_v1(tr.result_code),true
      into v_result_level,v_has_result
      from public.player_tournament_results tr
      where tr.player_id=p_player_id and tr.competition_id=obj.competition_id
      limit 1;

      v_result_level:=coalesce(v_result_level,0);
      v_has_result:=coalesce(v_has_result,false);

      if v_through>=coalesce(obj.start_absolute_day,obj.signed_absolute_day) then
        select coalesce(max(public.sponsor_match_round_level_v2(tm.round_label)),0)
        into v_round_level
        from public.tournament_matches tm
        where tm.competition_id=obj.competition_id
          and tm.draw_type='main_draw'
          and tm.status<>'cancelled'
          and (tm.player1_id=p_player_id or tm.player2_id=p_player_id);

        if exists(
          select 1
          from public.tournament_matches tm
          where tm.competition_id=obj.competition_id
            and tm.draw_type='main_draw'
            and lower(tm.round_label)='final'
            and tm.status in ('completed','walkover')
            and tm.winner_id=p_player_id
        ) then
          v_round_level:=8;
        end if;
      end if;

      v_current:=greatest(v_result_level,v_round_level);
      v_should_complete:=v_current>=obj.target_value;

      if not v_should_complete then
        if v_has_result then
          v_terminal_status:='failed';
        elsif v_through>coalesce(obj.deadline_absolute_day,obj.end_absolute_day) then
          v_terminal_status:='expired';
        elsif v_through>=coalesce(obj.start_absolute_day,obj.signed_absolute_day) then
          v_terminal_status:='active';
        else
          v_terminal_status:='upcoming';
        end if;
      end if;

    elsif obj.objective_code='ranking_peak' then
      v_current:=case when v_rank<=v_target_rank then 1 else 0 end;
      v_should_complete:=v_current=1;
      if not v_should_complete then
        v_terminal_status:=case
          when v_through>coalesce(obj.deadline_absolute_day,obj.end_absolute_day) then 'expired'
          else 'active' end;
      end if;
      update public.player_sponsor_objectives
      set metadata=jsonb_set(coalesce(metadata,'{}'::jsonb),'{current_rank}',to_jsonb(v_rank),true)
      where id=obj.id;

    elsif obj.objective_code='season_finish_rank' then
      v_current:=case when v_rank<=v_target_rank then 1 else 0 end;
      if v_through>=coalesce(obj.deadline_absolute_day,obj.end_absolute_day) then
        v_should_complete:=v_current=1;
        if not v_should_complete then v_terminal_status:='failed'; end if;
      else
        v_terminal_status:='active';
      end if;
      update public.player_sponsor_objectives
      set metadata=jsonb_set(coalesce(metadata,'{}'::jsonb),'{current_rank}',to_jsonb(v_rank),true)
      where id=obj.id;

    elsif obj.objective_code in ('match_wins_period','match_wins') then
      select count(*)::integer into v_current
      from public.statistics_player_match_facts_v1 f
      where f.player_id=p_player_id and f.won
        and (public.training_camp_week_start_absolute_v1(f.season,f.scheduled_season_week::smallint)+f.scheduled_day-1)
          between obj.signed_absolute_day and least(v_through,obj.end_absolute_day);
      v_should_complete:=v_current>=obj.target_value;
      if not v_should_complete then
        v_terminal_status:=case
          when v_through>coalesce(obj.deadline_absolute_day,obj.end_absolute_day) then 'expired'
          else 'active' end;
      end if;

    elsif obj.objective_code='appearances' then
      select count(distinct f.competition_id)::integer into v_current
      from public.statistics_player_match_facts_v1 f
      where f.player_id=p_player_id
        and (public.training_camp_week_start_absolute_v1(f.season,f.scheduled_season_week::smallint)+f.scheduled_day-1)
          between obj.signed_absolute_day and least(v_through,obj.end_absolute_day);
      v_should_complete:=v_current>=obj.target_value;
      if not v_should_complete then
        v_terminal_status:=case when v_through>obj.end_absolute_day then 'expired' else 'active' end;
      end if;

    else
      select count(distinct tr.competition_id)::integer into v_current
      from public.player_tournament_results tr
      where tr.player_id=p_player_id
        and public.sponsor_result_level_v1(tr.result_code)>=coalesce((obj.metadata->>'min_result_level')::smallint,8)
        and exists(
          select 1 from public.statistics_player_match_facts_v1 f
          where f.player_id=p_player_id and f.competition_id=tr.competition_id
            and (public.training_camp_week_start_absolute_v1(f.season,f.scheduled_season_week::smallint)+f.scheduled_day-1)
              between obj.signed_absolute_day and least(v_through,obj.end_absolute_day)
        );
      v_should_complete:=v_current>=obj.target_value;
      if not v_should_complete then
        v_terminal_status:=case when v_through>obj.end_absolute_day then 'expired' else 'active' end;
      end if;
    end if;

    update public.player_sponsor_objectives
    set current_value=greatest(0,coalesce(v_current,0)),
        status=case when v_should_complete then status else coalesce(v_terminal_status,status) end,
        updated_at=now()
    where id=obj.id;

    if v_should_complete then
      select name into v_sponsor_name
      from public.sponsor_companies
      where id=obj.sponsor_company_id;

      v_post:=public.post_career_finance_transaction_v1(
        p_player_id,
        obj.reward_amount,
        'performance_bonus',
        obj.objective_code,
        format('%s — %s sponsor bonus',v_sponsor_name,obj.title),
        'sponsor_objective',
        obj.id::text,
        format('sponsor-objective:%s:bonus',obj.id),
        jsonb_build_object(
          'taxable',true,
          'contract_id',obj.contract_id,
          'sponsor_company_id',obj.sponsor_company_id,
          'sponsor_name',v_sponsor_name,
          'objective_code',obj.objective_code,
          'objective_title',obj.title,
          'tournament_name',obj.tournament_name,
          'competition_id',obj.competition_id,
          'reward_amount',obj.reward_amount
        ),
        false,
        v_through
      );

      v_tx:=nullif(v_post->>'transaction_id','')::uuid;

      update public.player_sponsor_objectives
      set status='completed',
          achieved_absolute_day=coalesce(achieved_absolute_day,v_through),
          payout_transaction_id=coalesce(payout_transaction_id,v_tx),
          current_value=greatest(target_value,coalesce(v_current,0)),
          updated_at=now()
      where id=obj.id
        and status in ('upcoming','active');

      if found then v_completed:=v_completed+1; end if;
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'through_absolute_day',v_through,
    'checked',v_checked,
    'newly_completed',v_completed
  );
end;
$function$


revoke execute on function public.main_sponsor_player_reputation_v2(uuid) from public,anon,authenticated;
revoke execute on function public.sponsor_match_round_level_v2(text) from public,anon,authenticated;
revoke execute on function public.build_sponsor_objective_plan_v2(uuid) from public,anon,authenticated;
revoke execute on function public.sponsor_refresh_player_objectives_v1(uuid,integer) from public,anon,authenticated;

grant execute on function public.main_sponsor_player_reputation_v2(uuid) to service_role;
grant execute on function public.sponsor_match_round_level_v2(text) to service_role;
grant execute on function public.build_sponsor_objective_plan_v2(uuid) to service_role;
grant execute on function public.sponsor_refresh_player_objectives_v1(uuid,integer) to service_role;
