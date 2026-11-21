// Assemble a DISPOSABLE real Supabase Auth fixture from checked-in Helios SQL.
// No remote access; no production schema snapshot, user data, or deployed SQL changes.
import fs from 'node:fs'
import path from 'node:path'
import {fileURLToPath} from 'node:url'
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..')
const target=path.join(root,'.helios-guest-sandbox')
if(process.env.GITHUB_ACTIONS!=='true')throw Error('This disposable fixture builder is CI-only.')
if(fs.existsSync(target))throw Error('Refusing to overwrite an existing sandbox.')
const migrations=path.join(target,'supabase','migrations')
const config=[
 'project_id = "tennis_helios_guest_sandbox"',
 '[api]','enabled = true','port = 54341',
 '[db]','port = 54342','shadow_port = 54340','major_version = 17',
 '[studio]','enabled = false',
 '[local_smtp]','enabled = true','port = 54344',
 '[auth]','enabled = true','enable_anonymous_sign_ins = true','enable_manual_linking = true',
 'site_url = "http://127.0.0.1:8002"',
 'additional_redirect_urls = ["http://127.0.0.1:8002/guest/register"]',
 '[auth.email]','enable_confirmations = true',
 '[db.seed]','enabled = false',
].join('\n')+'\n'
const source=(name)=>fs.readFileSync(path.join(root,'supabase','migrations',name),'utf8')
const gate=source('20261120151000_helios_h01_anonymous_signup_gated.sql')
const stop=gate.indexOf('CREATE OR REPLACE FUNCTION public.grant_new_career_starting_coins_v1')
if(stop<0||!gate.includes('CREATE OR REPLACE FUNCTION public.handle_new_user()'))throw Error('Authoritative gate/profile SQL changed; review extraction.')
const files=[
 ['20261121000000_fixture.sql',fs.readFileSync(path.join(root,'tests','fixtures','helios_real_auth_ci_schema.sql'),'utf8')],
 ['20261121000001_guest_foundation.sql',source('20261120133000_helios_h01_guest_trial_foundation.sql')],
 ['20261121000002_auth_gate.sql',gate.slice(0,stop)+
  '\nCREATE TRIGGER aa_block_public_registration_v1 BEFORE INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.enforce_public_registration_gate_v1();\nCREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();\n'],
 ['20261121000003_trial_premium.sql',source('20261120160000_helios_h08_guest_premium_trial.sql')],
 ['20261121000004_conversion.sql',source('20261120180500_helios_h02_guest_identity_conversion.sql')],
 ['20261121000005_retired_fields.sql','ALTER TABLE control_center_private.tennis_guest_trials_v1 ADD COLUMN retired_at timestamptz, ADD COLUMN retirement_reason text;\n'],
 ['20261121000006_retired_conversion.sql',source('20261120195500_helios_retired_guest_conversion_guard.sql')],
 ['20261121000007_enable_local_gate.sql','UPDATE public.registration_control SET guest_test_enabled=true WHERE singleton_id=true;\n'],
]
fs.mkdirSync(migrations,{recursive:true})
fs.writeFileSync(path.join(target,'supabase','config.toml'),config)
for(const [name,sql] of files)fs.writeFileSync(path.join(migrations,name),sql)
console.log('Prepared disposable actual Auth stack using checked-in guest enrollment and conversion SQL. Not a full-schema test.')
