-- Helios H01: keep doubles ranking publication and partner matchmaking
-- consistent with zero-point guest tie-breaks used in official singles rank.
-- No extra placement or entry advantages; points remain the primary criterion.
CREATE OR REPLACE FUNCTION public.process_doubles_rankings_for_day_v1(p_absolute_day integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c record;v_pub integer:=0;v_exp integer:=0;v_act integer:=0;v_cycles integer:=0;v_n integer;v_cycle_pub integer;v_cycle_exp integer;v_cycle_act integer;
begin
  for c in
    select wc.id competition_id,e.tournament_series_id,wc.world,e.season_number,
      public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+7 publish_day
    from public.tournament_world_competitions wc
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
    where exists(select 1 from public.tournament_doubles_matches dm where dm.competition_id=wc.id and lower(dm.round_label)='final' and dm.status in ('completed','walkover') and dm.winner_team_id is not null)
    group by wc.id,e.tournament_series_id,wc.world,e.season_number
    having public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+7<=p_absolute_day
       and not exists(select 1 from public.doubles_ranking_defence_cycles dc where dc.competition_id=wc.id)
  loop
    v_cycle_pub:=0;v_cycle_exp:=0;v_cycle_act:=0;
    update public.player_doubles_tournament_results r set ranking_publish_status='published',ranking_published_at=coalesce(r.ranking_published_at,now()),updated_at=now()
    where r.competition_id=c.competition_id and r.ranking_publish_status='pending' and r.ranking_publish_absolute_day<=p_absolute_day;
    get diagnostics v_n=row_count;v_cycle_pub:=v_n;v_pub:=v_pub+v_n;
    if c.season_number>1 then
      update public.player_doubles_ranking_contributions oldc set is_active=false,deactivated_absolute_day=p_absolute_day,deactivated_at=now(),
        replaced_by_result_id=(select r.id from public.player_doubles_tournament_results r where r.competition_id=c.competition_id and r.player_id=oldc.player_id and r.ranking_publish_status='published' limit 1),
        replaced_by_competition_id=c.competition_id,replacement_reason=case when exists(select 1 from public.player_doubles_tournament_results r where r.competition_id=c.competition_id and r.player_id=oldc.player_id and r.ranking_publish_status='published') then 'next_edition_result' else 'next_edition_no_result' end,updated_at=now()
      where oldc.is_active and oldc.tournament_series_id=c.tournament_series_id and oldc.world=c.world and oldc.season_number=c.season_number-1;
      get diagnostics v_n=row_count;v_cycle_exp:=v_n;v_exp:=v_exp+v_n;
    end if;
    insert into public.player_doubles_ranking_contributions(player_id,source_result_id,competition_id,tournament_series_id,world,season_number,ranking_points,awarded_absolute_day,expires_absolute_day,published_at,is_active)
    select r.player_id,r.id,r.competition_id,c.tournament_series_id,c.world,c.season_number,r.ranking_points_earned,coalesce(r.ranking_publish_absolute_day,p_absolute_day),coalesce(r.ranking_publish_absolute_day,p_absolute_day)+366,coalesce(r.ranking_published_at,now()),true
    from public.player_doubles_tournament_results r where r.competition_id=c.competition_id and r.ranking_publish_status='published'
    on conflict(source_result_id) do nothing;
    get diagnostics v_n=row_count;v_cycle_act:=v_n;v_act:=v_act+v_n;
    insert into public.doubles_ranking_defence_cycles(competition_id,tournament_series_id,world,season_number,scheduled_publish_absolute_day,processed_absolute_day,published_results,expired_contributions,activated_contributions)
    values(c.competition_id,c.tournament_series_id,c.world,c.season_number,c.publish_day,p_absolute_day,v_cycle_pub,v_cycle_exp,v_cycle_act) on conflict(competition_id) do nothing;
    v_cycles:=v_cycles+1;
  end loop;

  update public.player_doubles_ranking_contributions
  set is_active=false,deactivated_absolute_day=p_absolute_day,deactivated_at=now(),replacement_reason=coalesce(replacement_reason,'scheduled_expiration'),updated_at=now()
  where is_active and expires_absolute_day<=p_absolute_day;
  get diagnostics v_n=row_count;v_exp:=v_exp+v_n;

  update public.player_doubles_rankings r
  set ranking_points=coalesce((
    select sum(rc.ranking_points)::integer
    from public.player_doubles_ranking_contributions rc
    where rc.player_id=r.player_id and rc.is_active
  ),0),
  updated_at=now();

  insert into public.player_doubles_ranking_snapshots(player_id,world,game_absolute_day,ranking_position,ranking_points)
  select r.player_id,r.world,p_absolute_day,
    row_number() over(partition by r.world
      order by r.ranking_points desc,
      public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,r.ranking_points) asc,
      r.seed_rating desc,r.player_id)::integer,r.ranking_points
  from public.player_doubles_rankings r
  join public.players p on p.id=r.player_id
  on conflict(player_id,game_absolute_day) do update set ranking_position=excluded.ranking_position,ranking_points=excluded.ranking_points;

  insert into public.doubles_ranking_publication_runs(game_absolute_day,published_results,defence_cycles_processed,contributions_expired,contributions_activated,processed_at)
  values(p_absolute_day,v_pub,v_cycles,v_exp,v_act,now())
  on conflict(game_absolute_day) do update set
    published_results=excluded.published_results,
    defence_cycles_processed=excluded.defence_cycles_processed,
    contributions_expired=excluded.contributions_expired,
    contributions_activated=excluded.contributions_activated,
    processed_at=now();

  return jsonb_build_object('status','published','game_absolute_day',p_absolute_day,'published_results',v_pub,'defence_cycles_processed',v_cycles,'contributions_expired',v_exp,'contributions_activated',v_act);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_tournament_doubles_hub_v1(p_competition_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  v_core jsonb;
  v_timeline jsonb;
  v_availability jsonb;
  v_tournament jsonb;
  v_listing jsonb;
  v_my_team jsonb;
  v_market jsonb;
  v_incoming jsonb;
  v_outgoing jsonb;
  v_teams jsonb;
  v_status text;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=v_uid
  limit 1;

  if v_player.id is null then raise exception 'A player profile is required.'; end if;

  v_core:=public.get_tournament_doubles_core_v1(p_competition_id);
  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  v_availability:=public.check_player_competition_availability_v1(v_player.id,p_competition_id);

  select jsonb_build_object(
    'competition_id',wc.id,
    'world',wc.world,
    'name',ts.name,
    'city',ts.city,
    'country_code',ts.country_code,
    'surface',ts.surface,
    'category_code',ts.category_code
  )
  into v_tournament
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=p_competition_id;

  select jsonb_build_object(
    'id',l.id,'status',l.status,'created_at',l.created_at
  )
  into v_listing
  from public.tournament_doubles_partner_listings l
  where l.competition_id=p_competition_id
    and l.player_id=v_player.id
  order by l.updated_at desc
  limit 1;

  select jsonb_build_object(
    'id',t.id,
    'status',t.status,
    'entry_strength',t.entry_strength_snapshot,
    'seed_number',t.seed_number,
    'partner_id',case when t.player1_id=v_player.id then t.player2_id else t.player1_id end,
    'partner_name',case
      when t.player1_id=v_player.id then trim(p2.first_name||' '||p2.last_name)
      else trim(p1.first_name||' '||p1.last_name)
    end,
    'partner_country_code',case
      when t.player1_id=v_player.id then p2.country_code else p1.country_code
    end,
    'partner_doubles_points',case
      when t.player1_id=v_player.id then coalesce(d2.ranking_points,0)
      else coalesce(d1.ranking_points,0)
    end
  )
  into v_my_team
  from public.tournament_doubles_teams t
  join public.players p1 on p1.id=t.player1_id
  join public.players p2 on p2.id=t.player2_id
  left join public.player_doubles_rankings d1 on d1.player_id=t.player1_id
  left join public.player_doubles_rankings d2 on d2.player_id=t.player2_id
  where t.competition_id=p_competition_id
    and (t.player1_id=v_player.id or t.player2_id=v_player.id)
  order by
    case t.status
      when 'active' then 1
      when 'alternate' then 2
      when 'confirmed' then 3
      when 'champion' then 4
      when 'eliminated' then 5
      else 6
    end,
    t.created_at desc
  limit 1;

  with doubles_ranked as (
    select
      dr.player_id,
      dr.ranking_points,
      row_number() over(
        partition by dr.world
        order by dr.ranking_points desc,
        public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,dr.ranking_points) asc,
        dr.seed_rating desc,dr.player_id
      )::integer rank_position
    from public.player_doubles_rankings dr
    join public.players p on p.id=dr.player_id
  ),
  singles_ranked as (
    select
      p.id player_id,
      coalesce(pr.ranking_points,0) ranking_points,
      row_number() over(
        partition by p.world
        order by coalesce(pr.ranking_points,0) desc,
        public.is_tennis_zero_point_guest_rank_tie_v1(p.owner_user_id,coalesce(pr.ranking_points,0)) asc,
        coalesce(pr.seed_rating,0) desc,p.id
      )::integer rank_position
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.moderation_status<>'rejected'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'listing_id',l.id,
    'player_id',p.id,
    'first_name',p.first_name,
    'last_name',p.last_name,
    'country_code',p.country_code,
    'preferred_surface',p.preferred_surface,
    'surface_match',lower(coalesce(p.preferred_surface,''))=lower(coalesce(v_tournament->>'surface','')),
    'playing_style',p.playing_style,
    'doubles_rank',dr.rank_position,
    'doubles_points',coalesce(dr.ranking_points,0),
    'singles_rank',sr.rank_position,
    'singles_points',coalesce(sr.ranking_points,0),
    'singles_participation',coalesce(
      (
        select case
          when te.entry_status='active' then te.draw_type
          else null
        end
        from public.tournament_entries te
        where te.competition_id=p_competition_id
          and te.player_id=p.id
        order by te.updated_at desc
        limit 1
      ),
      (
        select case
          when a.status='applied' then 'applied'
          when a.status='accepted_main_draw' then 'main_draw'
          when a.status='accepted_qualification' then 'qualification'
          else null
        end
        from public.tournament_applications a
        where a.competition_id=p_competition_id
          and a.player_id=p.id
          and a.status<>'withdrawn'
        order by a.updated_at desc
        limit 1
      ),
      'none'
    ),
    'doubles_events',(
      select count(*)
      from public.player_doubles_tournament_results r
      where r.player_id=p.id
    ),
    'doubles_titles',(
      select count(*)
      from public.player_doubles_tournament_results r
      where r.player_id=p.id
        and r.result_stage_code='winner'
    ),
    'is_me',p.id=v_player.id
  ) order by
    coalesce(dr.rank_position,2147483647),
    coalesce(sr.rank_position,2147483647),
    p.last_name,p.first_name),'[]'::jsonb)
  into v_market
  from public.tournament_doubles_partner_listings l
  join public.players p on p.id=l.player_id
  left join doubles_ranked dr on dr.player_id=p.id
  left join singles_ranked sr on sr.player_id=p.id
  where l.competition_id=p_competition_id
    and l.status='active'
    and p.world=v_player.world
    and not exists(
      select 1
      from public.tournament_doubles_teams t
      where t.competition_id=p_competition_id
        and t.status in ('confirmed','active','alternate')
        and (t.player1_id=p.id or t.player2_id=p.id)
    )
    and (
      (
        p.player_type='ai'
        and public.is_same_event_ai_doubles_candidate_v1(p.id,p_competition_id)
      )
      or (
        p.player_type<>'ai'
        and coalesce(
          (public.check_player_competition_availability_v1(p.id,p_competition_id)->>'available')::boolean,
          false
        )
      )
    );

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',i.id,
    'status',i.status,
    'partner_id',p.id,
    'partner_name',trim(p.first_name||' '||p.last_name),
    'country_code',p.country_code,
    'created_at',i.created_at,
    'expires_game_second',i.expires_game_second,
    'expires_at_game',public.game_moment_json_v1(i.expires_game_second),
    'doubles_points',coalesce(dr.ranking_points,0)
  ) order by i.created_at desc),'[]'::jsonb)
  into v_incoming
  from public.tournament_doubles_partner_invitations i
  join public.players p on p.id=i.inviter_player_id
  left join public.player_doubles_rankings dr on dr.player_id=p.id
  where i.competition_id=p_competition_id
    and i.invitee_player_id=v_player.id
    and i.status='pending';

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',i.id,
    'status',i.status,
    'partner_id',p.id,
    'partner_name',trim(p.first_name||' '||p.last_name),
    'country_code',p.country_code,
    'created_at',i.created_at,
    'expires_game_second',i.expires_game_second,
    'expires_at_game',public.game_moment_json_v1(i.expires_game_second),
    'doubles_points',coalesce(dr.ranking_points,0)
  ) order by i.created_at desc),'[]'::jsonb)
  into v_outgoing
  from public.tournament_doubles_partner_invitations i
  join public.players p on p.id=i.invitee_player_id
  left join public.player_doubles_rankings dr on dr.player_id=p.id
  where i.competition_id=p_competition_id
    and i.inviter_player_id=v_player.id
    and i.status='pending';

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',t.id,
    'status',t.status,
    'player1_id',p1.id,
    'player1_name',trim(p1.first_name||' '||p1.last_name),
    'player1_country_code',p1.country_code,
    'player2_id',p2.id,
    'player2_name',trim(p2.first_name||' '||p2.last_name),
    'player2_country_code',p2.country_code,
    'combined_doubles_points',t.combined_ranking_points_snapshot,
    'entry_strength',t.entry_strength_snapshot,
    'seed_number',t.seed_number
  ) order by
    case t.status
      when 'active' then 1
      when 'confirmed' then 2
      when 'alternate' then 3
      when 'champion' then 4
      else 5
    end,
    t.entry_strength_snapshot desc,
    t.created_at),'[]'::jsonb)
  into v_teams
  from public.tournament_doubles_teams t
  join public.players p1 on p1.id=t.player1_id
  join public.players p2 on p2.id=t.player2_id
  where t.competition_id=p_competition_id
    and t.status<>'withdrawn';

  if v_my_team is not null then
    v_status:=case v_my_team->>'status'
      when 'confirmed' then 'partnership_confirmed'
      when 'active' then 'entry_accepted'
      when 'alternate' then 'waitlisted'
      when 'champion' then 'champion'
      when 'eliminated' then 'eliminated'
      else 'withdrawn'
    end;
  elsif coalesce(v_listing->>'status','')='active' then
    v_status:='looking_for_partner';
  elsif jsonb_array_length(v_incoming)>0 then
    v_status:='invitation_received';
  elsif not coalesce((v_availability->>'available')::boolean,false) then
    v_status:='unavailable';
  elsif coalesce(v_timeline->>'phase','')='not_open' then
    v_status:='not_open';
  elsif coalesce((v_timeline->>'entry_locked')::boolean,false) then
    v_status:='entry_locked';
  else
    v_status:='available';
  end if;

  return jsonb_build_object(
    'competition_id',p_competition_id,
    'tournament',v_tournament,
    'core',v_core,
    'timeline',v_timeline,
    'availability',v_availability,
    'player_status',v_status,
    'my_listing',v_listing,
    'my_team',v_my_team,
    'marketplace',v_market,
    'incoming_invitations',v_incoming,
    'outgoing_invitations',v_outgoing,
    'teams',v_teams
  );
end;
$function$
;
