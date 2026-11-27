'use strict';
const assert=require('node:assert/strict'),{spawn}=require('node:child_process'),{connection}=require('./postgres-store.cjs'),{fixture}=require('./medical-settlement.test.cjs'),{project}=require('./official-settlement-review.cjs');
const db=connection(),clone=x=>JSON.parse(JSON.stringify(x));
const lit=x=>x===null?'NULL':"convert_from(decode('"+Buffer.from(String(x)).toString('base64')+"','base64'),'UTF8')";
const json=x=>lit(JSON.stringify(x))+'::jsonb';
function engine(role,sql){
 assert.ok(['ace','legacy','external'].includes(role));assert.equal(process.env.ACE_REVIEW_DB,'1');
 const port=Number(process.env.ACE_REVIEW_DB_PORT||55432);assert.ok(Number.isInteger(port)&&port>=1024&&port<=65535);
 return new Promise((resolve,reject)=>{
  const p=spawn('psql',['-X','-qAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',String(port),'-U','ace_cutover_'+role,'-d','ace_review','-w'],{env:{PATH:process.env.PATH,PGPASSWORD:'ace-disposable-'+role,PGCONNECT_TIMEOUT:'5',PGSSLMODE:'disable'},stdio:['pipe','pipe','pipe']});
  let out='',err='';const t=setTimeout(()=>{p.kill();reject(Error('cutover timeout'));},15000);
  p.stdout.on('data',x=>out+=x);p.stderr.on('data',x=>err+=x);p.stdin.on('error',()=>{});
  p.on('error',e=>{clearTimeout(t);reject(e);});p.on('close',code=>{clearTimeout(t);code===0?resolve(out.trim()):reject(Error(err));});p.stdin.end(sql+'\n');
 });
}
const q=(role,fn)=>engine(role,'SELECT ace_cutover_review.'+fn+';'),control=fn=>db.sql('SELECT ace_cutover_review.'+fn+';');
const freeze=(id,day,a,b)=>control('freeze_medical('+[lit(id),day,json(a),json(b)].join(',')+')');
const finish=(role,m,rev=1)=>q(role,'finish_medical('+[lit(m.match_id),rev,json(m)].join(',')+')');
const claim=async(role,id)=>JSON.parse(await q(role,'claim('+lit(id)+')'));
const start=(id,rev=1)=>q('ace','start_match('+lit(id)+','+rev+')');
const settle=x=>q('ace','settle_owned('+json(x)+',NULL)');
async function register(id){await control('register_competition('+lit(id)+')');await control('configure(true,ARRAY['+lit(id)+'])');}
async function seed(id,m,a=null,b=null){await control('seed_match('+[m.match_id,id,'singles'].map(lit).join(',')+",true,'scheduled','none',false,"+[m.player1_id,m.player2_id].map(lit).join(',')+')');await control('bind_feeders('+[m.match_id,a,b].map(lit).join(',')+')');}
async function run(){
 const c='identity-protected-ci';await register(c);
 const old=id=>db.sql('SELECT ace_review.claim_finalization('+[id,'foreign-competition','legacy','p1','p2'].map(lit).join(',')+',NULL,NULL);');
 const row=id=>({match_id:id,player1_id:'p1',player2_id:'p2'});
 await seed(c,row('identity-reserved'));await assert.rejects(old('identity-reserved'),/rejected/);
 assert.equal(await db.sql("SELECT count(*) FROM ace_review.finalization_claims WHERE match_id='identity-reserved';"),'0');
 assert.equal(await old('identity-preexisting'),'claimed');await assert.rejects(seed(c,row('identity-preexisting')),/rejected/);
 assert.equal(await db.sql("SELECT count(*) FROM ace_cutover_review.matches WHERE id='identity-preexisting';"),'0');
 const key='identity-concurrent';
 const race=await Promise.allSettled([old(key),seed(c,row(key))]);assert.equal(race.filter(x=>x.status==='fulfilled').length,1);
 assert.equal(await db.sql("SELECT (SELECT count(*) FROM ace_review.finalization_claims WHERE match_id='identity-concurrent')+(SELECT count(*) FROM ace_cutover_review.matches WHERE id='identity-concurrent');"),'1');
 await control("configure(false,ARRAY[]::text[])");
 console.log('PASS protected match identity reservation, foreign claim rejection and concurrent preclaim/seed exclusion');
}
run().catch(e=>{console.error(e);process.exitCode=1});
