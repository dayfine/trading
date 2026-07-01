# Per-screen decision-audit report — plan (2026-06-30)

**Origin:** 2026-06-29 user directive (`project_decision_audit_records_directive`):
*"we want screen-by-screen auditable records for more than just the candidates,
but also some of the high-ranking screened-out / missed candidates"* — to reason
about selection soundness and find better levers.

## Purpose — a FAITHFULNESS audit, not an outcome grader (2026-06-30 refinement)

Per 2026-06-30 user feedback: selection quality *by realized outcome* is expected
to look "poor" and that is **working as intended** — we cannot predict the future
and do not want to overfit. Grading picks by their returns is therefore the wrong
lens; it will always score poorly, correctly.

The useful question this report answers is **faithfulness: are we capturing and
*using* the screener's relevant signals soundly?** Concretely, per screen it
compares the **funded** set against the **cash-rejected near-misses** on the
**captured features** — score components, `rs_value`, `volume_ratio`,
`weeks_advancing`, `stage`, `sector` — *not* on returns:

- **If funded ≈ near-miss on every captured feature** → the tie is genuinely
  uninformative; we are faithful (not discarding usable signal). This is the
  expected/WAI case and the noise-floor grid predicts it.
- **If a captured feature *does* separate funded from near-miss but we do not fund
  on it** → a real **faithfulness gap**: a signal we record but ignore. That is the
  constructive payoff — a candidate lever, tested the usual default-off → WF-CV way.
- **Counterfactual (the honest "usable signal left on the table" test):** do the
  cash-skipped names' forward returns differ systematically from the funded? If not,
  there is no faithful lever being missed; if yes on some captured axis, dig.

So the report is a **capture-completeness + use-completeness audit**. The output
format below serves *that* question (feature comparison funded-vs-near-miss),
not per-trade outcome grading.

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

Plus a roll-up header (the **faithfulness** summary): total screens, mean
funded/near-miss counts, # screens with an inversion, and — the core output — the
**funded-vs-cash-rejected distribution on each captured feature**: score, and
(after the enrichment below) `rs_value`, `volume_ratio`, `weeks_advancing`,
`stage`, `sector`. The question each distribution answers: *does this captured
signal separate the funded from the near-misses?* If no signal separates them, the
tie is genuinely uninformative and we are faithful; if one does and we are not
funding on it, that is the lever.

### Data limitation → a Phase-0 audit enrichment

`alternative_candidate` (`trade_audit.mli:75`) currently stores only
`{symbol; side; score; grade; reason_skipped}` — the near-misses do **not** carry
`rs_value` / `volume_ratio` / `weeks_advancing`, so out of the box the
funded-vs-near-miss comparison is limited to **score + grade** (which the
noise-floor grid already implies is uninformative among ties). To run the *full*
faithfulness comparison, **Phase 0** enriches `alternative_candidate` with the same
decision-time features the funded `entry_decision` carries (rs_value, volume_ratio,
weeks_advancing, stage, sector, score_components). Small, additive, default-on
capture change (the recorder already has the `scored_candidate` in hand at skip
time). Without it, ship the score+grade comparison and note the ceiling.

## Why this is the right lever to expose

It directly tests **faithfulness**: at each screen, do the funded ~5 differ from the
cash-rejected near-misses on any signal we *capture*? It is the entry-side
complement to the exit-side `decision_grading` lens, and it operationalizes
`project_screener_alphabetical_tiebreak` + `project_cascade_selection_inversion`
per-screen. **It does not grade picks by outcome** (WAI-poor, see Purpose). The
counterfactual (stretch) — join each near-miss symbol's forward return (reuse
`decision_grading/post_exit`) — is the one place outcome enters, and only to test
"is there *usable captured signal* we are leaving on the table," not to score the
selection. If that comes back null (expected, per `project_edge_is_the_fat_tail` /
`accuracy_is_unreachable`), the honest conclusion is: selection is faithful, and the
only remaining lever is *explicit* diversification/capacity (fund more names/smaller
= the concentration axis `project_capacity_concentration_surface`), **not** a better
sort.

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
