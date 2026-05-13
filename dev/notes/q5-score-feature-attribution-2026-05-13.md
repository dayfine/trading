# Q5 score-feature attribution + soft-penalty design (2026-05-13)

Companion design note for `dev/experiments/entry-caps-2026-05-12/report.md`
follow-up E5 ("soft Q5 penalty in `Screener.scoring_weights`"). The hard cap
(`max_score_override = 79`) was rejected because, even though it confirms the
Q5 win-rate finding from `dev/notes/entry-signal-quintiles-2026-05-11.md`
(28.6% WR at score ≥80, the worst of all five quintiles), capping pushes
the strategy out of "ride winners until laggard rotation" mode into
"high-frequency stop-out churn" — Sharpe 0.85 → 0.59, MaxDD 18.4% → 52.1%.

This note answers: **which `scoring_weights` features mechanically push a
candidate above 80, and which 1-2 should be dampened to flatten Q5 without
removing the Q5 cohort?**

It is a static / heuristic analysis. No backtests were run; that work
belongs to the E5 sweep proposed at the end.

---

## Section 1 — How `_score` is computed

`trading/analysis/weinstein/screener/lib/screener_scoring.ml` lines 181-186:

```ocaml
let score_long ~weights ~sector (a : Stock_analysis.t) : int * string list =
  let w = weights in
  _tally
    (_stage_long_signal ~w ~a @ _late_stage2_signal ~w ~a @ _volume_signal ~w ~a
   @ _rs_long_signal ~w ~a @ _resistance_signal ~w ~a
    @ _sector_long_signal ~w ~sector)
```

`_tally` (line 172) is plain additive over six independent signal helpers.
There is no multiplication, no gating, no clipping — the score is the sum of
whichever (weight, label) pairs the helpers emit, with zero-point entries
dropped. The contribution table (defaults from line 29):

| Helper (line) | Condition | Pts emitted | Default |
|---|---|---:|---:|
| `_stage_long_signal` (52) | `prior_stage = Stage1`, current `Stage2 _` | `w_stage2_breakout` | **30** |
| `_stage_long_signal` (52) | `Stage2 { weeks_advancing ≤ 4 }` (no Stage1 prior) | `w_stage2_breakout / 2` | 15 |
| `_late_stage2_signal` (61) | `Stage2 { late = true }` | `w_late_stage2_penalty` | **-15** |
| `_volume_signal` (68) | `Strong _` | `w_strong_volume` | **20** |
| `_volume_signal` (68) | `Adequate _` | `w_adequate_volume` | 10 |
| `_rs_long_signal` (91) | `Bullish_crossover` | `w_positive_rs + w_bullish_rs_crossover` | **30** |
| `_rs_long_signal` (91) | `Positive_rising` | `w_positive_rs` | 20 |
| `_rs_long_signal` (91) | `Positive_flat` | `w_positive_rs / 2` | 10 |
| `_resistance_signal` (113) | `Virgin_territory` or `Clean` | `w_clean_resistance` | **15** |
| `_resistance_signal` (113) | `Moderate_resistance` | `w_clean_resistance / 2` | 7 |
| `_sector_long_signal` (141) | `Strong` | `w_sector_strong` | 10 |
| `_sector_long_signal` (141) | `Weak` | `-w_sector_strong` | -10 |

`grade_of_score` (lines 197-203) maps the int to a grade:
`≥85 → A+, ≥70 → A, ≥55 → B, ≥40 → C, ≥25 → D, else F`.

**Algebraic ceiling under defaults** — the maximum reachable score in normal
operating regime is:

```
  w_stage2_breakout                              = 30
+ w_strong_volume                                = 20
+ w_positive_rs + w_bullish_rs_crossover         = 30
+ w_clean_resistance                             = 15
+ w_sector_strong                                = 10
+ (no late_stage2 penalty)                       = 0
-----------------------------------------------
  TOTAL maximum                                  = 105
```

Score ≥80 (Q5) is therefore equivalent to "missing **at most 25 points** of
that 105-point ceiling." The Q5 boundary is tight: a candidate that drops
`w_clean_resistance` (-15) and the bullish-crossover bonus (-10 of the RS
30) is at exactly 80. A candidate carrying late-Stage-2 penalty (-15)
cannot reach Q5 even with every other signal maxed (max = 90 - 15 = 75)
unless `w_late_stage2_penalty` is itself dampened.

---

## Section 2 — Which features drive Q5

### 2.1 Necessary signals to clear 80

Working backward from the ceiling, a Q5 candidate must clear **at least 80
of 105** non-penalty points. There are three contributors that together
account for `(30 + 30 + 20) = 80` points if all three fire at their top
band: **Stage1→Stage2 breakout**, **RS bullish-crossover**, and **strong
volume**. Drop any one of those entirely and the remaining ceiling is at
most `105 - 30 = 75` (no Stage1 prior, only "Early Stage2"), `105 - 30 =
75` (RS only Positive_rising, no crossover), or `105 - 20 = 85` (volume
only Adequate) respectively. So Q5 admission essentially requires:

- The Stage1→Stage2 transition (full 30, not the half-credit Early Stage2
  branch), AND
- RS Bullish_crossover (the +10 bonus on top of +20 base = 30), AND
- Strong volume (+20, not Adequate +10).

The other two positive weights (`w_clean_resistance = 15`,
`w_sector_strong = 10`) provide the 5–25 point headroom but are not
individually decisive — losing one still leaves a candidate at 80–95.

### 2.2 The Q5-defining feature combo: "fresh Stage-2 + RS crossover + Strong volume"

The empirical Q5 cohort — per the entry-quintile note
(`dev/notes/entry-signal-quintiles-2026-05-11.md`):

> Q5 (≥80) has 28.6% WR despite being the cascade's "best" candidates… likely
> overweighting signals that look strong at the breakout moment but lack
> follow-through (e.g., extreme RS, extreme volume, late-Stage-2 timing).

The entry-caps report
(`dev/experiments/entry-caps-2026-05-12/report.md`) corroborates this with
the descriptor "late-Stage-2 high-volume breakouts" for the Q5 failure
mode. Cross-referenced with the score arithmetic:

- "Late-Stage-2 high-volume" is the **post-crossover, post-confirmation**
  phase — RS just inverted, volume just spiked, the move has been visible
  for weeks. By definition this is the regime where all three big-ticket
  signals (Stage transition, RS crossover, Strong volume) co-fire.
- The score model does not penalise *recency-of-spike*. A 4-week-old RS
  crossover with already-elevated volume scores the same 30+20+30 = 80 as
  a *just-occurred* fresh crossover.
- `w_late_stage2_penalty = -15` is **the only counterweight in the
  scoring rubric**, but it requires `Stage2 { late = true }` — a specific
  classification flag (set when a Stage 2 advance shows deceleration
  features) that fires on a subset of these candidates. Many of the failing
  Q5 trades will be Stage 2 advances that are *mature but not yet flagged
  late* — i.e. the `late` boolean missed them.

### 2.3 Top-2 over-contributing features

Ranking by "fraction of Q5's 80+ points that this feature contributes":

| Rank | Feature | Default pts | Share of 80-point Q5 threshold |
|---|---|---:|---:|
| 1 | `w_stage2_breakout` (Stage1→2 full credit) | 30 | 37.5% |
| 2 | `w_positive_rs + w_bullish_rs_crossover` | 30 (= 20 + 10) | 37.5% |
| 3 | `w_strong_volume` | 20 | 25.0% |
| — | `w_clean_resistance` | 15 | (headroom only) |
| — | `w_sector_strong` | 10 | (headroom only) |

The **top two** are tied at 30 pts each, but they behave differently as
soft-penalty targets:

- `w_stage2_breakout` is the *thesis-defining* signal — dampening it would
  punish every long candidate uniformly (every entry is a Stage-2 breakout
  by construction in the cascade gate), so it does not differentiate Q5
  from Q1–Q4 in the entered-trade population. Cutting it shifts the score
  *distribution* down but does not change the *ranking* of admitted
  candidates. Net effect: Q5 becomes Q4 by name but the same trades still
  fill the same slots. **Bad lever.**

- `w_positive_rs + w_bullish_rs_crossover` is differentiating: the
  M5.4 E4 evidence (`dev/notes/screener-weights-inertness-2026-05-13.md`
  §1.3) showed `rs-heavy` was *bit-equal to baseline* on the 5y window —
  meaning RS sign is uniform across surviving candidates, so the *base*
  20 doesn't move metrics. But the **+10 crossover bonus** fires only on
  fresh inversions (`Bullish_crossover` variant), which is precisely the
  Q5 phenotype. Dampening only the **crossover bonus** (not the base
  Positive RS weight) selectively downgrades the Q5 cohort without
  flattening the rest of the score distribution.

- `w_strong_volume` is the second clean target. The
  `_volume_signal` helper distinguishes `Strong _` (default +20) from
  `Adequate _` (default +10) — a 2× ratio. The entry-quintile note
  separately found that volume_ratio ≥ 3.0 has **31.3% WR** vs
  volume_ratio 1.5-2.0 at **37.9% WR**; Strong volume in the screener is
  the proxy for that extreme-volume bucket. Reducing the Strong vs
  Adequate spread (e.g. from 20/10 = 2× to 14/10 = 1.4×) preserves the
  *direction* of the volume preference while removing 6 points specifically
  from Q5 candidates.

**Top-2 soft-penalty targets**: `w_bullish_rs_crossover` and
`w_strong_volume`. Reducing both compresses Q5 toward Q4 *and* — because
their fire conditions correlate (fresh RS inversions tend to accompany
volume spikes) — produces a multiplicative downgrade for the worst
phenotype.

---

## Section 3 — Soft-penalty design recommendation

### 3.1 Goal

Shift the Q5 (≥80) population downward into Q4 (75-79) and Q3 (70-74)
without:
- Collapsing the score range (the gate at min_grade=C corresponds to score
  ≥40; we must keep enough headroom that admitted candidates spread out
  meaningfully).
- Re-ordering Q1/Q2 relative to each other (no evidence those buckets are
  miscalibrated).
- Triggering the same regime-shift as the hard cap (i.e. don't drop
  candidates entirely — keep them but rank them lower).

The mechanism: dampened weights produce a flatter top-end distribution.
Combined with the existing top-N cap (`max_buy_candidates = 20`) and the
entry-walk consumption order, lower Q5 scores mean Q5 candidates appear
**later** in the rank-sorted candidate list. With a 5-7 position
portfolio (per `feedback_position_count_capital_scaling`), Q5 candidates
that drop below Q4 in rank order will be skipped in favor of Q3/Q4
candidates whose scores now sit at the top of the list.

### 3.2 Three sweep cells

All three retain defaults for the four "headroom" weights
(`w_stage2_breakout = 30`, `w_adequate_volume = 10`,
`w_clean_resistance = 15`, `w_sector_strong = 10`,
`w_late_stage2_penalty = -15`). Each cell perturbs only the
Q5-correlated signals.

| Cell | `w_strong_volume` | `w_positive_rs` | `w_bullish_rs_crossover` | New Q5-threshold ceiling | Hypothesis |
|---|---:|---:|---:|---:|---|
| **E5a** soft | 15 | 20 | 5 | 30+15+25+15+10 = **95** | Single small bias against extreme-volume + fresh-crossover. Q5 admissions drop from 192/1793 (10.7%) to ≈5%. Smallest perturbation; tests whether Q5 over-confidence is sensitive to small differential adjustments. |
| **E5b** moderate | 14 | 20 | 0 | 30+14+20+15+10 = **89** | Zeros out the crossover bonus entirely — RS crossover and RS rising score identically. Combined with a 30% cut on Strong volume vs Adequate. Compresses Q5 maximum from 105 to 89; almost all Q5 candidates fall into Q4 (75-79) band. |
| **E5c** aggressive + Strong floor | 12 | 18 | 0 | 30+12+18+15+10 = **85** | E5b + cut base `w_positive_rs` from 20 to 18 to test whether the score's correlation with WR is genuinely driven by raw RS magnitude or only by the crossover bonus. New ceiling = exact A+ threshold (85). |

Note: E5c also drops `w_positive_rs` to 18 — this affects every candidate
with positive RS, not just Q5. Include as the *aggressive* arm to test
whether selective Q5 dampening (E5b) is sufficient or whether base RS
itself needs trimming. The M5.4 E4 evidence ("rs-heavy was bit-equal to
baseline") suggests E5c will be near-equal to E5b on metrics, but the
ticker-level rank diff (Jaccard) should be measured to confirm.

### 3.3 Sweep config — sexp shape

Critical: per `screener_scoring.mli:42-61` and the inertness note, use the
**exact record-field names** (the runner silently no-ops unknown overlay
keys):

```sexp
;; E5a — soft
((screening_config (weights ((w_strong_volume 15) (w_bullish_rs_crossover 5)))))

;; E5b — moderate
((screening_config (weights ((w_strong_volume 14) (w_bullish_rs_crossover 0)))))

;; E5c — aggressive
((screening_config (weights
  ((w_strong_volume 12) (w_positive_rs 18) (w_bullish_rs_crossover 0)))))
```

Each overlay is a single-shot — do not split into multiple `screening_config`
overlays per the runner-side merge bug documented in
`dev/experiments/entry-caps-2026-05-12/report.md` §"C vs B — broken
override."

### 3.4 Why not other weights?

- `w_stage2_breakout`: uniform across the entered population (§2.3). Cutting
  it shifts the whole distribution down but doesn't change rank order.
- `w_late_stage2_penalty`: currently -15. Making this more negative (e.g.
  -25) would help, but only on the *subset* of Q5 that's flagged
  `Stage2 { late = true }`. The Q5 cohort is broader than the "late"
  subset, so this lever is too narrow. Worth testing as a fourth arm if E5a/b
  show partial improvement.
- `w_adequate_volume` / `w_clean_resistance` / `w_sector_strong`: these fire
  more uniformly or are in the "headroom" band (5-25 points). Perturbing
  them does not selectively dampen Q5.

---

## Section 4 — Acceptance criteria for the E5 sweep

The hard-cap (entry-caps arm B) failed because it improved WR but
catastrophically inverted Sharpe and MaxDD. The soft-penalty must do
better on all three:

| Metric | Baseline (arm A) | E5 pass criterion | E5 reject criterion |
|---|---:|---:|---:|
| Win rate | 39.5% | ≥ 42.0% | < 40.0% (no Q5 effect) |
| Sharpe | 0.85 | ≥ 0.80 (no Sharpe destruction) | < 0.70 |
| MaxDD | 18.4% | ≤ 25% (mild expansion OK) | > 35% |
| Total return | 374% | ≥ 350% | < 300% |
| Avg hold | 46d | ≥ 35d (preserve compounding regime) | < 25d |
| Trade count | 768 | within ±25% (no churn explosion) | > 1200 |

**Primary pass condition**: E5b must hit Sharpe ≥ 0.80 AND WR ≥ 42% AND
MaxDD ≤ 25%. If E5b passes, E5a and E5c become diagnostic (small vs
aggressive bracketing) and we promote E5b's weights to the screener
default scoring_weights.

**Secondary metric**: per-quintile re-bucketing of the resulting trade set.
Confirm that under E5b, the new "Q5 ≥80" cohort (which will be smaller
because the ceiling drops to 89) recovers WR toward the population mean
(target: Q5 WR within ±5 pp of overall WR), instead of the current 11 pp
deficit.

**Failure mode to watch for**: if E5b produces the same regime-shift
signature as hard-cap arm B (avg hold collapse + DD blowup + trade count
doubling), it means the soft penalty is functionally equivalent to a hard
cap because the entry walk consumes the freed slots with the same
substitution profile. This would indicate the Q5 problem is structurally
inseparable from the long-hold regime — at which point E6 (Q5 cap × wider
initial stop) and E7 (Q5 cap conditional on Bullish macro) from the
entry-caps report become the next moves, not further weight perturbations.

### Sequencing

1. E5b first (the moderate arm — best risk/reward in the bracket).
2. If E5b passes acceptance, run E5a and E5c in parallel as bracketing
   sensitivity cells.
3. If E5b fails the primary pass condition, skip E5a/c and move to E6
   (Q5 cap + wider stop) per the entry-caps report's stated follow-ups.

Runtime budget: 15y Cell E baseline on sp500-historical 510 symbols was
~50 min for the 3-arm entry-caps sweep (parallel-3 on clean memory), so
E5a+b+c parallel should fit the same envelope.

---

## References

- `trading/analysis/weinstein/screener/lib/screener_scoring.ml`
  — score computation source.
- `trading/analysis/weinstein/screener/lib/screener_scoring.mli:42-61`
  — exact field-name documentation for overlays.
- `dev/notes/entry-signal-quintiles-2026-05-11.md` — Q5 28.6% WR finding
  and Q3 sweet-spot evidence.
- `dev/experiments/entry-caps-2026-05-12/report.md` — hard-cap rejection
  (Sharpe 0.85 → 0.59, MaxDD 18.4% → 52.1%) and E5/E6/E7 follow-up
  framing.
- `dev/notes/screener-weights-inertness-2026-05-13.md` — M5.4 E4
  evidence that weights ARE load-bearing when correct field paths are
  used; bit-equal axis catalog (rs-heavy, stage-heavy,
  late-stage-strict).
