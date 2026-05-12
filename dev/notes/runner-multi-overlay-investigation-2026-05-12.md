# Runner multi-overlay investigation — 2026-05-12

Origin: P4 from `next-session-priorities-2026-05-12.md` — "Fix runner
`_apply_overrides` deep-merge for multi-overlay". Filed against
`entry-caps-2026-05-12/report.md` §"Bug filed".

## Verdict — the deep-merge bug DOES NOT EXIST

The reported symptom (arms B and C produce byte-identical `trades.csv`
despite C adding `((screening_config ((candidate_params ((initial_stop_pct
0.10))))))`) is **real** but the **diagnosis is wrong**.

`Backtest.Runner._apply_overrides` deep-merges sequential overlays
correctly. The override IS applied — `screening_config.candidate_params.
initial_stop_pct` flips from 0.08 → 0.10 in the running config. The
override is silent because the **knob is vestigial in the trade-execution
path** (post-G15 refactor).

## Evidence

### 1. Unit test pins multi-overlay merge

Added `test_two_overlays_same_top_level_field` to
`trading/trading/backtest/test/test_runner_hypothesis_overrides.ml`. Applies:

- overlay 1: `((screening_config ((max_score_override (79)))))`
- overlay 2: `((screening_config ((candidate_params ((initial_stop_pct 0.10))))))`

Sequentially through the same fold-merge logic as
`Runner._apply_overrides`. Asserts both fields land in the final config.

Result: **PASS**. Both fields survive.

### 2. The knob `candidate_params.initial_stop_pct` is consumed only by `Screener.suggested_stop`

```
trading/analysis/weinstein/screener/lib/screener.ml:118
  else suggested_stop ~initial_stop_pct:params.initial_stop_pct entry
```

This populates `scored_candidate.suggested_stop` — an **advisory** field
on the screener output, not the installed stop. Per the comment in
`trading/trading/weinstein/strategy/lib/entry_audit_capture.ml:117`:

> "G15 step 3: size off the INSTALLED stop, not `cand.suggested_stop`.
> ... previous behaviour sized off `cand.suggested_stop`, which left a
> structural sizing [issue]."

The G15 refactor severed `suggested_stop` from both:
- Position sizing (now uses installed stop)
- Stop placement (computed independently from `stops_config` +
  `initial_stop_buffer`)

### 3. The actual installed stop comes from a separate path

`trading/trading/weinstein/strategy/lib/entry_audit_helpers.ml:42`
(`initial_stop_and_kind`) calls
`Weinstein_stops.compute_initial_stop_with_floor_with_callbacks` with:

- `~config:stops_config` — controls `min_correction_pct` (default 0.08),
  which drives both support-floor detection AND the buffer between the
  reference level and the placed stop (`delta = min_correction_pct / 2`).
- `~fallback_buffer:initial_stop_buffer` — only used when no qualifying
  support floor is found in the bar history (default 1.02 → 2% above
  entry as a synthetic reference, then `* (1 - 0.04)` → ≈ 2% below
  entry).

So the **effective** installed-stop distance depends on
`stops_config.min_correction_pct` and `initial_stop_buffer`. The
screener-layer `candidate_params.initial_stop_pct` is informational only.

## What the next overnight sweeper needs to know

To widen entry stops (the original intent behind arm C of entry-caps
sweep), the correct knobs are:

| Knob | Path | Default | Effect |
|---|---|---:|---|
| `stops_config.min_correction_pct` | `weinstein_strategy.config.stops_config` | 0.08 | Larger ⇒ wider stop, fewer support floors qualify (fallback path fires more often) |
| `initial_stop_buffer` | `weinstein_strategy.config.initial_stop_buffer` | 1.02 | Larger ⇒ wider fallback stop (only when no floor found) |
| `screening_config.candidate_params.initial_stop_pct` | `Screener.candidate_params.initial_stop_pct` | 0.08 | **VESTIGIAL** — only changes the advisory `suggested_stop` field on screener output. Does NOT change installed stop. |

## Recommended follow-ups (NOT in scope today)

1. **Re-run arm C with the correct knob.** Replace
   `((screening_config ((candidate_params ((initial_stop_pct 0.10))))))`
   with either `((initial_stop_buffer 1.10))` or
   `((stops_config ((min_correction_pct 0.10))))`. The choice matters —
   they have different mechanisms.

2. **Decide what to do with the vestigial knob.** Three options:
   - **Keep + document.** Update the docstring on
     `Screener.candidate_params.initial_stop_pct` to clarify it's
     advisory-only; doesn't drive installed stops. (Lowest churn.)
   - **Re-wire.** Plumb `candidate_params.initial_stop_pct` back into
     `entry_audit_helpers.initial_stop_and_kind` as an additional
     fallback / override on top of `stops_config`. (Restores the
     intent the report's author assumed.)
   - **Delete.** Remove the field. Anything that read
     `suggested_stop` should switch to computing the actual installed
     stop on entry. (Highest churn; breaks the screener's output
     contract for snapshot consumers.)

3. **Pin regression for the multi-overlay merge.** The new
   `test_two_overlays_same_top_level_field` test ships with this note.
   Anything that touches `Runner._apply_overrides` / `_merge_sexp` /
   `_merge_records` must keep this test green.

## Status

- ✅ `test_two_overlays_same_top_level_field` added (passes locally)
- ✅ Investigation note (this file)
- ⏸ Doc/wiring/delete decision — needs user input

## References

- `dev/experiments/entry-caps-2026-05-12/report.md` §"Bug filed"
- `trading/trading/backtest/lib/runner.ml` (`_merge_sexp`, `_apply_overrides`)
- `trading/analysis/weinstein/screener/lib/screener.ml:118` (where the
  vestigial knob is consumed)
- `trading/trading/weinstein/strategy/lib/entry_audit_helpers.ml:42`
  (`initial_stop_and_kind` — the actual stop placement path)
- `trading/trading/weinstein/strategy/lib/entry_audit_capture.ml:117`
  (G15 comment severing `suggested_stop` from sizing)
- `trading/trading/weinstein/stops/lib/weinstein_stops.ml:54`
  (`compute_initial_stop` — the formula that actually places the stop)
