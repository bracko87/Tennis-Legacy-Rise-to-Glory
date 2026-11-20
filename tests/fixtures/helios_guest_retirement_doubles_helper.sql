-- Snapshot of exact production DB function for isolated integration tests, 2026-11-20.
CREATE OR REPLACE FUNCTION control_center_private.tennis_doubles_team_available_v1(p_team_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'control_center_private', 'pg_temp'
AS $function$
  SELECT EXISTS(
    SELECT 1 FROM public.tournament_doubles_teams team
    WHERE team.id=p_team_id
      AND team.status<>'withdrawn'
      AND NOT EXISTS(
        SELECT 1 FROM public.players p
        JOIN auth.users u ON u.id=p.owner_user_id
        JOIN control_center_private.tennis_guest_trials_v1 g ON g.user_id=u.id
        WHERE p.id IN(team.player1_id,team.player2_id)
          AND u.is_anonymous AND g.expires_at<=now()
      )
  );
$function$
;
