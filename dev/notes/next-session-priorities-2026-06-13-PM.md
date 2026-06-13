# Next-session priorities — 2026-06-13 (PM)

**Supersedes** `next-session-priorities-2026-06-13.md` (the AM doc, which
predated the warmup-flip *merge* and still said "DO NOT FLIP" — now wrong;
see P0 below). Check main CI green before dispatching.

## What changed since the AM doc (2026-06-13 day session)

1. **Warmup default FLIPPED + merged (#1566)** — reversing the AM doc's
   "don't flip". The maintainer reframed `suppress_warmup_trading` from a
   *performance* question (where the WF-CV said don't-flip — warmup-trading is a
   net-beneficial bull "running start") to a *correctness* invariant ("measured
   window = window only; a 210-day backtest has 210 days of trades, not 420"),
   where that running-start gain IS the contamination. Default is now `true`.
   **Load-bearing: ZERO goldens re-pinned** — standalone goldens have cold
   warmup (no warmup trades), so the flip is bit-identical for them; it only
   changes **WF-CV / rolling-start matrices** (warm-indicator warmups). Both QC
   gates APPROVED with R3-NA (correctness fix, not alpha promotion).
2. **Cash-floor / close-path cluster scoped for GHA** (`dev/status/cash-floor-correctness.md`,
   track owner feat-weinstein). Each NS lands a **default-off flag** (no-op on
   merge; default-flip stays human-gated). The GHA orchestrator already built
   **NS1 → PR #1567** (cash-floor closing-trade exemption, #1557#3).
3. **#1563 filed** — short-sale proceeds not collateral-locked in backtests
   (margin-off → short sizing over-deploys). Moot for long-only Cell-E; matters
   for the long-short track. Scoped as cash-floor NS2 (design-rec first).
4. Merged: #1556, #1558, #1560, #1561, #1564, #1565, #1566. Stale ci-watchdog
   #1320 closed. Main green at db23af3d0.

## P0 — finish the GHA cash-floor cluster (mostly self-driving)

The cash-floor cluster is **`[non-blocking]`** per `.claude/rules/gha-local-coordination.md`
— the orchestrator owns dispatch → QC → merge end to end. Next session:
- **Check #1567 (NS1) landed** (it had both QC reviews + perf-smoke green when
  this doc was written; build-and-test was finishing). If it's stuck (CI red, QC
  NEEDS_REWORK past the cron, or merge not done), unstick it; otherwise it should
  be merged already.
- **NS2 (#1563 short-proceeds), NS3 (#1557#2 CancelExit), NS4 (the cash-floor
  opportunity-cost WF-CV experiment)** follow on subsequent orchestrator runs.
  NS3 partly obviated by NS1 (with the exemption, a cover never gets rejected, so
  the CancelExit revert is pure defense-in-depth) — reassess its scope after NS1.

## P0 (human decision — yours) — core-Portfolio default-flips

After NS1 + the NS4 experiment land, the actual **promotion** (flipping the
cash-floor exemption default on, and any #1563 proceeds-fix default) needs your
call. The flags land default-off; the experiment decides; you approve the flip.

## P1 — re-measure WF-CV / matrices under the FLIPPED warmup semantics

#1566 changed what WF-CV and the rolling-start matrices measure (warmup trades
now suppressed → honest fold-level numbers). The AM-doc P2 "definitive matrix on
composition-policy universe" should now be **re-run under the new default**, and
the prior WF-CV/matrix numbers (e.g. `project_rolling_start_matrix_first_run`)
are now measured under the old (contaminated) semantics — flag any that get
re-cited. The warmup WF-CV in `dev/experiments/warmup-comparison-2026-06-12/`
already has the off/on fold numbers if a quick reference is needed.

## Carried

Factor-decomposition lens (`project_index_beating_structural_bar`); weekly
>1%-ADV screener gate; trade-forensics LOW items.

## Cleanup nit (fold into next PR touching the file)

`trading/trading/backtest/walk_forward/test/test_variant_matrix.ml:243` — a
comment still calls `false` "the no-op default" for `suppress_warmup_trading`;
post-flip the default is `true`. Prose-only, breaks no contract; not worth its
own ~45-min-CI PR.

## Key references

`project_warmup_trading_running_start` (the flip + estimand lesson),
`project_exit_fill_reject_zombie` (#1553), `.claude/rules/gha-local-coordination.md`
(blocking-vs-non-blocking), `dev/status/cash-floor-correctness.md` (the NS queue),
issues #1557 / #1563.
