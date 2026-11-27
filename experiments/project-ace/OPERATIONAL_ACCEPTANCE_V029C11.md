# v0.29-C11 operational acceptance boundary

Disposable CI only. No production authority.

- Both same-day and extended projection paths must share phase, capacity, projected occupancy, live-resource and recovery checks.
- A feeder cannot be moved beyond the scheduled downstream match plus the required recovery interval; affected downstream schedules need coordinated planning rather than silent invalidation.
- Original imported source slots remain unchanged. Readiness revision invalidation, resource reservation and retry receipt are reviewed independently.
- Unknown duration estimates retain 420 minutes. The estimate is not a guarantee of completion.
- Remaining gates: authoritative phase/capacity and duration capture; automatic follow-up discovery from authentic completed match records; unadmitted target handling; coordinated downstream propagation; shared Legacy/Ace transactional authority; authentic database schema verification. The experiment is removed after isolated CI and is not a release migration.
