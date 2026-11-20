// Helios H08: offline guard only. Never run SQL or connect to production.
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const sql=readFileSync(resolve(root,'tests/helios_live_staff_schema_readonly_contract.sql'),'utf8');
const doc=readFileSync(resolve(root,'docs/HELIOS_H08_STAFF_BASELINE_METADATA.md'),'utf8');
if(!sql.includes('BEGIN READ ONLY;') || !sql.includes('ROLLBACK;'))
 throw Error('Staff metadata contract must use a read-only rollback transaction');
if(/\b(?:INSERT\s+INTO|DELETE\s+FROM|UPDATE\s+\S+\s+SET|TRUNCATE|ALTER\s+TABLE|CREATE\s+TABLE|CREATE\s+FUNCTION|DROP\s+TABLE|GRANT\s|REVOKE\s)\b/i.test(sql))
 throw Error('Staff metadata query contains a modifying SQL statement');
for(const marker of ['v_columns<>23','v_constraints<>13','v_indexes<>5','v_triggers<>4','v_required_cols<>9','relrowsecurity']){
 if(!sql.includes(marker))throw Error('Staff metadata invariant missing: '+marker);
}
for(const marker of ['Current columns (23)','13 constraints','5 indexes','4 application triggers','not a historical','Guest Mode OFF','Full historical replay NOT fixed']){
 if(!doc.includes(marker))throw Error('Staff baseline warning or inventory missing: '+marker);
}
console.log('PASS: metadata-only current staff baseline contract with explicit historical replay limits');
