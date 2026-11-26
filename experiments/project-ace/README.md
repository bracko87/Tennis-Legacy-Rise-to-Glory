# Project Ace isolated proof of concept — 2026-11-26
Run locally from repository root: `node experiments/project-ace/engine.test.cjs` (Node 18+).
Engine commit cc8483cfaed5088877955a04b18c7999f51146a2; test commit d1f56f2804b9468efaae3e705fb0ed1439094ef1.

## Evidence
The committed engine source was fetched and executed in an isolated JavaScript runtime with an assertion adapter; all seven test groups passed. The native Node command is provided for independent local verification, not claimed as executed here.
- 200 full matches across best-of-3 and best-of-5, 139 tiebreaks including seven deciding-set 10-point tiebreaks; scoring, service order, totals and condition bounds checked.
- 100 paired interventions after set one, identical seed and input: 100 changed next-point conditional probability, 44 changed final set scoreline. Previous event history unchanged for every pair.
- Seed 6 control lost 2–6, 6–2, 6–7; coached won 2–6, 6–2, 6–2. This is an existence proof, not evidence that coaching always improves results.
- Restart from serialized state deterministic; stale game revision rejected; invalid commands and completed match commands rejected.
- No predetermined winner or future point events at initialization.

## Boundaries
This is a synthetic, dependency-free prototype inspired by the documented SQL v1/v2 point equations, not a verified port of current production SQL. No actual account data, auth, live clock, UI, server persistence, scheduler or database access. The in-memory revision check is not a transactional concurrency guarantee. Point event probabilities are diagnostic and should not automatically be exposed to users. No calibration or production load validation. Best-of-five deciding tiebreak supported; best-of-three Grand Slam deciding-set rules and official competition variants still need verification. No production migration or deploy. No paid database branch.

## Next
Implement isolated server-side state and scheduling, local-only test identity mapped to the designated admin, independent server authorization, negative tests for anonymous/other users and test fixture isolation. Use synthetic profiles; no production mutation. Verify database recovery point before production integration. Add live read projection that reveals only elapsed points; coach commands effective at next game. Preserve tournament and historical replay contracts.
