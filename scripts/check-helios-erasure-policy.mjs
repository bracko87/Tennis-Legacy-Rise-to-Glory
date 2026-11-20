// Static safety gate for the Helios history/finance erasure proposal.
// This is intentionally offline; it never contacts production databases.
// It prevents accidentally publishing an incomplete decision record as approved.
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const policy = readFileSync(resolve(root,'docs/HELIOS_GUEST_ERASURE_HISTORY_FINANCE_POLICY.md'),'utf8');
const ledger = readFileSync(resolve(root,'docs/HELIOS_GUEST_ERASURE_180_TABLE_TRIAGE_LEDGER.md'),'utf8');
const needed = [
  'tournament_matches','tournament_match_sets','tournament_doubles_teams',
  'tournament_doubles_matches','player_tournament_results',
  'player_doubles_tournament_results','player_ranking_snapshots',
  'national_team_fixtures','players','billing_transactions',
  'premium_memberships','coin_ledger','user_wallets',
  'career_finance_transactions','tennis_premium_trials_v1'
];
for (const name of needed) {
  const needle = '`' + (name==='players' ? 'public.players' : 'public.'+name) + '`';
  if (!policy.includes(needle)) throw new Error('Missing high-risk table policy: '+needle);
  // Catalog reports public tables without schema qualification.
  if (name!=='players' && !ledger.includes('`'+name+'`'))
    throw new Error('High-risk table no longer appears in ledger: '+name);
}
for(const keyword of [
 'REVIEW_REQUIRED','NOT an approved retention schedule','No legal retention length',
 'Guest Mode OFF','tombstone','converted','full-schema','financial'
]) {
 if (!policy.includes(keyword)) throw new Error('Missing protection statement: '+keyword);
}
const ledgerRows=ledger.split('\n').filter(line=>/^\| \d+ \| `[^\x60]+` \|/.test(line));
if(ledgerRows.length!==180) throw new Error('Guest erasure inventory no longer covers 180 tables');
const prematurelyApproved=ledgerRows.filter(row=>!row.endsWith('| REVIEW_REQUIRED |'));
if(prematurelyApproved.length) throw new Error('One or more catalog rows has an unapproved deletion decision');
console.log('Helios H08 history/finance decision gate PASS: 15 critical tables represented, 180 dependencies remain REVIEW_REQUIRED; no production changes.');
