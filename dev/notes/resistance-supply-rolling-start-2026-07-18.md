# resistance-supply w30 — rolling-start terminal-wealth distribution (2026-07-18)

Promotion decision input #1 (per `resistance-supply-grid-2026-07-17.md`
§decision inputs): is the 28y single-path forfeit (w30 +1,991% vs baseline
+7,914%) the typical path outcome, or one draw?

**Method.** `rolling_start_eval` (#1476), one full backtest per start:
paired biennial start grid 2000-2024 (stride 730, no jitter → identical
grids both configs), fixed end 2026-06-26, top-3000 dedup-v3 sketch
warehouse, benchmark GSPC.INDX (price index, no dividends — context only,
the decision read is the paired internal delta), `min_window_days 1460`
(two short-window starts excluded from aggregates → n=12), parallel
processes at `SNAPSHOT_CACHE_MB=1024`. Configs: the record convention
(Run D basis) vs the same + `overhead_supply` armed at grid-robust
`w_overhead_supply = 30`. Reports:
`.sweep-output/rolling-start-promo/{baseline,w30}.md` (+ per-start sexp in
the stderr logs).

## Result — w30 is a distribution compressor with a regime-shaped left tail

Paired per-start CAGR delta (w30 − baseline), 12 counted starts:

| start | Δ CAGR pp/yr | | start | Δ CAGR pp/yr |
|---|---:|---|---|---:|
| 2000 | **−5.84** | | 2012 | +0.28 |
| 2002 | +1.38 | | 2014 | +1.42 |
| 2004 | +1.71 | | 2016 | +6.27 |
| 2006 | +3.60 | | 2018 | +0.47 |
| 2008 | **−6.68** | | 2020 | +0.92 |
| 2010 | **−8.54** | | 2022 | +9.92 |

- **w30 wins 9/12 paths**; median paired delta **+1.15pp CAGR/yr**, mean
  +0.41pp (the three losses are large).
- **Risk uniformly better**: MaxDD median 28.6% vs 32.2%, worst 33.9% vs
  40.5%; Sharpe higher on every winning path.
- **The left tail is regime-shaped, not random**: the three losing starts
  (2000, 2008, 2010) are exactly the windows that open into a post-crash
  recovery (dot-com, GFC) — the crash-recovery monster cohort the supply
  penalty structurally demotes. Loss sizes −5.8 to −8.5pp/yr are
  cohort-forfeit scale, consistent with the divergence forensic
  (`resistance-supply-divergence-forensic-2026-07-17.md`).
- **Edge floor degrades**: worst-start realized edge vs index +6.35%
  (baseline; beats the index on all 12 starts) → **−1.27%** (w30, loses
  to the index once — the 2010 GFC-recovery start).

## Reading for the promotion decision

The 28y draw's "¾ of terminal wealth" flag overstated the typical cost —
the median path is *better* under w30 and every path has lower DD. But
the cost is not one-draw luck either: **~25% of starts (the
recovery-window class) systematically forfeit 6-9pp/yr**. Both prior
reads survive: fold-level evidence favors w30; contiguous-wealth evidence
flags the recovery-cohort forfeit. They are the same fact seen from two
lenses.

**Bare-w30 promotion therefore buys median improvement + DD compression
at the price of a known, regime-conditional left tail.** The two designed
levers target that tail directly:

- `virgin_crossing_readmission` (#1997, MERGED, default-off) — re-admits
  redeemed monsters (AXTI-class). 28y single-path pair (w30+vc, vc-only)
  launched 2026-07-18 (`/tmp/sweeps/vc-pair/`) as decision input #2.
- Regime softener `w × (1 − k·index_supply)` — designed, unbuilt (lever b).

Recommendation standing: hold the default flip until the vc-pair read; if
vc repairs the recovery-window paths (and the fold surface with vc armed
still favors w≥15), promote the PAIR (w30 + vc) rather than bare w30.

## Caveats (screen-rigor)

- n=12 overlapping fixed-end windows — paths share the 2020-26 segment
  (and all contain the AXTI window); treat per-start deltas as correlated,
  not independent samples. Sign-pattern (9/12 + clustered losses) is the
  robust read, not a t-stat.
- CAGR is terminal-NAV-based (MTM at window end); capital-relative DD and
  medians are the robust columns. Benchmark is price-index (no dividends)
  — per the total-return comparator rule, do NOT quote the edge columns
  as the strategy-vs-market verdict; they are context only.
