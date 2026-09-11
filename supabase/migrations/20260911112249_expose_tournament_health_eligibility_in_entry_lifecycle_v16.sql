alter function public.get_tournament_entry_lifecycle_v2(uuid) rename to get_tournament_entry_lifecycle_base_v2;

create or replace function public.get_tournament_entry_lifecycle_v2(p_competition_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public','pg_temp'
as $$
declare
  j jsonb;
  h jsonb;
  v_eligible boolean;
begin
  j:=public.get_tournament_entry_lifecycle_base_v2(p_competition_id);
  h:=public.get_tournament_entry_health_status_v1(p_competition_id);
  v_eligible:=coalesce((h->>'eligible')::boolean,false);
  j:=jsonb_set(j,'{user,health_entry}',h,true);
  if not v_eligible then
    j:=jsonb_set(j,'{user,can_apply_normal}','false'::jsonb,true);
    j:=jsonb_set(j,'{user,can_apply_late}','false'::jsonb,true);
  end if;
  return j;
end;
$$;

revoke all on function public.get_tournament_entry_lifecycle_v2(uuid) from public;
grant execute on function public.get_tournament_entry_lifecycle_v2(uuid) to authenticated,service_role;
