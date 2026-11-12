# Experiment flag discipline

Every new strategy mechanism lands behind a **default-off** config flag
(or a value defaulting to the no-op), becomes an **experiment axis** the
day it lands, and is **not wired into the default config** until it has
an **ACCEPT verdict in the experiment ledger**.

This codifies de-facto practice (E2 segmentation, the stage3 exit-margin
knob in #1362) so it is checkable. It is Gap E of the systematic
experiment-platform program (`dev/plans/experiment-platform-2026-05-29.md`).

## The three rules

1. **Default-off on merge.** A new mechanism's flag (e.g.
   `enable_laggard_rotation : bool [@sexp.default false]`) or its no-op
   value (e.g. `stage3_exit_margin_pct : float [@sexp.default 0.0]`)
   must default to the behaviour the system had *before* the mechanism
   existed. Merging the mechanism changes no backtest result until a
   spec explicitly flips the flag. Backward-compat is preserved on
   merge, always.

2. **An axis the day it lands.** The mechanism is only useful if it is
   searchable. The same PR (or its immediate follow-up) that adds the
   flag should make it expressible as a `Variant_matrix` axis — i.e.
   the flag is a real `Weinstein_strategy.config` field that
   `Overlay_validator.apply_overrides` resolves, so
   `((flag <name>) (values (true false)))` expands and validates.
   (`Variant_matrix` lives at
   `trading/trading/backtest/walk_forward/lib/variant_matrix.mli`.)

3. **No default-on without an ACCEPT.** A mechanism is wired into the
   default config (flipped on by default, or its no-op value changed)
   **only after** it earns an ACCEPT verdict in the experiment ledger —
   i.e. it survived walk-forward CV with proper best-of-N correction
   (Deflated Sharpe), not a single-window win. Until then it stays
   default-off and lives as an axis.

## Rule 4 — retirement (the graveyard)

4. **Terminal REJECT marked do-not-revive → REMOVE.** A mechanism whose
   ledger verdict is a terminal REJECT explicitly marked do-not-revive
   (in the ledger entry, its writeup, or its `project_*` memory) is
   **deleted outright** — config field, code paths, tests, and
   docstrings — once it has sat unused for **3 sessions** after the
   verdict. "Unused" means: not referenced by any live scenario spec,
   preset, golden config, or in-flight experiment plan. The ledger
   entry (plus its memory / writeup) remains the durable record of
   what was tried and why it failed — deletion loses nothing.

Why 3 sessions: long enough that the post-verdict session (which may
still run a follow-up screen against the flag) and its immediate
successors have passed; short enough that dead docstrings don't
accumulate. Rejected mechanisms otherwise pile up forever as
default-off flags + docstrings + dead code paths + tests, diluting the
context every reader (human or agent) must wade through —
`weinstein_strategy_config.mli` reached ~1,450 lines by 2026-08-09,
much of it dead-mechanism docstrings. Rules 1–3 make landing safe;
Rule 4 makes leaving safe.

**Deletion is safe by construction.** A never-promoted flag defaults
to the no-op (R1), so the default config path is bit-identical with
the flag removed. Goldens unchanged + the full `dune build && dune
runtest` gates are the proof — a removal PR that moves any golden is
not a retirement, it's a behaviour change: stop and re-scope.

**Two REJECT shapes — only one retires:**

- **REJECT-do-not-revive.** The mechanism failed across every tested
  context and the record says do not revive (e.g. early-admission
  after the 27y deep-grid reversal). → **Remove.**
- **REJECT-as-default-but-legitimate-axis.** The mechanism lost as a
  *default* but remains a coherent regime-dependent or preset-scoped
  dial (e.g. a breadth-preset knob, or a screen blocked on data
  rather than rejected). → **Keep, default-off**, per Rules 1–2.

A REJECT with neither classification is **not** retirement-eligible —
record the classification first (ledger amendment or memory), don't
guess it at removal time.

**Removal PR mechanics:**

- Full three gates (CI + qc-structural + qc-behavioral) — removal PRs
  touch code, never docs-only.
- One mechanism per commit (flag + code + tests together), so each
  deletion is independently reviewable and revertable.
- PR body cites the terminal ledger REJECT entry (path under
  `dev/experiments/_ledger/`) and where do-not-revive is recorded.
- Goldens green / bit-identical = proof of the no-op claim.
- The retirement worklist is the flag inventory
  (`dev/notes/mechanism-flag-inventory-*.md`, newest wins).

Out of scope for Rule 4: retiring one *value* of a promoted knob, and
removing plumbing shared with a live mechanism — both are refactors,
not retirements, and need their own review.

## Why

The 2026-05-29 hysteresis episode and the 2026-05-13 continuation
combined-axis rejection both came from promoting a mechanism on a
single-window win that did not generalise. The discipline forces every
mechanism through the same gate: land safe (default-off), search the
surface (axis), promote only on a ledger-backed ACCEPT.

It also keeps `main` always shippable — no half-wired mechanism ever
changes live/backtest behaviour silently, because the default is the
pre-existing no-op.

## What QC can check

For a PR that adds a strategy mechanism:

- **R1 — default-off.** The new `config` field carries a
  `[@sexp.default <no-op>]` and the no-op equals the prior behaviour.
  FAIL if a new mechanism is on by default with no ledger ACCEPT cited.
- **R2 — searchable.** The flag/knob is a real `Weinstein_strategy.config`
  field (not a hardcoded constant), so it routes through
  `Overlay_validator` and can be an axis. FAIL if the mechanism is
  gated by anything other than a config field.
- **R3 — promotion needs a verdict.** A PR that flips a default
  (default-off → default-on, or changes a no-op default value) must
  cite the ledger ACCEPT entry that justifies it. FAIL otherwise.

For a PR that removes a strategy mechanism (Rule 4):

- **R4 — retirement eligibility.** The PR body cites (a) a terminal
  ledger REJECT entry under `dev/experiments/_ledger/`, (b) where the
  do-not-revive classification is recorded, and (c) evidence of no
  live references (grep of scenario specs / presets / plans for the
  flag name comes back empty outside the removal diff). FAIL if any
  of the three is missing, or if the record classifies the mechanism
  as a keep-as-axis REJECT.
- **R5 — pure deletion, no semantic drift.** The diff only removes:
  the config field with its `[@sexp.default <no-op>]`, the code paths
  gated on the non-default value, their tests, and their docstrings.
  Goldens are bit-identical and CI is green. FAIL if any golden
  changes, if the default path's behaviour is touched, or if the
  commit bundles more than one mechanism.

These are mechanical: grep the `config` record diff for the new field +
its `[@sexp.default ...]`; check the PR body for a ledger citation when
a default changes (R3) or a mechanism is deleted (R4).
