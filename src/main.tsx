/**
 * main.tsx
 *
 * React application entry point.
 *
 * Sider projects may expose #app, #root, or both. The application mounts into
 * the first supported container and removes the unused one so it cannot create
 * an additional empty viewport below every page.
 */

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import './shadcn.css'
import './styles/home-branding.css'
import './styles/skills-layout-fixes.css'
import './styles/page-header-standard.css'
import './styles/training-header-polish.css'
import './styles/finance-header-standard.css'
import './styles/training-camps-v2.css'
import './styles/player-scouting.css'
import './styles/staff-negotiation.css'
import './styles/staff-visual-standard.css'
import './styles/training-weekly-save.css'
import './styles/tournament-match-modal-expanded.css'
import './styles/tournament-match-side-mirror.css'
import './styles/tournament-match-avatar-normalization.css'
import './styles/tournament-status.css'
/* Keep typography last so page-specific styles cannot reintroduce another font. */
import './styles/font-standard.css'
import App from './App'

const appElement =
  document.getElementById('app')

const rootElement =
  document.getElementById('root')

const mountElement =
  appElement ?? rootElement

if (!mountElement) {
  throw new Error(
    'Unable to start the application because neither #app nor #root exists.',
  )
}

const unusedMountElement =
  mountElement === appElement
    ? rootElement
    : appElement

unusedMountElement?.remove()

createRoot(mountElement).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
