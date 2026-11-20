import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
const read = p => readFileSync(new URL('../'+p, import.meta.url), 'utf8')
const registration = read('src/pages/auth/Register.tsx')
const css = read('src/styles/onboarding-enhancements.css')
const checklist = read('HELIOS_CHECKLIST.md')

test('H07: registration requires only two visible steps while preserving strong login credentials',()=>{
  assert.match(registration,/type RegisterStep = 1 \| 2/)
  assert.match(registration,/Step \{registerStep\} of 2/)
  assert.match(registration,/\(registerStep \/ 2\) \* 100/)
  assert.doesNotMatch(registration,/registerStep === 3/)
  assert.match(registration,/passwordChecks\.length && passwordChecks\.letter && passwordChecks\.number/)
  assert.match(registration,/password === confirmPassword/)
  assert.match(registration,/const formValid = accountStepValid && securityStepValid && birthdayValid/)
})

test('H07: optional birthday is collapsed, omission submits directly, and incomplete dates still block',()=>{
  assert.match(registration,/<details className="tlg-register-optional-details">/)
  assert.match(registration,/Birthday gift \(optional\)/)
  assert.match(registration,/const birthdayValid = !birthdayProvided \|\|/)
  assert.match(registration,/if \(birthdayProvided\) \{\s*setConfirmOpen\(true\)\s*\} else \{\s*void createAccount\(\)/)
  assert.match(registration,/Please provide both a valid birth month and day/)
  assert.match(registration,/No date means no birthday reward/)
  assert.match(registration,/birthday_month: birthdayComplete \? Number\(month\) : null/)
  assert.match(css,/tlg-register-optional-details/)
})

test('H07: email verification, invitations, account-to-player flow and delivery record remain intact',()=>{
  assert.match(registration,/supabase\.auth\.signUp/)
  assert.match(registration,/emailRedirectTo: .+create-player/)
  assert.match(registration,/registration_invite_token/)
  assert.match(registration,/referral_code/)
  assert.match(registration,/navigate\('\/create-player'/)
  assert.match(registration,/No payment details required/)
  assert.match(checklist,/\*\*H07\*\*/)
  assert.match(checklist,/mobile and authenticated new-signup browser testing/)
})
