// A staging/release safety gate. No publisher secrets or implicit release claims.
import fs from 'node:fs';
const raw=fs.readFileSync(new URL('./manifest.json',import.meta.url),'utf8');
const m=JSON.parse(raw);
const mode=process.argv.includes('--release')?'release':'staging';
const blockers=Object.entries(m.blockers).filter(([k,v])=>v!==true).map(([k])=>k);
const appid=Number(m.steam_app_id);
if (mode==='release') {
  const problems=[...blockers];
  if (!Number.isInteger(appid)||appid<=0) problems.push('missing_real_app_id');
  if (m.state!=='ready_for_steam_review') problems.push('not_marked_review_ready');
  if (problems.length) {
    console.error('Steam release BLOCKED:',problems.join(', '));
    process.exit(1);
  }
  console.log('Preflight metadata passed. Manual end-to-end Steamworks review is still mandatory.');
} else {
  console.log('Steam STAGING ONLY. Pending:',blockers.join(', '));
  if (m.mode!=='online_multiplayer'||m.platform!=='windows_x64') process.exit(1);
  console.log('This staging check NEVER approves a Steam release.');
}
