# Per-week candidate emission (`candidates.sexp`) — design, 2026-08-23

Issue: **#2490** (per-week candidate list is unrecoverable). Sibling:
**#2486** (stop-ratchet observability), shipped separately — see the
`max_stop` / `n_stop_raises` columns on `trades.csv`.

Status: **DESIGN ONLY — not implemented.** This file exists so the next
dispatch is a straight implementation rather than a re-derivation. Read
§"Why this is not in the same PR" before scoping it.

## The gap, stated precisely

Today, three things survive a backtest run and none of them answers
*"which names did the cascade look at on week W, and where did each one
fall out?"*

| artefact | what it holds | why it does not answer the question |
|---|---|---|
| `trade_audit.sexp` → `cascade_summary` (per Friday) | per-phase admission **counts** (`long_breakout_admitted`, `long_sector_admitted`, …) | counts only; no names |
| `trade_audit.sexp` → `entry_decision.alternatives_considered` | full per-candidate rows (symbol, side, score, grade, stage, `weeks_advancing`, `rs_value`, `volume_ratio`, `sector_name`, `reason_skipped`) | emitted **only attached to a `Kept` entry** (`entry_audit_capture.ml` `_dispatch_one_decision`). A Friday that funds nothing emits nothing — the entire list is lost. And it covers only the screener's **top-N** output, not the cascade's full evaluation |
| `PANEL_GOLDEN_DEBUG=1` stderr trace (`entry_audit_helpers.ml:222`) | per-candidate lines | stderr only, no file sink, not machine-readable, not per-run |

So there are **two distinct sub-gaps**, and they want different fixes:

- **G1 — zero-funded Fridays lose the walk decisions.** Scope: the
  screener's top-N candidates and their entry-walk outcome
  (`Kept` / `Skipped of skip_reason`). The data already exists in the
  right shape; only its emission is conditional on a `Kept` sibling.
- **G2 — the cascade's own drops are nameless.** Scope: every candidate
  the cascade *evaluated* (post held / cooldown / membership filter) and
  which phase dropped it (macro / breakout / sector / rs / grade /
  top_n). No names are retained anywhere today.

G1 is roughly a fifth of the work of G2 and closes the concrete bug in
#2490's title. **Land G1 first**; G2 is a separate PR.

## Target artefact

`<scenario_dir>/candidates.sexp`, opt-in, written only under
`scenario_runner.exe --emit-candidates` (default OFF, mirroring
`--no-emit-all-eligible`'s precedent at
`scenarios/scenario_runner.ml:544` and
`all_eligible/lib/scenario_post_step.mli`'s `~enabled` gate).

Record types live in `trading/trading/backtest/lib/candidate_log.{ml,mli}`
(new module — one new module per PR, per the PR template). Field split
keeps every record inside the 7-9 field guidance:

```ocaml
type cascade_outcome =
  | Admitted                    (* survived to the screener's top-N *)
  | Dropped_at_macro
  | Dropped_at_breakout         (* long: breakout predicate / price floor /
                                   volume band / failed-breakout gate *)
  | Dropped_at_sector
  | Dropped_at_rs               (* short side only today; long RS folds into
                                   grade — see screener_admission.mli *)
  | Dropped_at_grade
  | Dropped_at_top_n
[@@deriving sexp, eq, show]

type signals = {                          (* 7 fields *)
  score : int;
  grade : Weinstein_types.grade;
  stage : Weinstein_types.stage;
  weeks_advancing : int option;
  rs_value : float option;
  volume_ratio : float option;
  sector_name : string;
}

type candidate = {                        (* 4 fields *)
  symbol : string;
  side : Trading_base.Types.position_side;
  outcome : cascade_outcome;
  signals : signals;
}

type week = { date : Core.Date.t; candidates : candidate list }
type t = week list
```

`signals` is deliberately field-for-field the decision-time subset of the
existing `Trade_audit.alternative_candidate` — the two must stay
projectable onto each other, and a test should pin that.

## Plumbing — G1 (zero-funded Fridays)

Four files, all additive.

1. **`weinstein/strategy/lib/audit_recorder.mli/.ml`** — add to
   `cascade_event`:
   ```ocaml
   candidates : alternative_input list;   (* [] when capture is off *)
   ```
   and to the recorder bundle `t`:
   ```ocaml
   capture_candidates : bool;  (* [false] in [noop] *)
   ```
   The flag lives on the **recorder**, not on `Weinstein_strategy.config`
   or `Screener.config`. That is the load-bearing choice: this is
   observability, not a strategy mechanism, so it must not become a
   `Variant_matrix` axis, must not route through `Overlay_validator`, and
   must not appear in any golden's `config_overrides`
   (`config-default-blast-radius.md` never fires). `noop` sets it
   `false`, so live mode and every existing test are bit-identical and
   allocate nothing.

2. **`weinstein/strategy/lib/entry_audit_capture.ml/.mli`** — the walk
   decisions are already computed and already projected by
   `alternatives_of_decisions`. Add a function that returns the full
   decision list projection (no `exclude_position_id`), for the caller to
   hand to the cascade event. `emit_entries` is unchanged.

3. **`weinstein/strategy/lib/weinstein_strategy_screening.ml`** — at the
   existing `record_cascade_summary` site (~line 469), populate
   `candidates` from the decisions when
   `audit_recorder.capture_candidates` is `true`, else `[]`.

4. **`backtest/lib/trade_audit_recorder.ml`** + `candidate_log` — map the
   event into `Candidate_log.week`. The collector can be a `Queue` on
   `Trade_audit.t` (mirroring `cascade_summaries`) or a standalone
   collector; prefer standalone so `trade_audit.sexp`'s on-disk shape does
   not move.

Then: `Runner.result` carries the weeks, `scenario_runner` threads
`~emit_candidates`, and a post-step writes the sexp. Reuse
`scenario_post_step`'s failure-isolation shape — a writer failure must
never abort the parent backtest.

## Plumbing — G2 (cascade drops, the full universe)

G2 additionally needs the **post-held/cooldown/membership candidate
list**, which is private to `Screener._screen` (`screener.ml:428`). Two
constraints shape the fix:

- `Screener.result` must not grow a field that is always computed —
  that is a cost on the default path for every run.
- No new `Screener.config` field, for the same axis/goldens reason as
  above.

The additive answer is an **optional callback** on the existing entry
points:

```ocaml
val screen_with_cooldown :
  ?membership_at:... ->
  ?decline_is_slow_grind:bool ->
  ?on_candidates:((Stock_analysis.t * sector_context) list -> unit) ->
  ...
```

Absent (the default) it is a provable no-op — no shape change, no
allocation, no behaviour change. Present, it hands the caller the exact
list the cascade evaluated.

The per-candidate phase outcome itself is already computed inside
`screener_admission.ml` by `_long_admission` / `_short_admission`
(they return the phase tuples the counters fold). Expose:

```ocaml
val long_outcomes  : <same labelled args as count_long_phases> ->
  macro_admits:bool -> top_n_tickers:Core.String.Set.t ->
  candidates:(Stock_analysis.t * sector_context) list ->
  (string * cascade_outcome) list
val short_outcomes : <mirror of count_short_phases>            -> ...
```

built on the **same** `_long_admission` / `_short_admission` the counters
use, so the named trace and the counted diagnostics cannot drift. A test
should assert exactly that: for any candidate set, the outcome list's
per-stage survivor counts equal `cascade_diagnostics`' counts.

`Screener` re-exports `Screener_admission` via `include module type of`,
so no `screener.mli` surface work beyond the callback.

## Why this is not in the same PR as the #2486 stop instrumentation

Two hard reasons, both from the acceptance checklist rather than taste:

1. **Ownership.** `screener_admission.ml`, `screener.ml`,
   `entry_audit_capture.ml` and `weinstein_strategy_screening.ml` are
   `feat-weinstein` surfaces (`feat-backtest`'s brief: *"screener cascade
   — propose changes via your status file rather than touching
   directly"*). G1 touches two of them; G2 touches all four. The design
   above is that proposal.
2. **PR sizing.** G1 + G2 together, with tests, is ~650-900 LOC across
   two libraries and adds two new modules. The template caps a PR at
   ≤500 LOC and one new module.

Split accordingly: **PR-A = G1** (`candidate_log` module + zero-funded
Friday emission + `--emit-candidates`), **PR-B = G2** (screener trace,
extending PR-A's artefact with the pre-top-N population).

## Test plan (both PRs)

- Flag off → no `candidates.sexp`, and `dune runtest` goldens
  bit-identical. This is the no-op proof; it is not optional.
- Flag on, synthetic run → file exists; a week with **zero funded
  entries** still carries its candidate list (the G1 regression pin).
- Flag on → per-stage survivor counts derived from the emitted outcomes
  equal the same week's `cascade_summary` counts (the anti-drift pin,
  G2).
- `Candidate_log.signals` projects onto
  `Trade_audit.alternative_candidate` field-for-field.
