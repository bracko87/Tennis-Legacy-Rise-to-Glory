import assert from 'node:assert/strict'
import test from 'node:test'
import { normalizePlayerName } from '../src/lib/playerName.ts'

test('corrects ordinary capitalization mistakes', () => {
  for (const [input, expected] of [['Denis','Denis'],['JAnsen','Jansen'],['jone','Jone'],['nadoul','Nadoul'],['DENIS','Denis'],['jean-pierre','Jean-Pierre'],['álvaro','Álvaro']]) {
    assert.equal(normalizePlayerName(input), expected)
  }
})
test('preserves intentional mixed case and surname particles', () => {
  for (const [input, expected] of [['McDonald','McDonald'],['MacDonald','MacDonald'],['Seo-yeon','Seo-yeon'],['O’Sullivan','O’Sullivan'],['van Dijk','van Dijk'],['Van Dijk','Van Dijk'],['VAN DER MEER','van der Meer'],['de vries','de Vries'],['  de   Vries  ','de Vries']]) {
    assert.equal(normalizePlayerName(input, true), expected)
  }
})
