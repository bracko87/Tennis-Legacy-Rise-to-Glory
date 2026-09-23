revoke execute on function public.national_team_current_abs_day_v1() from anon, authenticated;
revoke execute on function public.national_team_current_season_v1() from anon, authenticated;
revoke execute on function public.national_team_record_event_v1(uuid, text, jsonb, integer) from anon, authenticated;
revoke execute on function public.maybe_activate_national_association_v1(uuid) from anon, authenticated;
revoke execute on function public.sync_national_association_membership_for_player_v1(uuid) from anon, authenticated;
revoke execute on function public.trg_sync_national_association_membership_v1() from anon, authenticated;
revoke execute on function public.assign_national_association_bottom_entry_v1(uuid, integer, text) from anon, authenticated;
revoke execute on function public.ensure_national_captain_election_v1(uuid, integer) from anon, authenticated;
revoke execute on function public.resolve_national_captain_election_v1(uuid) from anon, authenticated;
revoke execute on function public.fill_national_team_division_vacancies_v1(text, text, integer) from anon, authenticated;
revoke execute on function public.prepare_national_team_division_entries_v1(integer) from anon, authenticated;
revoke execute on function public.process_national_association_lifecycle_v1() from anon, authenticated;
revoke execute on function public.contribute_national_association_fund_v1(uuid, integer) from anon, authenticated;
revoke execute on function public.register_national_captain_candidate_v1(uuid, text) from anon, authenticated;
revoke execute on function public.cast_national_captain_vote_v1(uuid, uuid) from anon, authenticated;
revoke execute on function public.get_my_national_association_v1() from anon, authenticated;

grant execute on function public.contribute_national_association_fund_v1(uuid, integer) to authenticated;
grant execute on function public.register_national_captain_candidate_v1(uuid, text) to authenticated;
grant execute on function public.cast_national_captain_vote_v1(uuid, uuid) to authenticated;
grant execute on function public.get_my_national_association_v1() to authenticated;

create index if not exists national_associations_activation_started_by_user_idx
  on public.national_associations(activation_started_by_user_id);
create index if not exists national_associations_region_idx
  on public.national_associations(region_code);

create index if not exists national_memberships_user_idx
  on public.national_association_memberships(user_id);

create index if not exists national_contributions_association_idx
  on public.national_association_contributions(association_id);
create index if not exists national_contributions_membership_idx
  on public.national_association_contributions(membership_id);

create index if not exists national_recognitions_user_idx
  on public.national_association_recognitions(user_id);
create index if not exists national_recognitions_player_idx
  on public.national_association_recognitions(player_id);

create index if not exists national_country_regions_region_idx
  on public.national_team_country_regions(region_code);

create index if not exists national_divisions_region_idx
  on public.national_team_divisions(region_code);

create index if not exists national_elections_winner_idx
  on public.national_captain_elections(winning_candidate_id);

create index if not exists national_candidates_membership_idx
  on public.national_captain_candidates(membership_id);
create index if not exists national_candidates_user_idx
  on public.national_captain_candidates(user_id);
create index if not exists national_candidates_player_idx
  on public.national_captain_candidates(player_id);

create index if not exists national_runoff_candidate_idx
  on public.national_captain_runoff_candidates(candidate_id);

create index if not exists national_votes_membership_idx
  on public.national_captain_votes(membership_id);
create index if not exists national_votes_voter_idx
  on public.national_captain_votes(voter_user_id);
create index if not exists national_votes_candidate_idx
  on public.national_captain_votes(candidate_id);

create index if not exists national_terms_election_idx
  on public.national_captain_terms(election_id);
create index if not exists national_terms_candidate_idx
  on public.national_captain_terms(candidate_id);
create index if not exists national_terms_membership_idx
  on public.national_captain_terms(membership_id);
create index if not exists national_terms_user_idx
  on public.national_captain_terms(user_id);
create index if not exists national_terms_player_idx
  on public.national_captain_terms(player_id);
