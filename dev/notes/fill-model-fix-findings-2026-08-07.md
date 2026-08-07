# Fill-model faithfulness — findings (2026-08-07 deep dive)

Trade-by-trade forensic of the record-vs-book fill-model inversion
(#2158 arc), tracing the +8,367% (record) vs +287% (book) gap down to
individual entry/exit decisions and then into the execution code. Companion
plan: `dev/plans/fill-model-faithfulness-2026-08-07.md`. Prior arc:
`fill-model-program-data-inventory-2026-08-07.md`, memory
`project_fill_model_inversion` (⭐).

Data used (all committed, 26y top-3000 PIT-2000):
`dev/experiments/stoplimit-entry-wfcv-2026-08-04/deep-pair/control-trades.csv`
(record) and `.../fullbook-ladder/fullbook-graded-trades.csv` (book).

## TL;DR

- **Neither arm is "correct."** Record is over-optimistic (fills at the
  Friday close it decides on); book is buggy (its entry price chases the
  extension upward week over week). The current A/B ("align live to record"
  vs "re-base records to book") is comparing an optimistic cheat against a
  broken strawman.
- The +8,367% vs +287% gap is produced by **three mechanisms**, all of
  which tax the fat tail — the strategy's entire edge (10th confirmation of
  `edge_is_the_fat_tail`).
- **Two real defects to fix** (both default-off, gated): record's
  Friday-close fill (realism), book's E-chase (faithfulness).
- **One thing NOT to fix:** the deep/wide protective stops. They look
  insane as orders (62% wider than 15%, up to 94%) but they ARE the edge —
  structural support-floor stops that give Stage-2 winners room to ride.
- **One open confound:** record's wide stops clear a 15% `Stop_too_wide`
  gate that the book arm enforces. Until resolved, the two arms may not be
  measuring the same strategy. A validation invariant would auto-catch this
  (see the plan).

## 1. Year-over-year gap (record vs book)

Year-end portfolio value from the committed equity curves
(`localtop-ladder/control-equity.csv`,
`fullbook-ladder/fullbook-graded-equity_curve.csv`), $1M start:

| Year | Record YoY | Book YoY | gap (pp) | note |
|---|---:|---:|---:|---|
| 2000 | +57.0 | +32.9 | +24.1 | both up, record 2× |
| 2004 | +46.5 | −7.9 | +54.4 | **book lost the year** |
| 2009 | +26.2 | +0.1 | +26.1 | post-GFC dawn |
| 2020 | +53.8 | +7.8 | +46.0 | COVID melt-up |
| 2025 | +59.0 | −2.1 | +61.1 | one trade (AXTI) |
| 2026* | +193.1 | +7.8 | +185.3 | *partial, MTM spike — inflated |

Every large gap is a **strong up-year** (post-crash dawns / melt-ups).
Book never out-gains record in a big year; its only wins are cutting bear
losses (2022: −6.1 vs −23.7; 2008: −7.5 vs −9.6). The edge is entirely
4-5 fat-tail up-years the book ticket cannot reach.

## 2. The three mechanisms (code-confirmed)

Per-year hold-time signature (record vs book):

| Year | record ≤3d stopout | book ≤3d stopout | record avg hold | book avg hold |
|---|---|---|---|---|
| 2000 | 11% | **56%** | 58d | 33d |
| 2004 | 0% | **54%** | 48d | 25d |
| 2009 | 6% | **40%** | 64d | 29d |
| 2020 | 16% | **59%** | 48d | 26d |
| 2025 | 8% | **39%** | 38d | 31d |

**Mechanism 1 — whipsaw tax (fires always).** Book enters at the breakout
extension E with a tight (≤15%) stop → the normal post-breakout shakeout
ejects it in ≤3 days 40-60% of the time. Record enters at the deep floor
(the Friday close, near the base) with a wide structural stop → survives
the shakeout → rides the runner. Example (2000, BDLN): record 50.00→99.38
held 77d (+98.8%); book same signal, 79.81→92.50 **d=1** (+15.9%), then
missed the run to $143.

**Mechanism 2 — missed fills on gap-ups (V-recoveries).** In 2009 book took
25 entries vs record's 48; the sharp V gapped *past* the resting StopLimit E
so it never triggered. The top 6 divergent 2009 trades were all record-only
(CTS +$219k, NWL +$131k, AOS +$122k, OI +$113k, AVP +$102k, LHX +$100k) —
book sat out the best entry environment of the decade.

**Mechanism 3 — smaller position when book does hold.** Higher entry basis →
fewer shares per fixed-risk dollar → a fraction of the gain even on the same
winner. Example (2020, LOGI): record 47.27→112.52 = +$1.62M at 24,860 sh;
book 49.09→112.52 = +$437k at 6,897 sh (same exit, ⅓ the profit).

The 2025 single-trade illustration: **AXTI** record 2.18→115.45 =
**+5,196%, +$64.3M** (336d); book caught the identical signal, entered 4.13,
**stopped d=1 at −3.2% = −$15k**. That one divergence is the entire 2025 gap.

## 3. BDLN 2000 deep dive (the Rosetta Stone)

BDLN (dot-com moonshot). Reconstructed from
`dump_snap /tmp/snap_top3000_dedup_v5thin_adj/BDLN.snap`.

- **1999 base:** fell from ~$66 (June) to a high-20s–mid-40s base
  (Aug–Dec). Repeatedly-touched ceiling ≈ **$45** (Oct-99 high 45.00) = the
  operative resistance shelf. 30-week MA at the signal ≈ **$37** (mean of 30
  Friday closes 7/2/99→1/21/00 = 1108.75/30, rising).
- **RECORD signal:** week ending Fri **2000-01-21**, weekly close **$50.00**
  (> $45 shelf = breakout; +35% over the rising MA = Stage 2; volume ratio
  3.85×). Orders: **market entry = $50.00 (the Friday close)**; **initial
  stop = $28.44** (43% below — the structural support floor / base low over
  the 90-bar lookback). Outcome: held 77d, extension_stop @ $99.38 =
  **+98.8%**, exited early April *before* the 4/14 collapse to $50.
- **BOOK:** its StopLimit at E never filled in January (price gapped through
  the limit band on 1/10 and 1/25). It only filled the **March re-breakout at
  $79.81** (E had floated up to the high-70s), then a 3/2 shakeout stopped it
  **d=1** at $92.50 — and it missed the run to $143 (3/21).

One trade contains two of the three mechanisms: **missed clean fill** (Jan
gap-through-limit) then **chased the extension** (March E $79.81, ~60% above
record's entry) into an immediate whipsaw.

## 4. Code findings

### Q1 — Market fill timing: Friday close, not Monday open

`trading/weinstein/strategy/lib/entry_audit_helpers.ml:41-51`
(`effective_entry_price`, record path `trigger_at_suggested = false`):
```ocaml
let bars = Bar_reader.daily_bars_for bar_reader ~symbol ~as_of:current_date in
match List.last bars with
| Some bar -> bar.close_price      (* last available daily close = Friday close *)
```
The strategy **decides on Friday's close and fills at that same close** —
no gap risk, no Monday-open slippage. This same-bar fill is a core source of
record's optimism. Real execution is next-bar (Monday) open. → **Fix #1.**

### Q2 — Deep structural stops: 62% wider than 15%, up to 94%

Record's protective stop is the structural support floor (prior base low,
`support_floor_lookback_bars = 90`, `stop_types.ml:64`). Empirical
distribution of `stop_initial_distance_pct` (= |suggested_entry −
installed_stop| / suggested_entry, `trade_context.ml:171-176`):

| arm | stops > 15% | mean | max |
|---|---|---|---|
| **record** | **62% (691/1122)** | 21.6% | **93.9%** |
| **book** | **0%** (hard-capped) | 5.1% | **15.0%** |

**This width gap IS the inversion.** Record's deep stop = winners survive
shakeouts and ride to the fat tail. Book's stop is re-anchored to
just-below-breakout (`stop_anchor_at_entry_base`, few %) or the candidate is
rejected as `Stop_too_wide` — a tight leash → 40-60%/yr whipsaw.
**Do NOT "fix" this** — it is faithful (structural, below the base) and it is
the edge. This is the 10th confirmation of `edge_is_the_fat_tail`.

### Q3 — Book's entry E chases the extension (confirmed)

`analysis/weinstein/screener/lib/screener.ml:126-138`:
```ocaml
let breakout = Option.value a.breakout_price ~default:(...) in
let entry_anchor = Option.value a.local_range_top ~default:breakout in
let entry = suggested_entry ~entry_buffer_pct:params.entry_buffer_pct entry_anchor
```
`suggested_entry = breakout_price × (1 + buffer)`, and `breakout_price` is
**recomputed every Friday** from the current analysis. For a stock making new
highs it floats up weekly, so the book's resting StopLimit E ratchets upward
with the trend. `entry_extension_max_pct` only caps fill-vs-E slippage
*within* a week; nothing freezes E to the *original* breakout. Result: book
systematically enters **higher and later** (BDLN: 79.81 in March vs record's
50 in January). From the screener's view it's a "fresh breakout" each week;
from a Weinstein-purist view it is **buying an extended stock** — the exact
thing the book warns against, and the reason the `entry_anchor_local_range_weeks`
(localtop) knob exists. → **Fix #2** (freeze/cap E to the first-qualifying
breakout).

### CONFOUND (narrowed) — the 15% gate is not tightening record's stops

`entry_audit_capture.ml:133-141` gates `stop_distance_pct >
max_stop_distance_pct` (default 0.15, `stop_types.ml:65`) → `Stop_too_wide`,
**unconditionally** (gate present since 2026-05-11, blame `19a511c94`). Single
entry path (`weinstein_strategy_screening.ml:329` → `entry_walk` →
`make_entry_transition`). The base config is `default_config` (gate 0.15,
`runner.ml:168-169`); **no committed staging scenario lifts it.** Yet:

| arm | flags | stops > 15% | max |
|---|---|---|---|
| control (record) | none | 62% | 93.9% |
| cap15 | stoplimit, close-trigger | 61% | 93.9% |
| trigonly | stoplimit, close-trigger | 60% | 93.9% |
| **fullbook-graded** | + **stop_anchor_at_entry_base** | **0%** | **15.0%** |

So **three arms carry 94%-wide stops; only `stop_anchor_at_entry_base` caps
them** (by re-anchoring the stop to just-below-breakout — a documented book
flag). The ablation `1b-wide-stops.sexp` is explicit: *"max_stop_distance_pct
= 0.50 (was 0.15) — must LIFT the gate or every 30%-stop candidate is rejected
with Stop_too_wide."* So the gate **does** reject wide stops when it runs — yet
these support-floor arms keep 94% stops with an unlifted gate. Two candidates,
mutually exclusive, distinguished only by the per-candidate audit trace:

- **(a) Provenance / reproducibility bug.** The Aug-4 experiment arms were run
  from a config that lifted the gate (deep floor), but the committed
  `staging-record-convention` scenarios omit that lift → **re-running them
  reproduces neither the record nor the deep-pair arms** (they'd gate to ≤15%,
  book-like). The re-run recipe in `fill-model-program-data-inventory` would
  silently give the wrong answer.
- **(b) Support-floor bypass.** The gate fires for screener-`initial_stop_pct`
  stops (the ablation) but the structural support-floor `installed_stop` path
  reaches the position without the gate rejecting it — a code gap.

**Resolution = the `trade_audit.sexp` regen** (the audit's
`emit_candidate_trace` logs `stop_distance_pct` / `max_stop_distance_pct` /
outcome per candidate; V12 then reads it). Cheap once run; deferred tonight
(disk ~30GB — no unattended multi-hour run per sweep-hygiene). **V12 is the
standing guard** either way.

**Why load-bearing — it reframes the A/B.** The deep support-floor stop is a
*separate axis* from the fill model, and the record-vs-book comparison bundles
them: record = deep-floor stops + Friday-close fill; book = tight
(stop_anchor) stops + E-anchored chase. The +8,367% vs +287% gap is therefore
**not attributable to fill timing alone** — the stop treatment differs too. An
honest re-run must **hold the stop gate fixed across both arms** to isolate the
fill-model effect. This is the same lesson as §4 Q2 (deep stops = the edge),
now shown to be entangled in the A/B rather than controlled.

## 5. Fix #1 execution seam (for implementation)

Record entries are **Market** orders whose fill price is the strategy-embedded
`entry_price` (`order_generator.ml:44-48,77` — `None` = "the historical Market
fill model"; the stoplimit path builds `StopLimit(entry_price, cap)` instead).
That `entry_price` is the Friday close (`entry_audit_helpers.ml:49-51`). So
Fix #1 is **not** a `bar_reader` lookup at decision time (no lookahead to
Monday) — it is a change in the *execution* layer: when
`sim_entry_fill_next_open` is on, a Market entry order fills at the **next
bar's open** rather than the embedded close. The seam is the entry-fill router
(`simulation/lib/fill_router.ml`, `EntryFill { fill_price }`) /
`order_generator`. Scoped but real; needs QC on the engine path.

## 6. Recommendation (→ plan doc)

**The gate confound now gates everything.** Because the deep stop is a separate
axis entangled in the record-vs-book comparison (§4 CONFOUND), resolving it
comes *before* implementing or judging the fill-model fixes — it may change
what "the fix" is.

1. **Resolve the confound first** — regen `trade_audit.sexp` for the record
   arm, run V12, decide (a) vs (b). If (a), fix the committed
   `record-convention` scenarios to reproduce the record (and fix the re-run
   recipe). If (b), fix the support-floor gate path.
2. **Validation invariants** (user ask #1) — ✅ V12 shipped (#2229): installed
   stop ≤ `gate_max_stop_distance_pct`. The standing guard for the confound.
3. **Faithfulness evaluation harness** (user ask #2) — ✅ shipped (#2230):
   per-year whipsaw / hold-time / stop-width + two-arm divergence, repeatable.
4. **Fix #1** — next-bar-open fill (default-off, execution-layer per §5).
   Removes the Friday-close optimism. Applies regardless of the A/B.
5. **Fix #2** — freeze/cap entry E to the first-qualifying breakout
   (default-off). Makes the book ticket book-faithful; honest book > +287%.
6. **Do NOT touch** the deep structural stops — but **hold the stop gate fixed
   across both arms** in the honest re-run so it isolates the fill-model effect.
7. **Sequence:** confound → (fixes 4/5 default-off) → re-run the ladder with an
   *honest* record and a *faithful* book, **gate held fixed** → only then decide
   the A/B, gated on WF-CV + the confirmation grid per
   `experiment-flag-discipline` / `promotion-confirmation`. Do NOT decide off
   these contaminated single-path numbers.
