# Earliness-primary candidate-ranking — WF-CV breadth grid findings (2026-06-29/30)

**Mechanism:** `Screener.config.candidate_ranking = Quality_earliness` (new, default-off).
Equal-score tiebreak led by **earliness** (`weeks_advancing` ascending — freshest
Stage-2 breakout first), then RS magnitude desc → volume desc → ticker.
**Framing:** faithfulness fix (the "do not buy an extended Stage 2" reading),
do-no-harm bar — NOT a return-seeker. The forward-directive successor to the
RS-primary `Quality` mode rejected by `2026-06-29-candidate-ranking-tiebreak-grid`.

**Grid:** top-500 / top-1000 / top-3000 PIT-1998, 2000-2026, 13 folds (2y
non-overlapping), fork-per-fold, snapshot mode. Long-only Cell-E. Baseline =
`Alphabetical` (default). Identical setup to the #1788 RS-primary grid, so
baselines reproduce bit-for-bit (integrity check: passed).

## Result — REJECT for default-flip (earliness is DOMINATED in all 3 cells)

| Cell | baseline Sharpe / Calmar / MaxDD / ret% | earliness Sharpe / Calmar / MaxDD / ret% | (ref) RS-`Quality` Sharpe / Calmar |
|---|---|---|---|
| top-500 (narrow, 327) | 0.667 / 0.850 / 14.79 / 17.80 | **0.649 / 0.657** / 14.98 / 17.20 | 0.636 / 0.676 |
| top-1000 (mid, 514) | 0.660 / 0.690 / 17.29 / 18.68 | **0.590 / 0.586** / 16.09 / 15.70 | 0.666 / 0.669 |
| top-3000 (broad, 1065) | 0.735 / 0.861 / 15.72 / 23.73 | **0.662 / 0.743** / 16.82 / 23.43 | 0.667 / 0.761 |

- **Earliness loses on Sharpe AND Calmar AND return in ALL 3 cells** → Pareto-**dominated**
  by baseline everywhere (the strongest possible reject; worse than RS-`Quality`,
  which at least tied baseline Sharpe in top-1000).
- m-of-n Sharpe gate (≥7/13, Δ≤0.30): **FAIL** in all 3 cells (top-500 9/13 but a
  fold-002 Δ1.12 blowout; top-1000 6/13; top-3000 6/13).
- **The hypothesis is REFUTED.** The directive guessed earliness underperformed in
  `Quality` *because it was relegated behind RS* — i.e. leading with earliness would
  help. The opposite: leading with earliness is **worse than RS-primary and worse
  than baseline**. Earliness does NOT avoid the Calmar tax (top-3000 0.861→0.743 ≈
  RS's 0.861→0.761) and it taxes Sharpe *more* (top-1000 0.590 vs RS 0.666).

## Why (transferable)

The freshest Stage-2 breakout is the **least-confirmed** one — it has not yet shown
sustained advance, so tilting the scarce ~5 funded slots toward it adds idiosyncratic
risk without return. RS-primary tilts toward **extended** names (taxes the fat tail);
earliness tilts toward **unconfirmed** names (taxes Sharpe more). **Both biased sorts
lose to unbiased `Alphabetical`.** High per-fold dispersion confirms it's noise, not
signal: top-3000 fold-012 baseline −20.5% vs earliness +4.1%, but fold-004 baseline
+10.1% vs earliness −1.3% — the tiebreak swings wildly either way per fold and nets
negative when tilted to fresh.

This is the third independent confirmation (after RS-`Quality` #1788 and the prior
score-vs-outcome work) of `project_edge_is_the_fat_tail` + `project_accuracy_is_unreachable`:
**no equal-score tiebreak on any entry feature adds return**, because no entry
feature predicts the realized winner. The scarce-cash slot allocation cannot be
improved by sorting.

## Where the tiebreak bites (mechanism — why this matters at all)

There are two limits, both walked in the **same ranked order**:
1. **Cap** — `max_buy_candidates = 20` (always applied). Bites when >20 candidates
   pass the cascade (broad universe, breakout-rich periods).
2. **Cash/exposure ladder (dominant).** `entries_from_candidates`
   (`weinstein_strategy_screening.ml`) walks ranked candidates through a running
   cash + exposure + sector budget; whoever the budget reaches first is funded, the
   rest hit `Insufficient_cash`. With `max_long_exposure 0.70` / `max_position 0.14`
   → **~5 fundable slots**; the 06-27 autopsy found **97% of entry decisions
   cash-constrained** (16,250 candidates skipped). So the tiebreak overwhelmingly
   decides *which ~5 of many tied grade-A breakouts get the scarce cash* — which is
   exactly why it reshuffles broad results 10-30pp per fold yet nets to noise.

## Decision

- **REJECT** `Quality_earliness` for default-flip. Mechanism stays a **default-off
  config axis** (#1786-style; both QC gates). No revert, no default change.
- `Alphabetical` (unbiased sampler) remains the default — it is not "good", it is
  *unbiased*, and unbiased beats biased-without-signal.
- Forward: the noise-floor **control experiment** (reverse-alpha / symbol-length /
  deterministic-hash≈random tiebreaks) quantifies this — if all uninformative sorts
  cluster and RS/earliness sit inside the band, "no sort beats unbiased sampling" is
  proven. See the companion control-grid (task #7).

## Artifacts
- Specs/base: `spec_top{500,1000,3000}.sexp`, `base_top{500,1000,3000}.sexp`.
- Per-cell results: `out_top{500,1000,3000}/aggregate.sexp` + `walk_forward_report.md`.
- Screen that gated this build: `dev/notes/earliness-primary-ranking-screen-2026-06-29.md`.
- Warehouses (gitignored): `dev/data/snapshots/wfcv-top{500,1000,3000}-1998`.
