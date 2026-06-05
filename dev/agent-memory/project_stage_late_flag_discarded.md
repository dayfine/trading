---
name: project-stage-late-flag-discarded
description: "The Stage2 `late` MA-deceleration flag (earliest top-warning) is computed every week but consumed ONLY at entry — never for held-position exposure/exit. Stage-4 exit lags every top by 5-29wk (price already -5% to -44%); `late` warns 7-26wk before the peak. Lever: late-driven held-exposure trim dial."
metadata: 
  node_type: memory
  type: project
  originSessionId: ca50bd58-52e8-4bfa-b1b2-6e777091a945
---

Diagnosis 2026-06-03 (`dev/notes/stage-lifecycle-pivot-diagnosis-2026-06-03.md`,
PRs #1441/#1442), driven by the question "is exposure sensitive to stage
lifecycle, e.g. were 2020-pivot decisions maximizing upside?"

**The stage lifecycle is fully encoded** — `Stage2 {weeks_advancing; late}`,
`Stage1 {weeks_in_base}`, etc. — and the `late` flag (MA-slope deceleration ≥
`late_stage2_decel`, default 0.5, computed at `stage.ml:417`) is the earliest
top-warning the machinery produces. **But `late` is consumed ONLY at entry**
(`stock_analysis.ml:419`: buy needs `Stage2 {late=false}` AND `weeks_advancing≤4`;
`screener_scoring.ml:56`). It NEVER trims a held position, scales sizing, or
drives an exit — its own doc-contract says "still hold, no longer a new buy." The
SPY-only reference path (`spy_only_signals.ml`) ignores lifecycle entirely
(`Stage2 _`).

**The actual de-risk trigger (Stage-4 flip) lags every top badly.** Battery of 7
episodes (SPY 2000/2008/2020/2022 + CSCO/INTC/GE/NKE/AIG):
- Stage-4 exit fires **5-29 weeks after the peak**, price already **−5% to −44%**
  (INTC 2000: −43.8% before any signal; SPY-2020: −31.8%).
- `late` warned **7-26wk before the peak in 6 of 7** (all 5 single names + 2 of
  the index cases), persisting to within 1-2wk of single-name tops. The lone miss
  = the 2020 *index* vertical blow-off (late reset into the acceleration) — only a
  daily/volatility/gap guard catches that.

**Recommended lever (NOT yet built — needs go + the strategy-mechanic care
process):** a **default-off `late`-driven held-exposure dial** — trim toward a
configurable fraction and/or tighten the trailing stop on `Stage2 {late=true}`
(or `weeks_advancing` beyond a threshold), paired with the existing daily gap stop
for fast crashes. Reuses a computed-but-discarded signal (low over-exploration
risk per [[feedback_strategy_mechanic_changes_too_explorative]]), Weinstein-
faithful, attacks the 37% deep-window DD ([[project_barbell_on_stocks]]). Test
visually (`stage_chart` CSV sidecar), via the per-symbol autopsy harness, and a
deep+bull backtest; promote only through the confirmation grid.

**Side-finding:** production trade-log worst losses cluster on split dates (NKE
−40% ending at its 2007 2:1 split, ISRG −60% at 2021 3:1, DISCA −52%/6d) →
likely split-adjustment artifacts in `trades.csv` pnl; would pollute the autopsy
harness. Separate follow-up.

Tool: `stage_chart` now emits `<out>.png.csv` (week,date,close,ma,stage,
weeks_in_stage,late) — see [[project_stage_chart_visual_diagnostic]].

**UPDATE 2026-06-05 — the dial is BUILT (#1446 merged) + first eval done.**
`Late_stage2_stop_runner`: default-off (`enable_late_stage2_stop_tighten` /
`late_stage2_stop_buffer_pct`), Friday cadence, long-only, on `Stage2 {late=true}`
raises (never lowers) the trailing stop to `close*(1-buffer)` via `UpdateRiskParams`.
The split-straddling trade-metric artifact (the side-finding above) was fixed FIRST
in #1445 (`metrics.ml` restates the entry leg to the post-split basis). First eval
(top-N broad, relative arms valid even though absolute baseline is the drifted
universe — see [[project_tier4_goldens_pit_migration]]):
- **covid 2020-2024** (vertical-crash regime): NEUTRAL→slightly-negative (return
  139.9→142.9%, MaxDD 52.9→53.9%, buf05≡buf08 — the dial barely engaged; the 2020
  blow-off resets `late`, so it structurally can't catch index crashes).
- **six-year 2018-2023** (rolling-top regime, 2022 bear): the dial HELPED — return
  110→131%, MaxDD 58.9→54.7%, Calmar 0.224→0.275 (+23%).
So the dial helps where names top *gradually* (its design target), neutral on
vertical crashes — consistent with the diagnosis. Still default-off; promotion
needs the confirmation grid ([[project_promotion_confirmation_grid]]). Buf05≡buf08
identical both windows → past a threshold the buffer doesn't differentiate; widen
the axis (e.g. {0.08, 0.12, 0.16}) when running the grid.

## Dial confirmation grid — REJECTED 2026-06-06

The default-off late-Stage2 stop-tighten dial (#1446) went through its confirmation
grid (deep PIT-2000 2000-2026 + bull PIT-2010 2010-2026, Cell E, buffer ∈ {0.03,0.05,0.08}).
**Clean REJECT** (`dev/experiments/_ledger/2026-06-06-late-stage2-stop-tighten-grid.sexp`):
- **MaxDD unchanged to the basis point** in both windows (37.32 deep / 17.50 bull) — the
  dial does NOT cut drawdown, which was its entire purpose.
- **Buffer-insensitive** (0.03/0.05/0.08 byte-identical) → no tunable surface.
- **Bull = total no-op**; deep = +321pp return bump (918→1239%) from ~1 trade (DD-neutral,
  Sharpe 0.70→0.76) = single-episode capital-recycling artifact, not robust.
- **ROOT CAUSE (the real lesson):** the worst drawdowns are FAST crashes (2000-02/2008/2020)
  that **reset `late` before the top**, so the dial never engages on the DD-defining episodes.
  It only acts on slow-topping cases, which aren't the max-DD drivers. So wiring the discarded
  `late` flag into held-exposure management does NOT recover drawdown — the premise that `late`
  precedes the costly tops holds for SLOW tops but not the fast crashes that set MaxDD.

Dial stays default-off / available as an axis; no further investment. The 2020-stall lever
remains **breadth** ([[project_cell_e_2020_stall_regime]]), not late-Stage2 stop-tightening.
A `late`-driven PARTIAL-TRIM variant (vs stop-tighten) could still differ, but the root-cause
above (fast crashes reset `late`) suggests it would hit the same wall on DD.
