/**
 * App.tsx
 *
 * Application routing entry point for Tennis Legacy: Rise to Glory.
 * BrowserRouter is used in production so Supabase email confirmation and
 * password-recovery redirects can use normal application URLs.
 */

import './styles/globals.css'
import './styles/premium.css'
import './styles/onboarding-enhancements.css'
import './styles/commerce.css'
import './styles/dashboard-modules.css'
import './styles/typography-sharp.css'

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
import TrainingPage from './pages/dashboard/Training'
import StaffPage from './pages/dashboard/Staff'
import CalendarPage from './pages/dashboard/Calendar'
import TournamentPage from './pages/dashboard/Tournament'
import RankingsPage from './pages/dashboard/Rankings'
import PlayerProfilePage from './pages/dashboard/PlayerProfile'
import SchedulePage from './pages/dashboard/Schedule'
import EquipmentPage from './pages/dashboard/Equipment'
import FinancePage from './pages/dashboard/Finance'
import PrivateLifePage from './pages/dashboard/PrivateLife'
import TennisClubPage from './pages/dashboard/TennisClub'
import StatisticsPage from './pages/dashboard/Statistics'
import ProPackagesPage from './pages/manager/ProPackages'
import GamePreferencesPage from './pages/manager/GamePreferences'
import InboxPage from './pages/manager/Inbox'
import ContactUsPage from './pages/manager/ContactUs'
import InviteFriendsPage from './pages/manager/InviteFriends'
import NotificationsPage from './pages/manager/Notifications'
import { ForumPage, HelpPage } from './pages/manager/CommunitySupport'
import { PlayerAccountPage } from './pages/manager/ManagerPages'

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/" element={<HomePage />} />

          <Route path="/login" element={<AnonymousOnly><LoginPage /></AnonymousOnly>} />
          <Route path="/register" element={<AnonymousOnly><RegisterPage /></AnonymousOnly>} />
          <Route path="/forgot-password" element={<AnonymousOnly><ForgotPasswordPage /></AnonymousOnly>} />
          <Route path="/reset-password" element={<RequireAuth><ResetPasswordPage /></RequireAuth>} />
          <Route path="/create-player" element={<RequireNoPlayer><CreatePlayerPage /></RequireNoPlayer>} />

          <Route path="/game/overview" element={<RequirePlayer><OverviewPage /></RequirePlayer>} />
          <Route path="/game/skills" element={<RequirePlayer><SkillsPage /></RequirePlayer>} />
          <Route path="/game/training" element={<RequirePlayer><TrainingPage /></RequirePlayer>} />
          <Route path="/game/staff" element={<RequirePlayer><StaffPage /></RequirePlayer>} />
          <Route path="/game/calendar" element={<RequirePlayer><CalendarPage /></RequirePlayer>} />
          <Route path="/game/tournaments/:competitionId" element={<RequirePlayer><TournamentPage /></RequirePlayer>} />
          <Route path="/game/rankings" element={<RequirePlayer><RankingsPage /></RequirePlayer>} />
          <Route path="/game/players/:playerId" element={<RequirePlayer><PlayerProfilePage /></RequirePlayer>} />
          <Route path="/game/schedule" element={<RequirePlayer><SchedulePage /></RequirePlayer>} />
          <Route path="/game/equipment" element={<RequirePlayer><EquipmentPage /></RequirePlayer>} />
          <Route path="/game/finance" element={<RequirePlayer><FinancePage /></RequirePlayer>} />
          <Route path="/game/private-life" element={<RequirePlayer><PrivateLifePage /></RequirePlayer>} />
          <Route path="/game/tennis-club" element={<RequirePlayer><TennisClubPage /></RequirePlayer>} />
          <Route path="/game/statistics" element={<RequirePlayer><StatisticsPage /></RequirePlayer>} />

          <Route path="/game/notifications" element={<RequirePlayer><NotificationsPage /></RequirePlayer>} />
          <Route path="/game/player-account" element={<RequirePlayer><PlayerAccountPage /></RequirePlayer>} />
          <Route path="/game/preferences" element={<RequirePlayer><GamePreferencesPage /></RequirePlayer>} />
          <Route path="/game/inbox" element={<RequirePlayer><InboxPage /></RequirePlayer>} />
          <Route path="/game/help" element={<RequirePlayer><HelpPage /></RequirePlayer>} />
          <Route path="/game/forum" element={<RequirePlayer><ForumPage /></RequirePlayer>} />
          <Route path="/game/pro-packages" element={<RequirePlayer><ProPackagesPage /></RequirePlayer>} />
          <Route path="/game/contact" element={<RequirePlayer><ContactUsPage /></RequirePlayer>} />
          <Route path="/game/invite-friends" element={<RequirePlayer><InviteFriendsPage /></RequirePlayer>} />

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  )
}
