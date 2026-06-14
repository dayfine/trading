# Factor-decomposition lens — design (2026-06-14)

**Goal (user, 2026-06-14):** stop reporting bare aggregates like "beats SP500 X%
of the time." For the rolling-start matrix, decompose **WHEN** the strategy beats
and **WHY**, joining each start to causal factors, in a form that steers
deployment ("deploy when {conditions}; else sit in the SPY-timing floor").

Named gap in `project_index_beating_structural_bar`; standard set by
`feedback_decompose_aggregates_when_why` + `mechanism-validation-rigor.md`.

## The unit of analysis

One row per rolling-start (n=31 on the 2011-2026 top-3000 matrix; extend to the
2000-2011 bear-decade matrix for regime coverage). The outcome and factor columns
below are joined per start.

## Outcome columns (what we're explaining)

1. **realized-edge** = realized return − benchmark return, annualized. **This is
   the primary outcome, NOT MTM-edge.** The matrix's MTM `edge` column is
   contaminated (post-2020 starts show +MTM-edge with deeply −realized, the AXTI
   effect). Eyeballing MTM-edge gives false signals (verified 2026-06-14: the
   benchmark-strength hypothesis looked muddied only because MTM-edge mixed in
   unrealized marks). Compute realized return per start from banked P&L, not
   terminal mark.
2. MTM-edge (kept for the realized-vs-MTM gap diagnostic — large gap = a few
   concentrated unrealized winners, flags the start as mark-dependent).

## Factor columns (candidate causes — the user's questions, operationalized)

| factor | question it answers | source |
|---|---|---|
| **SPY/macro stage at start** (1/2/3/4) | "macro stage of the starting year?" | stage classifier on GSPC at start_date |
| **Macro_composite at start** (continuous) | macro tape strength at entry | `Macro_composite` field already in the snapshot warehouse per date |
| **forward index max-DD in window** | "did it dodge a correction?" (H1) | GSPC.INDX bars over [start,end] — peak-to-trough |
| **forward index CAGR** (= bench CAGR) | "melt-up vs moderate?" (H2) | already in matrix table |
| **Stage-2 candidate count at start** | "were stocks acting interestingly? enough setups?" | screener candidate count on start_date |
| **sector-RS dispersion at start** | "stronger/weaker sectors?" | spread of sector relative-strength at start_date |
| **realized-vs-MTM gap** | concentration / mark dependence | realized − MTM per start |

## Hypotheses to test (stated up front, then confirmed/refuted)

- **H1 (dodge-a-correction):** realized-edge is POSITIVE when forward index max-DD
  in the window is large (the strategy's Stage-4 exits sidestep the drop B&H
  eats). Predicts: edge ~ forward-index-DD, positive.
- **H2 (melt-up tax):** realized-edge is NEGATIVE when forward index CAGR is high
  with small DD (smooth melt-up — winner-touching trims the mega-caps driving the
  cap-weighted index, nothing to dodge). Predicts: edge ~ (forward CAGR | low DD),
  negative.
- **H3 (fresh-supply / regime at start):** realized-edge is POSITIVE for starts in
  early-bull-leg / post-correction regimes (Stage-2 supply high, macro recovering)
  and NEGATIVE for toppy/late starts (failed breakouts, whipsaw). Predicts:
  edge ~ Stage-2-candidate-count, positive; edge worse when SPY start-stage is 3.

## Method (n is small — favor robust, legible stats)

- Per-factor: Spearman rank-correlation with realized-edge + a 2×2 / tercile
  contingency (e.g. high-DD vs low-DD × beat vs miss) — not a heavy regression
  (n=31 won't support multivariate).
- Trace 3-4 individual starts end-to-end (one clean beat, one melt-up miss, one
  bear-start) to sanity-check the aggregate mechanism — per mechanism-validation
  rigor §paired/event-level.
- Report the conditional rule the factors imply, with the realized-edge sign-rate
  in each cell, and explicitly flag any factor the n can't resolve.

## Implementation (OCaml, no Python)

Two viable shapes:
- **(A) Extend `rolling_start_runner`** to emit the factor columns alongside the
  existing per-start metrics (it already loops per start with the bar reader +
  benchmark series; add macro-stage / forward-DD / candidate-count computation
  at each start). Cleanest single source of truth.
- **(B) Post-hoc join script** reading the matrix sexp + the snapshot warehouse
  (GSPC bars for forward-DD, `Macro_composite` for macro, screener for candidate
  count). Doesn't touch the runner; more glue.

Prefer (A) — the runner already has the per-start loop, bar reader, and benchmark
series; the factors are local additions. Gate each new column behind the existing
report so it stays a superset (no golden churn for consumers that don't read it).

## Deliverable

Not a verdict — a **causal table**: each start with realized-edge + the factor
columns, plus the confirmed/refuted hypotheses and the resulting deployment rule
(e.g. "the strategy's positive realized-edge is concentrated in starts followed by
a >X% index drawdown AND with >Y Stage-2 candidates; in smooth melt-ups it
structurally lags → prefer the SPY-timing floor there"). Persist as a `project_*`
memory + an experiment writeup.
