/**
 * A browser-only UI preference shared by all GameLayout mounts.
 * Store only the desktop sidebar choice; the mobile drawer stays transient.
 */
export const GAME_SIDEBAR_PREFERENCE_KEY = 'tlg:game-sidebar-collapsed:v2'

type SidebarPreferenceStorage = Pick<Storage, 'getItem' | 'setItem'>

function browserStorage(): SidebarPreferenceStorage | null {
  if (typeof window === 'undefined') return null
  try {
    return window.localStorage
  } catch {
    // Some browsers block storage (privacy modes, embedded contexts, etc.).
    return null
  }
}

export function readSidebarCollapsed(
  storage: SidebarPreferenceStorage | null = browserStorage(),
): boolean {
  // The original key stored the old expanded default even without a click.
  // Start collapsed once on this version; subsequent explicit choices persist.
  try {
    return storage?.getItem(GAME_SIDEBAR_PREFERENCE_KEY) !== '0'
  } catch {
    return true
  }
}

export function saveSidebarCollapsed(
  collapsed: boolean,
  storage: SidebarPreferenceStorage | null = browserStorage(),
): void {
  try {
    storage?.setItem(GAME_SIDEBAR_PREFERENCE_KEY, collapsed ? '1' : '0')
  } catch {
    // Navigation must work even if preferences cannot be persisted.
  }
}
