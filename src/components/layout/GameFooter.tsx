import { Clock3, Radio } from 'lucide-react'

export default function GameFooter() {
  return (
    <footer className="border-t border-[rgba(112,168,213,.08)] bg-[rgba(3,10,18,.54)]">
      <div className="flex min-h-[58px] flex-col gap-2 px-5 py-3 text-[0.65rem] text-[color:#58748b] md:flex-row md:items-center md:justify-between lg:px-7">
        <div className="flex flex-wrap items-center gap-3">
          <span className="inline-flex items-center gap-1.5 rounded-lg border border-[rgba(109,169,214,.09)] bg-[rgba(7,26,44,.45)] px-2.5 py-1.5 text-[color:#7996ad]">
            <Clock3 size={12} />
            Season 1 · Global clock pending
          </span>
          <span className="inline-flex items-center gap-1.5 text-[color:#557189]">
            <Radio size={11} />
            1 real hour = 2 game hours
          </span>
        </div>
        <span>Persistent multiplayer career simulation · server-authoritative game state</span>
      </div>
    </footer>
  )
}
