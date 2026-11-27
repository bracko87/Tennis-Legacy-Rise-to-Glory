-- Disposable review of common scheduling lock and non-admitted inventory.
BEGIN;
DO $guard$ BEGIN IF current_database()<>'ace_review' OR NOT EXISTS(SELECT 1 FROM ace_migration_fixture.guard WHERE marker='ace-disposable-ci-v025') THEN RAISE EXCEPTION 'disposable review required'; END IF; END $guard$;
CREATE SCHEMA ace_shared_schedule_fixture;
CREATE TABLE ace_shared_schedule_fixture.inventory(
 id text PRIMARY KEY, owner text NOT NULL CHECK(owner IN ('ace','legacy','external')),
 status text NOT NULL CHECK(status IN ('scheduled','live','completed')),
 revision bigint NOT NULL DEFAULT 0, venue text NOT NULL, court int NOT NULL CHECK(court>0),
 player1 text NOT NULL, player2 text NOT NULL CHECK(player2<>player1),
 start_second bigint NOT NULL CHECK(start_second>=0), duration_minutes int NOT NULL CHECK(duration_minutes BETWEEN 60 AND 420));
CREATE FUNCTION ace_shared_schedule_fixture.change_slot(p_id text,p_revision bigint,p_start bigint,p_court int,p_start_live boolean) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_shared_schedule_fixture AS $fn$
DECLARE m ace_shared_schedule_fixture.inventory%ROWTYPE; actor text;
BEGIN
 -- Lock precedes all inventory row locks. Both engine roles use this same authority.
 PERFORM pg_advisory_xact_lock(91029001);
 actor:=CASE session_user WHEN 'ace_cutover_ace' THEN 'ace' WHEN 'ace_cutover_legacy' THEN 'legacy' ELSE NULL END;
 SELECT * INTO STRICT m FROM ace_shared_schedule_fixture.inventory WHERE id=p_id FOR UPDATE;
 IF actor IS NULL OR actor<>m.owner THEN RAISE EXCEPTION 'wrong scheduling owner'; END IF;
 IF m.status<>'scheduled' OR m.revision<>p_revision OR p_revision IS NULL OR p_start IS NULL OR p_start<0 OR p_court IS NULL OR p_court<1 OR p_start_live IS NULL THEN RAISE EXCEPTION 'invalid schedule revision'; END IF;
 IF p_start_live AND (p_start<>m.start_second OR p_court<>m.court) THEN RAISE EXCEPTION 'start must use current slot'; END IF;
 IF EXISTS(SELECT 1 FROM ace_shared_schedule_fixture.inventory x WHERE x.id<>m.id AND (
 (x.status='live' AND p_start_live AND ((x.venue=m.venue AND x.court=p_court) OR x.player1 IN (m.player1,m.player2) OR x.player2 IN (m.player1,m.player2))) OR
 (x.status IN ('scheduled','live','completed') AND (
 (x.venue=m.venue AND x.court=p_court AND p_start<x.start_second+(x.duration_minutes+15)*60 AND x.start_second<p_start+(m.duration_minutes+15)*60) OR
 ((x.player1 IN (m.player1,m.player2) OR x.player2 IN (m.player1,m.player2)) AND p_start<x.start_second+(x.duration_minutes+60)*60 AND x.start_second<p_start+(m.duration_minutes+60)*60)))))
 THEN RAISE EXCEPTION 'shared resource conflict'; END IF;
 UPDATE ace_shared_schedule_fixture.inventory SET start_second=p_start,court=p_court,status=CASE WHEN p_start_live THEN 'live' ELSE status END,revision=revision+1 WHERE id=p_id;
 RETURN CASE WHEN p_start_live THEN 'started_review' ELSE 'rescheduled_review' END;
END $fn$;
REVOKE ALL ON SCHEMA ace_shared_schedule_fixture FROM PUBLIC;
REVOKE ALL ON FUNCTION ace_shared_schedule_fixture.change_slot(text,bigint,bigint,int,boolean) FROM PUBLIC;
GRANT USAGE ON SCHEMA ace_shared_schedule_fixture TO ace_cutover_ace,ace_cutover_legacy;
GRANT EXECUTE ON FUNCTION ace_shared_schedule_fixture.change_slot(text,bigint,bigint,int,boolean) TO ace_cutover_ace,ace_cutover_legacy;
INSERT INTO ace_shared_schedule_fixture.inventory VALUES
 ('a','ace','scheduled',0,'venue',1,'p1','p2',36000,60),
 ('l','legacy','scheduled',0,'venue',2,'p3','p4',36000,60),
 ('e','external','scheduled',0,'venue',3,'p1','p5',54000,60);
COMMIT;
