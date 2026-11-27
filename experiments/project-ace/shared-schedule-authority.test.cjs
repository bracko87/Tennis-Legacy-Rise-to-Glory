'use strict';
const assert=require('node:assert/strict'),{execFile}=require('node:child_process'),{promisify}=require('node:util'),run=promisify(execFile);
function sql(role,query){const password=role==='postgres'?'ace-disposable-admin':role==='ace_cutover_ace'?'ace-disposable-ace':role==='ace_review_worker'?'ace-disposable-worker':'ace-disposable-legacy';return run('psql',['-X','-qAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p','55432','-U',role,'-d','ace_review','-c',query],{env:{...process.env,PGPASSWORD:password}}).then(r=>r.stdout.trim());}
const a='ace_cutover_ace',l='ace_cutover_legacy',call=(id,rev,start,court,live=false)=>"SELECT ace_shared_schedule_fixture.change_slot('"+id+"',"+rev+","+start+","+court+","+live+");";
async function main(){
 await assert.rejects(sql(l,call('a',0,36000,1)),/wrong scheduling owner/);
 await assert.rejects(sql(a,call('a',0,54000,1)),/shared resource conflict/);
 await assert.rejects(sql(a,"UPDATE ace_shared_schedule_fixture.inventory SET court=4"),/permission denied/);
 // Both engines request the same initially empty physical court and time.
 const results=await Promise.allSettled([sql(a,call('a',0,72000,4)),sql(l,call('l',0,72000,4))]);
 assert.equal(results.filter(x=>x.status==='fulfilled'&&x.value==='rescheduled_review').length,1);
 assert.equal(results.filter(x=>x.status==='rejected'&&/shared resource conflict/.test(x.reason.message)).length,1);
 const winner=results[0].status==='fulfilled'?'a':'l',role=winner==='a'?a:l;
 await assert.rejects(sql(role,call(winner,0,72000,4)),/invalid schedule revision/);
 assert.equal(await sql(role,call(winner,1,72000,4,true)),'started_review');
 assert.equal(await sql('postgres',"SELECT count(*) FROM ace_shared_schedule_fixture.inventory WHERE status='live'"),'1');
 const loser=winner==='a'?'l':'a',other=winner==='a'?l:a;
 await assert.rejects(sql(other,"SELECT ace_shared_schedule_fixture.finish_slot('"+winner+"',2,82800)"),/wrong scheduling owner/);
 await assert.rejects(sql(role,"SELECT ace_shared_schedule_fixture.finish_slot('"+winner+"',2,72001)"),/invalid completion evidence/);
 // Introduce authoritative scheduled inventory after activation, with slots safe under the initial estimate.
 const sharedPlayer=winner==='a'?'p1':'p3';
 await sql('postgres',"INSERT INTO ace_shared_schedule_fixture.inventory(id,owner,status,revision,venue,court,player1,player2,start_second,duration_minutes) VALUES ('affected-player','external','scheduled',0,'other-venue',1,'"+sharedPlayer+"','p6',81000,60),('affected-court','external','scheduled',0,'venue',4,'p7','p8',81000,60),('unaffected-boundary','external','scheduled',0,'other-venue',2,'"+sharedPlayer+"','p9',86400,60)");
 // Three-hour actual duration overrides the one-hour estimate.
 const finish="SELECT ace_shared_schedule_fixture.finish_slot('"+winner+"',2,82800)";
 const retries=await Promise.all([sql(role,finish),sql(role,finish)]);
 assert.deepEqual(retries.sort(),['already_completed_review','completed_review']);
 const obligations=JSON.parse(await sql('postgres',"SELECT jsonb_agg(to_jsonb(o) ORDER BY target_id) FROM ace_shared_schedule_fixture.obligations o"));
 assert.equal(obligations.length,2);
 assert.deepEqual(obligations.map(o=>[o.target_id,o.player_conflict,o.court_conflict,o.earliest_second,o.target_owner]),[['affected-court',false,true,83700,'external'],['affected-player',true,false,86400,'external']]);
 await assert.rejects(sql(other,"SELECT * FROM ace_shared_schedule_fixture.obligations"),/permission denied/);
 await assert.rejects(sql(other,call('affected-court',0,90000,5)),/wrong scheduling owner/);
 // Remove the synthetic external court blocker only as fixture administrator to isolate the recovery boundary.
 await sql('postgres',"UPDATE ace_shared_schedule_fixture.inventory SET start_second=100000 WHERE id='affected-court'");
 await assert.rejects(sql(other,call(loser,0,83699,4)),/shared resource conflict/);
 assert.equal(await sql(other,call(loser,0,83700,4)),'rescheduled_review');
 assert.equal(await sql(other,call(loser,1,83700,4,true)),'started_review');
 await assert.rejects(sql(role,"SELECT ace_shared_schedule_fixture.finish_slot('"+winner+"',2,82900)"),/invalid completion evidence/);
 assert.equal(await sql('postgres',"SELECT actual_end_second FROM ace_shared_schedule_fixture.inventory WHERE id='"+winner+"'"),'82800');
 // Separate owner-controlled obligation, next tournament day, with explicit phase bounds.
 await sql('postgres',"INSERT INTO ace_shared_schedule_fixture.inventory(id,owner,status,revision,venue,court,player1,player2,start_second,duration_minutes) VALUES ('resolve-target','"+(winner==='a'?'ace':'legacy')+"','scheduled',0,'venue-z',1,'z1','z2',81000,60); INSERT INTO ace_shared_schedule_fixture.obligations VALUES ('"+winner+"','resolve-target','"+(winner==='a'?'ace':'legacy')+"',0,true,false,86400,81000)");
 const resolve="SELECT ace_shared_schedule_fixture.resolve_slot('"+winner+"','resolve-target')";
 await assert.rejects(sql(other,resolve),/wrong scheduling owner/);
 assert.equal(JSON.parse(await sql(role,resolve)).status,'phase_policy_required');
 await sql('postgres',"INSERT INTO ace_shared_schedule_fixture.phase_policy VALUES ('resolve-target',0,0,2)");
 assert.equal(JSON.parse(await sql(role,resolve)).status,'no_safe_slot_review');
 await sql('postgres',"UPDATE ace_shared_schedule_fixture.phase_policy SET last_day=1 WHERE match_id='resolve-target'");
 const resolved=JSON.parse(await sql(role,resolve));
 assert.equal(resolved.status,'resolved_review');assert.equal(resolved.revised_second,122400);assert.equal(resolved.revised_court,1);
 assert.equal(JSON.parse(await sql(role,resolve)).status,'already_resolved_review');
 // Feeder identities protect future participants even when placeholder players differ.
 await sql('postgres',"INSERT INTO ace_shared_schedule_fixture.inventory(id,owner,status,revision,venue,court,player1,player2,start_second,duration_minutes) VALUES ('round1','ace','scheduled',0,'bracket',1,'b1','b2',208800,60),('round2','ace','scheduled',0,'bracket',2,'b3','b4',223200,60),('round3','legacy','scheduled',0,'bracket',3,'b5','b6',237600,60); INSERT INTO ace_shared_schedule_fixture.feeders VALUES ('round1','round2'),('round2','round3')");
 await assert.rejects(sql('postgres',"INSERT INTO ace_shared_schedule_fixture.feeders VALUES ('round3','round1')"),/cyclic feeder graph/);
 await assert.rejects(sql(a,call('round1',0,219601,1)),/downstream chronology conflict/);
 await assert.rejects(sql(a,call('round2',0,223200,2,true)),/feeder not ready/);
 await assert.rejects(sql(a,call('round2',0,216000-1,2)),/feeder not ready/);
 assert.equal(await sql(l,call('round3',0,252000,3)),'rescheduled_review');
 assert.equal(await sql(a,call('round2',0,234000,2)),'rescheduled_review');
 assert.equal(await sql(a,call('round1',0,226800,1)),'rescheduled_review');
 assert.equal(await sql(a,call('round1',1,226800,1,true)),'started_review');
 assert.equal(await sql(a,"SELECT ace_shared_schedule_fixture.finish_slot('round1',2,230400)"),'completed_review');
 assert.equal(await sql(a,call('round2',1,234000,2,true)),'started_review');
 await sql('postgres',"INSERT INTO ace_shared_schedule_fixture.inventory(id,owner,status,revision,venue,court,player1,player2,start_second,duration_minutes) VALUES ('batch1','ace','scheduled',0,'batch',1,'c1','c2',381600,60),('batch2','legacy','scheduled',0,'batch',2,'c3','c4',388800,60),('batch3','legacy','scheduled',0,'batch',3,'c5','c6',396000,60); INSERT INTO ace_shared_schedule_fixture.feeders VALUES ('batch1','batch2'),('batch2','batch3'); INSERT INTO ace_shared_schedule_fixture.phase_policy VALUES ('batch1',4,5,3),('batch2',4,5,3),('batch3',4,5,3)");
 const worker='ace_review_worker',plan=[{id:'batch1',owner:'ace',revision:0,second:388800,court:1},{id:'batch2',owner:'legacy',revision:0,second:396000,court:2},{id:'batch3',owner:'legacy',revision:0,second:403200,court:3}];
 const batch=(key,rows)=>"SELECT ace_shared_schedule_fixture.apply_round_plan('"+key+"','"+JSON.stringify(rows)+"'::jsonb)";
 await assert.rejects(sql(a,batch('valid',plan)),/permission denied/);
 await assert.rejects(sql(worker,batch('invalid',plan.slice(0,2))),/round plan feeder conflict/);
 assert.equal(await sql('postgres',"SELECT sum(revision) FROM ace_shared_schedule_fixture.inventory WHERE id LIKE 'batch%'"),'0');
 const applied=await Promise.all([sql(worker,batch('valid',plan)),sql(worker,batch('valid',plan))]);
 assert.deepEqual(applied.map(x=>JSON.parse(x).status).sort(),['already_applied_review','applied_review']);
 assert.equal(await sql('postgres',"SELECT sum(revision) FROM ace_shared_schedule_fixture.inventory WHERE id LIKE 'batch%'"),'3');
 await assert.rejects(sql(worker,batch('valid',plan.slice(0,2))),/conflicting round plan retry/);
 await sql('postgres',"INSERT INTO ace_shared_schedule_fixture.inventory(id,owner,status,revision,venue,court,player1,player2,start_second,duration_minutes) VALUES ('auto1','ace','scheduled',0,'auto-venue',1,'d1','d2',468000,60),('auto2','legacy','scheduled',0,'auto-venue',2,'d3','d4',475200,60),('auto3','legacy','scheduled',0,'auto-venue',3,'d5','d6',482400,60); INSERT INTO ace_shared_schedule_fixture.feeders VALUES ('auto1','auto2'),('auto2','auto3'); INSERT INTO ace_shared_schedule_fixture.phase_policy VALUES ('auto1',5,5,3),('auto2',5,5,3),('auto3',5,5,3)");
 const automatic=(key,earliest)=>"SELECT ace_shared_schedule_fixture.plan_rounds('"+key+"','auto1',0,"+earliest+")";
 await assert.rejects(sql(a,automatic('auto-test',475200)),/permission denied/);
 assert.equal(JSON.parse(await sql(worker,automatic('impossible',509400))).status,'manual_review_required');
 assert.equal(await sql('postgres',"SELECT sum(revision) FROM ace_shared_schedule_fixture.inventory WHERE id LIKE 'auto%'"),'0');
 const ar=await Promise.all([sql(worker,automatic('auto-test',475200)),sql(worker,automatic('auto-test',475200))]);
 assert.deepEqual(ar.map(x=>JSON.parse(x).status).sort(),['already_planned_review','applied_review']);
 const autoPlan=JSON.parse(ar[0]).plan;
 assert.deepEqual(autoPlan.map(x=>[x.id,x.second]),[['auto1',475200],['auto2',482400],['auto3',489600]]);
 assert.equal(await sql('postgres',"SELECT sum(revision) FROM ace_shared_schedule_fixture.inventory WHERE id LIKE 'auto%'"),'3');
 await assert.rejects(sql(worker,automatic('auto-test',477000)),/conflicting planning retry/);
 console.log('PASS automatic feeder propagation, speculative rollback and concurrent request recovery');
 console.log('PASS atomic cross-engine round plan, rollback, permission guard and concurrent retry');
 console.log('PASS feeder chronology, cycle prevention, reverse-order coordinated moves and activation gate');
 console.log('PASS explicit phase bounds, owner-only automatic slot selection, no-slot escalation and exact retry');
 console.log('PASS actual completion, exact retry, conflicting completion rejection and court recovery boundary');
 console.log('PASS both engine roles share slot authority, external inventory blocks conflicts, concurrent court collision and stale revision rejected');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
