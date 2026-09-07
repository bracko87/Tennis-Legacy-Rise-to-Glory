create or replace function public.build_human_starting_nine_skill_profile_v2(
  p_surface text,
  p_style text,
  p_seed text
)
returns jsonb
language plpgsql
immutable
set search_path to 'public'
as $function$
declare
  v integer[];
  s integer[] := array[0,0,0,0,0,0,0,0,0];
  i integer;
  idx integer;
  v_noise integer;
  v_target integer;
  v_sum integer := 0;
  v_residual integer;
  v_rotation integer;
  v_guard integer := 0;
  v_seed text := coalesce(p_seed,'human-player');
begin
  if p_surface='Clay' then
    v:=array[48,59,57,60,42,48,47,51,38];
  elsif p_surface='Grass' then
    v:=array[62,52,48,46,57,54,38,38,55];
  else
    v:=array[56,58,55,57,46,45,42,43,48];
  end if;

  if p_style='Aggressive Baseliner' then
    v[1]:=v[1]+1; v[2]:=v[2]+4; v[3]:=v[3]+2; v[4]:=v[4]+1;
    v[5]:=v[5]-2; v[6]:=v[6]-1; v[7]:=v[7]-2; v[8]:=v[8]-2; v[9]:=v[9]-1;
  elsif p_style='Defensive Baseliner' then
    v[1]:=v[1]-3; v[2]:=v[2]+1; v[3]:=v[3]+3; v[4]:=v[4]+4;
    v[5]:=v[5]-3; v[6]:=v[6]+1; v[7]:=v[7]+0; v[8]:=v[8]+2; v[9]:=v[9]-5;
  elsif p_style='Serve & Volley' then
    v[1]:=v[1]+5; v[2]:=v[2]-3; v[3]:=v[3]-4; v[4]:=v[4]-4;
    v[5]:=v[5]+6; v[6]:=v[6]+3; v[7]:=v[7]-3; v[8]:=v[8]-3; v[9]:=v[9]+3;
  end if;

  for i in 1..9 loop
    v_noise := (get_byte(decode(md5(v_seed||':skill:'||i::text),'hex'),0) % 7) - 3;
    s[i] := greatest(35,least(68,v[i]+v_noise));
    v_sum := v_sum+s[i];
  end loop;

  v_target := 440 + (get_byte(decode(md5(v_seed||':total'),'hex'),0) % 16);
  v_residual := v_target-v_sum;
  v_rotation := get_byte(decode(md5(v_seed||':rotation'),'hex'),0) % 9;

  while v_residual<>0 and v_guard<500 loop
    idx:=mod(v_rotation+v_guard,9)+1;
    if v_residual>0 and s[idx]<68 then
      s[idx]:=s[idx]+1;
      v_residual:=v_residual-1;
    elsif v_residual<0 and s[idx]>35 then
      s[idx]:=s[idx]-1;
      v_residual:=v_residual+1;
    end if;
    v_guard:=v_guard+1;
  end loop;

  return jsonb_build_object(
    'serve',s[1],
    'forehand',s[2],
    'backhand',s[3],
    'return_skill',s[4],
    'volley',s[5],
    'slice',s[6],
    'drop_shot',s[7],
    'lob',s[8],
    'smash',s[9],
    'technical_total',s[1]+s[2]+s[3]+s[4]+s[5]+s[6]+s[7]+s[8]+s[9]
  );
end;
$function$;

create or replace function public.initialize_player_skills_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_surface text:=coalesce(new.preferred_surface,'Hard');
  v_style text:=coalesce(new.playing_style,'All-court');
  v_technical_total integer:=case when new.player_type='ai' then new.ai_starting_technical_total else 450 end;
  v_physical_total integer:=case when new.player_type='ai' then new.ai_starting_physical_total else 200 end;
  t jsonb;
  p jsonb;
begin
  if new.player_type='ai' then
    t:=public.build_starting_nine_skill_profile_v1(v_surface,v_style,v_technical_total,coalesce(new.ai_profile_number,0));
  else
    t:=public.build_human_starting_nine_skill_profile_v2(v_surface,v_style,new.id::text);
  end if;

  p:=public.build_starting_physical_profile_v1(v_style,v_physical_total,coalesce(new.ai_profile_number,0));

  insert into public.player_skills(
    player_id,preferred_surface,playing_style,
    serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,
    fitness,stamina,recovery,movement,fatigue,sharpness,morale,confidence,focus
  ) values(
    new.id,v_surface,v_style,
    (t->>'serve')::smallint,(t->>'forehand')::smallint,(t->>'backhand')::smallint,(t->>'return_skill')::smallint,
    (t->>'volley')::smallint,(t->>'slice')::smallint,(t->>'drop_shot')::smallint,(t->>'lob')::smallint,(t->>'smash')::smallint,
    (p->>'fitness')::smallint,(p->>'stamina')::smallint,(p->>'recovery')::smallint,(p->>'movement')::smallint,
    0,50,50,50,50
  ) on conflict(player_id) do nothing;
  return new;
end;
$function$;

create temporary table human_skill_rebalance_map on commit drop as
select
  p.id as player_id,
  (t->>'serve')::integer-coalesce(h.serve,ps.serve)::integer as d_serve,
  (t->>'forehand')::integer-coalesce(h.forehand,ps.forehand)::integer as d_forehand,
  (t->>'backhand')::integer-coalesce(h.backhand,ps.backhand)::integer as d_backhand,
  (t->>'return_skill')::integer-coalesce(h.return_skill,ps.return_skill)::integer as d_return_skill,
  (t->>'volley')::integer-coalesce(h.volley,ps.volley)::integer as d_volley,
  (t->>'slice')::integer-coalesce(h.slice,ps.slice)::integer as d_slice,
  (t->>'drop_shot')::integer-coalesce(h.drop_shot,ps.drop_shot)::integer as d_drop_shot,
  (t->>'lob')::integer-coalesce(h.lob,ps.lob)::integer as d_lob,
  (t->>'smash')::integer-coalesce(h.smash,ps.smash)::integer as d_smash
from public.players p
join public.player_skills ps on ps.player_id=p.id
left join lateral (
  select h0.*
  from public.player_skill_history h0
  where h0.player_id=p.id
  order by h0.recorded_at,h0.id
  limit 1
) h on true
cross join lateral public.build_human_starting_nine_skill_profile_v2(
  coalesce(p.preferred_surface,ps.preferred_surface,'Hard'),
  coalesce(p.playing_style,ps.playing_style,'All-court'),
  p.id::text
) t
where p.player_type='human'
  and p.owner_user_id is not null;

update public.player_skill_history h
set
  serve=greatest(0,least(100,h.serve+m.d_serve))::smallint,
  forehand=greatest(0,least(100,h.forehand+m.d_forehand))::smallint,
  backhand=greatest(0,least(100,h.backhand+m.d_backhand))::smallint,
  return_skill=greatest(0,least(100,h.return_skill+m.d_return_skill))::smallint,
  volley=greatest(0,least(100,h.volley+m.d_volley))::smallint,
  slice=greatest(0,least(100,h.slice+m.d_slice))::smallint,
  drop_shot=greatest(0,least(100,h.drop_shot+m.d_drop_shot))::smallint,
  lob=greatest(0,least(100,h.lob+m.d_lob))::smallint,
  smash=greatest(0,least(100,h.smash+m.d_smash))::smallint
from human_skill_rebalance_map m
where h.player_id=m.player_id;

alter table public.player_skills disable trigger player_skill_notifications_after_update;
alter table public.player_skills disable trigger trg_record_player_skill_history;

update public.player_skills ps
set
  serve=greatest(0,least(100,ps.serve+m.d_serve))::smallint,
  forehand=greatest(0,least(100,ps.forehand+m.d_forehand))::smallint,
  backhand=greatest(0,least(100,ps.backhand+m.d_backhand))::smallint,
  return_skill=greatest(0,least(100,ps.return_skill+m.d_return_skill))::smallint,
  volley=greatest(0,least(100,ps.volley+m.d_volley))::smallint,
  slice=greatest(0,least(100,ps.slice+m.d_slice))::smallint,
  drop_shot=greatest(0,least(100,ps.drop_shot+m.d_drop_shot))::smallint,
  lob=greatest(0,least(100,ps.lob+m.d_lob))::smallint,
  smash=greatest(0,least(100,ps.smash+m.d_smash))::smallint,
  updated_at=now()
from human_skill_rebalance_map m
where ps.player_id=m.player_id;

alter table public.player_skills enable trigger trg_record_player_skill_history;
alter table public.player_skills enable trigger player_skill_notifications_after_update;

grant execute on function public.build_human_starting_nine_skill_profile_v2(text,text,text) to authenticated;
