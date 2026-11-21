-- DISPOSABLE AUTH integration only. Not a production schema or migration.
-- Supabase CLI supplies its real Auth objects, roles, mail, and PostgREST.
CREATE SCHEMA IF NOT EXISTS control_center_private;
CREATE TABLE public.registration_control(
 singleton_id boolean PRIMARY KEY DEFAULT true CHECK(singleton_id),
 public_signup_enabled boolean NOT NULL DEFAULT true,
 guest_test_enabled boolean NOT NULL DEFAULT false,
 google_oauth_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO public.registration_control(singleton_id) VALUES (true);
CREATE TABLE public.profiles(
 id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 username text NOT NULL UNIQUE,
 birthday_month integer, birthday_day integer, birthday_year integer,
 birthday_timezone text NOT NULL DEFAULT 'UTC'
);
CREATE TABLE public.billing_transactions(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 kind text, status text
);
CREATE TABLE public.premium_memberships(
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 plan_code text, status text, current_period_end timestamptz
);
CREATE TABLE public.tennis_premium_trial_claims_v1(email_claim_hash text PRIMARY KEY);
CREATE TABLE public.tennis_premium_trials_v1(
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 email_claim_hash text NOT NULL UNIQUE REFERENCES public.tennis_premium_trial_claims_v1(email_claim_hash),
 started_at timestamptz NOT NULL,
 expires_at timestamptz NOT NULL,
 reserved_for_launch boolean NOT NULL DEFAULT false,
 launch_cohort boolean NOT NULL DEFAULT false,
 CHECK(expires_at=started_at+interval '7 days')
);
ALTER TABLE public.registration_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.premium_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tennis_premium_trial_claims_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tennis_premium_trials_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.registration_control,public.profiles,public.billing_transactions,public.premium_memberships,public.tennis_premium_trial_claims_v1,public.tennis_premium_trials_v1 FROM PUBLIC,anon,authenticated;
