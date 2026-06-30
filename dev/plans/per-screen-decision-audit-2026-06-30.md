# Per-screen decision-audit report — plan (2026-06-30)

**Origin:** 2026-06-29 user directive (`project_decision_audit_records_directive`):
*"we want screen-by-screen auditable records for more than just the candidates,
but also some of the high-ranking screened-out / missed candidates"* — to reason
about selection soundness and find better levers.

## The gap (confirmed by code audit)

The data is **already captured**, but **nothing renders it**:

- `Trade_audit.entry_decision` (`trade_audit.mli:90`) carries, per funded entry:
  `entry_date` (the screen Friday), `symbol`, `cascade_score`, `cascade_grade`,
  `stage` (→ `weeks_advancing`), `rs_value`, `volume_ratio`, and crucially
  **`alternatives_considered : alternative_candidate list`** (`:136`) — the
  same-screen candidates that were scored but **not** entered.
- `alternative_candidate` (`:75`) = `{ symbol; side; score; grade; reason_skipped }`
  where `reason_skipped` (`:31`) ∈ `{ Insufficient_cash | Already_held |
  Sized_to_zero | Short_notional_cap | Stop_too_wide | Sector_exposure_cap }`.

What exists but does NOT answer the ask:
- `decision_grading/` lens — grades **exits** (post-exit continuation; which exit
  reasons add/destroy value). Entry side only as pnl/MFE capture. No near-miss view.
- `trade_audit_report` — buckets entries by cascade-score **quartile** win-rate.
  Aggregate, not per-screen, and no funded-vs-rejected comparison.
- **Nothing renders `alternatives_considered`.** (grep: zero report-side refs.)

So the near-miss data is sitting in `trade_audit.sexp` unused. This report surfaces it.

## What to build

A small additive lib + CLI (no behavior change; reuses the `trade_audit_report_bin`
audit loader):

**`decision_audit` lib** (pure):
- `load` the `audit_records` from a `trade_audit.sexp` (reuse existing loader).
- **Group entry_decisions by `entry_date`** → one record per weekly screen.
- For each screen produce:
  - `funded` : the entries taken that Friday — `{symbol; score; grade; weeks_advancing; rs_value; volume_ratio}`.
  - `near_misses` : the **union** of `alternatives_considered` across that screen's
    entries (dedup by symbol), each `{symbol; score; grade; reason_skipped}`,
    sorted score-desc. Emphasis on `Insufficient_cash` (the binding constraint —
    ~97% of decisions, the cash boundary where the tiebreak bites).
  - `summary` : `n_funded`, `n_near_miss`, `min_funded_score`,
    `max_nearmiss_score`, and a flag **`inversion`** = (any near-miss score >
    min funded score) — i.e. did we skip a higher-scored name for a lower one?
    (Usually no, since funding walks score-desc; an inversion flags a sizing/sector
    quirk worth eyeballing.)

**`decision_audit_bin`** — CLI: `--audit <trade_audit.sexp> --out <md>` →
a markdown report, one section per screen date:

```
## 2014-03-28  (funded 3 / 5 slots, 11 near-misses)
funded:      AAPL s78 gA w3 | MSFT s75 gA w2 | NKE s75 gA w5
near-miss:   ADBE s75 gA  [Insufficient_cash]
             AMD  s75 gA  [Insufficient_cash]   <- tied with funded, lost the tiebreak
             ... (8 more Insufficient_cash @ s70-75)
inversion:   none
```

Plus a roll-up header: total screens, mean funded/near-miss counts, # screens with
an inversion, and the **score distribution of funded vs cash-rejected** (the core
soundness question: are the funded names actually higher-scored than the rejected
ones, or is it mostly same-score tiebreak churn? — we already know from the grid
it's the latter, but this makes it auditable per screen).

## Why this is the right lever to expose

It directly tests selection soundness: at each screen, *were the funded ~5 the
best available, and what did we leave on the table?* It is the entry-side complement
to the exit-side `decision_grading` lens, and it operationalizes
`project_screener_alphabetical_tiebreak` + `project_cascade_selection_inversion`
(the funded-vs-near-miss score comparison is exactly the cascade-inversion question,
made per-screen and auditable). Stretch: join each near-miss symbol's forward return
(reuse `decision_grading/post_exit`) to grade the *counterfactual* — did the names
we cash-skipped actually outperform the ones we funded? That closes the loop from
"auditable" to "was the decision good."

## Scope / sizing
- Pure lib + CLI + OUnit tests on synthetic `audit_record` lists (~250-350 lines).
- Additive only; default-off; no engine/strategy change. Lives under
  `trading/trading/backtest/decision_audit/`.
- Phase 1 (this plan): per-screen funded/near-miss markdown + inversion flag +
  score-distribution roll-up. Phase 2 (stretch): forward-return counterfactual on
  the cash-rejected names.

## Status
Spec only (2026-06-30, written while the noise-floor control grid ran). Ready to
build on approval. Data source: any backtest's `trade_audit.sexp` (e.g. regenerate
a broad cell with audit, or reuse a `decision_grading` Phase-4 scenario dir).
