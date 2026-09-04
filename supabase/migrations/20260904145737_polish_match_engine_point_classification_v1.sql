alter function public.simulate_tournament_match_v1(uuid,text) rename to simulate_tournament_match_raw_v1;
revoke all on function public.simulate_tournament_match_raw_v1(uuid,text) from public,anon,authenticated;

create or replace function public.simulate_tournament_match_v1(p_match_id uuid,p_seed_override text default null)
returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare
  j jsonb;ev jsonb;events jsonb:='[]'::jsonb;idx integer:=0;r double precision;
  p1_name text;p2_name text;w1 integer:=0;w2 integer:=0;desc_text text;seed text;
  st1 jsonb;st2 jsonb;
begin
  j:=public.simulate_tournament_match_raw_v1(p_match_id,p_seed_override);
  seed:=j->>'engine_seed';
  p1_name:=j->'metadata'->'profile_snapshot'->'player1'->>'name';
  p2_name:=j->'metadata'->'profile_snapshot'->'player2'->>'name';
  for ev in select value from jsonb_array_elements(j->'events') loop
    idx:=idx+1;desc_text:=coalesce(ev->>'description','');
    if ev->>'kind'='point' and desc_text like '% winner' then
      r:=public.match_engine_random_v1(seed||':classification',idx);
      if r<0.36 then
        if left(desc_text,length(p1_name))=p1_name then w1:=w1+1;elsif left(desc_text,length(p2_name))=p2_name then w2:=w2+1;end if;
      else
        ev:=jsonb_set(ev,'{description}',to_jsonb('Rally ends with a forced error'::text));
      end if;
    end if;
    events:=events||jsonb_build_array(ev);
  end loop;
  st1:=jsonb_set(j->'player1_stats','{winners}',to_jsonb(w1));
  st2:=jsonb_set(j->'player2_stats','{winners}',to_jsonb(w2));
  return j||jsonb_build_object('engine_version','base-v1.1','events',events,'player1_stats',st1,'player2_stats',st2,'metadata',(j->'metadata')||jsonb_build_object('point_classification','winner / unforced error / forced error v1'));
end;$$;
revoke all on function public.simulate_tournament_match_v1(uuid,text) from public,anon,authenticated;