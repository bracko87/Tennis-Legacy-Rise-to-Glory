create or replace function public.build_starting_nine_skill_profile_v1(p_surface text, p_style text, p_total integer, p_rotation integer default 0)
returns jsonb
language plpgsql
immutable
set search_path='public'
as $$
declare
  v integer[] := array[50,50,50,50,50,50,50,50,50];
  s integer[] := array[0,0,0,0,0,0,0,0,0];
  i integer; j integer; idx integer; v_sum integer:=0; v_residual integer;
begin
  if p_total not between 300 and 480 then raise exception 'Starting technical total out of range.'; end if;
  if p_surface='Hard' then v:=array[51,52,51,52,48,48,48,50,50];
  elsif p_surface='Clay' then v:=array[47,53,52,53,47,49,49,53,47];
  elsif p_surface='Grass' then v:=array[54,50,48,47,54,52,45,46,54]; end if;
  if p_style='Aggressive Baseliner' then
    v[1]:=v[1]+1; v[2]:=v[2]+3; v[3]:=v[3]+1; v[5]:=v[5]-2; v[6]:=v[6]-1; v[7]:=v[7]-2; v[8]:=v[8]-1; v[9]:=v[9]+1;
  elsif p_style='Defensive Baseliner' then
    v[1]:=v[1]-2; v[2]:=v[2]+1; v[3]:=v[3]+2; v[4]:=v[4]+3; v[5]:=v[5]-2; v[6]:=v[6]-1; v[7]:=v[7]-1; v[8]:=v[8]+2; v[9]:=v[9]-2;
  elsif p_style='Serve & Volley' then
    v[1]:=v[1]+3; v[2]:=v[2]-1; v[3]:=v[3]-2; v[4]:=v[4]-2; v[5]:=v[5]+4; v[6]:=v[6]+1; v[7]:=v[7]-3; v[8]:=v[8]-2; v[9]:=v[9]+2;
  end if;
  for i in 1..9 loop s[i]:=floor(v[i]::numeric*p_total::numeric/450.0)::integer; v_sum:=v_sum+s[i]; end loop;
  v_residual:=p_total-v_sum;
  if v_residual>0 then for j in 1..v_residual loop idx:=mod(coalesce(p_rotation,0)+j-1,9)+1; s[idx]:=s[idx]+1; end loop; end if;
  return jsonb_build_object('serve',s[1],'forehand',s[2],'backhand',s[3],'return_skill',s[4],'volley',s[5],'slice',s[6],'drop_shot',s[7],'lob',s[8],'smash',s[9]);
end;
$$;

create or replace function public.build_starting_physical_profile_v1(p_style text, p_total integer, p_rotation integer default 0)
returns jsonb
language plpgsql
immutable
set search_path='public'
as $$
declare v integer[]:=array[0,0,0,0]; base integer; rem integer; i integer; idx integer;
begin
  if p_total not between 160 and 212 then raise exception 'Starting physical total out of range.'; end if;
  base:=floor(p_total::numeric/4)::integer; v:=array[base,base,base,base]; rem:=p_total-base*4;
  if rem>0 then for i in 1..rem loop idx:=mod(coalesce(p_rotation,0)+i-1,4)+1; v[idx]:=v[idx]+1; end loop; end if;
  if p_style='Aggressive Baseliner' then v[1]:=v[1]+2; v[4]:=v[4]+1; v[2]:=v[2]-1; v[3]:=v[3]-2;
  elsif p_style='Defensive Baseliner' then v[2]:=v[2]+2; v[3]:=v[3]+2; v[1]:=v[1]-2; v[4]:=v[4]-2;
  elsif p_style='Serve & Volley' then v[4]:=v[4]+2; v[1]:=v[1]+1; v[2]:=v[2]-1; v[3]:=v[3]-2; end if;
  return jsonb_build_object('fitness',v[1],'stamina',v[2],'recovery',v[3],'movement',v[4]);
end;
$$;

alter table public.players add column if not exists ai_skill_tier text;
alter table public.players drop constraint if exists players_ai_skill_tier_check;
alter table public.players add constraint players_ai_skill_tier_check check ((player_type='human' and ai_skill_tier is null) or (player_type='ai' and ai_skill_tier in ('elite','human_equivalent','competitive','standard')));
alter table public.players drop constraint if exists players_ai_profile_number_check;
alter table public.players add constraint players_ai_profile_number_check check (((player_type='human') and ai_profile_number is null and ai_starting_technical_total is null and ai_starting_physical_total is null) or ((player_type='ai') and ai_profile_number between 1 and 300 and ai_starting_technical_total between 350 and 480 and ai_starting_physical_total between 176 and 212));

create or replace function public.assign_ai_skill_tier_defaults_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $$
begin
  if new.player_type='ai' then
    if new.ai_profile_number between 1 and 12 then new.ai_skill_tier:='elite'; new.ai_starting_technical_total:=468; new.ai_starting_physical_total:=208;
    elsif new.ai_profile_number between 13 and 24 then new.ai_skill_tier:='human_equivalent'; new.ai_starting_technical_total:=450; new.ai_starting_physical_total:=200;
    elsif new.ai_profile_number between 25 and 36 then new.ai_skill_tier:='competitive'; new.ai_starting_technical_total:=423; new.ai_starting_physical_total:=196;
    else new.ai_skill_tier:='standard'; end if;
  else new.ai_skill_tier:=null; end if;
  return new;
end;
$$;
revoke all on function public.assign_ai_skill_tier_defaults_v1() from public,anon,authenticated;
drop trigger if exists assign_ai_skill_tier_defaults_v1 on public.players;
create trigger assign_ai_skill_tier_defaults_v1 before insert or update of player_type,world,ai_profile_number on public.players for each row execute function public.assign_ai_skill_tier_defaults_v1();

do $$
declare r record; old_t jsonb; new_t jsonb; old_p jsonb; new_p jsonb; target_tech integer; target_phys integer; target_tier text;
begin
  for r in select p.* from public.players p where p.player_type='ai' order by p.world,p.ai_profile_number,p.id loop
    if r.ai_profile_number between 1 and 12 then target_tier:='elite'; target_tech:=468; target_phys:=208;
    elsif r.ai_profile_number between 13 and 24 then target_tier:='human_equivalent'; target_tech:=450; target_phys:=200;
    elsif r.ai_profile_number between 25 and 36 then target_tier:='competitive'; target_tech:=423; target_phys:=196;
    else update public.players set ai_skill_tier='standard' where id=r.id; continue; end if;

    old_t:=public.build_starting_nine_skill_profile_v1(coalesce(r.preferred_surface,'Hard'),coalesce(r.playing_style,'All-court'),r.ai_starting_technical_total,coalesce(r.ai_profile_number,0));
    new_t:=public.build_starting_nine_skill_profile_v1(coalesce(r.preferred_surface,'Hard'),coalesce(r.playing_style,'All-court'),target_tech,coalesce(r.ai_profile_number,0));
    old_p:=public.build_starting_physical_profile_v1(coalesce(r.playing_style,'All-court'),r.ai_starting_physical_total,coalesce(r.ai_profile_number,0));
    new_p:=public.build_starting_physical_profile_v1(coalesce(r.playing_style,'All-court'),target_phys,coalesce(r.ai_profile_number,0));

    update public.player_skills s set
      serve=least(100,greatest(1,s.serve+((new_t->>'serve')::integer-(old_t->>'serve')::integer)))::smallint,
      forehand=least(100,greatest(1,s.forehand+((new_t->>'forehand')::integer-(old_t->>'forehand')::integer)))::smallint,
      backhand=least(100,greatest(1,s.backhand+((new_t->>'backhand')::integer-(old_t->>'backhand')::integer)))::smallint,
      return_skill=least(100,greatest(1,s.return_skill+((new_t->>'return_skill')::integer-(old_t->>'return_skill')::integer)))::smallint,
      volley=least(100,greatest(1,s.volley+((new_t->>'volley')::integer-(old_t->>'volley')::integer)))::smallint,
      slice=least(100,greatest(1,s.slice+((new_t->>'slice')::integer-(old_t->>'slice')::integer)))::smallint,
      drop_shot=least(100,greatest(1,s.drop_shot+((new_t->>'drop_shot')::integer-(old_t->>'drop_shot')::integer)))::smallint,
      lob=least(100,greatest(1,s.lob+((new_t->>'lob')::integer-(old_t->>'lob')::integer)))::smallint,
      smash=least(100,greatest(1,s.smash+((new_t->>'smash')::integer-(old_t->>'smash')::integer)))::smallint,
      fitness=least(100,greatest(1,s.fitness+((new_p->>'fitness')::integer-(old_p->>'fitness')::integer)))::smallint,
      stamina=least(100,greatest(1,s.stamina+((new_p->>'stamina')::integer-(old_p->>'stamina')::integer)))::smallint,
      recovery=least(100,greatest(1,s.recovery+((new_p->>'recovery')::integer-(old_p->>'recovery')::integer)))::smallint,
      movement=least(100,greatest(1,s.movement+((new_p->>'movement')::integer-(old_p->>'movement')::integer)))::smallint,
      updated_at=now()
    where s.player_id=r.id;

    update public.players set ai_skill_tier=target_tier,ai_starting_technical_total=target_tech,ai_starting_physical_total=target_phys where id=r.id;
  end loop;
end $$;
