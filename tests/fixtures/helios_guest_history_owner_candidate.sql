-- NONDEPLOYABLE CANDIDATE. Load in isolated integration tests only.
-- The original players_owner_by_type_check in production prohibits NULL
-- owner_user_id for *every* human player. Permit only the explicit historical
-- erasure shape; retain the normal human/AI invariant for all other players.
ALTER TABLE public.players ADD COLUMN guest_history_erased_at timestamptz;
ALTER TABLE public.players DROP CONSTRAINT players_owner_by_type_check;
ALTER TABLE public.players ADD CONSTRAINT players_owner_by_type_check CHECK (
 (player_type='human' AND owner_user_id IS NOT NULL AND guest_history_erased_at IS NULL)
 OR (player_type='ai' AND owner_user_id IS NULL AND guest_history_erased_at IS NULL)
 OR (player_type='human' AND owner_user_id IS NULL AND guest_history_erased_at IS NOT NULL
     AND moderation_status='rejected' AND first_name='Retired' AND last_name='Guest'
     AND image_path IS NULL AND home_city IS NULL)
);
CREATE FUNCTION control_center_private.guard_helios_guest_history_identity_candidate()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'pg_catalog','pg_temp'
AS $guard$
BEGIN
 IF TG_OP='INSERT' THEN
   IF NEW.guest_history_erased_at IS NOT NULL THEN
     RAISE EXCEPTION 'Historical guest markers are server generated' USING errcode='42501';
   END IF;
   RETURN NEW;
 END IF;
 IF OLD.guest_history_erased_at IS NOT NULL THEN
   IF NEW.guest_history_erased_at IS DISTINCT FROM OLD.guest_history_erased_at
      OR NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id
      OR NEW.first_name IS DISTINCT FROM OLD.first_name
      OR NEW.last_name IS DISTINCT FROM OLD.last_name
      OR NEW.country_code IS DISTINCT FROM OLD.country_code
      OR NEW.world IS DISTINCT FROM OLD.world
      OR NEW.player_type IS DISTINCT FROM OLD.player_type
      OR NEW.image_path IS DISTINCT FROM OLD.image_path
      OR NEW.home_city IS DISTINCT FROM OLD.home_city
      OR NEW.moderation_status IS DISTINCT FROM OLD.moderation_status
   THEN RAISE EXCEPTION 'Erased historical identity cannot be reassigned or reactivated' USING errcode='42501'; END IF;
   RETURN NEW;
 END IF;
 IF NEW.guest_history_erased_at IS NOT NULL THEN
   -- Neither a signed-in user nor a user-invoked SECURITY DEFINER RPC may
   -- manufacture an erased identity. Server-only migration/worker context.
   IF current_user <> 'postgres' OR auth.uid() IS NOT NULL THEN
     RAISE EXCEPTION 'Historical erasure requires a private server context' USING errcode='42501';
   END IF;
   IF OLD.owner_user_id IS NULL OR OLD.player_type<>'human'
      OR OLD.moderation_status<>'rejected'
      OR NOT EXISTS(
        SELECT 1 FROM auth.users u
        JOIN control_center_private.tennis_guest_trials_v1 g ON g.user_id=u.id
        WHERE u.id=OLD.owner_user_id AND u.is_anonymous
          AND g.retired_at IS NOT NULL AND g.expires_at<=now() AND g.converted_at IS NULL
      )
   THEN RAISE EXCEPTION 'Only a retired, unconverted guest can become a history-only identity' USING errcode='42501'; END IF;
 END IF;
 RETURN NEW;
END;
$guard$;
REVOKE ALL ON FUNCTION control_center_private.guard_helios_guest_history_identity_candidate() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER aa_guard_helios_guest_history_identity_candidate
BEFORE INSERT OR UPDATE ON public.players FOR EACH ROW
EXECUTE FUNCTION control_center_private.guard_helios_guest_history_identity_candidate();
