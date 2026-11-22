-- Preserve the existing disabled-by-default erasure gate and cron schedule.
CREATE OR REPLACE FUNCTION control_center_private.erase_expired_tennis_guests_v1(p_max integer DEFAULT 20)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'pg_catalog','pg_temp'
SET lock_timeout TO '1s'
AS $batch$
DECLARE g record; erased integer:=0; held integer:=0; hold_code text; state text; message text;
BEGIN
 IF current_user<>'postgres' OR auth.uid() IS NOT NULL THEN
   RAISE EXCEPTION 'Private server context required' USING errcode='42501';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM control_center_private.tennis_guest_erasure_control_v1 WHERE singleton_id AND enabled FOR SHARE)
 THEN RETURN jsonb_build_object('status','disabled','erased',0,'held',0); END IF;
 IF NOT pg_try_advisory_xact_lock(hashtextextended('helios-guest-erasure-batch-v1',0)) THEN
   RETURN jsonb_build_object('status','busy','erased',0,'held',0);
 END IF;
 FOR g IN SELECT t.user_id FROM control_center_private.tennis_guest_trials_v1 t
   JOIN auth.users u ON u.id=t.user_id
   WHERE u.is_anonymous AND t.converted_at IS NULL AND t.retired_at IS NOT NULL AND t.expires_at<=now()
   AND (t.erasure_next_attempt_at IS NULL OR t.erasure_next_attempt_at<=now())
   ORDER BY t.erasure_next_attempt_at NULLS FIRST,t.expires_at,t.user_id
   LIMIT least(greatest(coalesce(p_max,20),1),20)
   FOR UPDATE OF u SKIP LOCKED
 LOOP
   -- Lock the trial after its Auth row, before the per-account subtransaction.
   -- Skip contention rather than attempting retry metadata on a locked row.
   PERFORM 1 FROM control_center_private.tennis_guest_trials_v1 t
   WHERE t.user_id=g.user_id AND t.converted_at IS NULL AND t.retired_at IS NOT NULL
     AND t.expires_at<=now()
     AND (t.erasure_next_attempt_at IS NULL OR t.erasure_next_attempt_at<=now())
   FOR UPDATE SKIP LOCKED;
   IF NOT FOUND THEN CONTINUE; END IF;
   BEGIN
     PERFORM control_center_private.erase_retired_tennis_guest_v1(g.user_id);
     erased:=erased+1;
   EXCEPTION WHEN OTHERS THEN
     GET STACKED DIAGNOSTICS state=RETURNED_SQLSTATE,message=MESSAGE_TEXT;
     -- Never record SQLERRM or guest data. Store only a bounded diagnostic code.
     hold_code:=CASE
       WHEN message='Financial records need separate retention review' THEN 'financial'
       WHEN message='Shared governance requires operator review' THEN 'governance'
       WHEN message='Storage or privileged identity requires separate review' THEN 'storage_or_privileged'
       WHEN message='Unfinished competition activity' THEN 'unfinished_match'
       WHEN message LIKE 'Shared or unresolved dependent record:%' OR message LIKE 'Unreviewed identity dependency:%' OR message LIKE 'Unreviewed non-FK identity dependency:%' OR message='Shared staff contract requires review' THEN 'shared_dependency'
       WHEN state IN('55P03','40P01','40001') THEN 'transient_lock'
       ELSE 'unexpected_error' END;
     UPDATE control_center_private.tennis_guest_trials_v1
     SET erasure_attempts=least(erasure_attempts,1000000)+1,
         erasure_last_attempt_at=now(),
         erasure_next_attempt_at=now()+CASE WHEN hold_code IN('unfinished_match','transient_lock') THEN interval '15 minutes' ELSE interval '24 hours' END,
         erasure_hold_code=hold_code
     WHERE user_id=g.user_id AND converted_at IS NULL AND retired_at IS NOT NULL;
     held:=held+1;
   END;
 END LOOP;
 RETURN jsonb_build_object('status','processed','erased',erased,'held',held);
END;
$batch$;
REVOKE ALL ON FUNCTION control_center_private.erase_expired_tennis_guests_v1(integer) FROM PUBLIC,anon,authenticated,service_role;
