update public.notification_catalog
set is_active=false, updated_at=now()
where code in ('player.health.training_cleared','player.health.competition_cleared');