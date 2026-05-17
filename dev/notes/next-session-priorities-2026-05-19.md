# Next-session priorities (2026-05-19) — autonomous PM 2026-05-17

Rewritten end-of-session 2026-05-17 PM after a 4-PR autonomous batch.
Supersedes the prior "13 PRs full day" version (written earlier in the
same session, before the P0a fix landed and based on the pre-fix
sweep golden).

## TL;DR

- **P0a (BAH zero-trade bug) DONE.** PR #1172 merged; 1% gap-buffer in
  sizing drops the weekly-start-sweep zero-trade rate from 70/157 → 4/157.
  The 4 residual cells are all extreme overnight gap-ups (1.10%, 1.22%,
  1.39%, 3.47%) — those need the simulator silent-swallow fix to close.
- **P0b (Universe-snapshot consumer adapter) DONE.** PR #1174 (pending
  CI/QC at writing). Bridges `analysis/data/universe` Snapshot.t
  goldens into `Universe_file` consumers via auto-fallback in
  `Universe_file.load`. A2 allow-list widened to permit `universe`
  imports under `trading/trading/backtest/**`.
- **P1 (Q2-A composition memory opt) DONE.** PR #1175 (pending CI/QC).
  Drops bars from `_scored` records → frees ~250 MB at broad-universe
  scale; unblocks multi-year × multi-size composition runs that
  previously OOMed.
- **Docs fix-forward DONE.** PR #1173 merged — scenario sexp comment
  headers refreshed to match the gap-buffered sizing math.

## PRs landed 2026-05-17 PM (this autonomous session)

| PR | Track | Summary |
|---|---|---|
| #1172 | fix-bah | 1% gap buffer in BAH sizing — prevents stuck-Entering on overnight gap-ups |
| #1173 | docs | scenario sexp comment headers refresh after #1172 |
| #1174 | feat-scenarios | Universe-snapshot → Universe_file bridge (P0b adapter) |
| #1175 | perf | drop bars from `_scored` to fix multi-year × multi-size OOM (Q2-A P1) |

## Carry-forward — P0 items

### P0a-residual — simulator silent-swallow fix (Option B from #1172 review)

The 4 residual zero-trade cells in the sweep golden are extreme gap-ups
that exceed the 1% buffer (2023-11-13 +1.39%, 2025-04-07 +3.47%,
2025-04-21 +1.22%, 2026-03-30 +1.10%). Root cause confirmed:
`Simulator._apply_trades_best_effort` silently drops the rejected trade
(simulator.ml:354-358), the position stays stuck in `Entering` with 0
fills, and BAH's `_has_position_for_symbol` suppresses every retry.

**Fix design (Option B):** emit a `CancelEntry` transition for the
Entering position whenever its corresponding fill is rejected, so the
strategy sees `Closed` next day and naturally retries with updated
sizing. Touches:

- `Simulator._apply_trades_best_effort` — return rejected trades alongside accepted.
- `Simulator._process_step_day` — generate cancel transitions from rejected trades.
- `Simulator._apply_transitions` — add `CancelEntry` dispatch (the
  position state machine in `Position.apply_transition` already handles
  `Entering + CancelEntry → Closed`, but the simulator's transition
  dispatcher currently ignores `CancelEntry`).

**Effort:** ~50 LOC simulator + ~50 LOC tests. Re-pins BAH baselines
again (small shift downward as cancelled-then-retried entries pay extra
commission and incur 1 extra day of cash drag). Sweep golden should
re-anchor with 0/157 zero cells under typical conditions; pathological
multi-day gap-up streaks may still produce stuck cells but should be rare.

### P0b-followup — Weinstein scenario against a composition golden

PR #1174 wires the bridge but does not commit a runnable Weinstein
scenario that consumes one. Natural next step:

1. Add `goldens-custom-universe-scenarios/weinstein-2019-top-500.sexp`
   pointing at `../../goldens-custom-universe/composition/top-500-2019.sexp`
   with the standard Cell-E config and 2019-01-02..2023-12-29 period.
2. Pin expected ranges loosely on first run; tighten after measurement.
3. Compare to `sp500-2019-2023.sexp` baseline (same window, sp500.sexp
   universe) — the cap-weighted composition universe should produce
   comparable Sharpe / MaxDD within 1-2 standard-error bands.

**Effort:** ~30 LOC scenario file + 1 run (~10-15 min wall) to pin
expected ranges + smoke check that all 500 symbols' bars are present in
`data/` for the 2019-2023 window. Some 1998-era names may have stopped
trading by 2019 — the runner's degraded-mode drop-or-skip behavior for
missing-bar symbols needs verification.

## P1 — Optional follow-ups

### Composition-golden bar-coverage audit (1998-2005)

The `Universe_snapshot` bridge (#1174) projects composition goldens
into the runner via [Universe_file.load]. But the goldens were built
from EODHD inventory; some 1998-2005-era symbols (delisted, M&A'd,
gone) may have spotty or missing bars in `data/<X>/<Y>/<SYM>/data.csv`.
The runner's `Csv_snapshot_builder` tolerates missing bars (returns
empty rows + NaN columns), so a backtest doesn't crash — but the
universe effectively shrinks silently, and statistics on the
"500-symbol universe" become misleading.

**Deliverable:** per-symbol bar-coverage report for each
`top-{500,1000,3000}-{1998..2005}.sexp` composition golden. For each
golden + symbol: trading-day coverage percent over the snapshot's
forward 1y window. Flag symbols with `< 80%` coverage; flag goldens
with `> 10%` of symbols below threshold.

**Effort:** ~80 LOC OCaml (reads inventory + counts CSV rows) + 1-2h
operator wall to run across the 8 affected years. Output: a markdown
report at `dev/reports/composition-golden-bar-coverage-2026-05-XX.md`.

**Why P1, not P0:** the 2019+ goldens have near-100% coverage (current
symbols, complete bars). The hole shows up only when consuming
pre-2006 goldens, which is the broader-first agenda but not the
immediate 2026-05-19 work. File now so it doesn't get lost.

### Tunable-parameter inventory + private tuned-configs repo

See `dev/notes/tunable-parameters-inventory-2026-05-18.md` (inventory)
and `dev/plans/private-tuned-configs-repo-2026-05-18.md` (design). When
the next BO sweep produces a config worth blessing, set up the private
repo per the design plan.

### Decomposition + Composition unification

`Universe.Build_from_index` + `Universe.Build_from_individuals` both
produce `Snapshot.t` but expose different config shapes. The original
priorities note suggested a `Universe_builder` wrapper that dispatches by
date. Lower value than expected because the configs differ in shape
(composition needs bars/inventory/sectors; decomposition needs Shiller +
French observations), so a discriminated-union wrapper saves little.
**Defer or close as not-worth.**

### Q2-A 2026 gap

`top-{500,1000,3000}-2026.sexp` missing because EODHD bars don't extend
to 2026-05-31 in the inventory. Re-run cleanly once bars cache catches
up. Operational, not feature work.

### Cost-model wiring

Per `dev/status/cost-model.md` — all 4 deferred items are flagged
"defer until empirical evidence" or "every scenario needs re-pin".
Not actionable until a specific scenario demands the per-trade or
impact knob. **Defer.**

## Recommended sequencing for 2026-05-19

1. **Step 0**: `gh run list --branch main --limit 3` — verify green.
2. **P0a-residual** (simulator silent-swallow): ~2-3h. Closes the 4
   residual sweep zero-trade cells AND protects all future strategies
   from the same trap. Re-pin BAH baselines after.
3. **P0b-followup** (Weinstein composition scenario): ~1h. Concrete
   proof the universe-snapshot bridge unlocks the substrate.
4. **Bayesian production sweep** (from the older 2026-05-18 note) if
   IWV unblocks — still gated on the paid-scraper / Sharadar / EODHD
   tier decision.
5. **Optional**: small follow-up PRs (cleanup, docs, etc.).

## Open follow-ups

- Simulator silent-swallow fix (Option B) — primary P0 for next session.
- Weinstein-on-composition scenario file — secondary P0.
- `dev/status/cost-model.md` — 4 deferred items (no action).
- `dev/notes/iwv-scrape-akamai-block-2026-05-16.md` — paid-scraper
  decision still open; gates Bayesian production sweep + survivorship
  re-pin.
