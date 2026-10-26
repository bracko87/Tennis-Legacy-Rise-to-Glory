// node --experimental-strip-types --test tests/sidebarPreference.test.mjs
import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
  GAME_SIDEBAR_PREFERENCE_KEY,
  readSidebarCollapsed,
  saveSidebarCollapsed,
} from '../src/lib/sidebarPreference.ts'

function storageFixture() {
  const values = new Map()
  return {
    values,
    getItem(key) { return values.get(key) ?? null },
    setItem(key, value) { values.set(key, value) },
  }
}

test('sidebar starts expanded until the user collapses it', () => {
  const storage = storageFixture()
  assert.equal(readSidebarCollapsed(storage), false)
  assert.equal(storage.values.size, 0)
})

test('collapsed preference survives new layout mounts and remains until explicitly expanded', () => {
  const storage = storageFixture()
  saveSidebarCollapsed(true, storage)
  assert.equal(storage.values.get(GAME_SIDEBAR_PREFERENCE_KEY), '1')
  assert.equal(readSidebarCollapsed(storage), true)
  // A new GameLayout mount on another route restores the same choice.
  assert.equal(readSidebarCollapsed(storage), true)
  saveSidebarCollapsed(false, storage)
  assert.equal(readSidebarCollapsed(storage), false)
  assert.equal(storage.values.get(GAME_SIDEBAR_PREFERENCE_KEY), '0')
})

test('invalid values and unavailable browser storage fail safely', () => {
  const storage = storageFixture()
  storage.values.set(GAME_SIDEBAR_PREFERENCE_KEY, 'invalid')
  assert.equal(readSidebarCollapsed(storage), false)
  assert.equal(readSidebarCollapsed(null), false)
  assert.doesNotThrow(() => saveSidebarCollapsed(true, null))
  const blocked = {
    getItem() { throw new Error('Storage access denied') },
    setItem() { throw new Error('Storage access denied') },
  }
  assert.equal(readSidebarCollapsed(blocked), false)
  assert.doesNotThrow(() => saveSidebarCollapsed(true, blocked))
})

test('GameLayout initializes from preference and saves the choice; mobile drawer is independent', () => {
  const layout = readFileSync(new URL('../src/components/layout/GameLayout.tsx', import.meta.url), 'utf8')
  assert.match(layout, /useState\(readSidebarCollapsed\)/)
  assert.match(layout, /saveSidebarCollapsed\(sidebarCollapsed\)/)
  assert.match(layout, /setSidebarCollapsed\(\(value\) => !value\)/)
  assert.match(layout, /const \[sidebarMobileOpen, setSidebarMobileOpen\] = useState\(false\)/)
})
