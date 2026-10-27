-- GitHub Actions only: disposable PostgreSQL fixture helper.
-- The existing standalone fixture defines cron.schedule as a no-op. Replace
-- it with a recording stub so combined-migration QA can verify registration.
CREATE TABLE cron.job (
  jobname text PRIMARY KEY,
  schedule text NOT NULL,
  command text NOT NULL
);
CREATE OR REPLACE FUNCTION cron.schedule(p_name text,p_expr text,p_command text)
RETURNS bigint LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO cron.job(jobname,schedule,command)
  VALUES(p_name,p_expr,p_command)
  ON CONFLICT(jobname) DO UPDATE SET schedule=excluded.schedule,command=excluded.command;
  RETURN 1;
END $$;
