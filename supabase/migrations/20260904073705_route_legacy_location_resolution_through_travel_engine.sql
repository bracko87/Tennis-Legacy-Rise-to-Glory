-- Make every legacy travel-planning path resolve locations through the
-- universal city/country travel catalog.

create or replace function public.resolve_location_coordinates_v1(
  p_city text,
  p_country_code text,
  p_latitude double precision default null,
  p_longitude double precision default null
) returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  q jsonb;
begin
  q:=public.resolve_travel_location_v1(
    p_city,p_country_code,p_latitude,p_longitude
  );

  return jsonb_build_object(
    'city',q->>'city',
    'country_code',q->>'country_code',
    'latitude',q->'latitude',
    'longitude',q->'longitude',
    'basis',coalesce(q->>'coordinate_basis','unknown'),
    'hotel_cost_index',q->'hotel_cost_index',
    'cost_tier',q->>'cost_tier',
    'location_id',q->'location_id'
  );
end;
$$;

revoke all on function public.resolve_location_coordinates_v1(
  text,text,double precision,double precision
) from public,anon;

grant execute on function public.resolve_location_coordinates_v1(
  text,text,double precision,double precision
) to authenticated;

-- Rebuild only future unprocessed itineraries; current game time is untouched.
select public.rebuild_player_travel_plan_v1(p.id)
from public.players p
where p.player_type='human' and p.owner_user_id is not null;
