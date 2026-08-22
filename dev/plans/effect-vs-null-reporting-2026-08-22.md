# A2-1 — Automate effect-vs-null reporting

**Track:** `dev/status/arc-readiness.md` Axis 2(a).
**Date:** 2026-08-22.
**Branch:** `feat/arc-a2-1-effect-null`.

## 1. Context

Every verdict this program issues rests on a comparison of an **effect** (the
paired arm-to-arm gap) against a **null** (one arm's own salt-to-salt spread on
the same surface). That comparison — the "Rule 4 table" — is currently
**hand-assembled in prose in every writeup**. There is no code for it anywhere:

```
$ find trading/trading/backtest -name '*null*' -o -name '*effect*'
(nothing)
```

The only in-tree mention of a salt is `trading/trading/engine/test/test_market_state.ml`,
which pins `Price_path.seed_for_bar ~salt`. So the salted re-run mechanism exists;
the **reading of its output does not**.

The canonical hand-built instance is
`dev/experiments/rt-freshness-broad5y-2026-08-20/README.md` §"Rule 4 — paired gap
(rt − core) vs that metric's own null, all three salts". Its inputs are six
committed `results/s<N>-<arm>-actual.sexp` files of the form

```
((total_return_pct 8.72831266295053) (total_trades 258)
 (win_rate 27.906976744186046) (sharpe_ratio 0.18353512594502405)
 (max_drawdown_pct 32.8720113602886) ...)
```

and its output is a per-metric table of `gap | null | gap ÷ null | verdict`.

That writeup also records, from lived experience, the three ways the hand method
goes wrong — and all three are mechanisable:

1. **Scoring only the metrics that passed** ("the 26y record's repeated defect").
   Sortino and calmar were omitted from a table headed as complete.
2. **Importing a null across surfaces.** #2436 compared a broad-universe effect
   against an sp500 null and shipped a conclusion on it; that is what
   `.claude/rules/universe-discipline.md` exists to prevent.
3. **Quoting `max − min` of three draws as if it were the true spread** without
   the downward-bias caveat.

## 2. Approach

A pure statistics + rendering module, `Backtest_stats.Effect_vs_null`, alongside
`Deflated_sharpe` in `trading/trading/backtest/stats/lib/`. It sits beside — and
does not modify — `variant_ranking` (Pareto), `deflated_sharpe` (best-of-N), and
`fold_health_runner`. Those three answer *cross-variant selection*; this one
answers *is a single paired gap larger than its own surface's noise*, which none
of them does.

### The data model puts the context on the DRAW, not the arm

```ocaml
type context = { scale : string; universe : string }
type draw    = { salt : int; context : context; metrics : (string * float) list }
type arm     = { label : string; draws : draw list }
```

Attaching `context` to the **draw** rather than the arm is the load-bearing
choice. A null is assembled *from draws*; if context lived on the arm, a caller
could load salt 0 from a 26y run and salt 1 from a 5y run into one arm and build
a mixed-scale null that the type system waved through. With context on the draw,
the guard checks both levels:

- **within-arm** — every draw of an arm must share one context, so the *null
  itself* is never assembled across surfaces;
- **across-arm** — control and treatment contexts must be equal, so an effect is
  never scored against an imported null.

### The refusal is a hard error, not a warning

`analyze` returns `(t, refusal) result`; there is no `~force` flag, no warn-and-
continue path, and `render` accepts only a validated `t`, so **no code path
produces a report across contexts.** `refusal` is a variant (not a string) so
tests assert on the case, and `refusal_to_string` names **both** sides:

```
Effect_vs_null: refusing to compare across contexts.
  control "core" is scale "2000-01-01..2026-06-26" universe "universes/top-3000-2000.sexp"
  treatment "rangetop" is scale "2019-01-02..2023-12-29" universe "universes/top-3000-2019.sexp"
  differing on: scale, universe
```

Five refusal cases, each an error the hand method has actually made or could:

| case | why it refuses |
|---|---|
| `Cross_context` | the A2-1 hard requirement — effect vs a null from another scale/universe |
| `Inconsistent_arm` | the null itself assembled from mixed-context draws |
| `Too_few_draws` | a null needs ≥ 2 draws; one draw has no spread to report |
| `Salt_mismatch` | the comparison is **paired**; unpaired salts are not a gap |
| `Metric_missing` | a metric absent from one draw would otherwise be silently dropped — defect (1) |

### The verdict rule, stated once in code

For metric `m`, control values `c_s` and treatment values `t_s` over the shared
salt set:

- `null   = max_s c_s − min_s c_s` — the **control's own** spread, per metric.
- `gap_s  = t_s − c_s` — paired, per salt.
- `ratio_s = |gap_s| / null`.
- verdict:
  - `Null_degenerate` if `null <= 0` (nothing is interpretable against a zero null);
  - `Sign_flips` if the `gap_s` are not unanimous in sign (a zero gap is not a direction);
  - `Clears_null` if unanimous **and** every `ratio_s > 1`;
  - `Within_null` if unanimous but some `ratio_s <= 1`.

This reproduces the broad-5y table exactly: MaxDD `Clears_null` (14.9/1.4/19.3×),
ulcer `Within_null` (s0 at 0.88×), return / Sharpe / trades / holding days /
sortino / calmar `Sign_flips`, win rate `Sign_flips`.

`direction` (`Higher_is_better` / `Lower_is_better`) is carried per metric so the
report can say **which arm** a unanimous direction favours — a signed gap alone
does not, since a negative MaxDD gap is good and a negative return gap is bad.

### Defects (1) and (3) are closed by construction

- (1) — `analyze` takes the metric list explicitly and refuses with
  `Metric_missing` rather than silently skipping, so a table cannot quietly omit
  the metrics that failed.
- (3) — `render` emits the downward-bias caveat with the actual draw count in it,
  unconditionally. It is not an option.

### Rejected alternatives

- **Extend `variant_ranking`.** Different question (cross-variant Pareto
  selection vs single-pair noise-floor), different input type
  (`variant_stability` from walk-forward folds, not per-salt scenario summaries),
  and it would put a hard refusal inside a module whose current contract raises
  only on duplicate labels. Build alongside.
- **Warn instead of refuse on context mismatch.** Explicitly ruled out by A2-1
  and by the #2436 episode: a warning in a log is not read by the writeup that
  quotes the number.
- **Infer `context` from a spec file inside this module.** That couples a pure
  stats module to scenario-spec parsing. The caller supplies the identity; a
  follow-up wiring commit can derive it from the spec.
- **Ship a CLI in this PR.** Over the ≤500-LOC PR budget alongside lib + tests.
  Recorded as A2-1b follow-up; the library is the engine and `render` emits the
  finished markdown, so the wiring is thin.

## 3. Files to change

| file | note |
|---|---|
| `trading/trading/backtest/stats/lib/effect_vs_null.mli` | new — full API + doc comment per public value |
| `trading/trading/backtest/stats/lib/effect_vs_null.ml` | new — implementation |
| `trading/trading/backtest/stats/test/test_effect_vs_null.ml` | new — incl. the guard-mutation probes |
| `trading/trading/backtest/stats/test/dune` | add the test to `(names ...)` |
| `dev/status/arc-readiness.md` | tick A2-1, record what landed / what remains |
| `dev/plans/effect-vs-null-reporting-2026-08-22.md` | this file |

`stats/lib/dune` needs no change (`core` is already a dependency; no new libs).

**Not touched:** `weinstein_strategy.ml`, the stop machine, `simulator.ml`,
`variant_ranking`, `deflated_sharpe`, `fold_health_runner`, any golden, any
scenario spec.

## 4. Risks / unknowns

- **`scale` as a string is weakly typed.** A caller could pass `"26y"` in one
  draw and `"2000-01-01..2026-06-26"` in another and the guard would fire
  (correctly, if noisily) — or pass `"26y"` in both and hide a real difference.
  The module cannot verify a label it did not derive. Mitigated by documenting
  the canonical form (`period` and `universe_path` verbatim from the spec) in the
  `.mli`, and by making the refusal message print both values so a spurious
  mismatch is diagnosable in one read. A structured `context` derived from the
  spec is the follow-up (A2-1b), not this PR.
- **`max − min` is a biased null estimator.** Known and accepted — it is what
  every existing writeup uses, so matching it keeps the tool comparable with the
  record. Handled by emitting the caveat rather than by changing the estimator.
  A richer estimator would make this PR's output incomparable with the committed
  tables it is meant to replace.
- **Guard rot.** A prior harness suite here passed exit 0 with its guard deleted.
  Mitigated by mutation-testing: physically remove the guard, confirm the suite
  goes RED, restore. Reported in the session return, not just asserted.
- **Concurrent-load flakes** (`test_csv_snapshot_builder_cleanup`,
  `record_qc_audit_test`) may fire in a full `dune runtest`. Re-run in isolation
  before concluding.

## 5. Acceptance criteria

1. `analyze` **refuses** (returns `Error`, never a warning) when control and
   treatment contexts differ on `scale`, on `universe`, or on both; and when a
   single arm's own draws mix contexts.
2. The refusal message names **both** sides and which field(s) differ.
3. Deleting the guard from `effect_vs_null.ml` turns `dune runtest` RED —
   demonstrated by actually doing it, not by inspection.
4. A positive control passes: matching contexts produce `Ok`, so the guard cannot
   satisfy the suite by refusing everything.
5. `analyze` reproduces the committed broad-5y Rule-4 table on that experiment's
   six real `actual.sexp` values, to the precision quoted there.
6. Every public value in `effect_vs_null.mli` has a doc comment; no function
   exceeds 50 lines.
7. `dune build @fmt && dune build && dune runtest` exits **0**.
8. No golden moves; no strategy/simulation file is touched.

## 6. Out of scope

- The CLI / `scenario_runner` wiring that would emit the table from a run
  directory (A2-1b follow-up).
- Deriving `context` automatically from a scenario spec.
- Any change to the null **estimator** (bootstrap, k-of-n, variance-based).
- Any strategy-behaviour change, config field, or golden re-pin.
- Retro-fitting existing writeups to the tool's output.
