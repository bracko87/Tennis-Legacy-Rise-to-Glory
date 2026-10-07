-- Make the launch tutorial auto-open only once for genuinely new players.
-- Existing players never receive an automatic tutorial popup.

alter table public.player_tutorial_progress
  add column if not exists auto_launched_at timestamptz;

-- Every player who already existed before this migration is treated as an existing player.
-- Even if an earlier pre-launch build left their tutorial active/paused, do not auto-open it again.
update public.player_tutorial_progress
set
  auto_launched_at = coalesce(auto_launched_at, now()),
  status = case when status in ('active','paused') then 'available' else status end,
  current_step_id = case when status in ('active','paused') then null else current_step_id end,
  updated_at = now()
where auto_launched_at is null;

create or replace function public.initialize_player_tutorial_progress_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if new.player_type='human' and new.owner_user_id is not null then
    insert into public.player_tutorial_progress (
      player_id,
      tutorial_version,
      status,
      current_step_id,
      completed_step_ids,
      locale,
      started_at,
      auto_launched_at,
      updated_at
    )
    values (
      new.id,
      'launch-v1',
      'active',
      'welcome.overview',
      '{}'::text[],
      'en',
      now(),
      null,
      now()
    )
    on conflict (player_id) do nothing;
  end if;
  return new;
end;
$function$;

revoke all on function public.initialize_player_tutorial_progress_v1() from public;
revoke all on function public.initialize_player_tutorial_progress_v1() from anon;
revoke all on function public.initialize_player_tutorial_progress_v1() from authenticated;
