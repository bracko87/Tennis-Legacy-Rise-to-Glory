-- Tennis Legacy Season 2 Week 1 protected recovery and release checks
-- Source: live project SQL definitions, 2026-11-11
-- REVIEW/ISOLATED-TEST REFERENCE ONLY; THIS FILE DOES NOT APPROVE LIVE CUTOVER.
-- The production database already contains the private recovery tables and journal.
-- Before any real recovery: verify the backup and independent restore,
-- provide real human entry access, close registration and approve all 22 plans.
-- Never inject synthetic human applications or fake approval flags in production.
--
-- Tables used:
-- control_center_private.tennis_season2_week1_reselection_receipts_v1
-- control_center_private.tennis_season2_week1_recovery_plan_v1
-- control_center_private.tennis_season2_week1_preentries_v1
-- control_center_private.tennis_season_transition_runs_v1
-- control_center_private.tennis_season_atomic_rehearsal_evidence_v1
-- All 3 routines have EXECUTE revoked from public, anon, authenticated.

-- check_tennis_season1_to2_release_gate_v1
CREATE OR REPLACE FUNCTION control_center_private.check_tennis_season1_to2_release_gate_v1(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'public', 'control_center_private'
AS $function$
declare
  r record;
  c record;
  g record;
  v_baseline jsonb;
  v_preflight jsonb;
  v_draws jsonb;
  v_early_windows jsonb;
  v_recovery_integrity jsonb;
  v_reconciled jsonb;
  v_atomic_rehearsal_passed boolean:=false;
  v_blockers jsonb:='[]'::jsonb;
  v_steps integer;
  v_incorrect_step_status integer;
  v_unguarded_jobs integer;
  v_finance_bad integer;
  v_season2_finance integer;
  v_season2_rankings integer;
begin
  select * into r from control_center_private.tennis_season_transition_runs_v1
  where run_id=p_run_id;
  if not found or (r.source_season,r.target_season) is distinct from (1,2) then
    return jsonb_build_object('approved_for_cutover',false,'blockers',
       jsonb_build_array('A valid Season 1 to Season 2 migration plan was not found.'));
  end if;

  select * into c from public.get_game_clock_v1();
  select * into g from public.season_transition_boundary_guard_v1 where id=true;

  if not coalesce(g.enabled and g.source_season=1 and
    g.stop_at_total_seconds=31622399 and
    c.game_total_seconds=g.stop_at_total_seconds and c.speed_multiplier=0,false) then
    v_blockers:=v_blockers||jsonb_build_array('Season 1 clock is not held at the verified boundary.');
  end if;

  if r.status<>'planned' or r.execution_enabled is not true then
    v_blockers:=v_blockers||jsonb_build_array('Migration has not been approved/enabled for execution.');
  end if;
  if not (r.backup_verified and r.restore_test_verified) then
    v_blockers:=v_blockers||jsonb_build_array('Full backup and independent restore validation are missing.');
  end if;
  if not r.two_season_dry_run_verified then
    v_blockers:=v_blockers||jsonb_build_array('Two-season isolated migration dry run is missing.');
  end if;
  if not (r.contracts_verified and r.finance_verified) then
    v_blockers:=v_blockers||jsonb_build_array('Contract and financial rollover certification are missing.');
  end if;
  if not r.operator_approved then
    v_blockers:=v_blockers||jsonb_build_array('Final operator approval is missing.');
  end if;

  v_baseline:=control_center_private.verify_tennis_season1_transition_baselines_v1(p_run_id);
  if coalesce((v_baseline->>'all_unchanged')::boolean,false) is not true then
    v_blockers:=v_blockers||jsonb_build_array('Player, ranking, contract, wallet or calendar baselines have changed.');
  end if;

  v_preflight:=control_center_private.build_tennis_season2_migration_preflight_v1();
  v_draws:=v_preflight->'early_draws';
  v_early_windows:=control_center_private.audit_tennis_season2_early_entry_windows_v1();
  v_recovery_integrity:=control_center_private.audit_tennis_season2_week1_extended_recovery_v1();
  v_reconciled:=control_center_private.verify_tennis_season2_week1_reconciled_draws_v1();
  if coalesce((v_reconciled->>'ready_for_cutover')::boolean,false) is not true then
    if coalesce((v_recovery_integrity->>'all_original_sources_match')::boolean,false) is not true then
      v_blockers:=v_blockers||jsonb_build_array(
        'Week 1 original recovery archives changed before a certified field rebuild.'
      );
    end if;
    v_blockers:=v_blockers||jsonb_build_array(
      'Week 1 real human registration and atomic tournament-field reconciliation are not yet complete.'
    );
  end if;
  if coalesce((v_preflight#>>'{season1_closeout,completed}')::boolean,false) is not true then
    v_blockers:=v_blockers||jsonb_build_array('Season 1 closeout is not certified.');
  end if;
  if coalesce((v_preflight#>>'{season2_calendar,core_parity_verified}')::boolean,false) is not true then
    v_blockers:=v_blockers||jsonb_build_array('Season 2 calendar parity has failed.');
  end if;
  if coalesce((v_reconciled->>'ready_for_cutover')::boolean,false) is not true
    and coalesce((v_draws->>'structural_preflight_passed')::boolean,false) is not true then
    v_blockers:=v_blockers||jsonb_build_array('Existing Season 2 applications and draws failed structural validation.');
  end if;

  select count(*), count(*) filter(where status<>'waiting')
    into v_steps,v_incorrect_step_status
  from control_center_private.tennis_season_transition_steps_v1
  where run_id=p_run_id;
  if v_steps<>13 or v_incorrect_step_status<>0 then
    v_blockers:=v_blockers||jsonb_build_array('The migration step journal is incomplete or not in its initial state.');
  end if;

  select count(*) into v_unguarded_jobs from cron.job
   where jobid in (7,44,52,53,55) and
     (not active or position('get_game_clock_v1()' in command)=0 or
      position('not (select is_paused from public.game_clock where id=1)' in command)=0);
  if v_unguarded_jobs>0 or
     (select count(*) from cron.job where jobid in (7,44,52,53,55))<>5 then
    v_blockers:=v_blockers||jsonb_build_array('Tournament processing jobs are missing safety-stop/pause guards.');
  end if;

  with latest as (
    select distinct on (tx.player_id) tx.player_id,tx.balance_after
      from public.career_finance_transactions tx
      order by tx.player_id,tx.created_at desc,tx.id desc
  )
  select count(*) into v_finance_bad
    from public.player_career_finance_accounts a
    left join latest l on l.player_id=a.player_id
    where l.player_id is null or a.balance is distinct from l.balance_after;
  if v_finance_bad<>0 then
    v_blockers:=v_blockers||jsonb_build_array('Player account balance does not match the financial ledger.');
  end if;

  select count(*) into v_season2_finance from public.career_finance_transactions where season=2;
  select count(*) into v_season2_rankings from public.ranking_publication_runs where season=2;
  if v_season2_finance>0 or v_season2_rankings>0 then
    v_blockers:=v_blockers||jsonb_build_array('Season 2 finance or ranking publication occurred before release.');
  end if;

  select exists(
    select 1 from control_center_private.tennis_season_atomic_rehearsal_evidence_v1 a
    where a.run_id=p_run_id
      and a.scenario='positive_cutover_full_rollback'
      and a.status='passed' and a.rollback_confirmed
      and a.output->>'status'='completed_paused'
      and (a.output->>'steps_completed')::integer=13
  ) into v_atomic_rehearsal_passed;
  if not v_atomic_rehearsal_passed then
     v_blockers:=v_blockers||jsonb_build_array(
       'Positive-path atomic season-switch and rollback rehearsal is missing.'
     );
  end if;

  return jsonb_build_object(
    'run_id',p_run_id,'approved_for_cutover',jsonb_array_length(v_blockers)=0,
    'clock_held',coalesce(g.enabled and c.game_total_seconds=g.stop_at_total_seconds and c.speed_multiplier=0,false),
    'baseline_unchanged',coalesce((v_baseline->>'all_unchanged')::boolean,false),
    'draw_structure_passed',coalesce((v_draws->>'structural_preflight_passed')::boolean,false),
    'week1_reselection_verified',coalesce((v_reconciled->>'ready_for_cutover')::boolean,false),
    'atomic_rehearsal_passed',v_atomic_rehearsal_passed,
    'blocking_issue_count',jsonb_array_length(v_blockers),
    'blockers',v_blockers
  );
end
$function$;
REVOKE ALL ON FUNCTION control_center_private.check_tennis_season1_to2_release_gate_v1(uuid) FROM PUBLIC,anon,authenticated;

-- reconcile_tennis_season2_week1_draws_v1
CREATE OR REPLACE FUNCTION control_center_private.reconcile_tennis_season2_week1_draws_v1(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public', 'control_center_private'
AS $function$
declare
 v_run record;
 v_entry record;
 v_comp record;
 v_reply jsonb;
 v_choice_count integer;
 v_bad_choice_count integer;
 v_prev_publications integer;
 v_previous_matches integer;
 v_total_new_matches integer:=0;
 v_published integer:=0;
 v_examined integer:=0;
 v_inserted integer:=0;
 v_existing_receipts integer;
 v_rebuilt integer;
 v_human_evaluated integer;
 v_new_hash text;
begin
 perform pg_advisory_xact_lock(2026,1202);
 select * into v_run from control_center_private.tennis_season_transition_runs_v1
  where run_id=p_run_id for update;
 if not found or (v_run.source_season,v_run.target_season) is distinct from (1,2)
   or v_run.status<>'planned' or v_run.execution_enabled then
   raise exception 'Week 1 recovery requires the protected Season 1 to 2 plan';
 end if;

 select count(*) into v_existing_receipts
   from control_center_private.tennis_season2_week1_reselection_receipts_v1
   where run_id=p_run_id;
 if v_existing_receipts=22 and
  (select count(*) from control_center_private.tennis_season2_week1_recovery_plan_v1
    where run_id=p_run_id and plan_status='reconciled')=22 then
    return jsonb_build_object('status','already_reconciled','competitions',22,
       'rewrote_existing_draws',false,'replay_safe',true);
 end if;
 if v_existing_receipts<>0 then
   raise exception 'Partial Week 1 reconciliation detected; refuse re-application';
 end if;

 if not (v_run.backup_verified and v_run.restore_test_verified) then
    raise exception 'Independent backup and restore proof required before changing original Week 1 draws';
 end if;
 if not exists(
    select 1 from public.get_game_clock_v1() c
    join public.season_transition_boundary_guard_v1 g on g.id=true
    join public.game_clock gc on gc.id=1
    where c.game_total_seconds=31622399 and c.speed_multiplier=0
      and gc.season=1 and g.enabled and g.source_season=1
 ) then raise exception 'Game clock is no longer safely held at Season 1 boundary'; end if;

 if (select count(*) from control_center_private.tennis_season2_week1_recovery_plan_v1
    where run_id=p_run_id and plan_status='approved')<>22 then
     raise exception 'All 22 Week 1 recovery plans must be approved after registration closes';
 end if;

 if coalesce((control_center_private.audit_tennis_season2_week1_extended_recovery_v1()
              ->>'all_original_sources_match')::boolean,false) is distinct from true then
   raise exception 'Original Week 1 archive mismatch: cannot rebuild field safely';
 end if;
 select count(*) into v_choice_count
   from control_center_private.tennis_season2_week1_preentries_v1
   where run_id=p_run_id and status='selected';

 select count(*) into v_bad_choice_count
 from control_center_private.tennis_season2_week1_preentries_v1 choice
 left join public.players pl on pl.id=choice.player_id
 left join control_center_private.tennis_season2_week1_recovery_plan_v1 rec
   on rec.run_id=choice.run_id and rec.competition_id=choice.competition_id
 where choice.run_id=p_run_id and choice.status='selected' and (
      pl.id is null or pl.player_type<>'human'
      or pl.owner_user_id is distinct from choice.owner_user_id
      or pl.world is distinct from choice.world
      or rec.competition_id is null or rec.world is distinct from choice.world
 );
 if v_bad_choice_count>0 then
   raise exception '% invalid player tournament preferences',v_bad_choice_count;
 end if;

 select count(*) filter(where (source_counts->>'draws')::integer=1),
        coalesce(sum((source_counts->>'matches')::integer),0)
   into v_prev_publications,v_previous_matches
 from control_center_private.tennis_season2_week1_recovery_plan_v1
 where run_id=p_run_id;
 if (v_prev_publications,v_previous_matches) is distinct from (16,676) then
   raise exception 'Expected 16 old published fields and 676 original matches';
 end if;

 if exists(
   select 1 from public.tournament_matches m
   join control_center_private.tennis_season2_week1_recovery_plan_v1 rec
     on rec.competition_id=m.competition_id and rec.run_id=p_run_id
   where m.status in ('completed','in_progress') or m.started_at is not null
 ) then raise exception 'Week 1 includes started or played matches; refuse re-draw';end if;

 -- ALL following changes run in this one database transaction.
 -- A failure anywhere rolls everything back, including receipts and plan status.
 delete from public.tournament_matches m using
   control_center_private.tennis_season2_week1_recovery_plan_v1 rec
   where rec.run_id=p_run_id and m.competition_id=rec.competition_id;
 delete from public.tournament_draw_publications d using
   control_center_private.tennis_season2_week1_recovery_plan_v1 rec
   where rec.run_id=p_run_id and d.competition_id=rec.competition_id;
 delete from public.tournament_qualifier_slots s using
   control_center_private.tennis_season2_week1_recovery_plan_v1 rec
   where rec.run_id=p_run_id and s.competition_id=rec.competition_id;
 delete from public.tournament_entries en using
   control_center_private.tennis_season2_week1_recovery_plan_v1 rec
   where rec.run_id=p_run_id and en.competition_id=rec.competition_id;

 update public.tournament_competition_entry_cycles c
 set normal_allocation_processed_at=null,
     normal_allocation_game_second=null,
     ai_late_fill_processed_at=null,
     ai_late_fill_game_second=null,
     field_locked_at=null,
     field_locked_game_second=null
 from control_center_private.tennis_season2_week1_recovery_plan_v1 rec
 where rec.run_id=p_run_id and c.competition_id=rec.competition_id;

 update public.tournament_applications a
 set status='applied',
     decided_at=null,decision_reason=null,updated_at=now(),
     application_source=case when a.application_source='ai_late_fill'
       then 'ai' else a.application_source end
 from control_center_private.tennis_season2_week1_recovery_plan_v1 rec
 where rec.run_id=p_run_id and a.competition_id=rec.competition_id
   and a.status in ('accepted_main_draw','accepted_qualification','rejected','superseded');

 -- Project the actual, explicit human preferences into normal applications.
 -- Do not force entries or choose tournaments on behalf of human players.
 for v_entry in
  select pre.*,pl.moderation_status
  from control_center_private.tennis_season2_week1_preentries_v1 pre
  join public.players pl on pl.id=pre.player_id
  where pre.run_id=p_run_id and pre.status='selected'
  order by pre.player_id
 loop
   if v_entry.moderation_status='rejected' or
      coalesce((public.check_player_competition_availability_v1(
         v_entry.player_id,v_entry.competition_id)->>'available')::boolean,false) is not true or
      not public.player_tournament_entry_health_eligible_v1(v_entry.player_id,v_entry.competition_id)
   then raise exception 'A saved human Week 1 preference is no longer eligible: %',v_entry.player_id;end if;

   insert into public.tournament_applications (
    competition_id,player_id,owner_user_id,world,status,ranking_position_snapshot,
    ranking_points_snapshot,priority,accept_qualification,application_source,target_season_week,
    decision_reason,decided_at,created_at,updated_at
   ) select
    v_entry.competition_id,v_entry.player_id,v_entry.owner_user_id,v_entry.world,
    'applied',greatest(1,coalesce(public.get_player_world_rank_position_v1(v_entry.player_id),1)),
    coalesce(pr.ranking_points,0),null,v_entry.accept_qualification,'human',1,null,null,now(),now()
   from public.players pl left join public.player_rankings pr on pr.player_id=pl.id
   where pl.id=v_entry.player_id
   on conflict(competition_id,player_id) do update
    set owner_user_id=excluded.owner_user_id,world=excluded.world,
      status='applied',ranking_position_snapshot=excluded.ranking_position_snapshot,
      ranking_points_snapshot=excluded.ranking_points_snapshot,priority=null,
      accept_qualification=excluded.accept_qualification,
      application_source='human',target_season_week=1,
      decision_reason=null,decided_at=null,updated_at=now();
   v_inserted:=v_inserted+1;
 end loop;

 for v_comp in
   select rec.competition_id,
          (rec.source_counts->>'draws')::integer old_draw_count,
          (rec.source_counts->>'matches')::integer old_match_count,
          rec.source_fingerprint
   from control_center_private.tennis_season2_week1_recovery_plan_v1 rec
   where rec.run_id=p_run_id
   order by rec.competition_id
 loop
    v_reply:=public.allocate_tournament_applications_v3(v_comp.competition_id);
    if v_reply->>'status'<>'processed' then
      raise exception 'Cannot reselect competition %: %',v_comp.competition_id,v_reply;
    end if;

    if v_comp.old_draw_count=1 then
      v_reply:=public.publish_tournament_draw_v1(v_comp.competition_id);
      if v_reply->>'status'<>'published' then
        raise exception 'Cannot republish competition %: %',v_comp.competition_id,v_reply;
      end if;
      v_published:=v_published+1;
    end if;

    select count(*) into v_rebuilt from public.tournament_matches
      where competition_id=v_comp.competition_id;
    select count(*) into v_human_evaluated from public.tournament_applications a
      join public.players pl on pl.id=a.player_id
      where a.competition_id=v_comp.competition_id and pl.player_type='human'
        and a.status in ('accepted_main_draw','accepted_qualification','rejected','superseded');
    select md5(jsonb_build_object(
      'applications',(select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb)
          from public.tournament_applications a where a.competition_id=v_comp.competition_id),
      'entries',(select coalesce(jsonb_agg(to_jsonb(en) order by en.id),'[]'::jsonb)
          from public.tournament_entries en where en.competition_id=v_comp.competition_id),
      'matches',(select coalesce(jsonb_agg(to_jsonb(m) order by m.id),'[]'::jsonb)
          from public.tournament_matches m where m.competition_id=v_comp.competition_id),
      'draws',(select coalesce(jsonb_agg(to_jsonb(d) order by d.competition_id),'[]'::jsonb)
          from public.tournament_draw_publications d where d.competition_id=v_comp.competition_id)
    )::text) into v_new_hash;

    insert into control_center_private.tennis_season2_week1_reselection_receipts_v1
      (run_id,competition_id,previously_published,original_matches,rebuilt_matches,
       submitted_human_preferences,evaluated_human_applications,matching_new_draw,
       resulting_state_fingerprint,source_fingerprint)
    values(p_run_id,v_comp.competition_id,v_comp.old_draw_count=1,
      v_comp.old_match_count,v_rebuilt,
      (select count(*) from control_center_private.tennis_season2_week1_preentries_v1
       where run_id=p_run_id and competition_id=v_comp.competition_id and status='selected'),
      v_human_evaluated, (v_comp.old_draw_count=1 and v_rebuilt>0) or
         (v_comp.old_draw_count=0),
      v_new_hash,v_comp.source_fingerprint);
    v_examined:=v_examined+1;
    v_total_new_matches:=v_total_new_matches+v_rebuilt;
 end loop;

 if v_examined<>22 or v_published<>16 or v_inserted<>v_choice_count then
   raise exception 'Week 1 regeneration failed: competitions %, draws %, applied humans %/%',
      v_examined,v_published,v_inserted,v_choice_count;
 end if;
 if exists(select 1 from control_center_private.tennis_season2_week1_reselection_receipts_v1
     where run_id=p_run_id and not matching_new_draw) then
    raise exception 'One or more new Week 1 draws failed their completeness check';
 end if;
 update control_center_private.tennis_season2_week1_recovery_plan_v1
 set plan_status='reconciled',updated_at=clock_timestamp()
 where run_id=p_run_id and plan_status='approved';
 if not found then raise exception 'Could not finalize Week 1 recovery records';end if;

 return jsonb_build_object('status','reconciled','competitions',v_examined,
  'draws_republished',v_published,
  'human_preferences_applied',v_inserted,
  'generated_match_records',v_total_new_matches,
  'transaction_atomic',true);
end
$function$;
REVOKE ALL ON FUNCTION control_center_private.reconcile_tennis_season2_week1_draws_v1(uuid) FROM PUBLIC,anon,authenticated;

-- verify_tennis_season2_week1_reconciled_draws_v1
CREATE OR REPLACE FUNCTION control_center_private.verify_tennis_season2_week1_reconciled_draws_v1()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public', 'control_center_private'
AS $function$
with intended as (
 select r.run_id from control_center_private.tennis_season_transition_runs_v1 r
 where r.source_season=1 and r.target_season=2
 order by r.created_at desc limit 1
),
outcomes as (
 select plan.run_id,plan.competition_id,plan.plan_status,receipt.previously_published,
  receipt.resulting_state_fingerprint,receipt.source_fingerprint,
  plan.source_fingerprint as recorded_source_fingerprint,
  md5(jsonb_build_object(
    'applications',(select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb)
       from public.tournament_applications a where a.competition_id=plan.competition_id),
    'entries',(select coalesce(jsonb_agg(to_jsonb(e) order by e.id),'[]'::jsonb)
       from public.tournament_entries e where e.competition_id=plan.competition_id),
    'matches',(select coalesce(jsonb_agg(to_jsonb(m) order by m.id),'[]'::jsonb)
       from public.tournament_matches m where m.competition_id=plan.competition_id),
    'draws',(select coalesce(jsonb_agg(to_jsonb(d) order by d.competition_id),'[]'::jsonb)
       from public.tournament_draw_publications d where d.competition_id=plan.competition_id)
  )::text) as live_fingerprint,
  (select count(*) from public.tournament_draw_publications d
   where d.competition_id=plan.competition_id) as publication_count
 from control_center_private.tennis_season2_week1_recovery_plan_v1 plan
 join intended i on i.run_id=plan.run_id
 left join control_center_private.tennis_season2_week1_reselection_receipts_v1 receipt
   on receipt.run_id=plan.run_id and receipt.competition_id=plan.competition_id
),
pref as (
 select count(*) as selected_count,
    count(*) filter(where
      exists(
       select 1 from public.tournament_applications a
       where a.competition_id=p.competition_id and a.player_id=p.player_id
         and a.world=p.world and a.owner_user_id=p.owner_user_id
         and a.application_source='human'
         and a.status in ('applied','accepted_main_draw','accepted_qualification','rejected','superseded')
      )
    ) as reconciled_count
 from control_center_private.tennis_season2_week1_preentries_v1 p
 join intended i on i.run_id=p.run_id
 where p.status='selected'
),
summary as (
 select
  count(*) as total_competitions,
  count(*) filter(where plan_status='reconciled') as reconciled_competitions,
  count(*) filter(where resulting_state_fingerprint is not null) as receipts,
  count(*) filter(where resulting_state_fingerprint=live_fingerprint) as matches,
  count(*) filter(where source_fingerprint=recorded_source_fingerprint) as archived_provenance_matches,
  count(*) filter(where previously_published and publication_count=1) as republished_draws,
  count(*) filter(where not previously_published and publication_count=0) as underfilled_unpublished
 from outcomes
)
select jsonb_build_object(
 'total_week1_competitions',total_competitions,
 'reconciled_competitions',reconciled_competitions,
 'reselection_receipts',receipts,
 'live_fingerprints_matching',matches,
 'original_archive_provenance_matching',archived_provenance_matches,
 'draws_republished',republished_draws,
 'pending_underfilled_draws',underfilled_unpublished,
 'human_preferences_saved',(select selected_count from pref),
 'human_preferences_processed',(select reconciled_count from pref),
 'ready_for_cutover',total_competitions=22 and reconciled_competitions=22
    and receipts=22 and matches=22 and archived_provenance_matches=22
    and republished_draws=16 and underfilled_unpublished=6
    and (select selected_count=reconciled_count from pref),
 'original_source_archive_is_a_full_backup',false
) from summary
$function$;
REVOKE ALL ON FUNCTION control_center_private.verify_tennis_season2_week1_reconciled_draws_v1() FROM PUBLIC,anon,authenticated;
