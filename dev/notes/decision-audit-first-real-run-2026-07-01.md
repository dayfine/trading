# Decision-audit — first real run (faithfulness), 2026-07-01

First run of the `decision_audit` report (#1799) on **fresh, enriched**
`trade_audit.sexp` data. This is the research payoff of the P0 build: does any
**captured** decision-time feature separate the **funded** entries from the
**cash-rejected near-misses** — i.e. is there a signal we record but don't fund on?

## How it was produced

- Built from main `c8e4d7333` (Phase-0 enrichment present). Pre-enrichment sexp
  files on disk won't parse (new fields are required, no `[@sexp.default]`), so a
  fresh run was mandatory.
- `backtest_runner --smoke --csv-mode --experiment-name decision-audit-real-2026-07-01`
  with `TRADING_DATA_DIR=…/trading/test_data`. Smoke = 3 sp500 (~500-symbol,
  container-fit) windows: **bull** (2019 H2), **crash** (2020 H1), **recovery**
  (2023). Each emits its own `trade_audit.sexp`; report run per window.
- Default config (production defaults). Reports at
  `dev/experiments/decision-audit-real-2026-07-01/<window>/decision_audit.md`
  (gitignored; key numbers reproduced below).

## Funded vs near-miss on captured features (means)

| feature | bull | crash | recovery | read |
|---|---|---|---|---|
| **score** | 58.7 vs 52.5 | 58.0 vs 51.7 | 56.1 vs 54.1 | funded > near-miss in all 3 — mechanical (funding walks score-desc); score is *what we fund on*, not an ignored lever |
| **volume_ratio** | 2.39 vs 2.33 | 2.52 vs 2.21 | 2.36 vs 2.12 | funded slightly higher in all 3 — but `volume_quality` is already a cascade input → captured AND used (faithful direction) |
| **weeks_advancing** | 1.60 vs 1.92 | 1.70 vs 1.85 | 1.71 vs 2.09 | funded consistently *earlier* (fresher breakouts) — already tested as a lever: **earliness-primary REJECTED #1793** (freshest = least-confirmed, no return) |
| **rs_value** | 0.95 (n=1) vs 1.00 | — (n=0) | 0.98 (n=9) vs 1.01 | near-miss marginally higher, but **underpowered**: ~77% of records carry `rs_value = None` (461/595 in recovery). No claim. |

Screens / funded / near-miss: bull 8 / 15 / 115 · crash 11 / 27 / 147 ·
recovery 24 / 38 / 361. Near-miss skip reasons dominated by `Insufficient_cash`
(the binding constraint, as expected) then `Stop_too_wide`, with `Short_notional_cap`
appearing in the crash window.

## Verdict (calibrated per `.claude/rules/mechanism-validation-rigor.md`)

**Selection is faithful — the expected/WAI case.** No captured feature separates
funded from cash-rejected near-misses in a direction we're failing to exploit:

- `score` / `volume_ratio` separate in the *funded-favoured* direction (we already
  fund on both — faithful, not a gap).
- `weeks_advancing` separates (funded fresher) but its predictive value was already
  measured and **rejected** (earliness #1793). Not a new lever.
- `rs_value` is too sparse to read (see harness gap below).

This **confirms the 2026-06-30 noise-floor grid prediction**: among the tied,
cash-rejected near-misses, the captured signals are uninformative — the tiebreak
is unbiased noise, not discarded alpha. → The only remaining entry-side lever is
**explicit capacity / diversification** (fund more names at smaller size,
`project_capacity_concentration_surface`), **not a better sort**.

**This is a proxy screen, not a rejection.** Short (8–24 screen) sp500 windows;
a point-estimate-of-means comparison; the `rs_value` cell is underpowered. It
*decides* against prioritizing a new entry-selection sort (leaning on the
standing prior `project_edge_is_the_fat_tail` + the noise-floor grid); it does
**not** prove no captured signal exists. The honest "usable signal left on the
table" test is the **Phase-2 forward-return counterfactual** on the cash-skipped
names — not yet run.

## Follow-ups / harness observations

1. **RS coverage gap (worth a look):** ~77% of candidates carry `rs_value = None`
   in these sp500 windows. The RS faithfulness comparison is therefore both
   underpowered and selection-biased (only names with RS present). Investigate why
   RS analysis is absent on most candidates (benchmark-history requirement?
   gating?) before trusting any RS-based faithfulness read.
2. **Inversions are faithful:** 18/24 recovery screens flag `inversion` (a
   near-miss out-scored the min funded), but these are driven by `Stop_too_wide`
   (the sanctioned >15%-risk gate) + `Insufficient_cash`, **not** score-order
   violations — i.e. we correctly skip a higher-scored name whose structural stop
   is too wide. Faithful, not a sizing quirk.
3. **Phase 2 (the real signal test):** join each near-miss symbol's forward return
   (reuse `decision_grading/post_exit`) to test whether the cash-skipped names
   systematically out/under-perform the funded on any captured axis. Null →
   selection faithful, only lever is explicit capacity; non-null on some axis → a
   real lever. This is the one place outcome legitimately enters.
