-- Serve Realism Candidate v3: READ-ONLY paired smoke comparison.
-- Run ONLY in isolated test environment with service role after the INACTIVE
-- v3 candidate migration. Do not run repeatedly on a busy production database.
-- Simulates 3 fixed-seed matches per available ATP/WTA + surface cohort.
-- Neither function registers / publishes a match, score, replay or payout.
-- Use the same explicit seed for both versions; compare outcome changes honestly.
begin transaction read only;
with ranked as materialized (
  select m.id,wc.world,ts.surface,
    row_number() over (
      partition by wc.world,ts.surface order by md5(m.id::text)
    ) as row_num
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=e.tournament_series_id
  where m.status='completed'
    and m.player1_id is not null and m.player2_id is not null
    and m.winner_id is not null
    and upper(wc.world) in ('ATP','WTA')
    and lower(ts.surface) in ('hard','clay','grass')
),
samples as materialized (
  select id,world,surface,'serve-realism-v3-smoke:'||id::text as fixed_seed
  from ranked where row_num<=3
),
compared as materialized (
  select s.world,s.surface,
    public.simulate_tournament_match_raw_v2(s.id,s.fixed_seed) as old_result,
    public.simulate_tournament_match_raw_v3_candidate(s.id,s.fixed_seed) as new_result
  from samples s
),
scored as materialized (
  select world,surface,
    (old_result#>>'{player1_stats,aces}')::numeric +
      (old_result#>>'{player2_stats,aces}')::numeric as old_aces,
    (new_result#>>'{player1_stats,aces}')::numeric +
      (new_result#>>'{player2_stats,aces}')::numeric as new_aces,
    (old_result#>>'{player1_stats,double_faults}')::numeric +
      (old_result#>>'{player2_stats,double_faults}')::numeric as old_df,
    (new_result#>>'{player1_stats,double_faults}')::numeric +
      (new_result#>>'{player2_stats,double_faults}')::numeric as new_df,
    (old_result->>'total_games')::numeric as old_games,
    (new_result->>'total_games')::numeric as new_games,
    old_result->>'winner_id' is distinct from new_result->>'winner_id' as winner_changed,
    (old_result->>'engine_version') as old_version,
    (new_result->>'engine_version') as new_version
  from compared
)
select world,surface,count(*) as seeded_matches,
  round(avg(old_aces)/2,2) as prior_aces_per_player,
  round(avg(new_aces)/2,2) as v3_aces_per_player,
  round(avg(old_df)/2,2) as prior_df_per_player,
  round(avg(new_df)/2,2) as v3_df_per_player,
  round(avg(old_games),1) as prior_games,
  round(avg(new_games),1) as v3_games,
  count(*) filter(where winner_changed) as changed_winners,
  count(*) filter(where new_version not like 'base-v3.0%') as invalid_version
from scored
group by world,surface order by world,surface;
rollback;
