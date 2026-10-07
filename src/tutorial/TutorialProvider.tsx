import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from 'react'
import { createPortal } from 'react-dom'
import { ChevronLeft, ChevronRight, GraduationCap, Pause, X } from 'lucide-react'
import { useLocation, useNavigate } from 'react-router'

import { useAuth } from '../auth/AuthContext'
import { supabase } from '../lib/supabase'
import {
  TUTORIAL_PHASES,
  TUTORIAL_STEPS,
  TUTORIAL_VERSION,
  getTutorialPhase,
  getTutorialPhaseSteps,
  getTutorialResources,
  normalizeTutorialLocale,
  type TutorialStep,
} from './tutorialContent'
import '../styles/game-tutorial.css'

type TutorialStatus = 'loading' | 'available' | 'active' | 'paused' | 'completed' | 'skipped'

type TutorialProgressRow = {
  player_id: string
  tutorial_version: string
  status: Exclude<TutorialStatus, 'loading'>
  current_step_id: string | null
  completed_step_ids: string[]
  locale: string
  started_at: string | null
  completed_at: string | null
  skipped_at: string | null
  updated_at: string
}

type TutorialContextValue = {
  status: TutorialStatus
  currentStep: TutorialStep | null
  currentStepIndex: number
  totalSteps: number
  restartTutorial: () => Promise<void>
  resumeTutorial: () => Promise<void>
  pauseTutorial: () => Promise<void>
  skipTutorial: () => Promise<void>
}

const TutorialContext = createContext<TutorialContextValue | null>(null)

type TargetRect = {
  top: number
  left: number
  width: number
  height: number
  bottom: number
  right: number
}

function readLocale() {
  return normalizeTutorialLocale(document.documentElement.lang || navigator.language || 'en')
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value))
}

export function TutorialProvider({ children }: { children: ReactNode }) {
  const { player } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()
  const [status, setStatus] = useState<TutorialStatus>('loading')
  const [currentStepIndex, setCurrentStepIndex] = useState(0)
  const [completedStepIds, setCompletedStepIds] = useState<string[]>([])
  const [locale, setLocale] = useState(readLocale)
  const [nextCompetitionId, setNextCompetitionId] = useState<string | null>(null)
  const [tournamentLookupDone, setTournamentLookupDone] = useState(false)
  const [targetRect, setTargetRect] = useState<TargetRect | null>(null)
  const [targetReady, setTargetReady] = useState(false)
  const targetElementRef = useRef<HTMLElement | null>(null)
  const progressLoadedForPlayer = useRef<string | null>(null)

  const currentStep = TUTORIAL_STEPS[currentStepIndex] ?? null
  const resources = useMemo(() => getTutorialResources(locale), [locale])

  const persist = useCallback(async (
    nextStatus: Exclude<TutorialStatus, 'loading'>,
    nextStepIndex: number,
    nextCompleted: string[],
  ) => {
    if (!player?.id) return

    const now = new Date().toISOString()
    const step = TUTORIAL_STEPS[nextStepIndex] ?? TUTORIAL_STEPS[0]
    const payload = {
      player_id: player.id,
      tutorial_version: TUTORIAL_VERSION,
      status: nextStatus,
      current_step_id: step?.id ?? null,
      completed_step_ids: nextCompleted,
      locale,
      started_at: nextStatus === 'active' ? now : undefined,
      completed_at: nextStatus === 'completed' ? now : null,
      skipped_at: nextStatus === 'skipped' ? now : null,
      updated_at: now,
    }

    const { error } = await supabase
      .from('player_tutorial_progress')
      .upsert(payload, { onConflict: 'player_id' })

    if (error) {
      console.error('Unable to save tutorial progress:', error.message)
    }
  }, [locale, player?.id])

  useEffect(() => {
    if (!player?.id) {
      progressLoadedForPlayer.current = null
      setStatus('loading')
      setCurrentStepIndex(0)
      setCompletedStepIds([])
      return
    }

    if (progressLoadedForPlayer.current === player.id) return
    progressLoadedForPlayer.current = player.id

    let cancelled = false

    async function loadProgress() {
      setStatus('loading')
      const { data, error } = await supabase
        .from('player_tutorial_progress')
        .select('player_id,tutorial_version,status,current_step_id,completed_step_ids,locale,started_at,completed_at,skipped_at,updated_at')
        .eq('player_id', player!.id)
        .maybeSingle()

      if (cancelled) return

      if (error) {
        console.error('Unable to load tutorial progress:', error.message)
        setStatus('available')
        return
      }

      if (!data) {
        const first = TUTORIAL_STEPS[0]
        const currentLocale = readLocale()
        setLocale(currentLocale)
        setCurrentStepIndex(0)
        setCompletedStepIds([])
        setStatus('active')
        await supabase.from('player_tutorial_progress').insert({
          player_id: player!.id,
          tutorial_version: TUTORIAL_VERSION,
          status: 'active',
          current_step_id: first.id,
          completed_step_ids: [],
          locale: currentLocale,
          started_at: new Date().toISOString(),
        })
        return
      }

      const row = data as TutorialProgressRow
      const nextLocale = normalizeTutorialLocale(row.locale || readLocale())
      const index = Math.max(0, TUTORIAL_STEPS.findIndex((step) => step.id === row.current_step_id))
      setLocale(nextLocale)
      setCurrentStepIndex(index)
      setCompletedStepIds(row.completed_step_ids ?? [])
      setStatus(row.status)
    }

    void loadProgress()
    return () => { cancelled = true }
  }, [player?.id])

  useEffect(() => {
    if (!player?.id) return

    let cancelled = false
    setTournamentLookupDone(false)

    async function loadNextTournament() {
      const { data } = await supabase.rpc('get_player_tournament_summary_v1', {
        p_player_id: player!.id,
      })
      if (cancelled) return
      const next = (data as { next_tournaments?: Array<{ competition_id: string }> } | null)?.next_tournaments?.[0]
      setNextCompetitionId(next?.competition_id ?? null)
      setTournamentLookupDone(true)
    }

    void loadNextTournament()
    return () => { cancelled = true }
  }, [player?.id])

  const resolveRoute = useCallback((step: TutorialStep | null) => {
    if (!step) return '/game/overview'
    if (step.route === 'player-profile') {
      return player?.id ? `/game/players/${player.id}` : '/game/overview'
    }
    if (step.route === 'next-tournament') {
      return nextCompetitionId ? `/game/tournaments/${nextCompetitionId}` : '/game/calendar'
    }
    if (step.route === 'next-tournament-doubles') {
      return nextCompetitionId ? `/game/tournaments/${nextCompetitionId}/doubles` : '/game/calendar'
    }
    if (step.route === 'tournament-preparation') {
      return nextCompetitionId
        ? `/game/schedule?competition=${nextCompetitionId}&prepare=1`
        : '/game/schedule'
    }
    return step.route
  }, [nextCompetitionId, player?.id])

  useEffect(() => {
    if (status !== 'active' || !currentStep || !location.pathname.startsWith('/game/')) return

    const usesTournament = ['next-tournament', 'next-tournament-doubles', 'tournament-preparation'].includes(currentStep.route)
    if (usesTournament && !tournamentLookupDone) return

    const route = resolveRoute(currentStep)

    if (currentStep.route === 'tournament-preparation' && nextCompetitionId) {
      const params = new URLSearchParams(location.search)
      const alreadyOnPreparationTournament =
        location.pathname === '/game/schedule'
        && params.get('competition') === nextCompetitionId

      if (alreadyOnPreparationTournament) return
    }

    const current = `${location.pathname}${location.search}`
    if (current !== route) {
      navigate(route, { replace: true })
    }
  }, [
    currentStep,
    location.pathname,
    location.search,
    navigate,
    resolveRoute,
    status,
    tournamentLookupDone,
  ])

  useEffect(() => {
    if (status !== 'active' || !currentStep || !location.pathname.startsWith('/game/')) {
      setTargetRect(null)
      setTargetReady(false)
      targetElementRef.current = null
      return
    }

    let cancelled = false
    let frame = 0

    const findTarget = () => {
      if (cancelled) return
      const primary = currentStep.target
        ? document.querySelector<HTMLElement>(currentStep.target)
        : null
      const fallback = currentStep.fallbackTarget
        ? document.querySelector<HTMLElement>(currentStep.fallbackTarget)
        : null
      const element = primary ?? fallback ?? document.querySelector<HTMLElement>('[data-tutorial-page-content]')

      if (!element) {
        setTargetReady(false)
        frame = window.requestAnimationFrame(findTarget)
        return
      }

      if (targetElementRef.current !== element) {
        targetElementRef.current = element
        element.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'smooth' })
      }

      const rect = element.getBoundingClientRect()
      if (rect.width < 2 || rect.height < 2) {
        setTargetReady(false)
        frame = window.requestAnimationFrame(findTarget)
        return
      }

      setTargetRect({
        top: rect.top,
        left: rect.left,
        width: rect.width,
        height: rect.height,
        bottom: rect.bottom,
        right: rect.right,
      })
      setTargetReady(true)
    }

    const observer = new MutationObserver(findTarget)
    observer.observe(document.body, { childList: true, subtree: true })

    const onResize = () => findTarget()
    const onScroll = () => findTarget()
    window.addEventListener('resize', onResize)
    window.addEventListener('scroll', onScroll, true)

    const timer = window.setTimeout(findTarget, 120)
    frame = window.requestAnimationFrame(findTarget)

    return () => {
      cancelled = true
      window.clearTimeout(timer)
      window.cancelAnimationFrame(frame)
      observer.disconnect()
      window.removeEventListener('resize', onResize)
      window.removeEventListener('scroll', onScroll, true)
    }
  }, [currentStep, location.pathname, location.search, status])

  const goToStep = useCallback(async (index: number, completed = completedStepIds) => {
    const nextIndex = clamp(index, 0, TUTORIAL_STEPS.length - 1)
    setCurrentStepIndex(nextIndex)
    setStatus('active')
    await persist('active', nextIndex, completed)
  }, [completedStepIds, persist])

  const nextStep = useCallback(async () => {
    if (!currentStep) return
    const completed = completedStepIds.includes(currentStep.id)
      ? completedStepIds
      : [...completedStepIds, currentStep.id]
    setCompletedStepIds(completed)

    if (currentStepIndex >= TUTORIAL_STEPS.length - 1) {
      setStatus('completed')
      await persist('completed', currentStepIndex, completed)
      return
    }

    await goToStep(currentStepIndex + 1, completed)
  }, [completedStepIds, currentStep, currentStepIndex, goToStep, persist])

  const previousStep = useCallback(async () => {
    if (currentStepIndex <= 0) return
    await goToStep(currentStepIndex - 1)
  }, [currentStepIndex, goToStep])

  const restartTutorial = useCallback(async () => {
    const currentLocale = readLocale()
    setLocale(currentLocale)
    setCompletedStepIds([])
    setCurrentStepIndex(0)
    setStatus('active')
    if (player?.id) {
      const now = new Date().toISOString()
      const { error } = await supabase
        .from('player_tutorial_progress')
        .upsert({
          player_id: player.id,
          tutorial_version: TUTORIAL_VERSION,
          status: 'active',
          current_step_id: TUTORIAL_STEPS[0].id,
          completed_step_ids: [],
          locale: currentLocale,
          started_at: now,
          completed_at: null,
          skipped_at: null,
          updated_at: now,
        }, { onConflict: 'player_id' })
      if (error) console.error('Unable to restart tutorial:', error.message)
    }
    navigate('/game/overview')
  }, [navigate, player?.id])

  const resumeTutorial = useCallback(async () => {
    setStatus('active')
    await persist('active', currentStepIndex, completedStepIds)
  }, [completedStepIds, currentStepIndex, persist])

  const pauseTutorial = useCallback(async () => {
    setStatus('paused')
    await persist('paused', currentStepIndex, completedStepIds)
  }, [completedStepIds, currentStepIndex, persist])

  const skipTutorial = useCallback(async () => {
    setStatus('skipped')
    await persist('skipped', currentStepIndex, completedStepIds)
  }, [completedStepIds, currentStepIndex, persist])

  const value = useMemo<TutorialContextValue>(() => ({
    status,
    currentStep,
    currentStepIndex,
    totalSteps: TUTORIAL_STEPS.length,
    restartTutorial,
    resumeTutorial,
    pauseTutorial,
    skipTutorial,
  }), [
    currentStep,
    currentStepIndex,
    pauseTutorial,
    restartTutorial,
    resumeTutorial,
    skipTutorial,
    status,
  ])

  const tutorialUiVisible = status === 'active' && currentStep && location.pathname.startsWith('/game/')
  const pausedUiVisible = status === 'paused' && location.pathname.startsWith('/game/')

  return (
    <TutorialContext.Provider value={value}>
      {children}
      {tutorialUiVisible && createPortal(
        <TutorialOverlay
          step={currentStep}
          stepIndex={currentStepIndex}
          targetRect={targetRect}
          targetReady={targetReady}
          hasTournament={Boolean(nextCompetitionId)}
          locale={locale}
          onBack={previousStep}
          onNext={nextStep}
          onPause={pauseTutorial}
          onSkip={skipTutorial}
        />,
        document.body,
      )}
      {pausedUiVisible && createPortal(
        <button type="button" className="tlg-tutorial-resume" onClick={() => void resumeTutorial()}>
          <GraduationCap size={17} />
          <span>{resources.ui.resume}</span>
        </button>,
        document.body,
      )}
    </TutorialContext.Provider>
  )
}

function TutorialOverlay({
  step,
  stepIndex,
  targetRect,
  targetReady,
  hasTournament,
  locale,
  onBack,
  onNext,
  onPause,
  onSkip,
}: {
  step: TutorialStep
  stepIndex: number
  targetRect: TargetRect | null
  targetReady: boolean
  hasTournament: boolean
  locale: string
  onBack: () => Promise<void>
  onNext: () => Promise<void>
  onPause: () => Promise<void>
  onSkip: () => Promise<void>
}) {
  const resources = getTutorialResources(locale)
  const phase = getTutorialPhase(step.phaseId)
  const phaseIndex = TUTORIAL_PHASES.findIndex((item) => item.id === step.phaseId)
  const phaseSteps = getTutorialPhaseSteps(step.phaseId)
  const phaseStepIndex = phaseSteps.findIndex((item) => item.id === step.id)
  const copyKey = !hasTournament && step.noTournamentCopyKey ? step.noTournamentCopyKey : step.copyKey
  const copy = resources.steps[copyKey] ?? resources.steps[step.copyKey]
  const phaseCopy = resources.phases[phase.titleKey]
  const isLast = stepIndex === TUTORIAL_STEPS.length - 1
  const progress = Math.round(((stepIndex + 1) / TUTORIAL_STEPS.length) * 100)

  const highlightStyle: CSSProperties | undefined = targetRect && targetReady
    ? {
        top: Math.max(6, targetRect.top - 6),
        left: Math.max(6, targetRect.left - 6),
        width: Math.min(window.innerWidth - 12, targetRect.width + 12),
        height: Math.min(window.innerHeight - 12, targetRect.height + 12),
      }
    : undefined

  const tooltipStyle = getTooltipStyle(targetRect, targetReady)

  return (
    <div className="tlg-tutorial-layer" aria-live="polite">
      {targetReady && highlightStyle ? (
        <div className="tlg-tutorial-highlight" style={highlightStyle} aria-hidden="true" />
      ) : (
        <div className="tlg-tutorial-full-backdrop" aria-hidden="true" />
      )}

      <section className="tlg-tutorial-card" style={tooltipStyle} role="dialog" aria-modal="false" aria-label={resources.ui.tutorial}>
        <header className="tlg-tutorial-card-head">
          <div>
            <span>{resources.ui.tutorial}</span>
            <strong>{phaseCopy?.title ?? phase.id}</strong>
          </div>
          <button type="button" onClick={() => void onPause()} aria-label={resources.ui.closeLabel} title={resources.ui.pause}>
            <X size={17} />
          </button>
        </header>

        <div className="tlg-tutorial-progress-row">
          <span>{resources.ui.phase} {phaseIndex + 1}/{TUTORIAL_PHASES.length}</span>
          <span>{resources.ui.step} {phaseStepIndex + 1}/{phaseSteps.length}</span>
          <span>{progress}%</span>
        </div>
        <div className="tlg-tutorial-progress-track" aria-hidden="true">
          <span style={{ width: `${progress}%` }} />
        </div>

        <div className="tlg-tutorial-copy">
          <h2>{copy.title}</h2>
          <p>{copy.body}</p>
          <div className="tlg-tutorial-action">
            <span>{resources.ui.doThis}</span>
            <p>{copy.action}</p>
          </div>
          {copy.tip && (
            <div className="tlg-tutorial-tip">
              <span>{resources.ui.tip}</span>
              <p>{copy.tip}</p>
            </div>
          )}
        </div>

        <footer className="tlg-tutorial-card-footer">
          <button type="button" className="tlg-tutorial-text-button" onClick={() => void onSkip()}>
            {resources.ui.skip}
          </button>
          <div>
            <button type="button" className="tlg-tutorial-secondary" onClick={() => void onBack()} disabled={stepIndex === 0}>
              <ChevronLeft size={15} />
              {resources.ui.back}
            </button>
            <button type="button" className="tlg-tutorial-primary" onClick={() => void onNext()}>
              {isLast ? resources.ui.finish : resources.ui.next}
              {!isLast && <ChevronRight size={15} />}
            </button>
          </div>
        </footer>
      </section>

      <button type="button" className="tlg-tutorial-pause-compact" onClick={() => void onPause()}>
        <Pause size={14} />
        {resources.ui.pause}
      </button>
    </div>
  )
}

function getTooltipStyle(rect: TargetRect | null, targetReady: boolean): CSSProperties {
  if (typeof window === 'undefined') return {}
  const viewportWidth = window.innerWidth
  const viewportHeight = window.innerHeight

  if (viewportWidth <= 720) {
    return {
      left: 10,
      right: 10,
      bottom: 10,
      width: 'auto',
    }
  }

  const width = Math.min(430, viewportWidth - 32)
  if (!rect || !targetReady) {
    return {
      width,
      left: (viewportWidth - width) / 2,
      top: Math.max(20, (viewportHeight - 420) / 2),
    }
  }

  const estimatedHeight = 390
  const below = rect.bottom + 16
  const above = rect.top - estimatedHeight - 16
  const top = below + estimatedHeight <= viewportHeight
    ? below
    : above >= 16
      ? above
      : clamp(viewportHeight - estimatedHeight - 16, 16, viewportHeight - 120)

  const preferredLeft = rect.left + rect.width / 2 - width / 2
  const left = clamp(preferredLeft, 16, viewportWidth - width - 16)

  return { width, left, top }
}

export function useTutorial() {
  const value = useContext(TutorialContext)
  if (!value) {
    throw new Error('useTutorial must be used inside TutorialProvider.')
  }
  return value
}
