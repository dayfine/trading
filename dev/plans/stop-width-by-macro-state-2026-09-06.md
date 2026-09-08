# Per-macro-state `initial_stop_buffer` — implementation plan (2026-09-06)

> **Implemented 2026-09-08 on branch `feat/weinstein/stop-buffer-by-macro-state`**
> (PR opened from that branch; see `dev/status/portfolio-stops.md`
> §"Per-macro-state `initial_stop_buffer`"). Shipped as written: shape (a),
> flat five-float record with the `0.0` sentinel, one resolved buffer threaded
> to both consumers, map default-empty. Two deviations worth naming, neither
> changing the design: the new module lives in `strategy/lib` as planned but
> is also re-exported from `Weinstein_strategy` (so specs and tests can build a
> map without reaching into the private module), and `buffer_for` treats **any
> non-positive** slot as unset rather than exactly `0.0`, so a negative typo in
> a sweep spec falls back instead of inverting the stop.

Item 3 of the decided sequence in `dev/notes/next-session-priorities-2026-09-06.md`.
Builds on PR #2685's five-state breadth read (`Weinstein_types.breadth_state`,
`Macro.result.breadth_state`, `Breadth_direction`), which is already merged and
default-off.

## 1. Context

### What the user asked for

> `initial_stop_buffer` becomes a map over the five macro states (default: the
> current single value in every slot, so a no-op until set — R1). The
> fallback-stop builder reads the state at entry. First map to test, from the
> surface: Bullish / Recovering → 12% (`0.9167`), Neutral → 8–10%,
> Deteriorating / Bearish → the book's 4–6% band (`1.0`).

### Why the width must be state-conditioned at all

`dev/experiments/stop-width-cadence-surface-2026-09-05/` found a 12% fallback
stop with a weekly-raised trail to be a large, robust return lever (761% /
maxDD 29.7 at 26y vs the record's 303% / 36.3), **and** found why it cannot be
flipped as a constant: the wide arm's crash-week losses landed under
Bullish/Neutral labels because the three-state trend gate never turned in 2020.
The 27-year breadth study then measured entries made while breadth is
Deteriorating as losers in both books (−$604k record / −$668k arm) and
Recovering-breadth entries as the best in the run (+$627k / +$1.81M). So the
width has to be sized by a state that can see a fast crash. #2685 built that
state; this PR lets the stop width read it.

### What exists today

- `initial_stop_buffer : float`, declared at
  `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml:53`,
  default `1.0` (the book's §5.3 4% floor after the `min_correction_pct / 2`
  inset — see the `.mli` docstring; flipped from `1.02` in issue #2486 §2.1).
- Exactly **two** code read sites of `config.initial_stop_buffer`, both inside
  `Entry_walk.entries_from_candidates`:
  - `entry_walk.ml:109` — `_make_entry_fn`, the real ticket builder.
  - `entry_stop_width_order.ml:21` — the `Demote_over_max` ordering pass, whose
    stated contract is that it measures **exactly the stop the gate would
    install** ("Agreeing with the gate is the contract",
    `entry_stop_width_order.mli`). If only one of the two learns about the map,
    that invariant breaks silently.
- The snapshot generator (`weekly_snapshot_generator.ml:207`,
  `held_position_row.ml:27` → `Stop_thread.seed` / `Stop_recompute`) passes
  `config.initial_stop_buffer` down as a plain `float`. Those are **weekly-report
  recompute paths for already-held positions**, not entry decisions, and they have
  no macro result in scope — out of scope here (§6).
- `Macro.result` is already threaded into `entries_from_candidates` as
  `?macro`, and the live caller
  (`weinstein_strategy_screening.ml:439`) passes `~macro:macro_result`. So the
  state at entry is **already in scope at the one place that needs it** — no new
  plumbing through the strategy is required.

## 2. Approach

### Shape (a) — additive — is chosen. Shape (b) — type change — is rejected.

The dispatch brief asked for an explicit argument between:

- **(a)** keep `initial_stop_buffer : float` as the default/fallback, add a new
  optional map field that defaults to a no-op;
- **(b)** change `initial_stop_buffer`'s type to the map and migrate every
  consumer.

**Choosing (a).** Four reasons, in decreasing order of weight:

1. **`initial_stop_buffer` is a string-keyed public override key, and (b) breaks
   it at *runtime*, not at compile time.** It is documented in
   `config_override.mli` (both `stops_config.initial_stop_buffer=1.05` and bare
   `initial_stop_buffer=1.08`), `fuzz_spec.mli`
   (`stops_config.initial_stop_buffer=1.05±0.02:11`) and `runner.mli`; the tuner
   sweeps it by name in `grid_search`, `bayesian_runner` and `sensitivity_sweep`;
   and **eleven committed scenario specs already carry
   `(config_overrides (((initial_stop_buffer X))))`** —
   `trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep/*.sexp`
   (7 files) and `.../experiments/stop-buffer/*.sexp` (2 files). Under (b) each of
   those becomes a sexp parse failure discovered *inside* a running sweep, which
   is the worst place to discover it. `Overlay_validator` cannot help: it
   validates that a key *resolves*, not that its value still parses.
2. **R1 is provable under (a) and merely maintained under (b).** Under (a) the
   resolved buffer is `config.initial_stop_buffer` by construction whenever no
   slot is set — one branch, one source of truth, and the no-op is a theorem.
   Under (b) "the current single value in every slot" is an invariant five
   literals have to keep, and any *partial* override
   (`initial_stop_buffer.deteriorating=1.0`) silently loses the scalar for the
   other four states.
3. **The unconditioned path is still the dominant one.** `?macro` is optional on
   `entries_from_candidates` (several tests and `selection_trace` omit it), and
   the breadth-direction read is itself default-off — so
   `Macro.result.breadth_state` is the plain projection of `trend` in every
   existing run. (a) leaves that path structurally identical to today; (b) would
   have to synthesise a state for callers that have none.
4. **The user's intent is width-sized-by-state, and (a) delivers exactly that.**
   The map, once set, selects per state. The only thing that differs from a
   literal reading of "becomes a map" is that the scalar survives — as the
   documented default slot, which is what "the current single value in every
   slot" means operationally anyway.

This will be stated in the PR body.

### The new type

New module `trading/trading/weinstein/strategy/lib/stop_buffer_by_state.{ml,mli}`:

```ocaml
val unset : float                       (* 0.0 *)

type t = {
  bullish : float;        [@sexp.default unset]
  neutral : float;        [@sexp.default unset]
  deteriorating : float;  [@sexp.default unset]
  recovering : float;     [@sexp.default unset]
  bearish : float;        [@sexp.default unset]
} [@@deriving sexp]

val default : t                          (* every slot [unset] *)
val is_no_op : t -> bool
val buffer_for :
  t -> fallback:float -> state:Weinstein_types.breadth_state -> float
```

**A flat five-float record, not an option/assoc-list, because of
`Overlay_validator`.** The validator deep-merges the overlay against the *base
config's own sexp* and raises `Failure` for any overlay key with no matching key
in the base (`overlay_validator.ml` `_merge_records`). A field whose default
serialises to `Sexp.List []` — i.e. `None`, or `[]` for an assoc list — presents
**zero** base keys, so a record-shaped overlay against it makes every key
"unknown" and the overlay *raises* instead of applying. A flat record always
serialises all five keys, so both override forms resolve:

- dot-path: `initial_stop_buffer_by_macro_state.deteriorating=1.0`
  → `((initial_stop_buffer_by_macro_state ((deteriorating 1.0))))`
- full sexp: `((initial_stop_buffer_by_macro_state ((bullish 0.9167) (recovering 0.9167))))`

which is R2 — the knob is a real config field, resolvable by
`apply_overrides`, hence expressible as a `Variant_matrix` axis.

The same reasoning rules out `float option` per slot: the dot-path form yields
an `Atom` leaf, and `option_of_sexp` rejects an atom, so the ergonomic override
form would fail. Hence a plain `float` with a **sentinel**: `unset = 0.0` means
"this state has no width of its own; use `initial_stop_buffer`". `0.0` is not a
legal buffer (it is a multiplier on the entry price), so the sentinel is not
ambiguous with any meaningful value, and 0.0-means-off is the established
idiom in this config (`stage3_exit_margin_pct`, `short_sleeve_fraction`,
`short_min_price` all use it).

Field names are `bullish` / `neutral` / `deteriorating` / `recovering` /
`bearish` — the constructor names minus the `_breadth` suffix, so the override
key reads naturally. `buffer_for` matches exhaustively on `breadth_state`, so a
sixth state added later is a compile error here.

### The config field

Added to `weinstein_strategy_config.config` immediately after
`initial_stop_buffer`:

```ocaml
initial_stop_buffer_by_macro_state : Stop_buffer_by_state.t;
    [@sexp.default Stop_buffer_by_state.default]
```

`[@sexp.default …]` (not `[@sexp_drop_default]`) — the field must still be
*emitted* in the base config's sexp or the overlay would not resolve (above).

### The read site

One resolution, in `entry_walk.ml`, from the `?macro` already in scope:

```ocaml
let _initial_stop_buffer ~config ~macro =
  match macro with
  | None -> config.initial_stop_buffer
  | Some (m : Macro.result) ->
      Stop_buffer_by_state.buffer_for config.initial_stop_buffer_by_macro_state
        ~fallback:config.initial_stop_buffer ~state:m.Macro.breadth_state
```

computed once in `entries_from_candidates` and threaded to **both** consumers:

- `_make_entry_fn ~initial_stop_buffer …` (replacing its
  `config.initial_stop_buffer` read), and
- `_prepare_candidates` → `Entry_stop_width_order.prefer_narrow_stops
  ~initial_stop_buffer`.

`prefer_narrow_stops` gains `?initial_stop_buffer` as an **optional** argument
defaulting to `config.initial_stop_buffer`. Optional rather than required
because the default expression *is* the no-op statement — a caller that does not
know about macro state gets exactly today's behaviour — and because it keeps the
three existing test call sites untouched, so their green is evidence about the
default path rather than about my edits to them.

Threading one already-resolved float (rather than passing `?macro` down to both)
is deliberate: it makes it structurally impossible for the ordering pass and the
gate to resolve different buffers, which is the invariant
`entry_stop_width_order.mli` calls "the contract".

### Interaction worth documenting (not a bug)

With `macro_config.breadth_direction` at its default-off setting,
`Macro.result.breadth_state` is exactly
`breadth_state_of_market_trend result.trend`, so it can only ever be
`Bullish_breadth | Neutral_breadth | Bearish_breadth`. **Setting only the
`deteriorating` / `recovering` slots is therefore a no-op until the breadth read
is armed.** This goes in the `.mli` docstring — an operator arming a per-state
map without arming the state machine would otherwise see nothing happen and have
no way to tell why.

## 3. Files to change

| File | Change |
|---|---|
| `trading/trading/weinstein/strategy/lib/stop_buffer_by_state.mli` | **new** — type, `unset`, `default`, `is_no_op`, `buffer_for`; docstring covering the sentinel, the R1 no-op, the overlay-shape reason for the flat record, and the breadth-direction interaction |
| `trading/trading/weinstein/strategy/lib/stop_buffer_by_state.ml` | **new** — ~25 lines |
| `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml` | add `initial_stop_buffer_by_macro_state` field + `default_config` slot |
| `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli` | field + docstring (default-off statement, R1/R2 citation, book §5.1 ceiling note) |
| `trading/trading/weinstein/strategy/lib/entry_walk.ml` | `_initial_stop_buffer` resolver; thread it into `_make_entry_fn` and `_prepare_candidates` |
| `trading/trading/weinstein/strategy/lib/entry_stop_width_order.ml` | `?initial_stop_buffer` param, defaulting to `config.initial_stop_buffer` |
| `trading/trading/weinstein/strategy/lib/entry_stop_width_order.mli` | signature + docstring for the new param and why it exists |
| `trading/trading/weinstein/strategy/lib/entry_walk.mli` | one docstring sentence: the fallback buffer is per-state when the map is armed |
| `trading/trading/weinstein/strategy/test/test_stop_buffer_by_state.ml` | **new** — unit tests for the resolver |
| `trading/trading/weinstein/strategy/test/test_stop_width_by_macro_state.ml` | **new** — integration pin through `entries_from_candidates` (installed stop moves with the state) |
| `trading/trading/weinstein/strategy/test/dune` | register the two new test executables (or add to the existing one, per the dir's convention) |
| `dev/status/<track>.md` | session note |

Nine source/test files + plan + status. No changes to the screener, the stops
state machine, the tuner, `config_override`, or any golden.

## 4. Risks / unknowns

1. **Adding a field changes the config's sexp.** Anything that pins a *fully
   serialised* config would move. Mitigation: `[@sexp.default …]` makes reads of
   old sexps work; and a grep of `trading/test_data/` for `initial_stop_buffer`
   finds only `config_overrides` overlays (partial records), never a full config
   dump. Verified before implementation; will be re-verified as part of the
   `goldens-affected` check.
2. **The ordering pass and the gate disagreeing.** This is the one real
   correctness hazard, and the design closes it by construction (one resolved
   float, two consumers). A test asserts the demotion partition responds to the
   per-state buffer.
3. **Sentinel vs. a legitimate 0.0.** Not a real risk — a 0.0 buffer would put
   the fallback stop reference at price 0. Documented in the `.mli`.
4. **Magic-number linter on `0.0`.** Mitigated by the named `unset` binding;
   comparisons against 0.0 are semantic zeros per `.claude/rules/ocaml-patterns.md`.
5. **`?macro` absent in some callers.** Falls back to the scalar, which is
   today's behaviour — but it does mean a caller that forgets `~macro` silently
   gets the unconditioned width. The live path passes it
   (`weinstein_strategy_screening.ml:439`); noted in the `.mli`.

## 5. Acceptance criteria

- `dune build @fmt`, `dune build`, `dune runtest` each exit **0**, zero `^FAIL:`
  lines, read as a direct exit code (not through a pipe).
- Tests pin:
  1. **Default is a no-op** — with `default_config`'s empty map, the resolved
     buffer equals `config.initial_stop_buffer` for **all five** states, and an
     entry through `entries_from_candidates` installs the same stop as today.
  2. **A set map selects per state** — each of the five states resolves to its
     own value.
  3. **A missing slot falls back to the scalar** — a partially-populated map
     leaves the unset states on `initial_stop_buffer`.
  4. **Integration** — the same candidate entered under two different
     `breadth_state`s with a populated map installs two different stop levels
     (the wider state's stop is farther from entry).
  5. **Ordering agrees with the gate** — the `Demote_over_max` partition moves
     when the per-state buffer moves.
- Tests follow `.claude/rules/test-patterns.md`: one `assert_that` per value,
  composed with `all_of` / `field` / `elements_are`, Matchers library.
- PR body states the shape-(a) argument, cites R1/R2/R3 and W2, and reports the
  goldens grep for the new knob name (expected: zero matches — this PR *adds* a
  field and changes no default value, so `config-default-blast-radius.md`'s
  paired-run trigger should not fire).

## 6. Out of scope

- **Flipping anything on.** `initial_stop_buffer` stays `1.0`,
  `stop_update_cadence` stays `Daily`, no macro threshold moves, the map ships
  empty. R3: no default flips without a ledger ACCEPT.
- **The 12% / 8–10% / 4–6% map itself.** That is a *value* to be tested by item
  4's combined surface, not a default to be committed. It goes in the `.mli` as
  the documented first candidate map with its provenance, nothing more.
- **The admission half** ("Deteriorating / Bearish → no new entries") — that is
  item 2's gate, not the stop width.
- **`stop_update_cadence`** — a separate knob, deliberately not bundled.
- **The snapshot / weekly-report recompute paths** (`Stop_thread.seed`,
  `Stop_recompute.for_candidate` / `for_held_long`). They recompute stops for
  *already-held* positions from a `float`, have no macro result in scope, and
  the item's brief says "one read site" — the entry. Conditioning a held
  position's recomputed stop on *this week's* macro state would also change the
  trailing stop's meaning, which the state machine owns and this PR does not
  touch.
- **The exit side / `Audit_recorder` schema.** `breadth_state` is already
  recorded on the cascade event by #2685; nothing new is needed to attribute a
  stop width to a state after the fact.
