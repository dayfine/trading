# Screener `scoring_weights` — load-bearing or ornamental? (2026-05-13)

Design note investigating whether the Weinstein cascade screener's
`screening_config.weights.*` surface actually drives strategy outcomes. PR
#1051 (2026-05-12) ran an 81-cell flagship grid sweep and reported the axis is
"functionally inert"; this note re-examines that claim, walks the code, and
recommends a path forward.

**TL;DR — recommendation: Option C.** Keep the weights surface, but make it
load-bearing for *ranking among admitted candidates* by lowering the top-N cap
and/or raising `min_score_override` so the rank order actually controls which
candidates enter. Do not adopt Option A (numeric gate) — it loses the
deterministic grade-bucket transparency that audit-side analyses depend on.
Do not adopt Option B (remove weights) — the M5.4 E4 sweep already disproved
the "weights cannot move metrics" reading; the issue is that current defaults
have the top-N cap so loose that ranking rarely binds.

---

## Section 1 — Empirical evidence

### 1.1 PR #1051 — 81-cell flagship grid (the "inert" finding)

`dev/experiments/grid-screening-weights-2026-05-12/` swept 3⁴ cells over
`{rs, volume, breakout, sector}` × `{0.5, 1.0, 1.5}` on 3 smoke scenarios.
Headline from `report.md`:

> All 81 cells produce identical (Sharpe, num_trades, total_pnl) within each
> scenario. The screener-weight axis is functionally inert at the current
> cascade-filter design.

`sensitivity.md` shows mean Sharpe = **1.015555** at every sweep value of
every axis (a perfectly flat surface). The H1/H2 follow-up at
`dev/experiments/h1-h2-diagnostic-2026-05-12/` extended the range to
`rs ∈ {0.0, 5.0}` and got the same bit-identical metrics.

### 1.2 Confound — the swept paths do not name real record fields

The grid spec at `dev/experiments/grid-screening-weights-2026-05-12/tiny-grid-spec.sexp`
keys on `screening_config.weights.rs`, `screening_config.weights.volume`, etc.
The actual `scoring_weights` record (defined in
`trading/analysis/weinstein/screener/lib/screener_scoring.ml:17-27`) has fields:

```
w_stage2_breakout : int
w_strong_volume : int
w_adequate_volume : int
w_positive_rs : int
w_bullish_rs_crossover : int
w_clean_resistance : int
w_sector_strong : int
w_late_stage2_penalty : int
```

`rs`, `volume`, `breakout`, `sector` are **not field names**. The deep-merge
in `trading/trading/backtest/lib/runner.ml:86-106` iterates over *base*
fields only — overlay keys that don't exist in base are **silently dropped**.
Worse, the swept values (`0.0, 0.5, 1.0, 1.5, 5.0`) are floats; the record
fields are `int`. Even if a name happened to match, sexp parsing would fail
(or produce a different no-op).

**Conclusion: the 81-cell grid was sweeping a no-op key path.** Identical
metrics across all cells is the expected result whether or not the cascade is
grade-driven. The H1/H2 diagnostic also keys on the same fake path, so it
cannot distinguish "cascade is grade-driven" from "overlay is a no-op."

### 1.3 The real evidence — M5.4 E4 sweep used correct field names

`dev/experiments/m5-4-e4-scoring-weight-sweep/report.md` (2026-05-08) ran 8
single-axis weight perturbations using actual record-field paths
(`screening_config.weights.w_clean_resistance`, etc.) — see
`trading/test_data/backtest_scenarios/experiments/m5-4-e4-scoring-weight-sweep/resistance-heavy.sexp`.
The 8-cell table from `report.md`:

| Cell                | Return  | Trades | Sharpe | MaxDD  |
|---------------------|--------:|-------:|-------:|-------:|
| baseline            | 58.34%  | 81     | 0.53   | 33.60% |
| equal-weights       | 23.07%  | 99     | 0.32   | 29.51% |
| late-stage-strict   | 58.34%  | 81     | 0.53   | 33.60% |
| **resistance-heavy**| 80.67%  | 79     | 0.65   | 32.85% |
| rs-heavy            | 58.34%  | 81     | 0.53   | 33.60% |
| sector-heavy        | 59.09%  | 61     | 0.51   | 34.00% |
| stage-heavy         | 58.34%  | 81     | 0.53   | 33.60% |
| volume-heavy        | 35.02%  | 90     | 0.38   | 42.20% |

Three cells (`resistance-heavy`, `volume-heavy`, `sector-heavy`,
`equal-weights`) move metrics decisively; three (`late-stage-strict`,
`rs-heavy`, `stage-heavy`) are bit-equal to baseline. Weights are **not
universally inert** — they are inert *only along the axes where the surviving
candidate population has a uniform value for that signal*.

### 1.4 What does PR #1051's evidence actually show?

Strictly: nothing about weights. The grid swept fake keys; the runner silently
no-op'd them. Indirectly: the report's "H1: cascade is grade-driven so
uniform scaling can't change candidate set" intuition is partially correct
but is **also** about the top-N cap and ranking stickiness, not just the
grade gate. The M5.4 E4 evidence is the load-bearing data; the conceptual
hypothesis from #1051 is correct in spirit but mis-supported by its grid.

---

## Section 2 — Code walkthrough: where the weighted score lives vs. where the decision is made

### 2.1 Score computation

`trading/analysis/weinstein/screener/lib/screener_scoring.ml`:

- `score_long ~weights ~sector a` (lines 181-186) and
  `score_short ~weights ~sector a` (lines 189-194) compute an additive sum of
  signal contributions, each multiplied by a config-supplied weight.
- `_tally signals` (line 172) folds (points, label) pairs into (total_score,
  reasons). Score is a plain `int`.
- `grade_of_score ~thresholds score` (lines 197-203) is a step function:
  `>= 85 → A_plus`, `>= 70 → A`, `>= 55 → B`, `>= 40 → C`, `>= 25 → D`,
  else `F`.

### 2.2 The gate that decides admit/reject

`trading/analysis/weinstein/screener/lib/screener.ml:146-158`:

```ocaml
let _passes_score_floor ~thresholds ~min_grade ~min_score_override
    ~max_score_override score =
  (match min_score_override with
    | Some n -> score >= n
    | None -> compare_grade (grade_of_score ~thresholds score) min_grade <= 0)
  && match max_score_override with Some m -> score < m | None -> true
```

Key observation: when `min_score_override = None` (the default), the gate is
`grade_of_score(score) ≤ min_grade` (default `min_grade = C`). Because the
grade ladder is monotonic in the score, this is **algebraically equivalent**
to `score >= 40`. The grade form is just a relabelling.

**So the gate is already numeric.** "Grade-driven vs score-driven" is a
distinction without a difference at the gate. The grade ladder only matters
for the displayed label on a `scored_candidate`.

### 2.3 The selectors that DO act on weights

After the floor, two downstream mechanisms can let weights affect outcomes:

1. **Top-N cap** (`screener.ml:247-258, _top_n`):
   ```ocaml
   List.sort lst ~compare:(fun a b ->
       let by_score = Int.compare b.score a.score in
       if by_score <> 0 then by_score else String.compare a.ticker b.ticker)
   |> fun l -> List.sub l ~pos:0 ~len:(min n (List.length l))
   ```
   Default `max_buy_candidates = 20`, `max_short_candidates = 10`. Weights
   determine the score order; weights matter iff more candidates pass the
   floor than the cap.

2. **Downstream entry walk** (`weinstein_strategy_screening.ml:53-92`,
   `entries_from_candidates`): walks candidates in screener order
   (score-desc), consuming `remaining_cash` and short-notional budget. Once
   cash runs out, the tail is skipped. So **rank order** at the top of the
   candidate list determines which symbols actually trade. Per
   `dev/notes/cell-e-candidate-supply-bottleneck-2026-05-11.md`, cascade
   supply is roughly 10× downstream fill rate — i.e. only the top ~1.3 per
   Friday of the avg 12.5 admitted enter, so ranking is in principle
   decisive. But in practice the top of the list is dominated by candidates
   that all carry the same maxed-out signals (Stage-2 breakout + clean
   resistance + strong volume + strong RS = 30+15+20+20 = 85 = A+),
   producing many score ties.

### 2.4 Why so many cells were bit-equal in M5.4 E4

For a weight perturbation to change downstream metrics, it must:

- Move at least one candidate across the `min_grade` (score >= 40) threshold; OR
- Change the score ordering near the top such that the cash-walking entry
  pipeline selects a different symbol; OR
- Re-order the ranking such that ties resolved by ticker name flip.

The bit-equal cells (rs-heavy, stage-heavy, late-stage-strict) tested signals
that are **near-universal among Stage-2 breakout candidates** — every
candidate that reached the gate had the same prior_stage transition or the
same RS sign, so doubling those weights moved every candidate by the same
delta and the ranking was unchanged. The cells that DID move
(resistance-heavy, volume-heavy, sector-heavy) tested signals with
heterogeneous distribution across the candidate pool, so weight changes
produced rank inversions and different top-N picks.

### 2.5 Quintile diagnostic — the score has weak predictive value

`dev/notes/entry-signal-quintiles-2026-05-11.md` (1,793-trade aggregate)
bucketed entered trades by score:

| Bucket    | N   | WR %  | Avg $    |
|-----------|----:|------:|---------:|
| Q1: <65   | 567 | 39.2  | +$1,382  |
| Q2: 65-69 | 182 | 38.5  | -$1,137  |
| Q3: 70-74 | 288 | **43.8** | **+$4,297** |
| Q4: 75-79 | 564 | 34.2  | +$1,747  |
| Q5: ≥80   | 192 | **28.6** | **+$6** |

The highest-scored bucket (Q5, A+ grade) has the **worst** win rate and
essentially zero $/trade. The score does discriminate, but inversely at the
top end. This is direct evidence that the weight surface, as currently
calibrated, is producing miscalibrated signal — which is a different problem
from "inert."

---

## Section 3 — Design recommendation: Option C

Three options were on the table; I recommend **Option C** with a small,
mechanical pre-step.

### Option A — Make the score gate purely numeric, abandon grades

Replace `_passes_score_floor`'s grade path with `score >= min_score_override`
unconditionally; default `min_score_override = 40`. Delete the grade-mapping
gate.

**Pro**: removes the grade-thresholds knob (one less config dimension).
**Con**: as shown in §2.2 the existing form is already numerically
equivalent. The change is a no-op functionally, costing the human-readable
grade labels on `scored_candidate` (used in the watchlist output —
`_check_watchlist_grade` at screener.ml:221-232, in PR review/audit dumps,
and in `rationale` strings the entry recorder serialises). Audit-side
analyses (e.g. `cell-e-candidate-supply-bottleneck-2026-05-11.md`) read
grade labels directly from `actual.sexp` outputs to bucket-count
admissions. Eliminating the grade type would force every downstream
audit to bucket by raw int score, losing the stable A/B/C/D vocabulary.

**Verdict**: rejected. Cosmetic change that breaks audit conventions for
zero behavioural gain.

### Option B — Remove the weights surface entirely

Hard-code `default_scoring_weights` (or replace with a single composite
quality score) and delete `screening_config.weights` from `Screener.config`.

**Pro**: 32 LOC + sexp shape simpler. No more grid-search cells aimed at a
surface that needs careful framing to be useful. Reduces tuner search
space.
**Con**: the M5.4 E4 experiment (§1.3) showed `resistance-heavy` outperformed
default by **+22.3 pp return / +0.12 Sharpe** on the canonical 5y window;
`volume-heavy` and `equal-weights` both underperformed materially.
The weights surface is **demonstrably load-bearing** when correctly
swept. Removing it concedes ~22 pp of return on the pinned baseline.

**Verdict**: rejected. Decisively contradicted by E4 evidence.

### Option C — Keep weights, but make rank-among-admitted actually bind (recommended)

Two-step:

1. **Documentation / framing fix.** The screener `.mli` (line 9 in
   `screener.mli`) says `3. SCORING: Additive weighted score from config
   weights. 4. FILTER + SORT: Remove below min_grade. Remove already-held
   tickers. Sort by score descending.` Add an explicit subsection in the
   `.mli` header saying:
   - The grade-based filter (`min_grade = C`) is algebraically a numeric
     `score >= 40` floor; the grade naming is for output labelling only.
   - Weights affect outcomes **only** along axes where the surviving
     candidate population has heterogeneous values for the corresponding
     signal. Uniform signals across the survivor population produce
     bit-equal metrics under that axis's perturbation. Cite the M5.4 E4
     evidence directly.
   - Add a note that grid sweeps must use real record field paths
     (`weights.w_clean_resistance`, not `weights.rs`); a future linter could
     validate sweep specs against the sexp schema.

2. **Make rank-among-admitted bind on the canonical baseline.** Under the
   current default (`max_buy_candidates = 20`, `min_grade = C`), the
   per-Friday admitted set already averages 12.5 candidates (per the
   cell-e-candidate-supply-bottleneck note) — already below the top-N cap
   most weeks, so the cap rarely binds. But the **entry walk** at
   `weinstein_strategy_screening.ml:53-92` is rank-order-sensitive: the
   first few candidates consume cash first; when cash runs out the tail is
   dropped. With a 5-7 position portfolio, only the top ~3 ever enter.
   Therefore weights already affect outcomes through the entry walk — the
   M5.4 E4 evidence is consistent with this — but only when the perturbed
   axis varies across the top of the ranking.

   The actionable knob is `min_score_override`: tighten the floor (e.g. to
   55 = grade B+) so fewer candidates pass; then weights determine the
   small group of survivors more decisively. Cross-reference
   `dev/notes/888-score-threshold-quick-look-2026-05-06.md`: a sweep of
   `{40, 45, 50, 55, 60}` on multi-period scenarios is already planned
   for after capital-recycling work lands.

   **Even more direct**: the quintile evidence (§2.5) says the score is
   *inversely* predictive at the top end. Adding `max_score_override` (which
   already lives in `screener.mli:102-119`, pinned to `Some 79` after the
   2026-05-11 entry-quintile finding) caps the failing Q5 bucket. Pair that
   with a tighter `min_score_override` to compress the active admitted band
   to roughly score ∈ [55, 79], where the score is most predictive. Weights
   then determine rank within this band — a much smaller, more
   weight-sensitive population.

**The recommendation is therefore not to redesign the cascade** but to
acknowledge that weights are load-bearing for the rank-among-admitted
selection, document this explicitly, and run any future weight sweep with:
(a) the correct field-name paths, (b) a tighter `min_score_override`
configuration so ranking actually binds, and (c) directly measure trade-set
diff (Jaccard on entered ticker sets) per cell so a flat-Sharpe surface
doesn't hide ticker-level rank changes.

---

## Section 4 — Risks and open questions

### Risks of Option C as stated

1. **Audit-format dependency on grade labels** — any change to grade
   semantics requires care because `cascade_diagnostics.long_grade_admitted`
   counters and `scored_candidate.grade` are read by audit tooling. Option C
   does not modify these; mention only as context for why Option A is
   rejected.

2. **Tuner overhead** — keeping the weights surface means the tuner search
   space remains 8-dimensional (one per `w_*` field). Per the M5.4 E4
   evidence the surface is mostly flat-with-spikes; Bayesian / grid-search
   methods will need to be primed against the known-bit-equal axes
   (rs-heavy, stage-heavy, late-stage-strict) to avoid wasting cells. Add an
   explicit "screener weights priors" subsection to the tuner config so
   future agents know which axes are believed inert under default cascade
   width.

3. **Field-name validation** — the runner's silent no-op on invalid keys
   (`runner.ml:86-106`) is the root cause of PR #1051's wasted 2h grid run.
   This is a separate harness gap: the merge function should fail loudly on
   overlay keys not present in the base sexp. Track as a follow-up linter
   issue.

### Open questions

- **Q1**: Is the rank-among-admitted effect actually large enough on
  multi-year windows to justify keeping the weights surface? The M5.4 E4
  evidence (5y, single window) shows a 22 pp swing for `resistance-heavy`,
  but the walk-forward partition (§"Recommendation" of E4 report) is still
  outstanding. Until OOS validation completes, the resistance-heavy edge
  could be overfitting to 2019-2023's specific breakout regime.

- **Q2**: Should `min_score_override` and `max_score_override` defaults
  become `Some 55` / `Some 79` permanently? If so, the grade ladder
  becomes effectively dead code (no candidate would ever surface with grade
  outside [B-, A]). This is a candidate for a separate baseline-pin PR
  after the E4 walk-forward closes.

- **Q3**: Are the bit-equal axes (rs-heavy, stage-heavy) inert *universally*
  or only in the SP500 5y window? On a wider universe (e.g. norgate 10k) or
  longer horizon (15y), Stage-2 transitions and RS signs may exhibit more
  heterogeneity. Re-run M5.4 E4's exact 8-cell sweep on 15y once that
  baseline pins.

---

## Section 5 — Implementation sketch (if Option C is approved)

No source-code edits required for the core recommendation. The mechanical
work is:

1. **Documentation update** (~30 LOC):
   - Augment `screener.mli` header (the cascade-rules docstring) with the
     "weights bind via ranking among admitted" framing plus the field-name
     gotcha for sweeps.
   - Augment `screener_scoring.mli` near the `scoring_weights` definition
     with a note that uniform signals across the survivor population
     produce inert axes; cite M5.4 E4 and this note.

2. **Tuner priors file** (new, ~20 LOC):
   - `dev/tuner/screener-weights-priors-2026-05-13.md` (or similar) listing
     the axes believed inert on the SP500 5y/15y baselines as of this date,
     so future grid_search authors know which cells to skip and which to
     emphasise.

3. **Sweep-path validation linter** (separate follow-up; ~50 LOC OCaml):
   - In `trading/trading/backtest/lib/runner.ml`, change `_merge_records` to
     accumulate "unknown overlay keys" and propagate as a warning (or an
     error in tuner mode). Pre-condition: every grid-spec key must resolve
     to a real base field. Closes the PR #1051 silent-no-op hazard.

4. **Re-run the 81-cell flagship** with corrected key paths after #1 lands
   (~2h tier-3 budget). Replace `dev/experiments/grid-screening-weights-2026-05-12/`
   with corrected-spec results, or supersede it with a 2026-05-13 dated
   directory and add a redirect note in the old report.md.

5. **Pair the rerun with the planned `min_score_override` sweep**
   (`888-score-threshold-quick-look-2026-05-06.md` §Recommendation): the
   joint surface of `(min_score_override, weights)` is where the real
   tunable signal lives. Until both are swept together — first floor, then
   weights — single-axis weight sweeps will look flat for the structural
   reason that ranking doesn't bind when the floor is wide open.

None of this requires changes to core screener or strategy code. The
recommendation is fundamentally a framing + audit + correct-sweep
recommendation rather than a redesign.

---

## Summary

| Question                                          | Answer                                                                                                                |
|---------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| Are weights ornamental?                           | No. M5.4 E4 shows three axes move metrics by >20 pp return.                                                           |
| Was PR #1051's experiment valid?                  | No. It swept a non-existent key path; the no-op result is uninformative about cascade behaviour.                      |
| Is the cascade gate grade-driven?                 | The grade form is numerically equivalent to a `score >= 40` floor; the distinction is cosmetic.                       |
| Where do weights actually matter?                 | (a) Score ordering for top-N cap and (b) entry-walk consumption order under cash budget.                              |
| Should the weights surface be removed?            | No — Option B is contradicted by direct evidence.                                                                     |
| Should the gate be made numeric?                  | No — Option A is a cosmetic rename with audit-breaking cost.                                                          |
| What should change?                               | Option C: document the binding mechanism, fix the sweep-path validation gap, re-run with correct paths + tighter floor. |
