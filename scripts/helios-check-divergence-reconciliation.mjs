// H08: offline safety/traceability guard for nine unresolved SQL differences.
// Does not connect to a database and cannot approve historical replay.
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const sql=readFileSync(resolve(root,'tests/helios_h08_divergence_current_state_readonly.sql'),'utf8');
const doc=readFileSync(resolve(root,'docs/HELIOS_H08_NINE_DIVERGENCE_RECONCILIATION.md'),'utf8');
const registry=JSON.parse(readFileSync(resolve(root,'tests/recovered-migrations/known-applied-sql-divergences.json'),'utf8'));
if(!sql.includes('BEGIN READ ONLY;')||!sql.includes('ROLLBACK;'))
 throw Error('Metadata verification must remain READ ONLY and rollback');
if(/\b(?:INSERT\s+INTO|DELETE\s+FROM|UPDATE\s+[\w.]+\s+SET|ALTER\s+(?:TABLE|FUNCTION)|DROP\s+(?:TABLE|POLICY)|CREATE\s+(?:TABLE|POLICY)|GRANT\s|REVOKE\s|TRUNCATE)\b/i.test(sql))
 throw Error('Potentially mutating statement in metadata-only audit');
if(registry.safe_to_replay!==false||registry.review_status!=='REVIEW_REQUIRED'||registry.mismatches.length!==9)
 throw Error('All nine SQL differences must remain unapproved replay blockers');
for(const entry of registry.mismatches){
 if(entry.review_status!=='REVIEW_REQUIRED'||entry.replay_blocker!==true)
  throw Error('Unexpected resolved replay blocker '+entry.name);
 if(!doc.includes('`'+entry.name+'`'))
  throw Error('Missing documented source divergence '+entry.name);
}
for(const phrase of [
 '20261002112307_fix_training_camp_health_alias',
 '20261002141436_game_manual_generated_pdf_route_v1',
 '20261012155713_control_center_dynamic_disk_capacity_payloads_v1',
 '20261020063247_premium_statistics_intelligence_volatility_fix',
 'full historical replay **BLOCKED**',
 'Guest Mode and physical Auth deletion stay OFF'
]){
 if(!doc.includes(phrase))throw Error('Missing evidence or safety statement: '+phrase);
}
for(const x of ['get_premium_statistics_intelligence_v1','control_center_disk_capacity_bytes_v1',
 'check_training_camp_health_v1','admin_player_avatar_authenticated_read',
 'public_tennis_home_gallery_20_read']){
 if(!sql.includes(x))throw Error('Missing current-state schema metadata check '+x);
}
console.log('PASS: all nine differences remain replay blockers; four downstream migration corrections documented; current-state SQL is read-only.');
