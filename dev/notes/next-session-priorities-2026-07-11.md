# Next-session priorities — 2026-07-11

**Supersedes** `next-session-priorities-2026-07-10.md` (its S-queue is revised
below: S4 CLOSED by evidence, one new candidate added). Main green.

## What the 07-11 session shipped

1. **4y-fold sensitivity MERGED (#1925)** — the user's fold-horizon question,
   answered decisively: hold-exit's 2y-fold dominance (Sharpe 0.753, 8/13,
   DSR 0.9999) INVERTS at 4y folds (0.626 vs baseline 0.719, 2/6, DSR 0.872,
   off frontier). The "strongest fold candidate the program produced" was a
   fold-horizon artifact. Entry-gate consistent at both horizons
   (Sharpe-for-DD realism trade). Artifacts + ledger amendment in
   `dev/backtest/liquidity-overlay-wfcv-2026-07-10/` (4y-*).
2. **Methodology LAW upgraded (4th inversion; now standing):** compounded
   paths flatter compounding; SHORT FOLDS flatter exit mechanisms.
   Tail-dependent mechanism verdicts require a horizon sweep (2y vs 4y+) or
   the rolling-start matrix before being believed.
3. **Realism-defaults flip → draft PR #1926** (DO NOT MERGE until its
   "Remaining re-measures" checklist is empty): entry-gate $1M + stale-exit
   5d default-on; code/tests/ledger/goldens-small batch done; Batches B-D +
   sanity verifies + full linter pass remain, with exact commands in the PR.
4. **Capture-quality reflection** (session log 07-10): monsters ranked by
   loss-of-capture = (1) universe freshness [static PIT universes cannot see
   later IPOs — GME-class], (2) cash/capacity at signal, (3) early-cut slow
   compounders (SKYW/BVN), (4) parabola give-back. Signal detection misses ≈
   none (2 real never-traded 250%+ tickets in 146k). AXTI story + stage chart
   + exit branches recorded in session log; close/MA extension analysis says
   single-specimen thresholds are hindsight (April-28 shakeout trap).

## Queue for next session (revised)

**S0 — finish + merge the realism flip (#1926).** Work the PR's checklist:
Batch B (sp500 5y ×3), Batch C (sp500-2010-2026 pair), Batch D (goldens-broad
×4, warehouse), sanity-wide verifies, full linter pass → gates → merge.
STOP-rule: >20% return move on any sp500 tight golden → report first.

**S1 — AXTI exit verification (extended window).** AFTER S0 (flip re-pins use
the current warehouse): rebuild warehouse to 2026-06-26 (bars in `data/`;
~31 min), re-run honest-tradeable with end 2026-06-26, observe the exit
(branch A: trailing stop advanced past the mid-May pullback → exit ≈$90-100
around Jun 8; branch B: stop at April low → still holding ≈$70). Refresh SPY
TR comparator to same end. Context in the 07-10 session log + stage chart.

**S2 — extension-episode event-level screen** (close/MA ≥2.5-3× held
episodes across deep runs; paired high-trail variants 10/15/20/25%;
distributions, not means). Decides whether an `extension_stop` axis is worth
building. NOTE the upgraded LAW applies: if it advances past screen, its
WF-CV needs a horizon sweep.

**S3 — trader-preset BUNDLE audit + WF-CV** (per weinstein-faithful-core W3;
plan `dev/plans/weinstein-trader-investor-presets-2026-05-31.md`; AXTI as
the qualitative specimen).

**~~S4 — hold-exit promotion~~ CLOSED** by the 4y sensitivity (fold-horizon
artifact). The fold-008 realizability question survives only as an
epistemics curiosity, not a promotion gate.

**S5 — P1b step 3: sleeve lens screen vs TR-SPY** (unchanged).

**S6 — grind-weeks exposure** (carried).

**S7 (NEW, promoted from the capture reflection) — faithful per-week
universes (M6.6).** The largest identified capture loss is universe
staleness: static PIT membership cannot see later IPOs at all (the deep run
literally cannot trade GME). Scope: design first (universe snapshots per
screen date; data + runner seam), then cost it — this is a bigger build than
S1-S6 items and may deserve its own plan doc.

## Standing constraints

NO reversal timing; entry-selection/scale-in/reallocation/envelope/
stop-tuning closed; Weinstein spine fixed. Comparators TOTAL-RETURN.
LAW: horizon-sweep or rolling-start before believing tail-dependent
verdicts. Container: long runs solo; WIP-push within 30 min of any dispatch;
process checks must match strings a watcher's own argv cannot contain.
