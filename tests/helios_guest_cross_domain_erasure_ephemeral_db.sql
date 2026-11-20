-- Helios H08 cross-domain deletion hazards (DISPOSABLE POSTGRES ONLY).
-- This is a minimal *representative* schema, NOT a full-schema replay.
-- Every synthetic mutation is inside ROLLBACK. No production credentials.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='60s';

-- Isolate real-world ON DELETE actions in the fixture. This test proves
-- why deletion fails/loses data, and why detached history remains possible.
ALTER TABLE public.players DROP CONSTRAINT players_owner_user_id_fkey;
ALTER TABLE public.players ADD CONSTRAINT players_owner_user_id_fkey
 FOREIGN KEY(owner_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE TABLE public.h08_billing (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 amount_eur_cents integer NOT NULL
);
CREATE TABLE public.h08_coins (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
 amount integer NOT NULL
);
CREATE TABLE public.h08_career_finance (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,
 amount bigint NOT NULL
);
CREATE TABLE public.h08_equipment_inventory (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,
 condition_percent integer NOT NULL
);
CREATE TABLE public.h08_national_squad (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 player_id uuid REFERENCES public.players(id) ON DELETE RESTRICT,
 nominated_by_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
 result text NOT NULL
);
CREATE TABLE public.h08_completed_match (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 player_id uuid REFERENCES public.players(id) ON DELETE SET NULL,
 winner_id uuid REFERENCES public.players(id) ON DELETE SET NULL,
 score text NOT NULL
);

DO $test$
DECLARE
 u uuid:=gen_random_uuid();
 p uuid;
 b uuid;
 c uuid;
 f uuid;
 e uuid;
 s uuid;
 m uuid;
 v_count int;
 v_failed boolean;
BEGIN
 INSERT INTO auth.users(id,is_anonymous) VALUES(u,true);
 INSERT INTO control_center_private.tennis_guest_trials_v1(
  user_id,started_at,expires_at,retired_at)
 VALUES(u,now()-interval '15 days',now()-interval '1 day',now()-interval '1 day');
 INSERT INTO public.players(owner_user_id,first_name,last_name,country_code,world,player_type,moderation_status)
 VALUES(u,'Personal','Guest','DE','ATP','human','rejected') RETURNING id INTO p;
 INSERT INTO public.h08_billing(user_id,amount_eur_cents) VALUES(u,1999) RETURNING id INTO b;
 INSERT INTO public.h08_coins(user_id,amount) VALUES(u,100) RETURNING id INTO c;
 INSERT INTO public.h08_career_finance(player_id,amount) VALUES(p,5000) RETURNING id INTO f;
 INSERT INTO public.h08_equipment_inventory(player_id,condition_percent)
 VALUES(p,60) RETURNING id INTO e;
 INSERT INTO public.h08_national_squad(player_id,nominated_by_user_id,result)
 VALUES(p,u,'semifinal') RETURNING id INTO s;
 INSERT INTO public.h08_completed_match(player_id,winner_id,score)
 VALUES(p,p,'6-4 6-4') RETURNING id INTO m;

 -- A naive Auth delete must fail due to actual-style RESTRICT constraints.
 -- Catch only foreign-key violation in a subtransaction, preserving rows.
 v_failed:=false;
 BEGIN
  DELETE FROM auth.users WHERE id=u;
 EXCEPTION WHEN foreign_key_violation THEN v_failed:=true;
 END;
 IF NOT v_failed THEN RAISE EXCEPTION 'H08 unsafe Auth delete unexpectedly succeeded'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.h08_completed_match WHERE id=m AND winner_id=p)
 OR NOT EXISTS(SELECT 1 FROM public.h08_billing WHERE id=b)
 OR NOT EXISTS(SELECT 1 FROM public.h08_national_squad WHERE id=s)
 THEN RAISE EXCEPTION 'H08 rejected delete did not roll back atomically'; END IF;

 -- The synthetic retired public player can be detached without erasing
 -- competition references, but this is NOT authorization to erase Auth.
 UPDATE public.players SET owner_user_id=NULL,first_name='Retired',
  last_name='Guest',home_city=NULL,image_path=NULL
 WHERE id=p AND owner_user_id=u
 AND EXISTS(
  SELECT 1 FROM control_center_private.tennis_guest_trials_v1 t
  JOIN auth.users au ON au.id=t.user_id
  WHERE t.user_id=u AND au.is_anonymous
  AND t.retired_at IS NOT NULL AND t.expires_at<=now()
  AND t.converted_at IS NULL
 );
 GET DIAGNOSTICS v_count=ROW_COUNT;
 IF v_count<>1 THEN RAISE EXCEPTION 'H08 history detach blocked'; END IF;

 IF NOT EXISTS(SELECT 1 FROM public.h08_completed_match WHERE id=m AND player_id=p AND winner_id=p AND score='6-4 6-4')
 OR NOT EXISTS(SELECT 1 FROM public.h08_national_squad WHERE id=s AND player_id=p)
 OR NOT EXISTS(SELECT 1 FROM public.h08_equipment_inventory WHERE id=e)
 OR NOT EXISTS(SELECT 1 FROM public.h08_career_finance WHERE id=f)
 OR NOT EXISTS(SELECT 1 FROM public.h08_coins WHERE id=c)
 THEN RAISE EXCEPTION 'H08 detachment silently removed a child record'; END IF;

 -- Even after history is detached, a real-money transaction and national
 -- nomination remain attached to Auth and forbid unreviewed hard deletion.
 v_failed:=false;
 BEGIN
  DELETE FROM auth.users WHERE id=u;
 EXCEPTION WHEN foreign_key_violation THEN v_failed:=true;
 END;
 IF NOT v_failed THEN RAISE EXCEPTION 'H08 unreviewed national nomination should block Auth deletion'; END IF;

 -- Check that a financially significant record still exists and the Auth
 -- account survives both rejected delete attempts.
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=u)
 OR NOT EXISTS(SELECT 1 FROM public.h08_billing WHERE id=b AND amount_eur_cents=1999)
 THEN RAISE EXCEPTION 'H08 financial/audit invariant failed'; END IF;

 RAISE NOTICE 'H08 PASS: naive Auth delete fails on RESTRICT, no data loss, detached history preserves match/national result, billing/equipment/finance untouched; no actual erasure';
END;
$test$;

ROLLBACK;
