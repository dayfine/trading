# Plan — split-safe whole-window fallback telemetry (F5)

**Date:** 2026-08-06
**Track:** `dev/status/support-floor-stops.md`
**Branch:** `feat/split-safe-fallback-telemetry`
**Closes:** F5 (qc-behavioral follow-up on PR #2213)

## 1. Context

`split_safe_floors` (PR #2181 bar-list path, PR #2213 panel path) rescales the
support-floor scan window onto its split/dividend-adjusted basis before the
correction low / rally high is measured. The rescale is **all-or-nothing**: if
*any* offset in `support_floor_lookback_bars` has an unusable raw or adjusted
close, the whole bundle is returned untouched and the scan runs raw — i.e.
exactly what the flag-off path does.

That design is right (per-bar degradation creates a mixed-basis window, the
pathology the flag exists to remove — see the 2026-08-05 addendum's three-way
measurement table). But it is **silent at the single-decision level**. Today a
caller cannot distinguish:

| situation | observable today |
|---|---|
| (a) flag off | reference 104.0 |
| (b) flag on, window adjustable, adjusted answer happens to be 104.0 | reference 104.0 |
| (c) flag on, window **not** adjustable → fallback fired | reference 104.0 |

Diagnosability exists only in aggregate ("on == off across many rows"). Because
whole-window is by design sensitive to a *single* unusable cell anywhere in the
lookback, a walk-forward run over `((stops_config ((split_safe_floors true))))`
could be substantially inert with nobody knowing what fraction was affected. An
ACCEPT computed over a partly-inert surface would be uninterpretable — precisely
the failure class `.claude/rules/mechanism-validation-rigor.md` exists to
prevent. F5 is therefore gating for promotion (R3).

### Current code

The decision is a single point in
`trading/trading/weinstein/stops/lib/floor_stop.ml`:

```ocaml
let _to_adjusted_basis (cbs : callbacks) : callbacks =
  if _window_is_adjustable cbs then _rescaled cbs else cbs

let _scan_callbacks ~config ~callbacks =
  if config.split_safe_floors then _to_adjusted_basis callbacks else callbacks
```

`_scan_callbacks` has two in-library consumers (`_find_level`, used by
`compute_initial_stop_with_floor_with_callbacks`; and
`floor_is_structural_with_callbacks`). The main out-of-library consumer is
`trading/trading/weinstein/strategy/lib/entry_audit_helpers.ml`
(`initial_stop_and_kind`), whose results already flow into
`Audit_recorder.entry_event` → `Trade_audit.entry_decision` → `trade_audit.sexp`.

## 2. Approach

**Chosen: a pure three-way classifier, single-sourced with the scan decision,
threaded through the existing entry-audit record into `trade_audit.sexp`.**

### 2a. The classifier (stops layer)

```ocaml
type split_safe_basis =
  | Flag_off      (* split_safe_floors = false — no basis decision was taken *)
  | Adjusted      (* flag on, whole window rescalable — scan ran on adjusted basis *)
  | Raw_fallback  (* flag on, window NOT rescalable — whole-window fallback fired *)
[@@deriving show, eq, sexp]
```

Three constructors, not two: conflating `Flag_off` and `Raw_fallback` reproduces
exactly the ambiguity F5 is about.

The decision is made **once**, by a private function returning both the bundle
the scan reads and the basis it is on:

```ocaml
let _scan_basis ~config ~callbacks =
  if not config.split_safe_floors then (callbacks, Flag_off)
  else if _window_is_adjustable callbacks then (_rescaled callbacks, Adjusted)
  else (callbacks, Raw_fallback)

let _scan_callbacks ~config ~callbacks = fst (_scan_basis ~config ~callbacks)
let split_safe_basis_of_callbacks ~config ~callbacks = snd (_scan_basis ~config ~callbacks)
```

This is the load-bearing structural property: **the reported basis cannot drift
from the basis actually scanned**, because there is one branch. A separate
re-derivation of the predicate would reintroduce the #2167 class of bug (a
display flag disagreeing with the installed level), which this track has already
been burned by twice. `_to_adjusted_basis` disappears; its docstring moves to
`_scan_basis`.

Public surface (mirrors the existing `floor_is_structural` /
`floor_is_structural_with_callbacks` pair):

- `Floor_stop.split_safe_basis_of_callbacks : config:config -> callbacks:callbacks -> split_safe_basis`
- `Floor_stop.split_safe_basis_of_bars : config:config -> bars:… -> as_of:… -> split_safe_basis`

both re-exported from `Weinstein_stops`. The type is *named* `split_safe_basis`
and the functions `…_of_callbacks` / `…_of_bars` so the type and the value never
share a name.

### 2b. The sink (strategy → backtest → run artifact)

`Entry_audit_helpers.initial_stop_and_kind` already computes the callbacks
bundle; it returns the basis alongside the stop and the `stop_floor_kind` tag.
That threads through the existing, already-wired chain:

```
Entry_audit_helpers.initial_stop_and_kind
  → Entry_audit_capture.entry_meta.split_safe_basis
  → Audit_recorder.entry_event.split_safe_basis
  → Trade_audit_recorder._entry_decision_of_event
  → Trade_audit.entry_decision.split_safe_basis   [@sexp.default Flag_off]
  → <scenario-dir>/trade_audit.sexp
```

**How a walk-forward run surfaces the number, concretely.** Every scenario
directory already contains `trade_audit.sexp`, written by
`Backtest.Result_writer`. After this change each entry row carries its basis, so
the inert fraction of a surface cell is a one-liner over artifacts that already
exist:

```sh
adj=$(grep -c '(split_safe_basis Adjusted)'     <run>/*/trade_audit.sexp)
raw=$(grep -c '(split_safe_basis Raw_fallback)' <run>/*/trade_audit.sexp)
# inert fraction of the flag-on arm = raw / (adj + raw)
```

A `Flag_off` count that is non-zero in a `split_safe_floors true` arm would
itself be a wiring bug, so the three-way tag also self-checks the arm.

**Honest limitation (documented in the `.mli`, not papered over):**
`entry_decision` rows exist only for *entered* candidates. The tag therefore
measures "fraction of entered positions whose floor scan was inert", not
"fraction of all floor scans". Screened-and-skipped candidates land in
`alternatives_considered`, which carries no stop fields at all; extending that
record is a strictly larger change and is **out of scope**. Entries are the
decisions the mechanism actually changes, so this is the right first cut — but
the denominator must be named correctly when the number is read.

### Alternatives considered and rejected

1. **Global mutable counter in `Floor_stop`** (cheapest). *Rejected on purity.*
   CLAUDE.md and `.claude/rules/*` are emphatic that analysis functions are pure
   — same input, same output, no hidden state — *because reproducible backtests
   depend on it*. A module-level `ref` makes `Floor_stop` order-dependent and
   non-reentrant, silently couples any two backtests run in one process (the
   tuner and the walk-forward runner both do this), and would make the stops
   test suite order-sensitive. The saving is a few dozen lines; the cost is the
   invariant the whole backtest program rests on.

2. **`~on_fallback : unit -> unit` callback parameter.** *Rejected.* Pushes the
   impurity onto every call site instead of removing it, adds an optional
   argument to four public functions, and still leaves the aggregation to be
   invented by each caller. It also cannot express state (a) vs (b): a callback
   that only fires on fallback tells you nothing about how many scans *did*
   adjust, so it cannot produce a fraction — only a count with an unknown
   denominator.

3. **Richer return type on `compute_initial_stop_with_floor_with_callbacks`**
   (e.g. return `stop_state * split_safe_basis`). *Rejected on blast radius.*
   That function has many callers (`stop_recompute`, `stop_thread`,
   `spy_only_weinstein_strategy`, `sector_rotation_stops`, `entry_audit_helpers`,
   several test suites); every one would have to change even though most do not
   want the telemetry. A separate query function is additive and leaves
   default-off callers bit-identical *and* source-identical.

4. **`Audit_recorder` tag only, stopping at the strategy boundary.** *Rejected
   as false coverage.* `Trade_audit_recorder` would drop the field, so nothing
   reaches a run artifact — telemetry nobody reads, which reads as coverage
   without being it. The extra cost of the last two hops is ~20 lines.

5. **Aggregating counter type (`{ flag_off; adjusted; raw_fallback }`) in the
   stops layer.** *Deferred, not rejected.* Nothing accumulates it today, so it
   would be dead code; the per-decision tag in `trade_audit.sexp` already
   supports the aggregate query (above). Worth adding when a reporting consumer
   exists.

### A2 layering check

`.claude/rules/qc-structural-authority.md` row A2 forbids `analysis/` imports
into `trading/trading/` outside `backtest/**`. This change adds **no** dependency
edge at all:

- `Floor_stop` gains only a variant type — no new library in
  `trading/trading/weinstein/stops/lib/dune`.
- `Audit_recorder` (strategy lib) aliases `Weinstein_stops.split_safe_basis`;
  `weinstein_trading.stops` is already in that library's `dune`.
- `Trade_audit` (backtest lib) declares its **own** sexp-able copy of the
  variant and `Trade_audit_recorder` maps between them — exactly the existing
  `stop_floor_kind` convention, chosen so `backtest` needs no new dependency on
  `weinstein_trading.stops`.

## 3. Files to change

| file | change |
|---|---|
| `trading/trading/weinstein/stops/lib/floor_stop.ml` | `split_safe_basis` type; `_scan_basis` single-source; `_scan_callbacks` / `split_safe_basis_of_callbacks` / `split_safe_basis_of_bars` on top; delete `_to_adjusted_basis` (doc moves) |
| `trading/trading/weinstein/stops/lib/floor_stop.mli` | type + two vals with docs |
| `trading/trading/weinstein/stops/lib/weinstein_stops.ml` | re-export |
| `trading/trading/weinstein/stops/lib/weinstein_stops.mli` | re-export + the contract docstring (three states, the drift-free single-source property, the entered-only denominator caveat) |
| `trading/trading/weinstein/strategy/lib/entry_audit_helpers.ml` | `initial_stop_and_kind` also returns the basis |
| `trading/trading/weinstein/strategy/lib/entry_audit_capture.{ml,mli}` | `entry_meta.split_safe_basis`; thread into `build_entry_event` |
| `trading/trading/weinstein/strategy/lib/audit_recorder.{ml,mli}` | `type split_safe_basis = Weinstein_stops.split_safe_basis`; `entry_event.split_safe_basis` |
| `trading/trading/backtest/lib/trade_audit.{ml,mli}` | own sexp variant + `entry_decision.split_safe_basis` with `[@sexp.default Flag_off]` |
| `trading/trading/backtest/lib/trade_audit_recorder.ml` | `_split_safe_basis_of_event` mapping |
| `trading/trading/weinstein/stops/test/test_support_floor.ml` | new telemetry tests over the existing split / NaN fixtures |
| `trading/trading/weinstein/strategy/test/test_panel_callbacks.ml` | panel-path telemetry tests |
| backtest + strategy test files constructing `entry_decision` / `entry_meta` literals | one field each |
| `dev/status/support-floor-stops.md` | F5 state, mutation evidence |

## 4. Risks / unknowns

- **`[@sexp.default]` backward compatibility.** `trade_audit.sexp` is read back
  by `optimal_run_artefacts`, `validator_report` and `trade_audit_report`, and
  `test_trade_audit_report.ml` parses hand-written sexp literals. The default
  attribute must be present or every pre-existing artifact stops parsing. This
  is the single highest-risk line in the change; it gets its own test (parse a
  sexp with the field absent → `Flag_off`).
- **Record-literal fan-out.** ~5 test files construct `entry_decision` /
  `entry_meta` literals and will not compile until updated. Mechanical, but it
  is where the build-fix cycles will go.
- **No golden risk identified.** `trade_audit.sexp` is a run artifact; the
  checked-in goldens under `trading/test_data/backtest_scenarios/*golden*` are
  scenario *specs*, not audit output. To be re-confirmed by a green full
  `dune runtest`.

## 5. Acceptance criteria

- [ ] Telemetry distinguishes all three states (a)/(b)/(c); `Flag_off` is never
      conflated with `Raw_fallback`.
- [ ] No behaviour change to stop levels. `split_safe_floors = false` remains
      bit-identical; every existing test passes unchanged.
- [ ] The basis reported is single-sourced with the basis scanned (one branch).
- [ ] A test pins that on an unadjustable window with the flag **on**, the stop
      level equals the flag-off level *and* the basis is `Raw_fallback` — i.e.
      the same answer with distinguishable telemetry. This is the F5 case.
- [ ] A test pins the universal quantifier through the telemetry (unusable cell
      at a far day-offset still reports `Raw_fallback`).
- [ ] A test pins `[@sexp.default Flag_off]` for `entry_decision` sexps written
      before this change.
- [ ] **Mutation evidence:** report `Adjusted` unconditionally in the fallback
      branch (behaviour unchanged, telemetry lying) → new tests go RED; revert →
      green and `git diff --stat` empty.
- [ ] `dune build @fmt`, `dune build`, full-repo `dune runtest` all exit 0.

## 6. Out of scope

- **F3** (`trade_audit_report_bin.ml` reads raw where the domain wants adjusted)
  — real defect, needs its own PR with report-golden re-pins.
- **F1 / F2** (panel R2 fixture one-sidedness; R1 in-test transcription).
- Rendering the inert fraction in `trade_audit_report` / the HTML report — the
  shell one-liner above covers the immediate need; a report row is a follow-up.
- Telemetry for skipped (non-entered) candidates — would require extending
  `alternative_candidate`.
- Telemetry on the bar-list stop-maintenance path (`stop_recompute`,
  `stop_thread`): `split_safe_basis_of_bars` is exposed for it, but no caller is
  wired here. Entry-time floor placement is the decision the mechanism changes.
- Flipping the `split_safe_floors` default — still needs a ledger ACCEPT (R3).
