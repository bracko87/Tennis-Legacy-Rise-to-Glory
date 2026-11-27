'use strict';
const assert=require('node:assert/strict'),{execFile}=require('node:child_process'),{promisify}=require('node:util'),run=promisify(execFile);
function sql(role,query){const password=role==='postgres'?'ace-disposable-admin':role==='ace_cutover_ace'?'ace-disposable-ace':'ace-disposable-legacy';return run('psql',['-X','-qAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p','55432','-U',role,'-d','ace_review','-c',query],{env:{...process.env,PGPASSWORD:password}}).then(r=>r.stdout.trim());}
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
 console.log('PASS actual completion, exact retry, conflicting completion rejection and court recovery boundary');
 console.log('PASS both engine roles share slot authority, external inventory blocks conflicts, concurrent court collision and stale revision rejected');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
