---
name: project-never-measure-on-sp500
description: "USER RULE 2026-08-20: never measure performance on the sp500 universe — it is a sanity-check/rule-validation fixture only. Every verdict-bearing number comes from broad (top-3000). Codified in .claude/rules/universe-discipline.md; supersedes promotion-confirmation.md's old 'SP500-510 vs top-3000' grid example."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7959dddf-3101-4cab-8f02-c90b77a7d8fd
  modified: 2026-08-20T19:25:44.041Z
---

**User instruction, 2026-08-20:** *"we do NOT care about running on S&P500
universe. even 5y should run on broad."*

Codified as `.claude/rules/universe-discipline.md` (PR #2444).

## The line is PURPOSE, not file

`universes/sp500.sexp` is in ~78 committed specs and most are fine.

- **OK:** goldens / regression pins, determinism tripwires, mechanism-liveness
  checks ("does this flag fire at all"), smoke tests, CI speed.
- **NOT OK:** null / noise-floor measurements meant to generalise; any A/B or
  surface producing a verdict; a confirmation-grid cell; any figure quoted as
  evidence in a writeup's conclusion.

## The episode that forced it

PR #2436 measured the 5y drawdown null on **sp500-500 (187 traded names)** and
concluded `Range_top_breakout` "fails its first independent cell" — against a
26y cell on **top-3000**. That moved **period AND universe at once**. The record
hedged ("does not attribute the reversal") and shipped anyway; hedging is not
fixing. `dev/experiments/rt-freshness-broad5y-2026-08-20/` re-runs it at
top-3000 PIT-2019 to find out which axis was responsible, with a pre-registered
outcome that **retracts** #2436's headline.

[[project-cell-e-2020-stall-regime]] had **already** recorded that broad universe
is THE lever. The rule exists because that memory did not stop it — see
[[feedback-check-memory-before-claiming-about-code]] for the same failure shape.

## Two knock-ons

1. **`promotion-confirmation.md` used to endorse the mistake** — its grid section
   named *"SP500-510 vs top-3000"* as the universe-diversity example. Now
   **broad-vs-broad only**: a different PIT vintage (`top-3000-2019` vs
   `top-3000-2000`) or a different breadth tier (top-1000 vs top-3000).
   Narrowing to a large-cap index silently moves breadth while you think you are
   moving period.
2. **PIT vintage tracks the window.** Moving a broad cell to a new period means
   moving the composition year with it. `top-3000-2000.sexp` on a 2019 window is
   a different defect, not a control.

## The rule is RE-codification — the directive is from 2026-07-04 (#2445 audit)

`2026-07-05-continuation-add-v2-surface.sexp` says verbatim in its own
`base_scenario`: *"no sp500 per user directive 2026-07-04"*. So the instruction
predates 08-20 by ~6.5 weeks, was honoured **once**, and lapsed inside a week.
Three sp500-based verdicts follow it (`07-09-catstop-deep-wfcv` Reject,
`07-09-portfolio-floor-default-off` **Accept**, `08-04-sim-entry-stoplimit`
Reject), then #2436. **A stated directive decayed in one week; that is the
argument for U1–U4 being greppable checks, not prose.**

## Ledger exposure (audited 2026-08-20, all 59 entries, #2445)

**16 entries have a sole sp500 base** — 4 Accept, 10 Reject, 2 Inconclusive.

- ⚠ **`2026-06-23-ad-default-flip-confirmation-grid` has ZERO conforming
  cells** — an Accept marked PROMOTE that **flipped a default**, on a grid of
  sp500-2000 / sp500-2010 / sp500-2015. Three vintages of one index sold as
  universe diversity = exactly what U3 forbids. Its own notes record a
  contradicting long-only spot-check (MaxDD 21.6→31.3, Calmar 0.46→0.26)
  dismissed as "not a grid cell". Live by default, unestablished on broad.
  Contradicts [[project-ad-default-flip]] as currently written.
- **A Reject on sp500 ≠ an Accept on sp500.** Accept shipped on
  non-transferable evidence; Reject means a mechanism was **dismissed without
  a fair test**. 10 untested mechanisms is arguably the bigger cost for a
  program short on levers.

## ⚠ Path name is NOT the universe

`goldens-sp500-historical/` contains **top-3000** scenarios.
`capacity-concentration-BROAD` and `liquidity-overlay-wfcv` are grep hits for
`sp500` and are **not** violations. Any automated U1 check must read the
scenario's universe, never the directory name.

Related: [[project-broad-universe-semantics]],
[[project-pit-survivorship-inflation]],
[[project-composition-golden-survivor-bias]].
