---
name: project-trade-forensics-2026-06-12
description: "Trade-level forensics both regimes — laggard rotation is THE profit channel, stops eat -$7M, entry-type edge regime-flips, give-back measured (30pp laggard / 82pp big winners), A2 = silently-broken fold not reporting bug"
metadata: 
  node_type: memory
  type: project
  originSessionId: 78c98b7f-b5bb-42f0-abac-d99c79b0a11d
---

Trade-level forensics (2026-06-12, `dev/experiments/trade-forensics-2026-06-12/`),
652-trade bull (2011-26) + 321-trade bear-decade (2000-11) Cell-E audit ledgers:

- **Exit channels**: laggard_rotation = the de-facto PROFIT-TAKING channel (bull:
  192 exits +$11.0M avg +21%; bear: +$1.38M) vs stop_loss the loss-eater (bull:
  450 exits −$7.0M; bear −$1.26M). In the bear decade the two channels NET TO
  ZERO — all return was terminal unrealized carry of the post-2009 leg.
- **Concentration**: top-5 trades = 165% of bull realized P&L; AXTI (entered 14%,
  ran 36×, never trimmed) ≈ 100% of terminal bull NAV ($19.7M of $19.9M).
- **Entry-type edge REGIME-FLIPS**: post-2011 Early-Stage2 (score 70) = +34.6%/
  trade ≈ 98% of realized P&L while Stage1→2 breakouts (80% of trades) ≈ noise;
  in 2000-2011 score-70 is −1.9%/trade and breakouts mildly positive. Cascade
  reweighting on post-2011 evidence = regime bet ([[project_cascade_selection_inversion]]).
- **Give-back measured** (MFE/MAE live again — stale-memory corrected): laggard
  exits give back 30pp (bull)/24pp (bear) from peak; stopped trades avg MFE +6.7%
  (bull)/+12.7% (bear) before dying; MFE>20% cohort gives back 82pp of 142pp —
  the COGS of the 36× tail. Candidate axis: laggard trigger latency
  (rs_13w_neg_weeks) — laggard-touching, not winner-touching.
- **Stop anatomy**: ~70% of trades end at stops, half dead ≤11 days (failed
  breakouts = the bleed); gap-down stops (70% of stops) cost extra ~2.4pp —
  structural. Whipsaw negligible.
- **Macro-gate protection = entry SUPPRESSION** (2002: n=8, 2008: n=11 entries),
  not better picks (2008 win rate 9%).
- **G5**: Cell-E "long" baseline trades Stage4-breakdown SHORTS — net negative +
  unrealistic (no margin model; sub-$17 shorts need 83-362% margin per FINRA
  tiers, see dev/notes/long-short-margin-mechanics-2026-06-12.md; THM short at
  $0.69 bleeding −240% unstopped as a no-bars zombie).
- **A2 RESOLVED TO ENGINE BUG**: the corrupt matrix fold (start 2009-06-26 ×
  top-3000-2000) is a silently-BROKEN BACKTEST: zero trades, NAV flat at
  $352,220.30 from day 1 (initial $1M), totalpnl −$600k w/ empty ledger.
  Deterministic repro; fix dispatched (feat/runner-fold-fixes) with
  loud-failure invariant. Distinct from specimen 1 (MaxDD 190% = likely REAL
  short-blowup math, NAV<0 possible with shorts).

Synthesis doc: `dev/notes/changeable-vs-structural-2026-06-12.md` (6 structural
facts, 6 levers, operating thesis). See [[project_index_beating_structural_bar]],
[[project_rolling_start_matrix_first_run]], [[project_edge_is_the_fat_tail]].
