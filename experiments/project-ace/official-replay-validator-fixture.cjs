'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const migration=fs.readFileSync(path.join(__dirname,'../../supabase/migrations/20260904142332_live_match_replay_infrastructure_v1.sql'),'utf8');
const start=migration.indexOf('create or replace function public.validate_match_replay_events_v1'),end=migration.indexOf('create or replace function public.register_tournament_match_simulation_v1',start+1);
assert.ok(start>=0&&end>start);
const original=migration.slice(start,end).trim();
assert.ok(original.includes('returns boolean')&&original.includes('revoke all on function public.validate_match_replay_events_v1(jsonb,integer)'));
const target=process.argv[2];assert.ok(target);
fs.writeFileSync(path.join(target,'replay-validator.sql'),original+'\n');
