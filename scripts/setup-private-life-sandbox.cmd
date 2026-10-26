@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Tennis Legacy - schema-only Supabase sandbox setup for Windows CMD.
rem THIS SCRIPT IS READ-ONLY WITH RESPECT TO THE LIVE DATABASE.
rem It does not run db push, remote db reset, apply_migration or Netlify.
cd /d "%~dp0.."
if errorlevel 1 goto :failed

echo.
echo ============================================================
echo   Tennis Legacy - Private Life ISOLATED QA environment
echo ============================================================
echo.
echo Remote operations: Supabase LOGIN, LINK and SCHEMA-ONLY DUMP.
echo The database migrations will run against LOCAL DOCKER ONLY.
echo No player accounts, purchases or finance records are exported.
echo.

if exist ".private-life-sandbox\" (
  echo Existing .private-life-sandbox folder detected.
  echo Refusing to overwrite a previous testing environment.
  echo Stop and remove it manually ONLY if you no longer need it.
  exit /b 1
)
if not exist ".private-life-schema\" mkdir ".private-life-schema"
if errorlevel 1 goto :failed
if exist ".private-life-schema\existing.sql" (
  echo An existing schema dump is already present.
  echo Refusing to overwrite it. Review or rename it before proceeding.
  exit /b 1
)

where node >nul 2>&1
if errorlevel 1 (
  echo ERROR: Node.js was not found. Install Node.js first.
  exit /b 1
)
where docker >nul 2>&1
if errorlevel 1 (
  echo ERROR: Docker Desktop is not installed or is missing from PATH.
  exit /b 1
)
docker info >nul 2>&1
if errorlevel 1 (
  echo ERROR: Docker Desktop is not running.
  exit /b 1
)

echo.
echo [1/5] Verify the Supabase CLI...
call npx supabase --version
if errorlevel 1 goto :failed

echo.
echo [2/5] Sign in locally to Supabase (may open your browser)...
call npx supabase login
if errorlevel 1 goto :failed

echo.
echo [3/5] Link local CLI to the EXISTING project (no migrations)...
call npx supabase link --project-ref cwfznmroiqcyhfkfcrow
if errorlevel 1 goto :failed

echo.
echo [4/5] READ-ONLY export of the public schema, no player data...
call npx supabase db dump --linked --schema public -f ".private-life-schema\existing.sql"
if errorlevel 1 goto :failed
if not exist ".private-life-schema\existing.sql" goto :failed

echo.
echo [5/5] Build the separate local migration stack...
node scripts\prepare-private-life-sandbox.mjs ".private-life-schema\existing.sql"
if errorlevel 1 goto :failed

pushd ".private-life-sandbox"
if errorlevel 1 goto :failed
echo.
echo Starting LOCAL Docker Supabase and applying Private Life migrations.
echo This does NOT touch the linked remote database.
call npx supabase start
if errorlevel 1 (
  echo ERROR: The local schema restore or migration failed.
  echo Keep the terminal output for diagnosing the FIRST SQL error.
  popd
  exit /b 1
)
echo.
echo The isolated local database is ready. Save the LOCAL ANON_KEY:
call npx supabase status -o env
if errorlevel 1 (
  popd
  goto :failed
)
popd
echo.
echo ============================================================
echo  Local sandbox startup succeeded.
echo  In a second CMD window, FROM THE GAME REPOSITORY, enter:
echo    set TL_SUPABASE_URL=http://127.0.0.1:54331
echo    set TL_SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_ANON_KEY
echo    set TL_DEV_PORT=8001
echo    npm run dev
echo.
echo  Use the LOCAL anon key from the preceding status output.
echo  Do NOT put any production keys in this local test client.
echo ============================================================
exit /b 0

:failed
echo.
echo ERROR: Setup stopped. Production database was not modified.
echo Do NOT use db push or db reset --linked to fix a local error.
exit /b 1
