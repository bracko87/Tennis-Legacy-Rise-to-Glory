/**
 * GameFooter.tsx
 *
 * Global in-game footer showing the centralized game time placeholder
 * and the abstracted season-time rule used by Tennis Legacy.
 */

 /**
  * Renders the in-game footer with game-time display and time rule.
  * The displayed value is a static placeholder; a future Supabase-backed
  * global clock will control the real in-game time.
  */
export default function GameFooter() {
  return (
    <footer className="tlg-game-footer">
      <div className="mx-auto flex max-w-6xl flex-col gap-3 px-4 py-3 text-[0.8rem] text-[rgba(226,232,240,0.85)] md:flex-row md:items-center md:justify-between md:px-6">
        <div className="flex items-center gap-3">
          <div className="tlg-game-time-pill">
            <span className="inline-flex h-5 w-5 items-center justify-center rounded-full border border-[rgba(191,219,254,0.7)] bg-[rgba(15,23,42,0.9)] text-[0.62rem] font-semibold uppercase tracking-[0.18em]">
              TL
            </span>
            <span className="font-medium">
              Season 1 · March 14 · 18:00
            </span>
          </div>
        </div>
        <p className="text-[0.78rem] text-[rgba(148,163,184,0.9)]">
          1 real hour = 2 game hours. This value is a display-only
          placeholder and will be synchronized by a Supabase-controlled
          global clock.
        </p>
      </div>
    </footer>
  )
}