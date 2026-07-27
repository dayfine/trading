# `record_fill` CLI — edit `portfolio.sexp` without hand-editing sexp (2026-07-27)

**Track:** weekly-snapshot · **Branch:** `feat/record-fill-cli`
**Spec:** `dev/plans/picks-phase-c-2026-07-27.md` §Phase C bullet 3 (pointer only);
`dev/plans/weekly-picks-execution-protocol-2026-07-24.md` §Phase C bullet 3.

## 1. Context

`dev/weekly-picks/portfolio.sexp` (schema: `Live_portfolio.t`, defined in
`trading/trading/weinstein/snapshot/gen/lib/live_portfolio.{ml,mli}`) is the
human-editable live-holdings file the weekly generator reads via
`--portfolio`. Today the only way to update it is to hand-edit the sexp:
append a `position` record and manually debit `cash` for a new fill, delete a
`position` and manually credit `cash` for a close, or hand-edit `stop_price`
for a trailing-stop update. `Live_portfolio` currently only exposes `load`
(read); there is no `save` (write).

This item (4c.a) builds a CLI that performs those edits programmatically so
`cash` cannot drift out of sync with the position list — the entire point of
not hand-editing sexp.

Item 4c.b (the trailing-stop *state machine*, threaded automatically across
weeks) is a separate, later PR. This CLI does let the user manually update a
`stop_price` on an existing position (that's just editing a field the file
already carries), which is not the same as automating the trail.

## 2. Approach

### 2.1 Three operations, not one

The spec says "record a new fill... and adjust/close an existing one." A
single fill-recorder is not enough for real usage: a trader also needs to
(a) fully exit a position (crediting cash), and (b) update a stop or trim
shares on a position they're still holding, without closing it. Chosen: three
subcommands under one `record_fill` binary, backed by three pure functions in
a new library module `Portfolio_edit`:

- **`record`** — append a brand-new position. Fails if the symbol is already
  held (see idempotency below). Debits `cash -= shares * entry_price`; fails
  if that would take `cash` negative.
- **`close`** — fully exit an existing position at a given exit price.
  Credits `cash += shares_held * exit_price`; removes the position. This is
  the *only* operation that removes a symbol from the book — `adjust` never
  fully closes a position (see below), so there is exactly one code path that
  can zero out a holding, which is easier to reason about and test.
- **`adjust`** — modify shares and/or stop on an existing, still-open
  position, without closing it:
  - `--stop-price` alone: update the trailing stop, no cash movement. This is
    the common weekly case (raise the stop, no shares change).
  - `--trim-shares N --trim-price P` (must be given together): sell `N` of
    the held shares at `P`, crediting `cash += N * P` and reducing the
    position's `shares` by `N`. Rejected if `N >= shares_held` (use `close`
    instead — keeps "did this fully exit?" a single yes/no decision made by
    one function, not two).
  - At least one of the two adjustment kinds must be given, or the call is
    rejected as a no-op.

Rejected alternative: a single `record_fill` command with a `--side
buy|sell` flag and let the shares delta imply record/trim/close. Rejected
because a signed-delta API conflates three genuinely different invariants
(new position must not already exist; trim must leave the position open;
close must remove it) into one function's branches, which is exactly the
kind of implicit-state design the plan-first trigger exists to catch. Three
named operations make each invariant a one-line check in its own function
and a directly nameable test.

### 2.2 Idempotency policy

**`record` rejects a duplicate symbol outright** (case-normalized to
uppercase for both storage and comparison, so `aapl` and `AAPL` are the same
symbol). Recording the same fill twice — accidentally re-running the CLI, or
scripting it without checking prior state — cannot silently double a
position, because the second `record` call for an already-held symbol always
fails with a clear error ("AAPL already held; use `adjust` to change it or
`close` first").

This is deliberately **not** a weighted-average merge-on-duplicate policy.
Scaling into a position with multiple buys is a real Weinstein technique (the
book's ½-on-breakout / ½-on-pullback scale-in), but this system does not
currently size or track partial fills that way anywhere else in the
snapshot/portfolio code (`Live_portfolio.position` is one row per symbol,
`Trade_sizing` computes one full-size order), so adding weighted-average-merge
semantics here would invent portfolio behavior the rest of the system doesn't
share and can't test against. Reject-on-duplicate is the conservative,
correct-by-construction choice for "don't silently double a position" and
matches the existing one-row-per-symbol invariant. If scale-in support is
wanted later, it is a schema change to `position` (needs a lot list, not a
single `entry_price`), out of scope here.

`close` and `adjust` are naturally idempotent-safe in the opposite direction:
re-running `close` on a symbol that is no longer held fails with "not held"
rather than double-crediting cash; re-running `adjust --stop-price X` twice
is a no-op the second time (sets the same value) and is not rejected, since
setting the same stop twice is harmless (unlike doubling a position or
double-crediting cash) — no invariant is violated by an idempotent field
update.

### 2.3 `--as-of` is a required flag on every subcommand, not `Date.today`

`Portfolio_edit`'s three functions take `as_of:Date.t` as a required
argument, not read from the wall clock. The CLI likewise requires
`--as-of DATE` on every subcommand rather than defaulting to "now". This
keeps the library pure and deterministically testable (no hidden clock
read), matches the file's own existing convention ("as_of: the day you last
updated this file", already a manual field), and avoids introducing
wall-clock non-determinism into a codebase whose stated principle is "every
analysis function is pure, same input -> same output." The one-flag UX cost
is small next to that.

### 2.4 Preserving the file's header comment on rewrite

`portfolio.sexp`'s leading `;`-comment block documents the on-disk schema.
`Sexp.load_sexp` already ignores it on read (comments aren't part of the
sexp grammar), but a naive `Out_channel.write_all path
~data:(Sexp.to_string_hum (sexp_of_t t))` on write would silently drop it.
Chosen: `Live_portfolio.header : string` is the header text as a constant,
and the new `Live_portfolio.save t ~path` writes `header ^ "\n" ^
Sexp.to_string_hum (sexp_of_t t) ^ "\n"`. The header is preserved verbatim,
byte for byte, on every rewrite. (Its "100000.0 below is a placeholder" line
strictly speaking describes the *committed template*, not necessarily every
future value of `cash` — but the task instruction is to keep the header
intact, and rewriting user-facing prose describing the schema on every CLI
invocation is out of scope here.)

### 2.5 Validation asymmetry: `record` vs `adjust` on stop placement

`record` requires `stop_price < entry_price` (Weinstein's initial-stop rule:
the stop sits below the entry/base — `weinstein-book-reference.md` §5.1).
`adjust --stop-price` does **not** enforce `stop_price < entry_price`,
because a trailing stop legitimately rises above the original entry once a
position is in profit (a breakeven-plus stop) — enforcing the initial-stop
inequality on every adjustment would reject entirely correct trailing-stop
updates. `adjust` only requires `stop_price > 0.0`.

## 3. Files to change

New:
- `trading/trading/weinstein/snapshot/gen/lib/portfolio_edit.{ml,mli}` — the
  three pure functions.
- `trading/trading/weinstein/snapshot/gen/bin/record_fill.ml` — the CLI
  (`Command.group` with `record` / `close` / `adjust` subcommands, each with
  a `--dry-run` flag that prints the resulting sexp body instead of writing).
- `trading/trading/weinstein/snapshot/gen/test/test_portfolio_edit.ml`

Modified:
- `trading/trading/weinstein/snapshot/gen/lib/live_portfolio.{ml,mli}` — add
  `header : string` and `save : t -> path:string -> unit Or_error.t`.
- `trading/trading/weinstein/snapshot/gen/test/test_live_portfolio.ml` — add
  `save` / `header` round-trip tests.
- `trading/trading/weinstein/snapshot/gen/bin/dune` — new `record_fill`
  executable stanza.
- `trading/trading/weinstein/snapshot/gen/test/dune` — register
  `test_portfolio_edit`.
- `dev/status/weekly-snapshot.md` — mark 4c.a done.

Explicitly untouched: `weekly_snapshot_generator.ml`, `weekly_snapshot.mli`
(schema), any renderer, `generate_weekly_snapshot.ml` (no changes needed —
it already only *reads* `portfolio.sexp` via `Live_portfolio.load`).

## 4. Risks / unknowns

1. **Header staleness** — see §2.4; accepted, disclosed.
2. **Symbol case normalization** could surprise a user who expects literal
   preservation of a lowercase ticker; mitigated by uppercasing consistently
   and documenting it in `portfolio_edit.mli`.
3. **`dry-run` divergence from the real write path** — mitigated by having
   `-dry-run` call the exact same `Portfolio_edit` function and only branch
   at the final "write vs print" step, so there is no second code path to
   drift.

## 5. Acceptance criteria

- [ ] `Live_portfolio.save` round-trips (`load (save t) = Ok t`) and the
      written file's header matches `Live_portfolio.header` verbatim.
- [ ] `Portfolio_edit.record` / `close` / `adjust` each covered by tests for:
      the happy path, the specific invariant each enforces (duplicate
      symbol / insufficient cash / not-held / trim >= shares_held /
      no-op-adjust), and the cash arithmetic pinned numerically.
- [ ] Idempotency: a test that calls `record` twice with identical arguments
      and asserts the second call is `Error`, not a doubled position.
- [ ] `record_fill` CLI wires all three subcommands + `--dry-run`; smoke
      test or direct function test (CLI parsing itself is thin, so
      `Portfolio_edit` carries the real test weight per `ocaml-patterns.md`).
- [ ] `dune build @fmt && dune build && dune runtest` exit 0.
- [ ] Mutation evidence in the PR body: for each validation branch, name the
      test that goes RED when it's removed/inverted.

## 6. Out of scope

- The trailing-stop state machine threaded automatically across weeks (item
  4c.b, separate PR).
- Any change to the report renderers or `generate_weekly_snapshot.ml`
  selection/sizing/gating logic.
- Scale-in / multiple-lots-per-symbol support (§2.2).
- `dev/status/_index.md` — reconciled by the orchestrator, not this PR.
