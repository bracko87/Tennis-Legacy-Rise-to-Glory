
create or replace function public.seed_ai_doubles_partner_marketplace_v1(p_competition_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_world text;
  v_draw_size integer;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_inserted integer:=0;
begin
  select wc.world,ds.draw_size
  into v_world,v_draw_size
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id
    and ds.is_enabled;

  if v_world is null then return 0; end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if v_now<(v_timeline->>'registration_open_game_second')::bigint
     or v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
    return 0;
  end if;

  with pool as (
    select
      p.id,
      te.draw_type,
      coalesce(te.ranking_position_snapshot,999999) ranking_position,
      ((hashtextextended(p.id::text||':'||p_competition_id::text,0)%100000)+100000)%100000 as hash_bucket
    from public.tournament_entries te
    join public.players p on p.id=te.player_id
    where te.competition_id=p_competition_id
      and te.entry_status='active'
      and te.draw_type in ('qualification','main_draw')
      and p.world=v_world
      and p.player_type='ai'
      and p.moderation_status<>'rejected'
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
  ),
  ranked as (
    select
      pool.*,
      row_number() over(
        partition by draw_type
        order by hash_bucket,ranking_position desc,id
      ) rn,
      count(*) over(partition by draw_type) cnt
    from pool
  ),
  selected as (
    select *
    from ranked
    where
      (draw_type='qualification' and rn<=ceil(cnt*0.40)::integer)
      or
      (draw_type='main_draw' and rn<=floor(cnt*0.15)::integer)
    order by
      case when draw_type='qualification' then 0 else 1 end,
      rn
    limit greatest(0,coalesce(v_draw_size,16)*2)
  )
  insert into public.tournament_doubles_partner_listings(
    competition_id,player_id,owner_user_id,status,created_at,updated_at,closed_at
  )
  select p_competition_id,id,null,'active',now(),now(),null
  from selected
  on conflict(competition_id,player_id) do update
  set owner_user_id=null,
      status=case
        when public.tournament_doubles_partner_listings.status='matched'
          then public.tournament_doubles_partner_listings.status
        else 'active'
      end,
      updated_at=now(),
      closed_at=case
        when public.tournament_doubles_partner_listings.status='matched'
          then public.tournament_doubles_partner_listings.closed_at
        else null
      end;

  get diagnostics v_inserted=row_count;
  return v_inserted;
end;
$$;

revoke all on function public.seed_ai_doubles_partner_marketplace_v1(uuid)
from public,anon,authenticated;
grant execute on function public.seed_ai_doubles_partner_marketplace_v1(uuid)
to service_role;

-- Rebalance current automatic AI listings to the exact 40% qualification /
-- 15% main-draw quotas. Preserve pending invitations and all human listings.
with candidate_pool as (
  select
    te.competition_id,
    te.player_id,
    te.draw_type,
    ((hashtextextended(te.player_id::text||':'||te.competition_id::text,0)%100000)+100000)%100000 as hash_bucket,
    coalesce(te.ranking_position_snapshot,999999) ranking_position
  from public.tournament_entries te
  join public.players p on p.id=te.player_id
  where te.entry_status='active'
    and te.draw_type in ('qualification','main_draw')
    and p.player_type='ai'
),
ranked as (
  select cp.*,
    row_number() over(
      partition by competition_id,draw_type
      order by hash_bucket,ranking_position desc,player_id
    ) rn,
    count(*) over(partition by competition_id,draw_type) cnt
  from candidate_pool cp
),
selected as (
  select competition_id,player_id
  from ranked
  where
    (draw_type='qualification' and rn<=ceil(cnt*0.40)::integer)
    or
    (draw_type='main_draw' and rn<=floor(cnt*0.15)::integer)
)
update public.tournament_doubles_partner_listings l
set status='expired',closed_at=now(),updated_at=now()
where l.status='active'
  and l.owner_user_id is null
  and not exists(
    select 1 from selected s
    where s.competition_id=l.competition_id
      and s.player_id=l.player_id
  )
  and not exists(
    select 1 from public.tournament_doubles_partner_invitations i
    where i.competition_id=l.competition_id
      and i.status='pending'
      and (i.inviter_player_id=l.player_id or i.invitee_player_id=l.player_id)
  );

-- Re-seed all currently open marketplaces after pruning.
select public.seed_ai_doubles_partner_marketplace_v1(wc.id)
from public.tournament_world_competitions wc
join public.tournament_editions ed on ed.id=wc.tournament_edition_id
join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
where ds.is_enabled
  and public.current_game_second_v1()>=(public.get_tournament_doubles_entry_timeline_v1(wc.id)->>'registration_open_game_second')::bigint
  and public.current_game_second_v1()<(public.get_tournament_doubles_entry_timeline_v1(wc.id)->>'partnership_deadline_game_second')::bigint;

