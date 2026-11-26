-- Disposable review only. Install after cutover-settlement-review.sql.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.medical_snapshots (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.matches(id),
 absolute_day integer NOT NULL CHECK(absolute_day>=0),
 player1_records jsonb NOT NULL,
 player2_records jsonb NOT NULL,
 return1 integer, return2 integer,
 receipt jsonb
);
GRANT SELECT ON ace_cutover_review.medical_snapshots TO ace_review_worker;
CREATE FUNCTION ace_cutover_review.blocked_return(p_records jsonb,p_day integer) RETURNS integer
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
DECLARE x jsonb; ret integer; full_day integer; earliest integer;
BEGIN
 IF p_day IS NULL OR p_day<0 OR jsonb_typeof(p_records) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'invalid health snapshot'; END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(p_records) LOOP
  IF jsonb_typeof(x) IS DISTINCT FROM 'object' OR x->>'status' IS NULL OR x->>'status' NOT IN ('active','recovering','recovered') OR jsonb_typeof(x->'tournamentReturnDay') IS DISTINCT FROM 'number' OR jsonb_typeof(x->'fullRecoveryDay') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'invalid health record'; END IF;
  ret:=(x->>'tournamentReturnDay')::integer;full_day:=(x->>'fullRecoveryDay')::integer;
  IF ret<0 OR full_day<ret OR (x->>'status'='recovered' AND full_day>p_day) THEN RAISE EXCEPTION 'invalid health dates'; END IF;
  IF x->>'status'<>'recovered' AND p_day<ret THEN earliest:=least(earliest,ret); END IF;
 END LOOP;
 RETURN earliest;
END $$;
-- Trusted review controller freezes supplied records; this is not an authoritative production health query.
CREATE FUNCTION ace_cutover_review.freeze_medical(p_id text,p_day integer,p1 jsonb,p2 jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; h ace_cutover_review.medical_snapshots%ROWTYPE; r1 integer; r2 integer;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=m.competition) THEN RAISE EXCEPTION 'unregistered competition'; END IF;
 r1:=ace_cutover_review.blocked_return(p1,p_day);r2:=ace_cutover_review.blocked_return(p2,p_day);
 SELECT * INTO h FROM ace_cutover_review.medical_snapshots WHERE match_id=p_id;
 IF FOUND THEN
  IF ROW(h.absolute_day,h.player1_records,h.player2_records) IS DISTINCT FROM ROW(p_day,p1,p2) THEN RAISE EXCEPTION 'conflicting medical snapshot'; END IF;
  RETURN 'already_frozen';
 END IF;
 IF m.status<>'scheduled' OR m.started OR m.owner IS NOT NULL OR m.legacy_simulation<>'none' THEN RAISE EXCEPTION 'freeze before admission'; END IF;
 INSERT INTO ace_cutover_review.medical_snapshots(match_id,absolute_day,player1_records,player2_records,return1,return2) VALUES(p_id,p_day,p1,p2,r1,r2);
 RETURN 'frozen';
END $$;
CREATE FUNCTION ace_cutover_review.medical_winner(p_m ace_cutover_review.matches,p_h ace_cutover_review.medical_snapshots) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT CASE WHEN p_h.return1 IS NULL AND p_h.return2 IS NULL THEN NULL
 WHEN p_h.return1 IS NULL THEN p_m.player1 WHEN p_h.return2 IS NULL THEN p_m.player2
 WHEN p_h.return1<=p_h.return2 THEN p_m.player1 ELSE p_m.player2 END
$$;
CREATE FUNCTION ace_cutover_review.finish_medical(p_id text,p_revision bigint,p_receipt jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; h ace_cutover_review.medical_snapshots%ROWTYPE; winner text; blocked jsonb;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF ace_cutover_review.actor() IS DISTINCT FROM 'ace' OR m.owner IS DISTINCT FROM 'ace' THEN RAISE EXCEPTION 'wrong engine'; END IF;
 SELECT * INTO STRICT h FROM ace_cutover_review.medical_snapshots WHERE match_id=p_id FOR UPDATE;
 IF h.receipt IS NOT NULL THEN
  IF h.receipt IS DISTINCT FROM p_receipt THEN RAISE EXCEPTION 'conflicting medical receipt'; END IF;
  RETURN 'already_completed';
 END IF;
 IF m.revision IS DISTINCT FROM p_revision OR m.status<>'scheduled' OR m.started OR m.legacy_simulation<>'none' THEN RAISE EXCEPTION 'invalid medical completion'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.handoffs WHERE match_id=p_id AND resolution IS NULL) THEN RETURN 'handoff_pending'; END IF;
 winner:=ace_cutover_review.medical_winner(m,h);
 IF winner IS NULL THEN RAISE EXCEPTION 'both medically eligible'; END IF;
 blocked:=CASE WHEN h.return1 IS NOT NULL AND h.return2 IS NOT NULL THEN jsonb_build_array(m.player1,m.player2) WHEN h.return1 IS NOT NULL THEN jsonb_build_array(m.player1) ELSE jsonb_build_array(m.player2) END;
 IF p_receipt->>'match_id' IS DISTINCT FROM p_id OR p_receipt->>'competition_id' IS DISTINCT FROM m.competition
 OR p_receipt->>'player1_id' IS DISTINCT FROM m.player1 OR p_receipt->>'player2_id' IS DISTINCT FROM m.player2
 OR p_receipt->>'winner_id' IS DISTINCT FROM winner OR p_receipt->>'status' IS DISTINCT FROM 'completed'
 OR p_receipt->>'completion_reason' IS DISTINCT FROM 'health_walkover' OR p_receipt->>'score' IS DISTINCT FROM 'W/O'
 OR p_receipt->'actual_duration_minutes' IS DISTINCT FROM 'null'::jsonb OR p_receipt->'engine_version' IS DISTINCT FROM 'null'::jsonb
 OR p_receipt->'sets' IS DISTINCT FROM '[]'::jsonb OR p_receipt->'stats' IS DISTINCT FROM '[]'::jsonb
 OR p_receipt->'medical_absolute_day' IS DISTINCT FROM to_jsonb(h.absolute_day)
 OR p_receipt->'medically_unavailable_player_ids' IS DISTINCT FROM blocked
 OR p_receipt->>'completed_at' IS NULL OR p_receipt->>'started_at' IS DISTINCT FROM p_receipt->>'completed_at' THEN RAISE EXCEPTION 'medical receipt mismatch'; END IF;
 PERFORM (p_receipt->>'completed_at')::timestamptz;
 UPDATE ace_cutover_review.medical_snapshots SET receipt=p_receipt WHERE match_id=p_id;
 INSERT INTO ace_cutover_review.effects VALUES(p_id,'ace',winner,p_receipt);
 UPDATE ace_cutover_review.matches SET status='completed',revision=revision+1 WHERE id=p_id;
 RETURN 'completed';
END $$;
-- No generic finish or external resolution may bypass medical validation.
CREATE FUNCTION ace_cutover_review.guard_medical_effect() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE h ace_cutover_review.medical_snapshots%ROWTYPE;
BEGIN
 SELECT * INTO h FROM ace_cutover_review.medical_snapshots WHERE match_id=NEW.match_id;
 IF NEW.receipt->>'completion_reason'='health_walkover' THEN
  IF h.receipt IS DISTINCT FROM NEW.receipt OR NEW.engine<>'ace' THEN RAISE EXCEPTION 'use verified medical completion'; END IF;
 ELSIF h.return1 IS NOT NULL OR h.return2 IS NOT NULL THEN RAISE EXCEPTION 'medical restriction';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cutover_medical_effect BEFORE INSERT ON ace_cutover_review.effects FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_medical_effect();
CREATE FUNCTION ace_cutover_review.guard_medical_status() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE h ace_cutover_review.medical_snapshots%ROWTYPE;
BEGIN
 IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=NEW.competition) AND NEW.status IN ('walkover','cancelled','bye') THEN RAISE EXCEPTION 'protected external terminal state requires dedicated adapter'; END IF;
 IF NEW.status='in_progress' THEN
  SELECT * INTO h FROM ace_cutover_review.medical_snapshots WHERE match_id=NEW.id;
  IF h.return1 IS NOT NULL OR h.return2 IS NOT NULL THEN RAISE EXCEPTION 'medical restriction'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cutover_medical_status BEFORE UPDATE OF status ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_medical_status();
REVOKE ALL ON FUNCTION ace_cutover_review.blocked_return(jsonb,integer),ace_cutover_review.medical_winner(ace_cutover_review.matches,ace_cutover_review.medical_snapshots),ace_cutover_review.freeze_medical(text,integer,jsonb,jsonb),ace_cutover_review.finish_medical(text,bigint,jsonb),ace_cutover_review.guard_medical_effect(),ace_cutover_review.guard_medical_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.freeze_medical(text,integer,jsonb,jsonb) TO ace_review_worker;
GRANT EXECUTE ON FUNCTION ace_cutover_review.finish_medical(text,bigint,jsonb) TO ace_cutover_ace;
COMMIT;
