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
 console.log('PASS both engine roles share slot authority, external inventory blocks conflicts, concurrent court collision and stale revision rejected');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
