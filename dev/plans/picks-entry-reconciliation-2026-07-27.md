# Plan: weekly-picks entry reconciliation (issue #2103)

**Branch:** `feat/picks-entry-reconciliation`, stacked on `feat/picks-phase-c`
(PR #2105) — the two halves of Phase C share the generator seam.
**Issue:** #2103. **Date:** 2026-07-27.

## 1. Context

`Weekly_snapshot.candidate.entry` is `Screener.scored_candidate.suggested_entry`
— the breakout level computed on the **transition week**. The early-Stage-2
admission window is `weeks_advancing <= 4`, so a name can be admitted (and
re-admitted) for up to four weeks *after* that level was set. Nothing in the
generate seam compares the level against the price the stock actually trades at
today.

Consequences on the 2026-07-24 specimen
(`dev/weekly-picks/2bcf5b335/2026-07-24.{sexp,md}`):

```
| 3 | MBX | ... | $46.08 | $44.88* | 2.6% | ... |
    BUY STOP 651 sh @ $46.08 (~$29998, 30.0% of book, risk $784);
    on fill place SELL STOP @ $44.88, GTC
```

MBX traded ~$62 that Friday. A resting buy-stop at $46.08 with the market at
$62 is *already triggered*: at essentially every broker it becomes a market
order and fills at ~$62. So:

- **Fill price is wrong** — $46.08 displayed, ~$62 actual (+34.5%).
- **Size is wrong** — 651 sh × ~$62 = ~$40.4k of notional, not the $30.0k
  (30% of book) the sizer intended.
- **Risk is wrong by 14×** — displayed risk is `651 × (46.08 − 44.88) = $784`;
  the real risk of a $62 fill against a $44.88 stop is `651 × 17.12 ≈ $11,145`.

Three candidates on that list were >15% past entry (CRNX +43.7%, MBX +34.5%,
SAFT +26.0%) and six were 1–15% past.

**The defect is the sizing, not the label.** Everything else in this plan is
presentation of the same fact: *sizing must always use the expected FILL price,
never the historical breakout level*.

### Current code shape

`Weekly_snapshot_generator._build_candidates` builds each candidate as:

```
Snapshot_display.candidate_of_scored          (* entry = suggested_entry *)
|> _overlay_structural_stop ~side             (* #2084 F2: real support floor *)
|> _size_long                                 (* longs only; sizes at c.entry *)
```

then `Spike_bar_gate.flag_candidates` annotates. `Trade_sizing.size_candidate`
calls `Portfolio_risk.compute_position_size ~entry_price:c.entry` — the stale
level. `Report_shared.instruction` formats a `BUY STOP … @ c.entry` ticket from
the `sized_*` fields, and both renderers (Markdown `Report_renderer`, HTML
`Html_report_renderer`) print it verbatim.

### Weinstein authority

`docs/design/weinstein-book-reference.md` §1 "Stage 2 detail (Ch. 2)" (verified
verbatim, 2026-07-27):

> After initial rally, usually at least one pullback close to the breakout
> point — this is a second chance to buy. […] **Late Stage 2 warning:** when
> stock sags closer to its MA, angle of MA ascent slows, stock is being
> "discovered" — still a "hold" but no longer a buy; reward/risk has shifted
> against you.

The book names the breakout point (and the pullback back to it) as the buy, and
says explicitly that as reward/risk shifts against you a name is no longer a
buy. Suppressing an order on a name that has already run far past its own
breakout is faithful to that. It is **not** a new entry mechanic: no pullback
timing, no re-entry rule, no change to who is admitted as a candidate. The
spine (§W1: Stage-2-only, breakout + volume, structural stop, macro/sector
gates) is untouched — this changes only the *executable ticket* attached to an
already-admitted candidate.

## 2. Approach

Per-candidate reconciliation computed **at generate time**, right after the
structural-stop overlay and **before** sizing.

### Classification

For a candidate with entry `E` and current close `C`, define the side-signed
**overshoot** — how far price has travelled past the entry *in the trade's own
direction*:

```
long:  overshoot_pct = (C - E) / E * 100
short: overshoot_pct = (E - C) / E * 100
```

Two config thresholds (names taken from the issue):

| class | condition | ticket |
|---|---|---|
| `Valid_stop` | `overshoot_pct <= entry_through_band_pct` | today's resting BUY STOP @ E, unchanged |
| `Through_entry` | `entry_through_band_pct < overshoot_pct <= entry_extension_max_pct` | MARKET buy at C, **re-sized on C vs the structural stop** |
| `Extended` | `overshoot_pct > entry_extension_max_pct` | **suppressed**: no order, do-not-chase reason, row kept |
| `Not_reconciled` | mechanism disarmed, or no resident bar | today's behaviour, bit-identical |

`entry_through_band_pct` is a de-minimis band: a stop order resting a few cents
under the market fills essentially at the stop, so a sub-band overshoot is not
worth re-anchoring.

### Where each piece lives

- **`Entry_reconciliation`** (new, `snapshot/lib/`) — the schema-side variant
  plus the pure `classify`. Depends on nothing but `Core`, so
  `Weekly_snapshot` can reference the type and both renderers can read it.
- **`Weekly_snapshot.candidate`** — one additive field,
  `reconciliation : Entry_reconciliation.t [@sexp.default Not_reconciled]`.
  The close and the overshoot ride inside the armed constructors, so no second
  field and no schema bump (additive + defaulted, exactly as `sized_*`,
  `stop_is_structural` and `data_suspect` were).
- **`Weekly_snapshot.expected_fill_price : candidate -> float`** — the single
  source of truth for "what will this actually fill at". `Through_entry` → the
  close; everything else → `entry`. Both the sizer and the renderers call it,
  so display and arithmetic cannot drift.
- **`Entry_reconcile`** (new, `snapshot/gen/lib/`) — the bar-reader-backed pass
  (`for_candidate` / `for_candidates`), mirroring `Stop_recompute`'s shape.
- **`Trade_sizing.size_candidate`** — sizes at `expected_fill_price`, and
  returns an explicitly unsized candidate for `Extended` (there is no ticket to
  size).
- **`Report_shared`** — `instruction` gains the market / suppressed arms;
  new `close_vs_entry` cell text + `entry_reconciliation` legend, shared by
  both renderers.
- **Renderers** — one new `Close vs entry` column in each; the HTML one wraps
  the cell in a class-tagged chip per the Phase-C design spec.

### Rejected alternatives

1. **Rewrite `candidate.entry` to the close for through-entry names.** Loses
   the breakout level, which the chart's green dashed line and the `+X%`
   overshoot both need, and would silently corrupt forward-trace / pick-diff
   comparisons across weeks.
2. **Fix it in the renderer only.** The `.sexp` would keep carrying the wrong
   `sized_risk_amount`; anything downstream of the snapshot (forward trace,
   round-trip verifier, a future execution adapter) would still read 14×-wrong
   risk. The defect is in the sized ticket, so the fix belongs at generate time.
3. **Drop extended candidates entirely.** The issue explicitly says keep the
   row for watch purposes, and dropping would make the pick list silently
   shorter with no explanation — the exact failure mode the Warnings section
   exists to prevent.
4. **Recompute the structural stop at the new fill price.** Deliberately not
   done — see §5.

## 3. Config (experiment-flag-discipline R1/R2)

Two real `Weinstein_strategy.config` fields, so they resolve through
`Backtest.Overlay_validator.apply_overrides` and are expressible as
`Variant_matrix` axes (R2):

```ocaml
entry_through_band_pct  : float; [@sexp.default 0.0]
entry_extension_max_pct : float; [@sexp.default 0.0]
```

**Arming switch: `entry_extension_max_pct > 0.0`.** At the `0.0` default the
whole pass is skipped — every candidate keeps `Not_reconciled`, sizing uses
`entry`, and both renderers emit exactly today's bytes plus one `-` column
cell. That is the R1 no-op.

**Backward-compatibility argument (explicit, per the dispatch brief).** I am
*not* taking a non-no-op default, even though this is a bug fix, for three
reasons:

1. These fields are read **only** by `Weekly_snapshot_generator.generate`. The
   backtest / live strategy path (`on_market_close`) never reads them, so a
   default flip could not fix a backtest number anyway — it would only change
   the human artifact.
2. The exact same family of report-hygiene fixes (#2083 F1 sparse-tail, F2
   rename, F3 spike-bar; #2084 F1 failed-breakout) all shipped default-off and
   armed in `dev/weekly-picks/live-config-overrides.sexp`. Diverging here would
   make one of five sibling gates behave differently for no structural reason.
3. **The danger is fixed in this PR regardless**, because the same PR arms the
   thresholds in `live-config-overrides.sexp` at the issue's own boundaries
   (1% band / 15% extension cap). The next live run emits corrected tickets;
   code defaults stay honest no-ops. This is the arming file's stated purpose:
   "Code defaults stay no-op (experiment-flag R1); arming happens here."

## 4. Files to change

**New (snapshot lib):**
- `snapshot/lib/entry_reconciliation.{ml,mli}` — `levels` record, the 4-way
  variant, `classify`, `label`, `overshoot_of`.

**New (gen lib):**
- `snapshot/gen/lib/entry_reconcile.{ml,mli}` — `for_candidate` /
  `for_candidates` over a `Bar_reader.t`.

**New (tests):**
- `snapshot/test/test_entry_reconciliation.ml` — the pure classifier: all four
  classes, both sides, both boundaries, disarmed no-op.
- `snapshot/gen/test/test_entry_reconcile.ml` — the bar-reader pass: close
  pickup, no-bars degradation, side mirroring, disarmed no-op.

**Modified:**
- `snapshot/lib/weekly_snapshot.{ml,mli}` — `reconciliation` field +
  `expected_fill_price`.
- `snapshot/lib/report_shared.{ml,mli}` — `instruction` arms,
  `close_vs_entry`, `entry_reconciliation` legend, `any_reconciled`.
- `snapshot/lib/report_renderer.ml` — `Close vs entry` column.
- `snapshot/lib/html_report_renderer.ml` — same column, chip-wrapped.
- `snapshot/lib/html_page.ml` — chip CSS (3 class variants).
- `snapshot/gen/lib/snapshot_display.ml` — field default + why.
- `snapshot/gen/lib/trade_sizing.{ml,mli}` — size at expected fill; `Extended`
  arm.
- `snapshot/gen/lib/weekly_snapshot_generator.{ml,mli}` — wire the pass for
  **both** long and short arms, before sizing.
- `strategy/lib/weinstein_strategy_config.{ml,mli}`,
  `strategy/lib/weinstein_strategy.mli` — the two config fields.
- `dev/weekly-picks/live-config-overrides.sexp` — arm at 1% / 15%.
- Existing tests carrying `candidate` record literals
  (`test_trade_sizing`, `test_weekly_snapshot_generator`, `test_pick_diff`,
  `test_report_renderer`, `test_html_report_renderer`, `test_round_trip`,
  `test_forward_trace`, `test_split_replay`,
  `backtest/decision_audit/test/test_weekly_adapter`).
- `dev/status/weekly-snapshot.md`.

Code-health: no `lib/*.ml` file crosses 300 lines as a result (the two largest
touched are `html_report_renderer.ml` ~260 and `weekly_snapshot_generator.ml`
~290 after wiring). The two new behaviours land as new modules rather than
growing the generator, per `code-health-discipline.md`.

## 5. Risks / unknowns / known gaps

- **The structural stop is not re-derived at the new fill price.** A
  `Through_entry` candidate keeps the support-floor stop computed from the
  breakout level. For a *structural* stop that is correct (a support floor is a
  chart level, not a function of entry). For a **fallback** stop
  (`entry × initial_stop_buffer`, `stop_is_structural = false`) it means the
  stop stays anchored to the old level, so the re-sized risk is honest but the
  stop distance is wider than an 8% buffer off the fill. Disclosed in the
  `.mli`; not fixed here because moving the stop is a strategy change, not a
  reconciliation.
- **Short candidates stay unsized.** Short entries are default-off in the live
  strategy, so `sized_shares = 0` and the Instruction cell for a
  `Through_entry` short still renders `-`. Shorts DO get classified, and an
  `Extended` short DOES get the do-not-chase suppression text. Disclosed.
- **The 2026-07-24 artifact is not regenerated** by this PR — it needs a live
  data pull. The next weekly run emits the corrected form.
- `data_suspect` flagging runs after reconciliation; both are independent
  annotations on the same record, so order does not matter.

## 6. Acceptance criteria

- [ ] `Entry_reconciliation.classify` pins all four classes on **both** sides
      with **distinguishable** fixtures (different closes, different resulting
      classes — no two fixtures that would pass under a collapsed
      implementation), plus both boundaries (inclusive at the band, inclusive
      at the extension cap) and the disarmed no-op.
- [ ] **The re-sizing arithmetic is pinned numerically** against a
      hand-computed expectation for a `Through_entry` candidate —
      `sized_shares`, `sized_position_value`, `sized_risk_amount` — not just
      the class label. A label-only test would not have caught #2103.
- [ ] `Extended` keeps its row, sizes to zero, and emits a do-not-chase
      instruction naming the overshoot; no executable order text.
- [ ] The **short arm** is pinned at the `generate` seam: mutating the
      short-side reconcile call to a no-op turns a dedicated test red.
- [ ] Disarmed default is bit-identical: a generator run with default config
      produces candidates with `Not_reconciled` and `entry`-based sizing.
- [ ] Old snapshots without the field round-trip (`[@sexp.default]`).
- [ ] Both renderers show the class; the Markdown instruction text and the
      HTML instruction text remain character-identical (shared `Report_shared`).
- [ ] `dune build @fmt && dune build && dune runtest` exit 0.

## 7. Out of scope

- **Any pullback / re-entry timing mechanic.** The no-reversal-timing rule
  stands; `Extended` suppresses an order, it does not schedule one.
- Changing which candidates the screener admits (the ≤4-week early-Stage-2
  window is untouched — #2103 is about the ticket, not the admission).
- Re-deriving the stop at the new fill price (§5).
- Sizing short candidates.
- Regenerating historical weekly artifacts.
- Any change to the backtest / live strategy path.
