# Status: experiment-platform

## Last updated: 2026-05-30

## Status
IN_PROGRESS

## Notes

Track created 2026-05-29 by `feat-backtest` per the systematic
experiment-platform program plan
(`dev/plans/experiment-platform-2026-05-29.md`, PR #1368). The program
makes discrete feature/mechanism exploration systematic: hypotheses
become variant matrices, evaluated by walk-forward CV, ranked with
proper statistics (Deflated Sharpe), recorded in an append-only ledger.

Filed after the 2026-05-29 stage3-hysteresis WF-CV rejection
(`dev/notes/stage3-hysteresis-walkforward-cv-2026-05-29.md`): we tested
one point, never a surface. PR-1 lets a spec declare axes that expand
into the `variants` list the WF runner already consumes.

Sequencing (per plan §Sequencing):
- **PR-1** — Variant-matrix generator (Gap A) + flag-discipline rule (Gap E).
- PR-2 — Experiment ledger + retroactive seed (Gap D).
- PR-3 — Matrix ranking + Deflated Sharpe (Gap C; shares DSR w/ BO program).
- Skill — Experimentation gap-closing skill (Gap F).

## Interface stable
NO

The PR-1 `Walk_forward.Variant_matrix` surface below is the stable part;
the program-level interface (ledger schema, ranking output) is still
forming across PR-2/PR-3, so the track is NO until those land.

`Walk_forward.Variant_matrix` surface (PR-1):
- `type axis = Key of { path; values } | Flag of { name; values }`
  (on-disk record shape: `((key (a b)) (values (...)))` /
  `((flag name) (values (...)))`).
- `type expansion = Cartesian | Sampled of { n; seed }`.
- `type t = { axes; expansion }`.
- `val expand : t -> Walk_forward_runner.variant list` — validates every
  generated override against the canonical default config at expansion
  time (raises `Failure` on a typo'd key, the 2026-05-12 81-cell guard).

`Walk_forward.Spec.load` now accepts an optional `axes` block; when
present it prepends the auto-baseline cell then appends the expanded
matrix (explicit `variants`, if any, kept first). De-dups by label.
Axes-absent specs parse 100% backward-compatibly.

## Work

### Gap A — Variant-matrix generator (PR-1)
- [x] **`Walk_forward.Variant_matrix`** — `axis` / `expansion` / `t`
  types + `expand`, with expansion-time `Overlay_validator` validation.
  Surface at
  `trading/trading/backtest/walk_forward/lib/variant_matrix.{ml,mli}`.
- [x] **`Walk_forward.Spec` axes wiring** — optional `axes` field;
  `load` expands + prepends auto-baseline + de-dups by label; backward-
  compatible with hand-written `variants`. At
  `trading/trading/backtest/walk_forward/lib/spec.{ml,mli}`.
- [x] **Flag-discipline rule (Gap E)** — `.claude/rules/experiment-flag-discipline.md`.

Verify: `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune build && dune exec backtest/walk_forward/test/test_variant_matrix.exe && dune exec backtest/walk_forward/test/test_spec.exe'`
(variant_matrix 10/10; spec 19/19 = 15 legacy + 4 axes-on-load).

### Gap B — Loud override validation
- [x] Already shipped (#1069) and reused at expansion time by PR-1.

### Gap D — Experiment ledger (PR-2)
- [x] **`Experiment_ledger`** — append-only per-experiment sexp +
  machine-readable index, with effective-config-hash dedup. New pure lib
  at `trading/trading/backtest/experiment_ledger/lib/experiment_ledger.{ml,mli}`
  (sibling to `walk_forward`; deps `core` / `backtest` /
  `weinstein_trading.strategy`). Types: `verdict` (`Accept`/`Reject`/
  `Inconclusive`), `fold_aggregate` (optional per variant), `variant_record`,
  `entry`, `index_row`. Functions: `config_hash` (the dedup key —
  applies overrides onto the canonical default config via
  `Overlay_validator.apply_overrides`, `sexp_of`s the effective config,
  `Sexp.to_string_mach` + MD5; so two logically-equal override blobs hash
  identically), `save_entry` (append-only, raises on overwrite),
  `load_entry`, `load_index`, `build_index`, `save_index`, `lookup`.
- [x] **Retroactive seed** under `dev/experiments/_ledger/`: full
  machine-aggregate entry for the stage3-hysteresis WF-CV rejection
  (`2026-05-29-stage3-hysteresis-wf-cv.sexp`, h1-m0 vs h2-m02, Reject);
  minimal seeds for continuation-combined-axis, M5.5 single-lever, and
  laggard-disable retraction. `index.sexp` regenerated from the entries.
  Verified hashes: empty-override = `236ef895…`, h2-m02 = `9dfc464e…`,
  continuation = `82ecc7b9…`.

Verify: `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune build && dune exec trading/backtest/experiment_ledger/test/test_experiment_ledger.exe'`
(9/9 tests: round-trip, config-hash equal/differ/stable, append-only raise,
build_index, lookup hit/miss, load_index round-trip).

## Next Steps

1. **PR-3 — Matrix ranking + Deflated Sharpe**: cross-variant best-of-N
   correction on top of `Fold_gate`; Pareto rank over (Sharpe, MaxDD,
   Calmar). Shares the DSR module with the BO program.
2. **Skill (Gap F)** — now unblocked (PR-1 + PR-2 give it the matrix
   generator and the ledger lookup); build after PR-3.
3. **First real use** — re-attack the autopsy missed-gain (modes 1+2) as
   a surface: hysteresis_weeks grid × exit_margin grid × relevant
   `enable_*` flags through WF-CV, ranked with DSR.

## Out of scope (PR-2)

- DSR ranking (PR-3), the skill (Gap F).
- Any change to the WF runner / gate / report (reused unchanged).
- Ledger-consuming dedup wiring into the WF runner / skill (PR-3 + skill).
- Promotion automation (stays manual, ledger-backed).
