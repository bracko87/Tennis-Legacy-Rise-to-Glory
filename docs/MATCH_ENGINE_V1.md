# Tennis Legacy — Match Engine v1

Match Engine v1 is the first production point-by-point tennis simulator. It is intentionally limited to player skills, preferred surface, physical attributes, and current condition. Equipment, staff, weather, injuries and match tactics are extension layers for later engine versions.

## Core principle

Long-term skills define the player's ceiling. Current condition determines how much of that ceiling can be expressed today. Surface preference creates only a small matchup edge. Fitness and Stamina increasingly matter as the match gets longer.

The engine is deterministic for a fixed match/input snapshot through an engine seed, but individual points still contain deterministic pseudo-random variation.

## Technical attributes

- Serve — primary service quality. Drives first- and second-serve point strength, ace probability and indirectly double-fault control.
- Forehand — primary attacking and rally quality from the forehand wing.
- Backhand — primary attacking and rally quality from the backhand wing.
- Return — ability to neutralise or attack an opponent serve and therefore central to break probability.
- Volley — net finishing and transition quality; more relevant on faster surfaces.
- Slice — variety and low-ball control; receives more rally relevance on grass.
- Drop Shot — situational attacking variety; receives more relevance on clay.
- Lob — defensive and transition option against net pressure.
- Smash — overhead finishing and part of net-point strength.

Technical skills do not rise or fall immediately because of a match. They change through long-term development/training systems.

## Physical attributes

- Fitness — general physical capacity. It contributes to rally quality and reduces late-match performance deterioration.
- Stamina — ability to maintain level as points and sets accumulate. Its effect grows throughout a long match.
- Recovery — not a direct point-winning modifier in v1. It reduces how much match fatigue is retained after completion, improving the player's next-round state.
- Movement — court coverage and defensive positioning. It is important to return and rally quality and has extra relevance on clay.

## Current condition

- Fatigue — the strongest negative current-condition modifier. Its penalty is nonlinear and becomes much more significant at high fatigue.
- Sharpness — timing and match readiness; improves how much long-term skill is expressed.
- Focus — the strongest mental component; also contributes to first-serve reliability.
- Confidence — a smaller mental expression modifier and changes after wins/losses.
- Morale — the smallest persistent mental modifier.

Current-condition expression is calculated from a nonlinear fatigue factor multiplied by Sharpness and a mental factor. At perfect condition the multiplier reaches 1.0; poor condition reduces skill expression but does not replace the underlying skill hierarchy.

## Preferred surface

Preferred surface is deliberately a small modifier:

- preferred surface: +1.5% skill expression
- non-preferred surface: -0.5%

This is enough to create a meaningful edge between otherwise equal players without turning surface preference into a dominant rating.

Surface also changes the underlying rally/serve environment:

- Grass slightly increases server advantage and gives more weight to volley/slice/serve-oriented rally skills.
- Clay slightly reduces server advantage and gives more weight to Movement, Stamina and longer-rally skills.
- Hard is the neutral baseline.

## Point model

Each service point determines:

1. first serve in/out;
2. ace possibility on a first serve;
3. double-fault possibility after a first-serve miss;
4. first- or second-serve point probability from server attack vs receiver return/rally defense;
5. point outcome classification: winner, unforced error or forced error;
6. scoreboard state and break-point statistics.

The simulator supports ordinary tennis scoring, deuce/advantage, break points and tiebreaks.

## Match format

- ATP Grand Slam main-draw matches: best of five sets.
- All other current ATP/WTA matches: best of three sets.

Replay length remains compressed to the separate live-replay system's 8–30 minute real-time window.

## In-match physical decline

The engine uses the number of points already played to gradually reduce effective performance. Lower Fitness/Stamina creates a larger drop late in long matches. This means two equally skilled players can separate in a third/fifth set because one maintains physical level better.

## Post-match condition

When the official live replay completes, both players receive an idempotent match-condition event.

- Fatigue rises based on estimated real match duration, sets, games, surface, Fitness, Stamina and Recovery.
- Sharpness generally rises slightly from competitive match play.
- Winner receives a Confidence boost and small Morale boost.
- Loser receives a small Confidence/Morale reduction.
- Very long matches can reduce Focus even for the winner.

These changed values are stored in `player_skills`, so a next-round match automatically uses the new condition.

## Current v1 exclusions

These do not affect winner calculation yet:

- Equipment
- Staff bonuses
- Weather
- Injury modifiers
- Match tactics
- Playing-style outcome bonuses

Playing Style currently affects replay shot flavour only. Later engine versions can add outcome modifiers without changing the v1 base model.

## Replay integration

At scheduled match time the server:

1. snapshots both players' current Match Engine profiles;
2. calculates the full point-by-point match once;
3. seals winner, sets, stats and replay events in the immutable simulation table;
4. starts the locked 1× first-occurrence replay;
5. publishes the winner and applies downstream tournament/condition systems only when the official replay duration expires.

Clients cannot call simulation/registration/finalisation functions directly.

## Prematch preview

`get_tournament_match_engine_preview_v1(match_id)` exposes an authenticated, result-safe comparison of both players' effective pre-match profiles and attribute explanations. Once a simulation is sealed, the preview uses the frozen pre-match snapshot rather than later changed player values. It never exposes the hidden winner or future point sequence.