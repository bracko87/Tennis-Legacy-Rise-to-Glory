-- Helios H08: staff baseline metadata ONLY. No staff or user rows.
-- Current schema contract is not a historical starting migration.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL statement_timeout='30s';

DO $verify$
DECLARE
 v_columns integer;
 v_constraints integer;
 v_indexes integer;
 v_triggers integer;
 v_rls boolean;
 v_required_cols integer;
BEGIN
 SELECT count(*) INTO v_columns
 FROM pg_attribute
 WHERE attrelid='public.staff_members'::regclass
   AND attnum>0 AND NOT attisdropped;

 SELECT count(*) INTO v_constraints
 FROM pg_constraint WHERE conrelid='public.staff_members'::regclass;

 SELECT count(*) INTO v_indexes
 FROM pg_index WHERE indrelid='public.staff_members'::regclass;

 SELECT count(*) INTO v_triggers
 FROM pg_trigger WHERE tgrelid='public.staff_members'::regclass
   AND NOT tgisinternal;

 SELECT relrowsecurity INTO v_rls
 FROM pg_class WHERE oid='public.staff_members'::regclass;

 WITH expected(name,typ,not_null) AS (
  VALUES
   ('id','uuid',true),
   ('market_serial','bigint',true),
   ('required_rank_position','integer',false),
   ('current_player_id','uuid',false),
   ('age','smallint',true),
   ('experience_years','smallint',true),
   ('education','text',true),
   ('courses','jsonb',true),
   ('image_path','text',false)
 )
 SELECT count(*) INTO v_required_cols FROM expected e
 JOIN pg_attribute a ON a.attrelid='public.staff_members'::regclass
   AND a.attname=e.name AND NOT a.attisdropped
 WHERE pg_catalog.format_type(a.atttypid,a.atttypmod)=e.typ
 AND a.attnotnull=e.not_null;

 IF v_columns<>23 OR v_constraints<>13 OR v_indexes<>5
  OR v_triggers<>4 OR v_rls IS DISTINCT FROM true OR v_required_cols<>9
 THEN RAISE EXCEPTION
  'Helios staff metadata drift. columns=%, constraints=%, indexes=%, triggers=%, rls=%, core_fields=%',
  v_columns,v_constraints,v_indexes,v_triggers,v_rls,v_required_cols;
 END IF;
 RAISE NOTICE 'Helios current staff baseline reference verified. Historical migration replay still NOT safe.';
END;
$verify$;

ROLLBACK;
