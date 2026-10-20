// Run on Node 22+: node --experimental-strip-types --test tests/trainingOptimizationModel.test.mjs
import assert from 'node:assert/strict'
import test from 'node:test'
import {
  analyzeTrainingChoices, complementarySkill, suggestedFocusRotation, weakestSkill,
} from '../src/lib/trainingOptimizationModel.ts'

const event = (focus, gain, week = 1, source = 'regular') => ({
  source, activity: source === 'regular' ? 'technical' : 'camp_development',
  focus_attribute: focus, season: 1, game_week: week,
  efficiency: 0.8, gains: { serve: gain, forehand: 0.01 },
})

test('camp days and invalid regular events are excluded from focus comparisons', () => {
  const data = [
    event('serve', 0.5),
    event('serve', 0.7),
    event('serve', 0.9, 2, 'camp'),
    event(null, 42),
    event('unknown', 20),
  ]
  const results = analyzeTrainingChoices(data, 'serve')
  assert.equal(results.regularCount, 2)
  assert.equal(results.cohorts.length, 1)
  assert.equal(results.cohorts[0].focus, 'serve')
  assert.equal(results.cohorts[0].targetGain, 0.6)
  assert.equal(results.goalFocusedCount, 2)
  assert.equal(results.compared, false)
})

test('two groups each with three observations enable a descriptive comparison', () => {
  const data = [
    ...Array.from({length: 3}, () => event('serve', 0.2)),
    ...Array.from({length: 3}, () => event('forehand', 0.1)),
  ]
  const results = analyzeTrainingChoices(data, 'serve')
  assert.equal(results.compared, true)
  assert.equal(results.cohorts[0].focus, 'serve')
  assert.equal(results.recentTrend, null)
})

test('trends require 12 regular sessions across three distinct game weeks', () => {
  const recent = Array.from({length: 6}, () => event('serve', 0.4, 3))
  const older = [
    ...Array.from({length: 3}, () => event('serve', 0.2, 2)),
    ...Array.from({length: 3}, () => event('serve', 0.2, 1)),
  ]
  const report = analyzeTrainingChoices([...recent, ...older], 'serve')
  assert.equal(report.recentTrend?.recent, 0.4)
  assert.equal(report.recentTrend?.previous, 0.2)
  assert.equal(analyzeTrainingChoices([...recent, ...older].map(x => ({...x, game_week: 3})), 'serve').recentTrend, null)
})

test('weakest-skill priorities and read-only rotations stay within available slots', () => {
  const scores = { serve: 50, forehand: 60, backhand: 55, fitness: 40, stamina: 45, recovery: 48, movement: 47 }
  assert.equal(weakestSkill(scores), 'fitness')
  assert.equal(complementarySkill('serve', scores), 'fitness')
  assert.deepEqual(suggestedFocusRotation('serve', 'fitness', 4, 'focused'),
    ['serve', 'serve', 'serve', 'fitness'])
  assert.deepEqual(suggestedFocusRotation('serve', 'fitness', 4, 'balanced'),
    ['serve', 'fitness', 'serve', 'fitness'])
  assert.equal(suggestedFocusRotation('serve', 'fitness', 99, 'focused').length, 4)
})
