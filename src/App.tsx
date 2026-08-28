/**
 * App.tsx
 *
 * Application routing entry point for Tennis Legacy: Rise to Glory.
 * BrowserRouter is used in production so Supabase email confirmation and
 * password-recovery redirects can use normal application URLs.
 */

import './styles/globals.css'
import './styles/premium.css'

import {
  BrowserRouter,
  Navigate,
  Route,
  Routes,
} from 'react-router'

import { AuthProvider } from './auth/AuthContext'
import {
  AnonymousOnly,
  RequireAuth,
  RequireNoPlayer,
  RequirePlayer,
} from './auth/RouteGuards'
import HomePage from './pages/Home'
import LoginPage from './pages/auth/Login'
import RegisterPage from './pages/auth/Register'
import ForgotPasswordPage from './pages/auth/ForgotPassword'
import ResetPasswordPage from './pages/auth/ResetPassword'
import CreatePlayerPage from './pages/player/CreatePlayer'
import OverviewPage from './pages/dashboard/Overview'
import SkillsPage from './pages/dashboard/Skills'
import CalendarPage from './pages/dashboard/Calendar'
import SchedulePage from './pages/dashboard/Schedule'
import FinancePage from './pages/dashboard/Finance'
import EquipmentPage from './pages/dashboard/Equipment'
import StatisticsPage from './pages/dashboard/Statistics'

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/" element={<HomePage />} />

          <Route
            path="/login"
            element={
              <AnonymousOnly>
                <LoginPage />
              </AnonymousOnly>
            }
          />
          <Route
            path="/register"
            element={
              <AnonymousOnly>
                <RegisterPage />
              </AnonymousOnly>
            }
          />
          <Route
            path="/forgot-password"
            element={
              <AnonymousOnly>
                <ForgotPasswordPage />
              </AnonymousOnly>
            }
          />
          <Route
            path="/reset-password"
            element={
              <RequireAuth>
                <ResetPasswordPage />
              </RequireAuth>
            }
          />

          <Route
            path="/create-player"
            element={
              <RequireNoPlayer>
                <CreatePlayerPage />
              </RequireNoPlayer>
            }
          />

          <Route
            path="/game/overview"
            element={
              <RequirePlayer>
                <OverviewPage />
              </RequirePlayer>
            }
          />
          <Route
            path="/game/skills"
            element={
              <RequirePlayer>
                <SkillsPage />
              </RequirePlayer>
            }
          />
          <Route
            path="/game/calendar"
            element={
              <RequirePlayer>
                <CalendarPage />
              </RequirePlayer>
            }
          />
          <Route
            path="/game/schedule"
            element={
              <RequirePlayer>
                <SchedulePage />
              </RequirePlayer>
            }
          />
          <Route
            path="/game/finance"
            element={
              <RequirePlayer>
                <FinancePage />
              </RequirePlayer>
            }
          />
          <Route
            path="/game/equipment"
            element={
              <RequirePlayer>
                <EquipmentPage />
              </RequirePlayer>
            }
          />
          <Route
            path="/game/statistics"
            element={
              <RequirePlayer>
                <StatisticsPage />
              </RequirePlayer>
            }
          />

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  )
}
