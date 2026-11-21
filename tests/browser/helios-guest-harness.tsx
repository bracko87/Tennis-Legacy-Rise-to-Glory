// Test-only mount of the actual production guest screens and AuthProvider.
// Other game screens are intentionally not mounted: no full-schema claim.
import React from 'react'
import {createRoot} from 'react-dom/client'
import {BrowserRouter,Routes,Route,Link} from 'react-router'
import {AuthProvider,useAuth} from '../../src/auth/AuthContext'
import {RequireAuth,RequireNoPlayer} from '../../src/auth/RouteGuards'
import TryAsGuest from '../../src/pages/auth/TryAsGuest'
import GuestRegistration from '../../src/pages/auth/GuestRegistration'
import {supabase} from '../../src/lib/supabase'
function SessionProbe(){
 const {user,authLoading}=useAuth()
 return <aside><output data-testid="identity">{authLoading?'loading':user?.id||'signed-out'}</output>
 <output data-testid="identity-type">{user?.is_anonymous===true?'guest':user?'registered':'none'}</output></aside>
}
function CreatePlayerContinues(){
 return <main><h1>Guest onboarding route reached</h1><Link to="/guest/register">Continue to registration</Link></main>
}
// Verify remote identity on the actual local Auth endpoint without displaying tokens.
function Login(){
 return <main><h1>Signed out</h1></main>
}
createRoot(document.getElementById('root')!).render(<BrowserRouter><AuthProvider>
 <SessionProbe/>
 <Routes>
  <Route path="/try-as-guest" element={<TryAsGuest/>}/>
  <Route path="/guest/register" element={<RequireAuth><GuestRegistration/></RequireAuth>}/>
  <Route path="/create-player" element={<RequireNoPlayer><CreatePlayerContinues/></RequireNoPlayer>}/>
  <Route path="/game/overview" element={<h1>Overview route reached</h1>}/>
  <Route path="/login" element={<Login/>}/>
  <Route path="*" element={<Link to="/try-as-guest">Try as Guest</Link>}/>
 </Routes>
 </AuthProvider></BrowserRouter>)
