drop trigger if exists trg_record_player_skill_history on public.player_skills;

create trigger trg_record_player_skill_history
after insert or update of
  serve,
  forehand,
  backhand,
  return_skill,
  volley,
  slice,
  drop_shot,
  lob,
  smash,
  fitness,
  stamina,
  recovery,
  movement,
  fatigue,
  sharpness,
  morale,
  confidence,
  focus
on public.player_skills
for each row
execute function public.record_player_skill_history();
