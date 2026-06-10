# Next-session priorities — 2026-06-11

**Supersedes** `next-session-priorities-2026-06-10-PM.md`. Check main CI green
before dispatching.

## TL;DR — the 2026-06-10-PM P0: NO-BUILD decision (the screen, corrected)

The P0 from the prior handoff — **harvest-and-rotate by forward expected return**
(trim a mature/extended Stage-2 winner to fund a cash-blocked fresh early-S2
candidate; the AAPL-dividend logic) — was screened **read-only before building**.

**⚠ The first writeup overclaimed ("REJECTED, decisively"); corrected after review.**
The real distributions are weaker and differently shaped — see the new rule
`.claude/rules/mechanism-validation-rigor.md`:

- **(b) realizable per-event test** `diff = C_fwd − P_mostext_fwd` over the 373
  actual cash-blocked decisions: **median −0.12%, mean −1.79%, C beats P 49.9%**
  (p10 −22.9% / p90 +16.3%) — a **coin flip** per decision; the negative *mean* is
  a fat-LEFT-tail effect (occasionally rotating out of a name that then rips), not
  a consistent disadvantage.
- **(a) fresh-early vs mature-extended** fwd-4w: early mean +1.15% (**+14.9%/yr**)
  vs mature +2.59% (**+33.6%/yr**) — large mean gap but distributions overlap
  almost fully, n small (311 vs 114), and **mature-extended is survivor-selected**
  (not the real-time decision; biased favourable).

**What the screen supports: no obvious free lunch + a mild tail-risk cost to
rotating → don't prioritize a build** (also leaning on the standing prior against
explorative position-management). It is **not** a rigorous rejection — that needs
the mechanism as a default-off **surface** (`k`, late-threshold, pick-rank)
backtested under WF-CV with the engine doing the real rotation + stops. Full record
(incl. corrected distributions + `p0_stats.sh`):
`dev/experiments/harvest-rotate-validation-2026-06-10/`. Memory:
`project_harvest_rotate_rejected` + `project_mechanism_validation_rigor`.

## ⏳ IN PROGRESS — the rigorous harvest-rotate test (user greenlit 2026-06-10 PM)

The user chose to run the **rigorous** test (mechanism as a default-off surface →
WF-CV), explicitly to get the *decomposed why* (timing / picks / structural-tax /
cost), not just a verdict. Plan: `dev/plans/harvest-rotate-rigorous-test-2026-06-10.md`.

Build sequence status:
- **Step 1 — core partial-exit transition: ✅ MERGED #1525.** Strategy-agnostic
  `TriggerPartialExit`; `Holding→Exiting→Holding(q−trim)`; default behaviour
  bit-identical (dead code until a caller wires it). 3-gate green.
- **Step 2 — harvest-rotate mechanism (NEXT).** Behind `harvest_rotate_enabled`
  (default-off) in the Weinstein strategy: faithful **late-flag** trigger + detect a
  cash-blocked higher-score candidate (the existing `alternatives_considered` /
  `Insufficient_cash` signal) → emit `TriggerPartialExit(k)` on the held winner +
  the rotation entry. Grounding the dispatch needs: where `on_market_close` builds
  transitions, and where the blocked-candidate signal is available to the strategy.
- **Step 3 — Variant_matrix axis wiring** (`harvest_rotate_enabled`, `k`, trigger,
  `min_candidate_score`).
- **Step 4 — decomposed WF-CV** on top-3000 (~4h) + **Step 5 — decision/ledger**.

Expected outcome REJECT (per `project_edge_is_the_fat_tail`: winner-touching levers
tax the tail) — but the deliverable is the WF-CV-grade *why*, quantifying how much is
structural-tax vs timing vs picks.
- **Concentration-TRIM direction — weak on a return basis.** Trimming an
  extended winner moves capital to a use with (at best) no better expected return.
  The only residual
  reason to bound single-name NAV% is **unrealised-mark / tail-RISK**
  (`project_broad_universe_790_mtm_inflated`) — a *risk* argument, not a return
  one — and prior risk-cap probes were already strictly dominated. Revive only if
  framed explicitly as tail-risk insurance with a metric that rewards it (e.g.
  capital-relative DD / Ulcer), not as a return improvement.

## Open priorities (carried, re-ranked)

**P0 — Re-weight the "top-3000 = artifact" priors (docs).** The liquidity work +
this validation both show the broad-universe edge is real on realized + liquid
trades and that the concentration *is* the return. Sweep the status/notes prose
that still treats top-3000 returns as an MTM/illiquidity artifact and reconcile.
`project_pit_survivorship_inflation` (survivorship in the SP500 composition golden)
is a *separate, still-valid* concern; keep it.

**P1 — Trade-forensics tooling (carried).** PR-3 post-exit capture ratio + PR-4
auto-`stage_chart` for top-impact trades remain open
(`dev/notes/trade-forensics-2026-06-09.md`). LOW urgency.

**P2 — (optional) Fix the MFE/MAE harness gap.**
`Trade_audit.exit_decision.max_favorable_excursion_pct` and
`max_adverse_excursion_pct` are **always 0** in every recent run — the simulator
step-stream never populates them. This blocks any audit-based give-back / capture
analysis (the validation above had to recompute forward returns from bars). Small,
well-scoped fix if MFE/MAE-based forensics is wanted.

## Where the strategic search stands

The discrete-feature / position-management levers explored over the last sessions
(cascade-reweight, laggard, force-exit, stage2-ma-hold, macro-bearish-trim,
late-flag stop-tighten, early-admission, hysteresis, continuation — each
WF-CV-rejected or kept default-off — **and now harvest-rotate**, de-prioritized at
the cheap-screen stage). The recurring lesson:
the Cell-E baseline is near-optimal on its surface, and the broad-universe edge is
the **fat-tailed let-winners-run** behaviour — mechanisms that trim, rotate, or
re-time winners keep destroying that tail. Future search should bias toward levers
that *preserve* the tail (universe breadth, entry quality, holding discipline) and
away from anything that caps or recycles a still-advancing winner.

## Infra notes

- Cell-E top-3000 single full run ≈ 30min (snapshot mode, `snap_top3000_2011`,
  fork parallel=1). Writes `trades.csv` + `trade_audit.sexp` (incl.
  `alternatives_considered` / `Insufficient_cash`). **Run via**
  `scenario_runner.exe --dir <spec-dir> --snapshot-dir /tmp/snap_top3000_2011
  --fixtures-root / --no-emit-all-eligible` — note `--fixtures-root /` is required
  because the spec's `universe_path` is repo-relative (`Filename.concat` does not
  special-case absolute paths).
- Forward-return-from-bars: **use the `adjusted_close` column (col 6), not raw
  close (col 5)** — raw close has reverse-split glitches (a fake +50,200% 4-week
  return on NDN poisoned the first pass). Always median + winsor on top-3000 bars.
