import test from 'node:test'
import assert from 'node:assert/strict'
import {parseStatus,requireLocalUrl,assertTrial,restrictedFetch} from '../scripts/helios-local-guest-auth-acceptance.mjs'
const publicKey='sb_publishable_disposable_test_key_only'
test('localhost guard rejects other hosts, ports, TLS, credentials and remote URLs',()=>{
  assert.equal(requireLocalUrl('http://127.0.0.1:54341',54341).hostname,'127.0.0.1')
  for(const url of ['https://127.0.0.1:54341','http://127.0.0.1:54321',
    'http://evil.example:54341','http://guest:secret@127.0.0.1:54341','https://cwfznmroiqcyhfkfcrow.supabase.co']){
    assert.throws(()=>requireLocalUrl(url,54341))
  }
})
test('status parsing accepts local public key, never a privileged token',()=>{
  assert.deepEqual(parseStatus('API_URL="http://127.0.0.1:54341"\nPUBLISHABLE_KEY="'+publicKey+'"'),
    {origin:'http://127.0.0.1:54341',key:publicKey})
  const jwt=claims=>'eyJhbGciOiJIUzI1NiJ9.'+Buffer.from(JSON.stringify(claims)).toString('base64url')+'.dummy'
  assert.throws(()=>parseStatus('API_URL="http://127.0.0.1:54341"\nANON_KEY="'+jwt({role:'service_role'})+'"'))
  assert.throws(()=>parseStatus('API_URL="http://127.0.0.1:54341"\nSERVICE_ROLE_KEY="'+jwt({role:'service_role'})+'"'))
  assert.throws(()=>parseStatus('API_URL="https://cwfznmroiqcyhfkfcrow.supabase.co"\nPUBLISHABLE_KEY="'+publicKey+'"'))
  assert.throws(()=>parseStatus('API_URL="http://127.0.0.1:54341/more"\nPUBLISHABLE_KEY="'+publicKey+'"'))
})
test('restricted fetch rejects a remote destination before making any request',async()=>{
  await assert.rejects(restrictedFetch('https://example.invalid/'))
  await assert.rejects(restrictedFetch('http://127.0.0.1:54342/'))
})
test('trial acceptance rejects a changed lifetime, duplicate benefit or inactive Premium',()=>{
  const a={state:'active',is_guest:true,can_play:true,premium_trial_active:true,
    started_at:'2026-11-21T00:00:00Z',expires_at:'2026-12-05T00:00:00Z',
    premium_expires_at:'2026-11-28T00:00:00Z'}
  assert.doesNotThrow(()=>assertTrial(a,{...a}))
  assert.throws(()=>assertTrial(a,{...a,expires_at:'2026-12-06T00:00:00Z'}))
  assert.throws(()=>assertTrial({...a,premium_trial_active:false},a))
  assert.throws(()=>assertTrial({...a,premium_expires_at:'2026-11-29T00:00:00Z'},a))
})
