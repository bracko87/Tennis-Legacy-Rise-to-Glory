import {createRoot} from 'react-dom/client'
import Replay from '../../src/components/tournament/TournamentMatchReplayModal'
createRoot(document.getElementById('root')!).render(<Replay matchId="review-match" onClose={()=>{document.body.textContent='Closed'}} />)
