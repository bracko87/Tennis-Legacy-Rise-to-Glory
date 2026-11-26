'use strict';
const assert=require('node:assert/strict'),{connection}=require('./postgres-store.cjs'),{reordered}=require('./official-review.test.cjs');
const lit=x=>x===null?'NULL':"convert_from(decode('"+Buffer.from(String(x)).toString('base64')+"','base64'),'UTF8')";
const clone=x=>JSON.parse(JSON.stringify(x));
async function run(){
 const db=connection(),stage=x=>db.sql('SELECT ace_review.stage_settlement('+lit(JSON.stringify(x))+'::jsonb);');
 const claim=(m,engine='ace',f1=null,f2=null)=>db.sql('SELECT ace_review.claim_finalization('+[m.match_id,m.competition_id,engine,m.player1_id,m.player2_id,f1,f2].map(lit).join(',')+');');
 const finish=id=>db.sql('SELECT ace_review.finalize_staged_competition('+lit(id)+');');
 const counts=id=>db.sql('SELECT jsonb_build_array((SELECT count(*) FROM ace_review.finalized_matches WHERE competition_id='+lit(id)+'),(SELECT count(*) FROM ace_review.finalized_competitions WHERE competition_id='+lit(id)+'),(SELECT count(*) FROM ace_review.finalized_prizes WHERE competition_id='+lit(id)+'));').then(JSON.parse);
 function fixture(id){const x=clone(reordered),old=x.competition_id;x.competition_id=id;for(const m of x.matches){m.competition_id=id;m.match_id=id+'-'+m.match_id;for(const row of [...m.sets,...m.stats])row.match_id=m.match_id;}for(const row of x.results){row.competition_id=id;row.match_id=id+'-'+row.match_id;}for(const row of [...x.conditions,...x.support_events])row.match_id=id+'-'+row.match_id;for(const row of x.transactions){row.source_id=id;row.idempotency_key='tournament-prize:'+id+':'+row.player_id;}return x;}
 const x=fixture('final-ok');await stage(x);
 const [a,b,c]=x.matches;
 const feeder=id=>[a,b].find(m=>m.winner_id===id).match_id;
 await claim(a);await claim(b);
 await assert.rejects(finish(x.competition_id),/rejected/);assert.deepEqual(await counts(x.competition_id),[0,0,0]);
 const claims=await Promise.allSettled([claim(c,'ace',feeder(c.player1_id),feeder(c.player2_id)),claim(c,'ace',feeder(c.player1_id),feeder(c.player2_id))]);
 assert.deepEqual(claims.map(v=>v.value).sort(),['already_claimed','claimed']);
 await assert.rejects(claim(c,'legacy',feeder(c.player1_id),feeder(c.player2_id)),/rejected/);
 const completed=await Promise.all([finish(x.competition_id),finish(x.competition_id)]);
 assert.deepEqual(completed.sort(),['already_finalized','finalized_review']);assert.deepEqual(await counts(x.competition_id),[3,1,1]);
 assert.equal(await finish(x.competition_id),'already_finalized');
 const wrong=fixture('final-feeder-conflict');await stage(wrong);
 const [d,e,f]=wrong.matches;await claim(d);await claim(e);
 const reversed=id=>[d,e].find(m=>m.winner_id!==id).match_id;
 await claim(f,'ace',reversed(f.player1_id),reversed(f.player2_id));
 await assert.rejects(finish(wrong.competition_id),/rejected/);assert.deepEqual(await counts(wrong.competition_id),[0,0,0]);
 const legacy=fixture('final-legacy-owned');await stage(legacy);const [g,h,i]=legacy.matches;
 await claim(g,'legacy');await assert.rejects(claim(g,'ace'),/rejected/);await claim(h);await claim(i);
 await assert.rejects(finish(legacy.competition_id),/rejected/);assert.deepEqual(await counts(legacy.competition_id),[0,0,0]);
 await assert.rejects(db.sql('DELETE FROM ace_review.finalized_prizes'),/rejected/);
 console.log('PASS isolated engine ownership, feeder validation, concurrent finalization, immutable prizes and atomic rollback');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
