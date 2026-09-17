from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing replacement target: {label}")
    return text.replace(old, new, 1)


# Add one shared, reference-counted body scroll lock so stacked dialogs cannot
# restore a stale `overflow: hidden` value after they close in a different order.
lock_path = Path('src/lib/bodyScrollLock.ts')
lock_path.write_text("""let activeBodyScrollLocks = 0
let originalBodyOverflow = ''

export function lockBodyScroll() {
  if (typeof document === 'undefined') return () => undefined

  const body = document.body
  if (activeBodyScrollLocks === 0) {
    originalBodyOverflow = body.style.overflow
    body.style.overflow = 'hidden'
  }
  activeBodyScrollLocks += 1

  let released = false
  return () => {
    if (released) return
    released = true
    activeBodyScrollLocks = Math.max(0, activeBodyScrollLocks - 1)

    if (activeBodyScrollLocks === 0) {
      body.style.overflow = originalBodyOverflow
      originalBodyOverflow = ''
    }
  }
}
""")

# Equipment details modal: replace its independent overflow bookkeeping with the
# shared lock manager. Keeping the existing dependencies is now safe because a
# cleanup/re-run simply releases/reacquires its own lock instead of capturing
# another modal's `overflow: hidden` as the value to restore later.
eq_path = Path('src/pages/dashboard/Equipment.tsx')
eq = eq_path.read_text()
eq = replace_once(
    eq,
    "import { supabase } from '../../lib/supabase'\n",
    "import { lockBodyScroll } from '../../lib/bodyScrollLock'\nimport { supabase } from '../../lib/supabase'\n",
    'Equipment body scroll lock import',
)
eq = replace_once(
    eq,
    """  useEffect(() => {\n    if (!selectedMarketItem && !selectedInventoryItem) return\n    const previousOverflow = document.body.style.overflow\n    document.body.style.overflow = 'hidden'\n    const closeOnEscape = (event: KeyboardEvent) => {\n      if (event.key !== 'Escape' || pendingPurchase || pendingSale || pendingDiscard) return\n      setSelectedMarketItem(null)\n      setSelectedInventoryItem(null)\n    }\n    window.addEventListener('keydown', closeOnEscape)\n    return () => { document.body.style.overflow = previousOverflow; window.removeEventListener('keydown', closeOnEscape) }\n  }, [selectedMarketItem, selectedInventoryItem, pendingPurchase, pendingSale, pendingDiscard])\n""",
    """  useEffect(() => {\n    if (!selectedMarketItem && !selectedInventoryItem) return\n    const unlockBodyScroll = lockBodyScroll()\n    const closeOnEscape = (event: KeyboardEvent) => {\n      if (event.key !== 'Escape' || pendingPurchase || pendingSale || pendingDiscard) return\n      setSelectedMarketItem(null)\n      setSelectedInventoryItem(null)\n    }\n    window.addEventListener('keydown', closeOnEscape)\n    return () => {\n      window.removeEventListener('keydown', closeOnEscape)\n      unlockBodyScroll()\n    }\n  }, [selectedMarketItem, selectedInventoryItem, pendingPurchase, pendingSale, pendingDiscard])\n""",
    'Equipment modal scroll effect',
)
eq_path.write_text(eq)

# Shared confirmation dialog can be stacked above the equipment details dialog.
# It must participate in the same lock count instead of remembering a local
# previousOverflow value (which may already be "hidden").
confirm_path = Path('src/components/common/GameConfirmDialog.tsx')
confirm = confirm_path.read_text()
confirm = replace_once(
    confirm,
    "import { useEffect, useRef, type ReactNode } from 'react'\n\nimport '../../styles/game-confirm-dialog.css'\n",
    "import { useEffect, useRef, type ReactNode } from 'react'\n\nimport { lockBodyScroll } from '../../lib/bodyScrollLock'\nimport '../../styles/game-confirm-dialog.css'\n",
    'GameConfirmDialog body scroll lock import',
)
confirm = replace_once(
    confirm,
    """    const previousOverflow = document.body.style.overflow\n    document.body.style.overflow = 'hidden'\n    const frame = window.requestAnimationFrame(() => cancelButtonRef.current?.focus())\n""",
    """    const unlockBodyScroll = lockBodyScroll()\n    const frame = window.requestAnimationFrame(() => cancelButtonRef.current?.focus())\n""",
    'GameConfirmDialog lock acquisition',
)
confirm = replace_once(
    confirm,
    """      window.cancelAnimationFrame(frame)\n      window.removeEventListener('keydown', onKeyDown)\n      document.body.style.overflow = previousOverflow\n""",
    """      window.cancelAnimationFrame(frame)\n      window.removeEventListener('keydown', onKeyDown)\n      unlockBodyScroll()\n""",
    'GameConfirmDialog lock cleanup',
)
confirm_path.write_text(confirm)

# The console warning visible in the screenshot is separate from the scroll bug:
# the accessory select() helper returns labels from a map without a React key.
setup_path = Path('src/components/equipment/EquipmentMatchSetupsEnhancement.tsx')
setup = setup_path.read_text()
setup = replace_once(
    setup,
    "=> <label className=\"tlg-match-setup-field\">",
    "=> <label key={label} className=\"tlg-match-setup-field\">",
    'custom match setup mapped label key',
)
setup_path.write_text(setup)

print('Applied equipment modal scroll-lock fix and React key warning fix.')
