'use strict';
const assert=require('node:assert/strict'),{spawn,execFile}=require('node:child_process'),{promisify}=require('node:util'),run=promisify(execFile);
const {isolatedSchedulePoller}=require('./shared-schedule-poller.cjs'),{connection}=require('./postgres-store.cjs');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const args=['-X','-qAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p','55432','-d','ace_review'];
async function admin(q){return (await run('psql',[...args,'-U','postgres','-c',q],{env:{...process.env,PGPASSWORD:'ace-disposable-admin'}})).stdout.trim();}
async function until(fn){for(let i=0;i<100;i++){if(await fn())return;await delay(100);}throw Error('Recovery test timed out');}
async function main(){
 assert.throws(()=>isolatedSchedulePoller({}),/opt-in/);
 const db=connection(),errors=[];
 await admin("INSERT INTO ace_shared_schedule_fixture.inventory(id,owner,status,revision,venue,court,player1,player2,start_second,duration_minutes,actual_end_second) VALUES ('kill-source','ace','completed',2,'kill-venue',1,'k1','k2',640800,60,651600),('kill-target','legacy','scheduled',0,'kill-venue',2,'k1','k3',648000,60,NULL); INSERT INTO ace_shared_schedule_fixture.phase_policy VALUES ('kill-target',7,8,2); INSERT INTO ace_shared_schedule_fixture.obligations VALUES ('kill-source','kill-target','legacy',0,true,false,655200,648000)");
 const child=spawn('psql',[...args,'-U','ace_review_worker'],{env:{...process.env,PGPASSWORD:'ace-disposable-worker'},stdio:['pipe','pipe','pipe']});
 let out='',err='';child.stdout.on('data',c=>out+=c);child.stderr.on('data',c=>err+=c);
 const closed=new Promise((resolve,reject)=>{child.once('close',resolve);child.once('error',reject);});
 child.stdin.write("BEGIN; SELECT ace_shared_schedule_fixture.drain_schedule_queue(1);\n\\echo DRAIN_UNCOMMITTED\n");
 try{
  await until(()=>out.includes('DRAIN_UNCOMMITTED')||child.exitCode!==null);
  assert.ok(out.includes('DRAIN_UNCOMMITTED'),err);
  assert.equal(JSON.parse(await db.sql('SELECT ace_shared_schedule_fixture.drain_schedule_queue(1);')).status,'busy');
  assert.equal(await admin("SELECT state||':'||attempts FROM ace_shared_schedule_fixture.queue WHERE target_id='kill-target'"),'pending:0');
 }finally{child.kill('SIGKILL');await closed;}
 const poller=isolatedSchedulePoller(process.env,e=>errors.push(e));
 try{poller.start();await until(async()=>await admin("SELECT state FROM ace_shared_schedule_fixture.queue WHERE target_id='kill-target'")==='resolved');}finally{await poller.stop();}
 assert.deepEqual(errors,[]);
 assert.equal(await admin("SELECT state||':'||attempts FROM ace_shared_schedule_fixture.queue WHERE target_id='kill-target'"),'resolved:1');
 assert.equal(await admin("SELECT revision||':'||start_second FROM ace_shared_schedule_fixture.inventory WHERE id='kill-target'"),'1:655200');
 assert.equal(await admin("SELECT count(*) FROM ace_shared_schedule_fixture.reconciliations WHERE target_id='kill-target'"),'1');
 assert.equal(JSON.parse(await db.sql('SELECT ace_shared_schedule_fixture.drain_schedule_queue(1);')).processed,0);
 console.log('PASS forced worker termination, uncommitted rollback, concurrent busy protection, restarted poller and exactly-once reconciliation');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
