# Plan — make the weekly-picks chart answer "how was entry picked?"

**Date:** 2026-08-20
**Trigger (user, reading the 08-14 arc report):** *"the chart is puzzling to some
extent — how's entry picked? compared to the breakout / crossover point? … would
also be nice to have dates on there to know what time period and dates I am
looking at."*

The question is fair, and the chart currently cannot answer it: **it draws one
of three levels, and not the one that governs admission.**

## The three levels, and which is drawn

```
entry_anchor = local_range_top      split-safe max HIGH over the last N weekly
                                    bars (N = entry_anchor_local_range_weeks)
             = breakout_price       fallback when that knob is 0
entry        = entry_anchor x (1 + entry_buffer_pct)     buffer 0.005
stop         = entry x (1 - initial_stop_pct)            0.08, or a structural floor
```

| level | drives | drawn today? |
|---|---|---|
| MA crossover / Stage-2 start | the *stage* event — when the name became eligible at all | ❌ |
| **`breakout_price`** (graded resistance top) | **admission, grading, swing_target** | ❌ |
| `local_range_top` → `entry` | the ticket and its derived stop | ✅ (the only one) |

`screener.ml:_build_candidate` is explicit: *"Only the entry (and its derived
stop / risk) moves; `breakout` still drives `swing_target` and admission/grading
are untouched (they read `breakout_price`)."*

So a reader sees the **ticket** level while the **admission** level is invisible.
This is not hypothetical: on 2026-08-20 the dispatcher tried to explain why TPC
and INVX dropped out of the arc pick list using close-vs-entry, and the
explanation failed — because entry is not the level rt tests against. The chart
actively misleads on the one question it looks like it answers.

## ⚠ Scoping: three of four improvements are BLOCKED ON THE SCHEMA

The snapshot's candidate record carries:

```
symbol score grade entry stop sector rationale rs_vs_spy resistance_grade
sized_shares sized_position_value sized_position_pct sized_risk_amount
sizing_note stop_is_structural data_suspect
reconciliation(close, overshoot_pct, cap) score_components
```

It does **not** carry `breakout_price`, `local_range_top`, or any Stage-2 start
date. So drawing them is not a rendering task — the producer has to emit them
first. Building the consumer without its producer is exactly the failure that
cost an hour earlier the same day (`project_rt_needs_its_anchor_knob`).

## Phase A — date axis (no schema change)

Bars already carry dates, so this is pure `Svg_chart` work.

- [ ] **A1** — `?date_axis:bool` (default `false`, so every existing byte is
      unchanged when omitted — the module's determinism contract and its
      "omitted = byte-identical" convention for `?ma_period` / `?annotate` are
      the precedent to follow).
- [ ] **A2** — first and last bar dates under the plot, plus interior tick
      labels at a readable density. Reserve height rather than overprinting the
      volume strip.
- [ ] **A3** — window span in the card caption and the root `aria-label`:
      "90 weekly bars, 2024-11-15 → 2026-08-17".
- [ ] **A4** — tests in `test_svg_chart.ml`: omitted ⇒ byte-identical to today;
      enabled ⇒ first/last dates present and correct; a mutation that drops the
      axis must fail a test (per the #2449 lesson — a test named for a property
      that does not pin it is worse than no test).

**A3 has immediate diagnostic value beyond legibility.** The 08-14 arc report's
charts run through **2026-08-17** while the picks are as-of **08-14**, because
chart bars come from `data/` which has moved on. Today that mismatch is silent;
a date axis makes it self-evident.

## Phase B — the levels that explain the entry (needs `schema_version 2`)

- [ ] **B1** — emit per candidate: `breakout_price`, `local_range_top`, and the
      Stage-2 start date (or `weeks_advancing`, from which the date is
      derivable). Bump `schema_version` 1 → 2 and keep the reader
      backward-compatible with v1 files (the committed `dev/weekly-picks/*/`
      history is v1 and must still render).
- [ ] **B2** — `Breakout` level kind in `Svg_chart.level_kind` with its own CSS
      class, so entry-vs-breakout is visible as two distinct lines.
- [ ] **B3** — a vertical rule at the Stage-2 start, with a `<title>` naming the
      date and the weeks-advancing count.
- [ ] **B4** — shade the N-bar anchor window that sets `local_range_top`. This
      is the single mark that makes "how is entry picked" self-evident: the
      entry line sits a buffer above the highest high in the shaded region.
- [ ] **B5** — legend entries + hover tooltips for each new mark
      (`user_picks_report_preferences`: hover tooltips explaining markers).

## Acceptance

A reader looking at one candidate card can answer, without leaving the page:
what date range am I seeing; when did this turn Stage 2; where is the graded
breakout; which bars set the entry anchor; and why is the entry line where it is
relative to both.

## Notes for whoever builds it

- `Svg_chart` is a **pure** function with a byte-identical-output determinism
  contract. Every new parameter must default to the current behaviour, and the
  tests should pin that, not just the new marks.
- Keep chart-module changes cadence-agnostic: preparing the series is
  `Svg_series`'s job, not the chart's.
- The report renderer is `render_weekly_report.ml` (`-html`, `-html-out`,
  `-data-dir` / `-bars-snapshot-dir`).
- Phase A alone leaves the main question unanswered; Phase B alone leaves the
  reader unable to tell what period they are looking at. They are worth one
  brief, but A is independently shippable if B stalls on the schema bump.
