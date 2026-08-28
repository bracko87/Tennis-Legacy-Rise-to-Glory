/**
 * App.tsx
 *
 * Application routing entry point for Tennis Legacy: Rise to Glory.
 * Uses HashRouter for compatibility inside the Sider preview iframe.
 */

import './styles/globals.css'

import {
  HashRouter,
  Navigate,
  Route,
  Routes,
} from 'react-router'

import HomePage from './pages/Home'
import LoginPage from './pages/auth/Login'
import RegisterPage from './pages/auth/Register'
import CreatePlayerPage from './pages/player/CreatePlayer'
import OverviewPage from './pages/dashboard/Overview'
import SkillsPage from './pages/dashboard/Skills'
import CalendarPage from './pages/dashboard/Calendar'
import SchedulePage from './pages/dashboard/Schedule'
import FinancePage from './pages/dashboard/Finance'
import EquipmentPage from './pages/dashboard/Equipment'
import StatisticsPage from './pages/dashboard/Statistics'

/**
 * Renders the application's public and in-game routes.
 */
export default function App() {
  return (
    <HashRouter>
      <Routes>
        <Route
          path="/"
          element={<HomePage />}
        />

        <Route
          path="/login"
          element={<LoginPage />}
        />

        <Route
          path="/register"
          element={<RegisterPage />}
        />

        <Route
          path="/create-player"
          element={<CreatePlayerPage />}
        />

        <Route
          path="/game/overview"
          element={<OverviewPage />}
        />

        <Route
          path="/game/skills"
          element={<SkillsPage />}
        />

        <Route
          path="/game/calendar"
          element={<CalendarPage />}
        />

        <Route
          path="/game/schedule"
          element={<SchedulePage />}
        />

        <Route
          path="/game/finance"
          element={<FinancePage />}
        />

        <Route
          path="/game/equipment"
          element={<EquipmentPage />}
        />

        <Route
          path="/game/statistics"
          element={<StatisticsPage />}
        />

        <Route
          path="*"
          element={
            <Navigate
              to="/"
              replace
            />
          }
        />
      </Routes>
    </HashRouter>
  )
}