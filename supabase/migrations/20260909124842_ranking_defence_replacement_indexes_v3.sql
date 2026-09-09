create index if not exists player_ranking_contributions_replaced_result_idx
  on public.player_ranking_contributions(replaced_by_result_id)
  where replaced_by_result_id is not null;

create index if not exists player_ranking_contributions_replaced_competition_idx
  on public.player_ranking_contributions(replaced_by_competition_id)
  where replaced_by_competition_id is not null;