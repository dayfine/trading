# Next-session priorities — 2026-06-10 (PM)

**Supersedes** `next-session-priorities-2026-06-10.md`. Overnight autonomous
session (2026-06-09 night → 2026-06-10). Check main CI green before dispatching.

## TL;DR — what the night settled + the new steering idea

1. **Cascade-selection inversion: validated, then the fix REJECTED.** A+/confirmed
   breakouts under-perform early-Stage2 on win-rate (all breadths), but
   up-weighting early entries **fails WF-CV** — baseline (the historical 2:1
   breakout/early ratio) is the sole Pareto cell, highest DSR (0.9883); every
   reweight worse on Sharpe+Calmar+MaxDD, per-fold gate all FAIL. The breakout
   premium is **earning the fat tail**, not a scoring error. Ledger:
   `2026-06-10-cascade-w-early-stage2-reweight-top3000.sexp` (Reject).
2. **Liquidity is a non-issue at our scale — top-3000 is NOT illiquid.** (User
   directive.) 91% of top-3000 trades < 0.1 days-of-ADV; the fat-tail winners and
   the cascade-inversion are all in liquid names; the edge survives realistic
   position caps. The AXTI $6.69M mark (78% NAV) is on a Verified $983M/day name →
   real + exitable. **Reframes the "top-3000 = MTM-inflation artifact" prior.**
   Writeup: `dev/notes/trade-realism-liquidity-findings-2026-06-10.md`.
3. **Concentration is largely the return** (entry-cap probe): shrinking the entry
   cap 0.14→0.07 cuts return ~6× (+761%→+116%) for only ~5pp MaxDD. The monsters
   need size. → don't shrink entries; a 14% entry / 35-50% NAV bound are fine. The
   live lever is **not** a risk cap — see P0.

## The steering reframe (user direction, 2026-06-10 PM) → P0

The right mechanism is **capital allocation by forward expected return**, not a
concentration risk-cap. As a winner (e.g. AXTI) climbs its Stage-2 curve, the gain
is banked but the *forward* expected return per dollar still parked in it falls
(later in the move, more extended above the 30-week MA, nearer the Stage-3 top). A
fresh early-Stage-2 breakout has *higher* forward expected return per dollar (more
move ahead), at higher risk. So at the margin: **harvest some of the mature winner
and rotate into the fresher, cash-blocked candidate** — exactly the AAPL-dividend
logic (return capital when reinvestment IRR drops below the alternative).
Concentration is the *symptom* (a big mature $ position = lots of capital earning a
declining forward rate), not the target.

## What shipped (10 PRs, all merged)
- **#1509 / #1510** — cascade-inversion forensics writeup + memory.
- **#1512 / #1513** — `w_early_stage2` config axis (decouple early-Stage2 weight,
  default-off) + the `[@sexp.default None]` fix that made it actually overridable.
- **#1514** — liquidity-realism findings + cascade-reweight WF-CV scaffold.
- **#1515** — concentration/rebalance plan.
- **#1516** — cascade-reweight WF-CV REJECT ledger + report + this handoff.
- **#1517 / #1518** — agent-memory snapshots + concentration entry-cap probe note.
- **#1519** — handoff date fix (this doc).

## Priorities for next session

**P0 (NEW) — Harvest-and-rotate by forward expected return.** The live lever. Both
required signals already exist in the system and are currently thrown away:
- **"Forward return declining" detector** = the Stage-2 `late` flag (MA
  deceleration, fires 7-26 wk before tops, 6/7 episodes) — *computed but discarded
  for held positions* today, consumed only at entry
  (`project_stage_late_flag_discarded`). (A late-flag *stop-tighten* was REJECTED
  #1446, but that was **risk**-framed; this is **allocation**-framed — same signal,
  different and more principled use.)
- **"Better candidate to enter" detector** = the trade-audit already logs
  `alternatives_considered … reason_skipped Insufficient_cash` per entry — the
  fresh names we couldn't fund because capital was tied up.

  **Validate the thesis BEFORE building** (the discipline that just saved us on the
  cascade-reweight). Two measurable questions:
  - **(a) Forward-return decay:** for held positions, does subsequent N-week return
    fall as the position gets later / more-extended in Stage 2 — and is it lower
    than fresh early-S2 entries' forward returns? (Justifies harvesting the mature.)
  - **(b) Opportunity cost:** how often are early-S2 candidates skipped for
    insufficient cash *while* mature extended winners are held, and would the
    skipped names have out-returned the capital left in the mature hold?

  If both hold → build a **default-off harvest-rotate dial** (trigger: held
  position is late/extended **and** a higher-forward-return candidate is
  cash-blocked → trim the mature to fund it). If forward return does *not* decay,
  it's just churn+cost → drop it. Weinstein-faithful (exit-aggressiveness +
  rotate-to-leadership, the "trader's way"); default-off; WF-CV + confirmation grid
  before any default flip.

  **First step:** regenerate the top-3000 run (~38min; the `trade_audit.sexp` with
  the `Insufficient_cash` records was cleaned up) and run the (a)/(b) measurements.
  Scripts/templates: `/tmp/liq_full.sh`, `dev/plans/concentration-rebalance-2026-06-10.md`,
  `dev/notes/concentration-entry-cap-probe-2026-06-10.md`.

**P1 — Enabling core change: a partial-exit transition (decision item).** Both the
harvest-rotate (P0) and any concentration trim need it: today `TriggerExit` is
**whole-position only** — there is no transition to sell *part* of a position. Land
a small, strategy-agnostic `TriggerPartialExit` (or `target_quantity` on
`TriggerExit`) + engine/simulator support (`ExitFill` already supports partial
`filled_quantity`; the gap is the initiating transition + "return to Holding"
instead of "Closed"). Touches the A1 core watch-list
(`trading/trading/strategy/`, `engine`, `simulation`) → **needs human sign-off per
CLAUDE.md.** This gates P0's build (not its validation, which is read-only). Plan:
`dev/plans/concentration-rebalance-2026-06-10.md` §build-scoping.

**P2 — Re-weight the "top-3000 = artifact" priors.** The liquidity work shows the
broad-universe edge is real on realized + liquid trades. Past rejections (laggard,
force-exit, stage2-ma-hold, cascade-reweight) rest on cross-breadth / per-fold
generalisation — which is correct — NOT on an implicit "top-3000 is illiquid/junk"
assumption. `project_pit_survivorship_inflation` (survivorship in the SP500
composition golden) is a *separate, still-valid* concern; liquidity is not.

**P3 — Trade-forensics tooling (carried).** PR-3 post-exit capture ratio + PR-4
auto-`stage_chart` for top-impact trades remain open
(`dev/notes/trade-forensics-2026-06-09.md`). A productionised `trade_liquidity`
tool is LOW priority (liquidity is a non-issue at current scale).

## Closed / negative results (do not revive)
- `w_early_stage2` reweight — REJECTED (WF-CV). Axis stays default-off.
- Tight entry cap (< 0.14) as a concentration control — strictly dominated
  (entry-cap probe: ~6× return loss for ~5pp MaxDD). Don't pursue.
- "top-3000 returns are an illiquidity artifact" — disproven; don't repeat it.

## Infra notes
- WF-CV on top-3000 (15 folds, 4 variants, fork-per-fold parallel=1) ≈ **4h**
  (~4min/fold after warmup). N=3000 can't safely parallelise (container 7.75GB).
- `snap_top3000_2011` warehouse (1.5G) still on container `/tmp`. Liquidity scripts:
  `/tmp/liq_{analyze,summary,full}.sh` (bar store `data/<f>/<l>/<SYM>/data.csv`,
  $-vol = close×volume). Single top-3000 full run ≈ 38min, writes `trade_audit.sexp`
  (entry incl. `alternatives_considered` / `Insufficient_cash`) + `trades.csv`.
