/**
 * GameHeader.tsx
 *
 * Header bar used on all in-game dashboard pages. Displays the current
 * page title, player identity placeholder, world badge and quick actions.
 */

import AppButton from '../common/AppButton'

/**
 * Props for the GameHeader component.
 */
export interface GameHeaderProps {
  /** Title of the current in-game page. */
  title: string
  /** Optional subtitle describing the current view. */
  subtitle?: string
  /** Callback to toggle the sidebar on mobile screens. */
  onToggleSidebarMobile?: () => void
}

/**
 * Renders the in-game header with page title and player/world placeholders.
 */
export default function GameHeader({
  title,
  subtitle,
  onToggleSidebarMobile,
}: GameHeaderProps) {
  return (
    <header className="tlg-game-header">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 md:px-6">
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={onToggleSidebarMobile}
            className="inline-flex h-8 w-8 items-center justify-center rounded-md border border-[rgba(15,23,42,0.7)] bg-[rgba(15,23,42,0.8)] text-[rgba(226,232,240,0.9)] hover:bg-[rgba(15,23,42,1)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[rgba(191,219,254,0.9)] md:hidden"
            aria-label="Toggle navigation"
          >
            <span className="h-3 w-3">
              <span className="block h-0.5 w-full bg-[rgba(226,232,240,0.9)]" />
              <span className="mt-1 block h-0.5 w-full bg-[rgba(226,232,240,0.9)]" />
            </span>
          </button>

          <div className="space-y-0.5">
            <p className="tlg-page-heading-eyebrow">
              Tennis Legacy · Manager View
            </p>
            <div>
              <h1 className="text-base font-semibold tracking-wide text-[color:var(--tlg-white)] md:text-lg">
                {title}
              </h1>
              {subtitle && (
                <p className="text-[0.8rem] text-[rgba(226,232,240,0.82)]">
                  {subtitle}
                </p>
              )}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="hidden items-center gap-2 rounded-full border border-[rgba(191,219,254,0.45)] bg-[rgba(15,23,42,0.35)] px-2 py-1 text-[0.8rem] font-medium text-[rgba(226,232,240,0.9)] sm:flex">
            <span className="inline-flex h-5 w-5 items-center justify-center rounded-full bg-[rgba(37,99,235,0.8)] text-[0.6rem] font-bold">
              W
            </span>
            <span>World · ATP / WTA</span>
          </div>

          <button
            type="button"
            aria-label="Notifications"
            className="inline-flex h-8 w-8 items-center justify-center rounded-md border border-[rgba(191,219,254,0.5)] bg-[rgba(15,23,42,0.4)] text-[rgba(226,232,240,0.9)] hover:bg-[rgba(15,23,42,0.95)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[rgba(191,219,254,0.9)]"
          >
            <span className="h-3 w-3 rounded-full border border-[rgba(226,232,240,0.9)]" />
          </button>

          <AppButton variant="secondary">
            <span className="hidden text-xs md:inline">
              Player Account
            </span>
            <span className="inline-flex h-6 w-6 items-center justify-center rounded-full border border-[rgba(191,219,254,0.5)] text-[0.65rem]">
              TL
            </span>
          </AppButton>
        </div>
      </div>
    </header>
  )
}