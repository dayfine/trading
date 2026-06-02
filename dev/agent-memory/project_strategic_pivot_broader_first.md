---
name: 2026-05-15 strategic pivot — broader-first beats more-knobs
description: User agreed broader-universe + walk-forward CV + ML-discipline tuning is P0; sector cap / margin / etc. demoted to P1. Synthetic deferred.
type: project
originSessionId: 4d6537ae-8820-4dcd-bdf8-cf449e669439
---
After two cross-window inversions in one week — M5.5 axis-2's 5y→16y
blowup (PR #1086) and the P3-followup combined-axis continuation
sweep (PR #1095) — the limiting factor on strategy improvement is no
longer "what knob to add" but "what the optimizer is looking at".

**Why:**
1. M5.5's 4-axis sweep confirmed Cell E is locally near-optimal on
   the levers it exposes (`memory/project_m5-5-tuning-exhausted.md`).
2. The continuation-combined sweep showed even multi-axis tuning of
   a working detector inverts across 5y → 16y when validation is
   weak (`memory/project_continuation_combined_rejected.md`).
3. PR #1091's slot-budget finding (trade count pinned at 261-266
   regardless of detector tuning) is invisible to single-lever
   sweeps but visible to joint search.
4. PR #1076 / #1089 / #1094 just produced the first survivorship-
   correct universe (510-sym sp500-2010-2026). Now is the moment
   to compound it.

**How to apply:**
- For new feature-work proposals from agents: the bar shifts. A new
  knob with a 5y win is no longer interesting; multi-window stability
  + walk-forward CV is the requirement.
- For tuning experiments: prefer walk-forward CV over fixed-window
  sweeps. Cross-fold variance is now a first-class metric.
- For data work: broader-universe (Russell 3000) + 30y survivorship-
  correct cohort (1996-2026) is the load-bearing P0.
- For synthetic data: defer. Without a specific failure mode to
  study, synthetic fits to our priors about market behavior. Synth-v1/
  v2/v3 already exist for unit-test purposes; that's enough.

**New primary priorities doc:**
`dev/notes/next-session-priorities-2026-05-15.md` (supersedes the
2026-05-14 note). P0 broader-first, P1 features (sector cap, margin),
P2 defer.

**Sequencing recommendation locked in:**
- Phase 1 (1-2 weeks): universe extension to 1996 + 3000-sym cohort.
- Phase 2 (1 week): walk-forward CV harness (30 rolling folds).
- Phase 3 (1 week): multi-parameter Bayesian opt over the full Cell E
  config surface.
- P1 features land in parallel as small PRs.

Tradeoff acknowledged: ~2-4 weeks of foundation work before the next
visible tuning result. Decided that's worth it given the diagnosis.
