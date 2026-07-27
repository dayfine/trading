# Trailing-stop state machine persisted across weeks (weekly-snapshot 4c.b)

**Track:** weekly-snapshot · **Branch:** `feat/trailing-stop-state-machine`
**Spec:** `dev/plans/picks-phase-c-2026-07-27.md` §Phase C bullet 4
(`dev/status/weekly-snapshot.md` §Next Steps 4c.b).
**Domain authority:** `docs/design/weinstein-book-reference.md` §5.1 "Initial
Stop Placement" + §5.2 "Trailing Stop — Investor Method".

## 1. Context — what is wrong today

Phase A gave held positions a **recomputed** stop floor. Every week
`Held_position_row.enrich` calls `Stop_recompute.for_held_long`, which derives a
*fresh* support floor from the current bars at the *current* price, and the
report shows it side by side with the trader's working stop.

Two consequences:

1. **The report cannot describe the stop's history.** "This week's floor is
   $x" is a different statement from "the stop has ratcheted up through three
   correction cycles and now sits at $x". The recomputation is stateless, so
   the second sentence is unavailable.
2. **Nothing enforces the ratchet.** `Portfolio_edit.adjust --stop-price`
   accepts a *lowered* stop (PR #2117 deferred the policy here explicitly —
   `portfolio_edit.mli` says so in prose). Book §5.2 is unambiguous: the
   sell-stop moves up as the MA advances and is never moved against the
   position. A lowered stop is §5.4's "don't hold hoping it will come back",
   mechanised.

## 2. The key realisation — the state machine already exists

`Weinstein_stops` (`trading/trading/weinstein/stops/lib/`) is the full
Weinstein trailing-stop state machine, already used by the backtest/live
strategy:

- `stop_state = Initial | Trailing | Tightened` — an explicit OCaml variant
  with `[@@deriving sexp, eq, show]`, so it is already persistable.
- `stop_event = Stop_hit | Stop_raised | Entered_tightening | No_change`.
- `update ~config ~side ~state ~current_bar ~ma_value ~ma_direction ~stage`
  advances it one period, and is documented as never moving the stop against
  the position.

**So 4c.b does not write a state machine.** Writing a second one would be a
domain-logic fork — the exact failure mode `Stop_recompute` was created to fix
on the candidate side. 4c.b **persists** that machine's state per held position
and **threads** it week to week.

The work is therefore: a persisted record, a pure driver that folds
`Weinstein_stops.update` over the weeks since the state was last advanced, and
the ratchet policy on manual edits.

## 3. Approach

### 3.1 `Stop_track` (new, `snapshot/gen/lib/stop_track.{ml,mli}`)

The persisted per-position record plus the pure operations on it that need no
bars:

```ocaml
type t = {
  state   : Weinstein_stops.stop_state;  (* the machine's own state, verbatim *)
  updated : Date.t;   (* week-ending date the state was last advanced through *)
  raises  : int;      (* Stop_raised events since the track was seeded *)
}
[@@deriving sexp, eq, show]

val level  : t -> float                      (* the stop in force *)
val label  : t -> string                     (* "Trailing (2 raises)" *)
val ratchet : t -> to_:float -> t option     (* L2: None when to_ < level *)
```

`state` is stored **verbatim**, not re-modelled. A parallel hand-rolled mirror
of a three-constructor variant with six fields in one arm is a drift bug
waiting to happen, and the machine's own type is the only thing that can be fed
back into `Weinstein_stops.update` without a lossy conversion.

`ratchet` is the single way to move the *track's* level for **L2** — it returns
`None` for a target below the level in force, and otherwise returns the track
with the level raised *inside its existing constructor* (so `Trailing`'s
correction bookkeeping survives a manual raise). Both the manual-edit path
(§3.3) and the seeding path (§3.4) call it.

It is **not** the only monotonicity check in the subsystem, and the first draft
of this plan said otherwise. `ratchet` guards the *machine's* level;
`Portfolio_edit._check_stop_not_lowered` independently guards the *trader's*
`stop_price`, because that one has to emit a CLI error naming
`--allow-lower-stop` and has to be overridable by it — neither of which an
`option`-returning ratchet can express. Two numbers, two guards, one book rule;
each has its own test (`ratchet_refuses_a_lower_level`,
`adjust_rejects_lowered_stop`).

`raises` is what lets the report say "trailing up for N cycles" rather than
"the floor happens to be here" — the history the recomputed-floor design cannot
express.

### 3.2 `Live_portfolio.position.stop_state` (schema change)

```ocaml
type position = {
  … ;
  stop_state : Stop_track.t option; [@sexp.default None]
}
```

`[@sexp.default None]` is the backward-compatibility seam: every existing
`dev/weekly-picks/portfolio.sexp` (and the committed template) has no such
field and must keep loading. Pinned by a test that parses a **literal
pre-4c.b sexp string** — not a round-trip of the new type, which would not
exercise the default at all.

`stop_price` stays the trader's working stop and stays authoritative for the
report's "Stop" column. `stop_state` is the machine's view. They are kept in
step by §3.3 and §3.4; the two are not redundant, because the machine can only
propose and the trader's broker order is what is actually resting.

**Schema-drift obligation (`dev/status/cleanup.md` §Backlog).**
`Live_portfolio.header` is a hand-written `;`-comment block re-emitted verbatim
by `save`, with nothing tying it to `type position`. Adding a field without
updating it would actively worsen a known, filed defect. `header` is updated in
the **same commit** as the field, and the PR body calls this out.

### 3.3 `Portfolio_edit.adjust` — the ratchet policy (the deferred decision)

**Decision: `adjust --stop-price` rejects a stop below the one in force.**

- Authority: §5.2 ("Continue moving the sell-stop up as the MA advances";
  "the sell-stop was always kept below the MA") and §5.4 ("Don't hold hoping it
  will come back"). Lowering a stop converts a defined loss into an open-ended
  one — precisely the behaviour the stop exists to prevent.
- Signature gains `?allow_lower:bool` (default `false`); the CLI exposes it as
  `--allow-lower-stop`. The escape hatch exists because a *typo* is a real
  failure mode (recording `$16.80` for `$168.00` then being permanently unable
  to correct it downward would be worse than the rule it enforces), but it must
  be **explicit and deliberate**, and the refusal message names the flag.
- **Equal** is allowed (idempotent re-runs of the same command should not fail);
  only strictly-lower is refused.
- Interaction with `stop_state`, so the two cannot drift:
  - a raise ratchets the track's level up via `Stop_track.ratchet`;
  - a `--allow-lower-stop` lower **clears** the track (`None`). The machine's
    invariant was deliberately overridden, so its accumulated state is no
    longer a truthful description of the position; the holding falls back to
    the stateless recomputed floor rather than carrying a state the trader has
    contradicted.
  - `--trim-shares` does not touch the track (share count is not stop state).

**Clearing is one-way in this increment.** `Stop_thread.seed` is unwired (§8),
so nothing recreates a cleared track and the ratchet history is lost until
someone hand-writes a `stop_state` back into `portfolio.sexp`. The working stop
is unaffected and the report stays correct, only stateless — but an operator
reaching for `--allow-lower-stop` on a long-held position should know this. It
is documented in `portfolio_edit.mli` and in the `portfolio.sexp` header block
the trader actually reads. Wiring `seed` (4c.c) closes the trapdoor.

`record` still seeds `stop_state = None`: `Portfolio_edit` is pure and bar-free
by design, so seeding belongs where the bars are (§3.4) — which 4c.c wires.

### 3.4 `Stop_thread` (new, `snapshot/gen/lib/stop_thread.{ml,mli}`)

The pure driver. Bar **lists** in, no `Bar_reader`, no I/O — same shape as
`Rename_detector` (the caller owns loading).

```ocaml
type outcome =
  | Holding of Stop_track.t
  | Triggered of { track : Stop_track.t; week : Date.t;
                   close : float; stop_level : float }

val seed :
  stops_config:Weinstein_stops.config -> initial_stop_buffer:float ->
  entry_price:float -> working_stop:float ->
  daily_bars:Types.Daily_price.t list -> as_of:Date.t -> Stop_track.t

val advance :
  stops_config:Weinstein_stops.config -> stage_config:Stage.config ->
  weekly_bars:Types.Daily_price.t list -> prior:Stop_track.t -> outcome
```

**`seed`** (L1) computes the initial stop from real bar history via
`Weinstein_stops.compute_initial_stop_with_floor` — the prior correction low,
falling back to the fixed buffer only when no qualifying correction exists —
then ratchets to the trader's working stop if that is higher. Encodes
**INITIAL**: "below the base, not an arbitrary percentage".

**`advance`** folds `Weinstein_stops.update` over the weekly bars *strictly
after* `prior.updated`, threading state, counting `Stop_raised` events into
`raises`, and stopping at the first `Stop_hit` with `Triggered`. Per-week
`ma_value` / `ma_direction` / `stage` come from `Stage.classify` on the weekly
prefix ending at that week — the same three values the strategy feeds `update`,
derived the same way `_chained_prior_stage` already does it in the generator.
Idempotent: re-running with the same `as_of` advances zero weeks and returns
the input track unchanged (pinned).

**L3 — weekly close, not an intra-week touch.** `advance` runs `update` with
`{ stops_config with trigger_on_weekly_close = true }`. The bars it is fed are
*weekly* bars, so the config's default (`false`, an intra-bar low/high trigger,
kept for backtest golden stability) would fire on an intra-**week** wick. That
is exactly what L3 forbids. This is a selection of the documented trigger
semantics for this cadence, not a new threshold; it is pinned by a test whose
week pierces the stop intra-week and closes above it.

Transitions are `Weinstein_stops`': `Initial → Trailing → Tightened`, plus this
module's terminal `Triggered`, matched exhaustively.

### 3.5 Consumption — `Held_position_row.enrich`

A held position **with** a track reports the machine's stop as
`recommended_stop`; a position **without** one keeps today's
`Stop_recompute.for_held_long` recomputation, byte-identical. This is the
back-compat seam at the report boundary and needs no schema change and no
renderer change, so the existing renderer contracts and their tests are
untouched.

## 4. Files to change

New:
- `trading/trading/weinstein/snapshot/gen/lib/stop_track.{ml,mli}`
- `trading/trading/weinstein/snapshot/gen/lib/stop_thread.{ml,mli}`
- `trading/trading/weinstein/snapshot/gen/test/test_stop_track.ml`
- `trading/trading/weinstein/snapshot/gen/test/test_stop_thread.ml`

Modified:
- `…/gen/lib/live_portfolio.{ml,mli}` — `stop_state` field + `header`
- `…/gen/lib/portfolio_edit.{ml,mli}` — L2 ratchet, `?allow_lower`
- `…/gen/lib/held_position_row.{ml,mli}` — consume the track
- `…/gen/bin/record_fill.ml` — `--allow-lower-stop`
- `…/gen/test/{dune,test_portfolio_edit.ml,test_live_portfolio.ml}`
- `dev/status/weekly-snapshot.md`, this plan

Explicitly untouched: `trading/trading/portfolio/`, `orders/`, `position/`,
`strategy/`, `engine/` (CLAUDE.md: propose, don't execute); `weinstein/stops/`
(the state machine is correct — this drives it, it does not modify it);
`weekly_snapshot.{ml,mli}` (no snapshot-schema change); both renderers;
`dev/status/_index.md`.

## 5. Risks / unknowns

1. **Persisting an analysis type into a human-editable file.** `stop_state` is
   verbose sexp a human would not hand-write. Mitigated: the field is optional,
   the CLI and generator own it, and `header` says so. The alternative (a
   hand-rolled mirror) trades verbosity for a drift bug, which is worse.
2. **`Stage.classify` per weekly prefix is O(n²) over the holding window.**
   Bounded: it runs once at seed time over one position's history, then one
   week per subsequent run, for a handful of held positions. Not a hot path.
3. **A documented guard with no test** — the failure mode QC caught on #2117
   three times. Mitigated by §6: every guard gets a named test and a mutation.
4. **Silent behaviour change for held rows.** Mitigated by the §3.5 fallback:
   `stop_state = None` (every portfolio on disk today) takes the existing path
   unchanged.

## 6. Evidence standard

For every guard claimed in an `.mli`, name the test that goes **red** when the
guard is deleted, and verify it by actually deleting it. Mutations must be
**binding-preserving** — a mutation that leaves a value unused fails the
*build*, which is a false red (the #2117 author's own correction). The table
goes in the PR body. Non-negotiable rows:

- `Stop_track.ratchet` monotonicity removed → red.
- `Portfolio_edit.adjust` lowered-stop refusal removed → red.
- `?allow_lower:true` failing to clear the track → red.
- `trigger_on_weekly_close = true` reverted to the config default → red (the
  intra-week-wick test).
- `seed`'s ratchet-to-working-stop removed → red.
- `advance` not stopping at `Stop_hit` → red.
- `Held_position_row` ignoring the track → red.
- A literal pre-4c.b portfolio sexp string fails to parse → red.
- **`_step` freezing `stop_level` while the arm, the event and `raises` advance
  normally → red.** Added after rework 1: this row was missing, and without it
  the suite could not tell a trailing stop from a frozen one. Only
  `advance_raises_the_stop_level_on_every_cycle` catches it.

## 7. Acceptance criteria

- [ ] `stop_state` persists per position, round-trips, and a **literal
      pre-4c.b sexp** (no `stop_state` field) still loads.
- [ ] `Live_portfolio.header` documents the new field, in the same commit.
- [ ] `adjust --stop-price` refuses a lowered stop; `--allow-lower-stop`
      overrides it and clears the track. Both pinned.
- [ ] `Stop_thread.seed` places the initial stop off the support floor (L1),
      never below the trader's working stop.
- [ ] `Stop_thread.advance` threads `Weinstein_stops.update` week by week,
      counts raises, is idempotent, triggers on a weekly **close** (L3), and
      terminates at `Stop_hit` (L4).
- [ ] Held rows with a track report the machine's stop; rows without one are
      byte-identical to today.
- [ ] Every new module has an `.mli`; no file over the 300-line soft limit; no
      limit bumped, no `@large-module` marker, no linter exception.
- [ ] `dune build @fmt && dune build && dune runtest` exit 0.
- [ ] Mutation table in the PR body; any deliberately-unpinned line disclosed.

## 8. Out of scope (follow-up 4c.c)

Deliberately deferred to keep this PR inside the ≤500-LOC sizing rule, per the
dispatch's own instruction ("land the state machine + persistence first and
thread it into the report in a follow-up increment; say so in the plan"):

- **Write-back**: a `generate_weekly_snapshot --update-stops` flag that saves
  the advanced portfolio after a run. Until it lands, `advance` runs read-only
  inside the report and a track is only created by hand-editing
  `portfolio.sexp` — `record` deliberately seeds `None` (§3.3), and `adjust`
  only ratchets a track that already exists.
- **Seeding `Stop_thread.seed` from the generator.** `seed` ships here, tested,
  with **no production caller** — it is the piece the write-back increment
  calls, and calling it today would build a track nothing persists. It is the
  same 4c.c increment as the write-back and is called out separately only
  because the doc-comments now have to say so explicitly (§9.5).
- **Report surfacing of the history**: a `held_position.stop_state_label`
  schema field rendering `Trailing (2 raises)` in the Markdown and HTML
  reports. This PR changes what the *stop value* means; the label change
  touches two renderers and their goldens and is a clean separate increment.
- Short-side held positions (the live held book is long-only today).
- Any change to `Weinstein_stops` itself, to the snapshot schema, or to the
  backtest path.

## 9. Deviations from the plan as written

Recorded rather than revised silently.

1. **`Stop_track` gained `state_name`, and `with_level` stayed private.** The
   §3.1 sketch listed only `level` / `label` / `ratchet`. `state_name` is
   needed by `label`, by `Held_position_row`, and by the tests that assert the
   arm without depending on the payload; `with_level` is an implementation
   detail of `ratchet` and is not exported, so `ratchet` remains the only way
   to change a stop level and therefore the only place the never-lower rule can
   be bypassed.
2. **`advance` reads `Weinstein_strategy.config.stage_config`.** §3.4 said the
   per-week stage comes from `Stage.classify` "the way the generator already
   derives a chained stage"; the generator uses
   `Stock_analysis.default_config.stage`, but the strategy config carries a
   `stage_config` field directly, which is the more honest source for a
   held-position pass and is what `Held_position_row` threads through.
3. **§8's write-back note was inaccurate as first written** and has been
   corrected in place: `record_fill` cannot create a track (`record` seeds
   `None` by design, §3.3), so until the write-back flag lands the only
   producer is a hand edit. This makes the follow-up more clearly load-bearing
   than the plan first implied.
4. **`Held_position_row` surfaces the state through `status`, not a new schema
   field.** §3.5 said the track would be reported as `recommended_stop`; it is,
   and additionally the free-form `status` string now carries
   `Stop_track.label` (or the STOP HIT line). This was not in the plan and is
   strictly more than it promised — but it is the cheapest way to get the
   *history* into both reports, and it needs no `current_schema_version` bump
   and no renderer change, so the §8 deferral of the schema-field label still
   holds.

### Rework 1 (QC behavioral, 2026-07-27)

5. **Four texts asserted a wiring that does not exist, and are now true.**
   `Stop_thread.seed` has no production caller, but the `portfolio.sexp`
   header block told the trader "the tooling writes and updates it",
   `live_portfolio.mli` said to "let `Stop_thread.seed` derive it",
   `stop_thread.mli`'s module doc said `Stop_track` "persists the result" and
   its `seed` doc read as a live step, and `portfolio_edit.{ml,mli}` said a
   cleared track means "the next advance re-seeds from bars". All five now say
   what the code does: nothing writes the field, `advance` is the only wired
   entry point, and an un-threaded holding falls back to `Stop_recompute`.
   Chosen over wiring `seed` because a caller with no persistence would build a
   track that is discarded — that is 4c.c's job, not a rework's. The header
   correction is pinned by `header_does_not_promise_an_unwired_write_back`, so
   the operator-facing text cannot silently regress.
6. **`--allow-lower-stop` is a one-way trapdoor and now says so** (§3.3).
   Documented, not redesigned: closing it properly means wiring `seed`, which
   is 4c.c.
7. **The stop-level *rise* is now pinned across three cycles.** Every prior
   `advance` test asserted the bookkeeping around the level — the arm, the
   `raises` count, the week — so freezing `stop_level` while letting all of
   that advance left the whole suite green, and the report would have printed
   `Trailing (2 raises, …)` beside a stop that never moved. §5's mutation list
   did not cover it. `advance_raises_the_stop_level_on_every_cycle` replays
   book §5.2's three-cycle shape (its points E, G, I) one cycle at a time and
   counts strict rises in the level itself; it fails under that freeze and is
   the only test that does.
