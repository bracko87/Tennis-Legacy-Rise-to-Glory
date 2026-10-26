-- Local-only stand-ins for legacy definer travel wrappers; the two
-- travel writer functions are already loaded from the ACTUAL new migration.
create or replace function public.rebuild_player_travel_plan_core_v1(p_player_id uuid)
returns jsonb language sql security definer as $$select '{}'::jsonb$$;
create or replace function public.resolve_player_origin_before_day_v1(p_player_id uuid,p_target_absolute_day integer)
returns jsonb language sql security definer as $$select '{}'::jsonb$$;
create or replace function public.rebuild_player_travel_plan_v1(p_player_id uuid)
returns jsonb language sql security definer as $$select '{}'::jsonb$$;
create or replace function public.apply_training_camp_split_travel_v1(p_player_id uuid)
returns jsonb language sql security definer as $$select '{}'::jsonb$$;
create or replace function public.process_due_travel_legs_v1(p_player_id uuid,p_through_absolute_day integer)
returns jsonb language sql security definer as $$select '{}'::jsonb$$;
