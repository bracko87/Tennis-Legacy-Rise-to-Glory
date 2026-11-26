'use strict';
const assert=require('node:assert/strict'),{connection}=require('./postgres-store.cjs'),{exportPayload}=require('./official-review.test.cjs');
const literal=x=>"convert_from(decode('"+Buffer.from(JSON.stringify(x)).toString('base64')+"','base64'),'UTF8')::jsonb";
async function run(){
 const db=connection(),stage=x=>db.sql('SELECT ace_review.stage_settlement('+literal(x)+');');
 const results=await Promise.all([stage(exportPayload),stage(exportPayload)]);
 assert.deepEqual(results.sort(),['already_staged','staged']);
 const altered=JSON.parse(JSON.stringify(exportPayload));altered.transactions[0].amount++;
 await assert.rejects(stage(altered),/rejected/);
 const row=await db.sql("SELECT payload FROM ace_review.settlement_exports WHERE competition_id='source-competition';");
 assert.deepEqual(JSON.parse(row),exportPayload);
 await assert.rejects(db.sql("UPDATE ace_review.settlement_exports SET payload='{}'::jsonb"),/rejected/);
 await assert.rejects(db.sql("DELETE FROM ace_review.settlement_exports"),/rejected/);
 console.log('PASS review-only official settlement projection, concurrent duplicate staging, conflicting payload rejection and immutable export');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
