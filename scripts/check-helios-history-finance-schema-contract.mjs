// Offline safety/coverage check for the read-only Helios SQL metadata contract.
// No Supabase connection, no credentials, no player records.
import {readFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const sql=readFileSync(resolve(root,'tests/helios_guest_history_finance_schema_contract.sql'),'utf8');
if(!sql.includes('BEGIN READ ONLY;') || !sql.includes('ROLLBACK;'))
  throw new Error('The schema metadata contract must be transactionally READ ONLY');
if(/\b(?:DELETE\s+FROM|INSERT\s+INTO|UPDATE\s+[\w.]+\s+SET|TRUNCATE|DROP\s+TABLE|ALTER\s+TABLE|CREATE\s+TABLE|CREATE\s+FUNCTION|GRANT\s|REVOKE\s)\b/i.test(sql))
  throw new Error('Destructive/mutating statement detected in read-only metadata contract');
if(!sql.includes('physical guest deletion remains FORBIDDEN'))
  throw new Error('Required deletion prohibition missing');
const expectedForeignKeys = [
 'players_owner_user_id_fkey',
 'tournament_matches_player1_id_fkey',
 'tournament_matches_player2_id_fkey',
 'tournament_matches_winner_id_fkey',
 'tournament_match_sets_match_id_fkey',
 'tournament_doubles_teams_player1_id_fkey',
 'tournament_doubles_teams_player2_id_fkey',
 'tournament_doubles_matches_team1_id_fkey',
 'tournament_doubles_matches_team2_id_fkey',
 'tournament_doubles_matches_winner_team_id_fkey',
 'player_tournament_results_player_id_fkey',
 'player_doubles_tournament_results_player_id_fkey',
 'player_doubles_tournament_results_team_id_fkey',
 'player_ranking_snapshots_player_id_fkey',
 'billing_transactions_user_id_fkey',
 'premium_memberships_user_id_fkey',
 'coin_ledger_user_id_fkey',
 'user_wallets_user_id_fkey',
 'career_finance_transactions_player_id_fkey',
 'tennis_premium_trials_v1_user_id_fkey'
];
for (const fk of expectedForeignKeys) {
 if (!sql.includes("'"+fk+"'")) throw new Error('Missing high-risk FK contract: '+fk);
}
if (new Set(expectedForeignKeys).size !== 20) throw new Error('Duplicate critical FK check');
const checkedColumns=[
 'owner_user_id','first_name','last_name','image_path','home_city',
 'winner_id','player1_id','player2_id','status','match_id',
 'ranking_points_earned','ranking_points','stripe_payment_intent_id',
 'amount_eur_cents','stripe_subscription_id','balance_after','metadata',
 'converted_at','retired_at','expires_at'
];
for(const col of checkedColumns) {
 if (!sql.includes("'"+col+"'"))throw new Error('Missing critical column check: '+col);
}
const doc=readFileSync(resolve(root,'docs/HELIOS_GUEST_HISTORY_FINANCE_SCHEMA_CONTRACT.md'),'utf8');
for(const phrase of ['20 foreign keys','24 columns','read-only','not full-schema','Guest Mode remains disabled']){
 if (!doc.includes(phrase)) throw new Error('Missing scope warning: '+phrase);
}
console.log('PASS: Helios history/finance FK contract covers 20 critical FKs, 24 expected columns; metadata-only read-only guard.');
