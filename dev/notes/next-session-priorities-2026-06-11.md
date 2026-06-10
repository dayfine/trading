# Next-session priorities — 2026-06-11

**Supersedes** `next-session-priorities-2026-06-10.md`. Overnight autonomous
session (2026-06-10). Check main CI green before dispatching.

## TL;DR — what the night settled

1. **Cascade-selection inversion: validated, then the fix REJECTED.** The
   forensics finding (A+/confirmed-breakout under-performs early-Stage2 on
   win-rate, all breadths) is real, but **up-weighting early entries fails
   WF-CV** — baseline (the historical 2:1 breakout/early ratio) is the sole
   Pareto-frontier cell, highest DSR (0.9883); every reweight worse on Sharpe +
   Calmar + MaxDD, per-fold gate all FAIL. The breakout premium is **earning the
   fat tail**, not a scoring error. Ledger:
   `2026-06-10-cascade-w-early-stage2-reweight-top3000.sexp` (Reject).
2. **Liquidity is a non-issue at our scale — top-3000 is NOT illiquid.** (User
   directive.) 91% of top-3000 trades < 0.1 days-of-ADV; the fat-tail winners and
   the cascade-inversion are all in liquid names; the edge survives realistic
   position caps (≥100% of realized). The AXTI $6.69M terminal mark (78% NAV) is
   on a Verified $983M/day name → real + exitable, not fantasy. **Reframes the
   "top-3000 = MTM-inflation artifact" prior.** Writeup:
   `dev/notes/trade-realism-liquidity-findings-2026-06-10.md`.
3. **The real open lever is concentration / position-management,** not selection
   or liquidity — and the faithful version needs a core change (below).

## What shipped (7 PRs, all merged)
- **#1509 / #1510** — cascade-inversion forensics writeup + memory snapshot.
- **#1512** — `w_early_stage2` config axis (decouple early-Stage2 weight, default-off).
- **#1513** — fix: `[@sexp.default None]` so the axis is actually overridable
  (`[@sexp.option]` omitted it from `sexp_of_config`, breaking `Overlay_validator`;
  caught by an in-sample reweight run, not the unit tests).
- **#1514** — liquidity-realism findings + cascade-reweight WF-CV scaffold.
- **#1515** — concentration/rebalance plan.

## Priorities for next session

**P0 — Concentration / winner-rebalance (user-flagged, needs a decision).** AXTI at
78% of NAV is the strategy *working* (catching + riding a Stage-2 monster is the
goal — user's framing, and the fill is liquid+real), but single-name concentration
is unmanaged: `max_position_pct_long` caps size at ENTRY only, never re-applied as a
winner appreciates. Plan: `dev/plans/concentration-rebalance-2026-06-10.md`.
**Decision item (CLAUDE.md):** a faithful *soft* concentration cap (trim the excess
only, keep riding) needs a **core position-model change** — `TriggerExit` is
whole-position only; there is no partial-exit transition. Recommended sequence:
(1) land a small, strategy-agnostic `TriggerPartialExit` (or `target_quantity` on
`TriggerExit`) + engine/simulator support as its own PR (decision item — get human
sign-off); (2) build the default-off `max_single_name_nav_pct` trim runner on top;
(3) experiment surface {0.0, 0.25, 0.35, 0.50} on top-3000, measuring **max
single-name NAV%, MaxDD/Ulcer, and realised-vs-unrealised split** (trimming converts
unrealised marks to realised + redeployable capital). A crude full-exit-on-cap
probe (no core change, mirrors `macro_bearish_trim`) can give a directional read
sooner if you want it before the core change.

**P1 — Re-weight the "top-3000 = artifact" priors.** The liquidity work shows the
broad-universe edge is real on realized + liquid trades. Past rejections (laggard,
force-exit, stage2-ma-hold, and now cascade-reweight) should rest on
cross-breadth / per-fold generalisation — which they do — NOT on an implicit
"top-3000 is illiquid/fat-tail-junk" assumption. `project_pit_survivorship_inflation`
(survivorship in the SP500 composition golden) is a *separate, still-valid* concern;
liquidity is not.

**P2 — Trade-forensics tooling (carried).** The forensics loop produced a real
(if ultimately non-promotable) lead this round — keep building it. PR-3 post-exit
capture ratio + PR-4 auto-`stage_chart` for top-impact trades remain open
(`dev/notes/trade-forensics-2026-06-09.md`). A productionised `trade_liquidity`
tool is LOW priority (liquidity is a non-issue at current scale) — the
concentration lens (P0) is the higher-value position-management capability.

## Closed / negative results (do not revive)
- `w_early_stage2` reweight — REJECTED (WF-CV). Axis stays default-off.
- "top-3000 returns are an illiquidity artifact" — disproven; don't repeat it.

## Infra notes
- WF-CV on top-3000 (15 folds, 4 variants, fork-per-fold parallel=1) ≈ **4h**
  (~4min/fold after warmup). N=3000 can't safely parallelise (container 7.75GB).
- `snap_top3000_2011` warehouse (1.5G) still on container `/tmp`. Liquidity scripts:
  `/tmp/liq_{analyze,summary,full}.sh` (bar store `data/<f>/<l>/<SYM>/data.csv`,
  $-vol = close×volume).
