# Tennis Legacy — System Health Integration Policy

Status: **Required for every new production feature/process**
Effective: 2026-10-02

From this point forward, every new production subsystem, scheduled job, lifecycle process, recovery mechanism, or player-critical initialization flow must be integrated into System Health and therefore visible in the Game Control Center.

## Required implementation rule

A new production feature is not complete until its operational health is observable.

For each new subsystem, determine which of the following applies:

1. **Scheduled/background process**
   - Register the cron/job in `system_monitor_processes`.
   - Define expected execution interval and stale threshold.
   - Detect missing/disabled jobs.
   - Detect repeated failures or stale execution.
   - Log runs to `system_monitor_runs`.
   - Raise/resolve `system_incidents`.

2. **Business/lifecycle process**
   - Register a `business_check` process.
   - Verify the actual expected game state, not just whether a cron returned success.
   - Use the same authoritative game-time/deadline calculation as the production process.
   - Log every health-check execution.
   - Raise a deduplicated incident when unhealthy.
   - Resolve it automatically once healthy.

3. **Player-critical transactional process**
   - Prefer transactional/idempotent execution so partial state cannot be committed.
   - Add integrity monitoring for the resulting state.
   - Add automatic recovery only when it is safe and deterministic.
   - Alert if recovery cannot restore the expected state.

## Control Center requirement

System Health is the authoritative operational source for Control Center.

Every registered process must appear in the `system-health` snapshot with:
- process key
- label/category
- latest run status
- latest run timestamp
- latest summary/error
- current incident state

The independent `control-center-system-health-snapshot-v1` delivery job publishes this state to Control Center.

Do not build a second, independent timing or health interpretation in the Control Center UI.

## Alerting rule

For genuine critical failures:
- create/update the System Health incident
- surface it in Control Center
- queue administrator email notification
- keep the existing repeated critical reminder behavior while unresolved
- stop reminders automatically after resolution

Do not generate alerts for normal waiting/grace states.

## Recovery rule

Where safe, critical processes should have an independent recovery path.

The recovery path must:
- not depend on the failed primary path
- be idempotent
- preserve audit/history
- never convert a technical failure into a destructive game event
- raise a critical incident if recovery also fails

## Completion checklist for future features

Before a new production feature is considered complete, verify:
- primary implementation works
- idempotency is defined where value/state is granted
- health process is registered
- stale/failure detection is defined
- business-state correctness is checked
- safe recovery exists where appropriate
- incident dedupe/resolution works
- Control Center snapshot contains the process
- administrator alerting works for critical failures
- a controlled failure test has been performed

## Current example: New Player Starting Scheme v1

Registered processes:
- `cron:tennis-new-player-starting-scheme-health-v1`
- `check:new_player_starting_scheme`

The health check verifies:
- master career initialization trigger
- $25,000 finance configuration
- exact starter equipment catalog
- Coin and equipment idempotency guards
- all 250 countries mapped to 10 property tiers
- post-enforcement initialization audit presence
- opening cash correctness
- one-time 20-Coin grant
- exact starter equipment package
- Day-1 validation state

A narrow automatic recovery is attempted only for very recent incomplete careers that have no subsequent user-managed state.
