import assert from 'node:assert/strict'
import test from 'node:test'
import { isPortraitReservationConflict } from '../src/lib/playerCreationConflict.ts'

test('database city uniqueness errors do not clear the selected portrait', () => {
  assert.equal(isPortraitReservationConflict({
    code: '23505',
    message: 'duplicate key value violates unique constraint "private_life_property_locations_country_code_city_key"',
  }), false)
})

test('a genuine portrait reservation collision can prompt a different portrait', () => {
  assert.equal(isPortraitReservationConflict({
    code: '23505',
    message: 'duplicate key value violates unique constraint "player_avatar_reservations_pkey"',
  }), true)
})

test('existing account uniqueness and unrelated errors are not portrait conflicts', () => {
  assert.equal(isPortraitReservationConflict({
    code: '23505',
    message: 'duplicate key value violates unique constraint "players_owner_user_id_key"',
  }), false)
  assert.equal(isPortraitReservationConflict({
    code: '23503',
    message: 'violates foreign key constraint "players_country_code_fkey"',
  }), false)
})
