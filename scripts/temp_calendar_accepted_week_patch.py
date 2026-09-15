from pathlib import Path

calendar = Path('src/pages/dashboard/Calendar.tsx')
s = calendar.read_text()

old = """function playerActivityPriority(activity: PlayerCalendarActivityRow) {
  if (activity.activity_type === 'injured') return 1
  if (activity.activity_type === 'tournament' && activity.source !== 'tournament_predicted') return 2
  if (activity.activity_type === 'travel') return 3
  if (activity.activity_type === 'training_camp') return 4
  if (activity.activity_type === 'tournament') return 9
  return 10
}"""
new = """function playerActivityPriority(activity: PlayerCalendarActivityRow) {
  if (activity.activity_type === 'injured') return 1
  if (activity.activity_type === 'tournament' && activity.source === 'tournament_accepted') return 8
  if (activity.activity_type === 'tournament' && activity.source !== 'tournament_predicted') return 2
  if (activity.activity_type === 'travel') return 3
  if (activity.activity_type === 'training_camp') return 4
  if (activity.activity_type === 'tournament') return 9
  return 10
}"""
assert old in s, 'priority block not found'
s = s.replace(old, new, 1)

old = "Confirmed match days are secured; predicted tournament days remain planning days until progression makes them certain."
new = "Accepted main-draw weeks are reserved with a light overlay until your first match schedule is known. Confirmed match days are secured; predicted tournament days remain planning days until progression makes them certain."
assert old in s, 'calendar description not found'
s = s.replace(old, new, 1)

old = """          const tournamentPredicted = activity?.activity_type === 'tournament' && activity.source === 'tournament_predicted'
          const tournamentConfirmed = activity?.activity_type === 'tournament' && !tournamentCompleted && !tournamentPredicted
          const tournamentState = tournamentCompleted ? 'completed' : tournamentPredicted ? 'predicted' : tournamentConfirmed ? 'confirmed' : ''"""
new = """          const tournamentAccepted = activity?.activity_type === 'tournament' && activity.source === 'tournament_accepted'
          const tournamentPredicted = activity?.activity_type === 'tournament' && activity.source === 'tournament_predicted'
          const tournamentConfirmed = activity?.activity_type === 'tournament' && !tournamentCompleted && !tournamentAccepted && !tournamentPredicted
          const tournamentState = tournamentCompleted ? 'completed' : tournamentAccepted ? 'accepted' : tournamentPredicted ? 'predicted' : tournamentConfirmed ? 'confirmed' : ''"""
assert old in s, 'tournament state block not found'
s = s.replace(old, new, 1)

old = "? `Tournament · ${tournamentCompleted ? 'Played' : tournamentPredicted ? 'Predicted' : 'Confirmed'}`"
new = "? `Tournament · ${tournamentCompleted ? 'Played' : tournamentAccepted ? 'Accepted' : tournamentPredicted ? 'Predicted' : 'Confirmed'}`"
assert old in s, 'tournament label not found'
s = s.replace(old, new, 1)
calendar.write_text(s)

css = Path('src/styles/calendar-player-activity.css')
c = css.read_text()
marker = """.tlg-calendar-day-tournament-predicted {
  background: #f1f8fd;
  border-color: #bcdced;
}
"""
insert = marker + """
/* Main-draw acceptance reserves the whole tournament week before the exact
   first-match/travel schedule exists. Keep it deliberately very light. */
.tlg-calendar-day-tournament-accepted {
  background: #f4fbf6;
  border-color: #c5e6d0;
}
"""
assert marker in c, 'predicted day style not found'
c = c.replace(marker, insert, 1)

marker = """.tlg-calendar-player-activity.tournament.predicted > strong {
  color: #365e76;
}
"""
insert = marker + """
.tlg-calendar-player-activity.tournament.accepted {
  color: #4d8962;
}

.tlg-calendar-player-activity.tournament.accepted > strong {
  color: #315f42;
}
"""
assert marker in c, 'predicted text style not found'
c = c.replace(marker, insert, 1)
css.write_text(c)
