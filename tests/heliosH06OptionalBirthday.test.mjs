import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const read = path => readFileSync(new URL('../'+path, import.meta.url), 'utf8')
const sql = read('supabase/migrations/20261120123000_helios_h06_optional_birthday.sql')
const registration = read('src/pages/auth/Register.tsx')
const checklist = read('HELIOS_CHECKLIST.md')

test('H06: birthday is optional as an all-or-none profile value, not a fake default', () => {
  assert.match(sql, /ALTER COLUMN birthday_month DROP NOT NULL/)
  assert.match(sql, /ALTER COLUMN birthday_day DROP NOT NULL/)
  assert.match(sql, /profiles_birthday_complete_or_blank_h06/)
  assert.match(sql, /birthday_month IS NULL AND birthday_day IS NULL AND birthday_year IS NULL/)
  assert.match(sql, /birthday_month IS NOT NULL AND birthday_day IS NOT NULL/)
})

test('H06: account creation accepts empty birthday and rejects partial/invalid dates', () => {
  assert.match(sql, /if v_month is null then/)
  assert.match(sql, /\(v_month is null\) <> \(v_day is null\)/)
  assert.match(sql, /v_month is null and v_year is not null/)
  assert.match(sql, /perform make_date\(2000,v_month,v_day\)/)
  assert.match(sql, /v_birth_date:=make_date\(v_year,v_month,v_day\)/)
  assert.match(registration, /const birthdayValid = !birthdayProvided \|\|/)
  assert.match(registration, /birthday_month: birthdayComplete \? Number\(month\) : null/)
  assert.match(registration, /birthday_day: birthdayComplete \? Number\(day\) : null/)
  assert.match(registration, /birthday_year: birthdayComplete && yearProvided \? Number\(year\) : null/)
})

test('H06: birthday scheduler skips blank dates; reward requires a matching date', () => {
  assert.match(sql, /and p\.birthday_month is not null/)
  assert.match(sql, /and p\.birthday_day is not null/)
  assert.match(sql, /birthday_matches_local_date_v1/)
  assert.match(sql, /raise exception 'Birthday reward not eligible\.'/)
  assert.match(registration, /No date means no birthday reward/)
  assert.match(registration, /Confirm registration without a birthday/)
  assert.match(checklist, /\*\*H06\*\*/)
})
