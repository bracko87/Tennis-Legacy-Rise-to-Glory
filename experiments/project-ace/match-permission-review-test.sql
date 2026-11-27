-- Isolated rehearsal only. No production installation.
BEGIN;
DO $guard$
BEGIN
 IF current_database()<>'ace_review' OR NOT EXISTS(SELECT 1 FROM ace_migration_fixture.guard WHERE marker='ace-disposable-ci-v025') THEN RAISE EXCEPTION 'disposable review required'; END IF;
END $guard$;
CREATE SCHEMA ace_permission_fixture;
CREATE TABLE ace_permission_fixture.tournament_matches(id integer PRIMARY KEY);
CREATE TABLE ace_permission_fixture.tournament_match_sets(id integer PRIMARY KEY);
CREATE TABLE ace_permission_fixture.tournament_match_player_stats(id integer PRIMARY KEY);
GRANT USAGE ON SCHEMA ace_permission_fixture TO authenticated,anon,ace_review_worker;
DO $setup$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['tournament_matches','tournament_match_sets','tournament_match_player_stats'] LOOP
 EXECUTE format('ALTER TABLE ace_permission_fixture.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('CREATE POLICY authenticated_read ON ace_permission_fixture.%I FOR SELECT TO authenticated USING (true)',t);
 EXECUTE format('GRANT SELECT,TRUNCATE ON ace_permission_fixture.%I TO authenticated',t);
 EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE,TRUNCATE ON ace_permission_fixture.%I TO ace_review_worker',t);
 EXECUTE format('CREATE POLICY server_access ON ace_permission_fixture.%I FOR ALL TO ace_review_worker USING (true) WITH CHECK (true)',t);
 EXECUTE format('INSERT INTO ace_permission_fixture.%I VALUES(1)',t);
 END LOOP;
END $setup$;
REVOKE TRUNCATE ON ace_permission_fixture.tournament_matches,ace_permission_fixture.tournament_match_sets,ace_permission_fixture.tournament_match_player_stats FROM authenticated;
SET LOCAL ROLE authenticated;
DO $check$
DECLARE t text; n int;
BEGIN
 FOREACH t IN ARRAY ARRAY['tournament_matches','tournament_match_sets','tournament_match_player_stats'] LOOP
 EXECUTE format('SELECT count(*) FROM ace_permission_fixture.%I',t) INTO n;
 IF n<>1 THEN RAISE EXCEPTION 'read regression'; END IF;
 BEGIN
 EXECUTE format('TRUNCATE ace_permission_fixture.%I',t);
 RAISE EXCEPTION 'unexpected truncate access';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 IF has_table_privilege(current_user,'ace_permission_fixture.'||t,'INSERT,UPDATE,DELETE,TRUNCATE') THEN RAISE EXCEPTION 'unexpected write grant'; END IF;
 END LOOP;
END $check$;
RESET ROLE;
SET LOCAL ROLE ace_review_worker;
INSERT INTO ace_permission_fixture.tournament_matches VALUES(2);
UPDATE ace_permission_fixture.tournament_matches SET id=3 WHERE id=2;
DELETE FROM ace_permission_fixture.tournament_matches WHERE id=3;
INSERT INTO ace_permission_fixture.tournament_match_sets VALUES(2);
INSERT INTO ace_permission_fixture.tournament_match_player_stats VALUES(2);
RESET ROLE;
DO $verify$
BEGIN
 IF (SELECT count(*) FROM ace_permission_fixture.tournament_matches)<>1 OR (SELECT count(*) FROM ace_permission_fixture.tournament_match_sets)<>2 OR (SELECT count(*) FROM ace_permission_fixture.tournament_match_player_stats)<>2 THEN RAISE EXCEPTION 'server writes failed'; END IF;
 RAISE NOTICE 'PASS authenticated reads preserved, truncate denied, server writes preserved';
END $verify$;
ROLLBACK;
