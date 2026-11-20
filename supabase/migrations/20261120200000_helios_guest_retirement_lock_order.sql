-- Acquire auth.users lock before guest-trial lock, consistent with Auth
-- same-identity conversion trigger; avoid conversion/retirement deadlock.
-- Recheck anonymous status with row lock, then atomically retire.
CREATE OR REPLACE FUNCTION control_center_private.retire_expired_tennis_guests_v1(p_max_accounts integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'control_center_private', 'pg_temp'
AS $function$
DECLARE
  g record;
  p record;
  v_count integer:=0;
  v_singles integer:=0;
  v_doubles integer:=0;
  v_apps integer:=0;
  v_steps integer;
  v_changed integer;
  v_total_changed integer;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtextextended('tennis-guest-retirement-v1',0)) THEN
    RETURN jsonb_build_object('status','busy');
  END IF;

  FOR g IN
    SELECT t.user_id,t.expires_at
    FROM control_center_private.tennis_guest_trials_v1 t
    JOIN auth.users u ON u.id=t.user_id
    WHERE t.expires_at<=now()
      AND t.converted_at IS NULL AND t.retired_at IS NULL
      AND u.is_anonymous IS TRUE
    ORDER BY t.expires_at,t.user_id
    LIMIT least(greatest(coalesce(p_max_accounts,20),1),100)
    FOR UPDATE OF u SKIP LOCKED
  LOOP
    -- Recheck the same auth row while it is locked. An identity converted
    -- in time is not retired even when the expiry worker races conversion.
    PERFORM 1 FROM auth.users u
    WHERE u.id=g.user_id AND u.is_anonymous IS TRUE
    FOR UPDATE;
    IF NOT FOUND THEN CONTINUE; END IF;

    FOR p IN
      SELECT id FROM public.players
      WHERE owner_user_id=g.user_id AND player_type='human'
      ORDER BY id
    LOOP
      -- An opponent with a playable, scheduled (never started) singles
      -- match wins by walkover. Both unavailable participants means cancel,
      -- not a fabricated winner. The existing bracket trigger advances
      -- a walkover winner to the next round.
      FOR v_steps IN 1..12 LOOP
        UPDATE public.tournament_matches m
        SET status=CASE WHEN m.player1_id=p.id AND m.player2_id IS NOT NULL
                         AND NOT EXISTS(
                           SELECT 1 FROM public.players op
                           JOIN auth.users u ON u.id=op.owner_user_id
                           JOIN control_center_private.tennis_guest_trials_v1 t ON t.user_id=u.id
                           WHERE op.id=m.player2_id AND u.is_anonymous
                             AND t.expires_at<=now()
                         ) THEN 'walkover'
                        WHEN m.player2_id=p.id AND m.player1_id IS NOT NULL
                         AND NOT EXISTS(
                           SELECT 1 FROM public.players op
                           JOIN auth.users u ON u.id=op.owner_user_id
                           JOIN control_center_private.tennis_guest_trials_v1 t ON t.user_id=u.id
                           WHERE op.id=m.player1_id AND u.is_anonymous
                             AND t.expires_at<=now()
                         ) THEN 'walkover'
                        ELSE 'cancelled' END,
            winner_id=CASE
              WHEN m.player1_id=p.id AND m.player2_id IS NOT NULL
               AND NOT EXISTS(
                 SELECT 1 FROM public.players op
                 JOIN auth.users u ON u.id=op.owner_user_id
                 JOIN control_center_private.tennis_guest_trials_v1 t ON t.user_id=u.id
                 WHERE op.id=m.player2_id AND u.is_anonymous AND t.expires_at<=now()
               ) THEN m.player2_id
              WHEN m.player2_id=p.id AND m.player1_id IS NOT NULL
               AND NOT EXISTS(
                 SELECT 1 FROM public.players op
                 JOIN auth.users u ON u.id=op.owner_user_id
                 JOIN control_center_private.tennis_guest_trials_v1 t ON t.user_id=u.id
                 WHERE op.id=m.player1_id AND u.is_anonymous AND t.expires_at<=now()
               ) THEN m.player1_id
              ELSE NULL END,
            completion_reason='guest_trial_expired',
            completed_at=now(),
            updated_at=now()
        WHERE m.status='scheduled'
          AND m.started_at IS NULL
          AND (m.player1_id=p.id OR m.player2_id=p.id)
          AND NOT EXISTS(
            SELECT 1 FROM public.tournament_match_simulations sim WHERE sim.match_id=m.id
          );
        GET DIAGNOSTICS v_changed=ROW_COUNT;
        v_singles:=v_singles+v_changed;
        EXIT WHEN v_changed=0;
      END LOOP;

      -- Doubles: a team containing the departing guest withdraws.
      UPDATE public.tournament_doubles_teams t
        SET status='withdrawn',withdrawn_at=coalesce(withdrawn_at,now()),updated_at=now()
      WHERE p.id IN(t.player1_id,t.player2_id)
        AND t.status IN('active','confirmed','alternate');

      FOR v_steps IN 1..12 LOOP
        UPDATE public.tournament_doubles_matches m
        SET status=CASE WHEN m.team1_id IN(
                      SELECT t.id FROM public.tournament_doubles_teams t
                      WHERE p.id IN(t.player1_id,t.player2_id))
                      AND m.team2_id IS NOT NULL
                      AND control_center_private.tennis_doubles_team_available_v1(m.team2_id)
                      THEN 'walkover'
                    WHEN m.team2_id IN(
                      SELECT t.id FROM public.tournament_doubles_teams t
                      WHERE p.id IN(t.player1_id,t.player2_id))
                      AND m.team1_id IS NOT NULL
                      AND control_center_private.tennis_doubles_team_available_v1(m.team1_id)
                      THEN 'walkover'
                    ELSE 'cancelled' END,
            winner_team_id=CASE
                    WHEN m.team1_id IN(
                      SELECT t.id FROM public.tournament_doubles_teams t
                      WHERE p.id IN(t.player1_id,t.player2_id))
                      AND m.team2_id IS NOT NULL
                      AND control_center_private.tennis_doubles_team_available_v1(m.team2_id)
                      THEN m.team2_id
                    WHEN m.team2_id IN(
                      SELECT t.id FROM public.tournament_doubles_teams t
                      WHERE p.id IN(t.player1_id,t.player2_id))
                      AND m.team1_id IS NOT NULL
                      AND control_center_private.tennis_doubles_team_available_v1(m.team1_id)
                      THEN m.team1_id
                    ELSE NULL END,
            completion_reason='guest_trial_expired',
            completed_at=now(),updated_at=now()
        WHERE m.status='scheduled' AND m.started_at IS NULL
          AND (m.team1_id IN(
            SELECT t.id FROM public.tournament_doubles_teams t
            WHERE p.id IN(t.player1_id,t.player2_id)
          ) OR m.team2_id IN(
            SELECT t.id FROM public.tournament_doubles_teams t
            WHERE p.id IN(t.player1_id,t.player2_id)
          ));
        GET DIAGNOSTICS v_changed=ROW_COUNT;
        v_doubles:=v_doubles+v_changed;
        EXIT WHEN v_changed=0;
      END LOOP;

      UPDATE public.tournament_applications a
      SET status='withdrawn',decision_reason='guest_trial_expired',
          decided_at=now(),updated_at=now()
      WHERE a.player_id=p.id AND a.status IN('applied','accepted_main_draw','accepted_qualification');
      GET DIAGNOSTICS v_changed=ROW_COUNT;
      v_apps:=v_apps+v_changed;

      UPDATE public.tournament_entries
      SET entry_status='withdrawn',updated_at=now()
      WHERE player_id=p.id AND entry_status='active';

      -- Existing official ranking queries hide moderation_status=rejected.
      -- This is a technical retirement marker, not a disciplinary judgment.
      UPDATE public.players
      SET moderation_status='rejected',updated_at=now()
      WHERE id=p.id AND moderation_status<>'rejected';
    END LOOP;

    UPDATE control_center_private.tennis_guest_trials_v1
    SET retired_at=now(),retirement_reason='unconverted_14_day_expiry'
    WHERE user_id=g.user_id AND retired_at IS NULL;
    v_count:=v_count+1;
  END LOOP;

  RETURN jsonb_build_object('status','processed','retired_guests',v_count,
    'singles_matches_resolved',v_singles,'doubles_matches_resolved',v_doubles,
    'applications_withdrawn',v_apps);
END;
$function$
;
