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

`Backtest_stats` + `Walk_forward.Variant_ranking` surface (PR-3):
- `Backtest_stats.Normal_dist` — `cdf` / `inv_cdf` (Gaussian CDF and
  quantile via `Owl.Maths.erf` / `erfinv`).
- `Backtest_stats.Deflated_sharpe` — `psr` (Probabilistic Sharpe),
  `expected_max_sharpe` (best-of-N benchmark SR*), `deflated_sharpe`
  (PSR at that benchmark), plus `skewness` / `kurtosis` population
  moment helpers. Pure; shared with the BO tuner (new `backtest_stats`
  lib, deps `core` / `owl` only — no heavy `backtest` coupling).
- `Walk_forward.Variant_ranking` — `dominates` (Pareto over Sharpe up /
  Calmar up / MaxDD% down), `rank` (frontier + `dominated_by` per
  variant over `Walk_forward_types.variant_stability`), `render`
  (deterministic markdown frontier + per-variant table with a Deflated
  Sharpe column passed in by the caller).

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

### Gap C — Matrix-aware ranking + Deflated Sharpe (PR-3)
- [x] **`Backtest_stats.Deflated_sharpe`** + **`Backtest_stats.Normal_dist`**
  — pure Bailey & López de Prado closed form. New `backtest_stats` lib at
  `trading/trading/backtest/stats/lib/{deflated_sharpe,normal_dist}.{ml,mli}`
  (deps `core` / `owl` only, so both this matrix path and the BO tuner can
  reuse it without pulling the heavy `backtest` lib). No prior DSR existed
  in-repo (grep clean); `Normal_dist` wraps `Owl.Maths.erf` / `erfinv` for
  Φ / Φ⁻¹. Pinned reference values: PSR(SR̂=0.5, T=24, normal, SR*=0)=
  0.9881134547; PSR(…SR*=0.3)=0.8170846532; PSR(SR̂=0.8, T=36, γ3=−0.5,
  γ4=4, SR*=0.2)=0.9951851034; expected_max_sharpe(N=12, var=0.04)=
  0.3329622776; end-to-end DSR(obs=0.5, folds=[1..5], N=12, var=0.04)=
  0.6281656469. Φ(1.96)≈0.975, Φ⁻¹(0.975)≈1.96. Degenerate guards
  (n_obs<2, n_trials<2, zero variance) raise `Invalid_argument` and are
  pinned.
- [x] **`Walk_forward.Variant_ranking`** — Pareto dominance over (Sharpe ↑,
  Calmar ↑, MaxDD% ↓) reusing the emitted
  `Walk_forward_types.variant_stability`. `rank` returns per-variant
  `{ label; stability; on_frontier; dominated_by }` + the frontier set;
  `render` is a deterministic markdown frontier + per-variant table with a
  Deflated-Sharpe column (DSR passed in by the caller, so the ranking lib
  stays decoupled from `backtest_stats`). At
  `trading/trading/backtest/walk_forward/lib/variant_ranking.{ml,mli}`.

Verify: `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune build && dune exec trading/backtest/stats/test/test_normal_dist.exe && dune exec trading/backtest/stats/test/test_deflated_sharpe.exe && dune exec trading/backtest/walk_forward/test/test_variant_ranking.exe'`
(normal_dist 5/5; deflated_sharpe 14/14; variant_ranking 6/6).

### Gap F — Gap-closing experimentation skill
- [x] **`.claude/skills/experiment-gap-closing/SKILL.md`** — invocable skill
  encoding the full loop: name the gap → hypothesis→axes (prefer existing
  flags; new mechanism behind a default-off flag first) → check the ledger
  (skip rejected config-hashes) → generate the matrix (`Variant_matrix`) →
  run WF-CV (`sweep-hygiene`) → rank (`Variant_ranking` Pareto +
  `Deflated_sharpe` best-of-N deflation) → verdict + `Experiment_ledger`
  append → promote winner (`promote_config.sh`) → memory. Bakes in the two
  hard lessons (autopsy = labeller-not-recommender; test a surface, not a
  point) and the continuous-vs-discrete reframe.

### Gap-closing experiments — landed mechanisms (default-off, awaiting sweep)

- [x] **`late_stage2_admission` Step 1 — dual-MA early Stage-2 admission**
  (PR #1378, branch `feat/weinstein/early-admission`). Adds default-off
  `Stage.config.early_admission_ma_period : int option` (`[@sexp.default
  None]`). When `None` the classifier is bit-identical to today (all 26
  pre-existing stage golden tests stay green); when `Some fast_p` a fast
  confirmation SMA of the most recent `fast_p` closes (read self-contained
  from `get_close`) can promote a would-be Stage1 to Stage2 or prevent a
  demotion of a prior Stage2 while the fast MA is rising and price is above
  it — never blocks a slow-MA Stage2, never forces an exit, hands back on
  rollover. Mechanism extracted into a sibling `Early_admission` module
  (`compute` + `apply`) to keep `stage.ml` under the file-length limit.
  Flag-discipline R1/R2 satisfied; **R3 pending** — not wired into any
  default config, awaits a surface-sweep ACCEPT in the ledger. Targets the
  autopsy failure mode where the slow 30-week MA admits Stage 2 months late
  off bear bottoms (Mar 2009 / Mar 2020). Verify: `dune runtest
  analysis/weinstein/stage/` → 33 tests OK.

## Platform usage log

- **2026-05-30 — exit-timing surface (#1375): REJECT.** First real use;
  whole exit-timing knob surface rejected on the fold distribution
  (`dev/experiments/_ledger/2026-05-30-exit-timing-surface.sexp`).
- **2026-05-30 — early-admission surface: INCONCLUSIVE.** First
  entry-timing mechanism (PR #1378), swept
  `stage_config.early_admission_ma_period ∈ {5,7,10,13}` vs `None`
  baseline over the nominal 31-fold 2010-2026 geometry. The within-run
  signal was strongly positive (all cells beat baseline on Sharpe; best
  cell ma=10 Sharpe 0.414 vs 0.251, DSR 0.9987), **but the run is
  compromised by a data-coverage defect** and cannot be promoted. See
  `dev/notes/early-admission-surface-2026-05-30.md` +
  `dev/experiments/_ledger/2026-05-30-early-admission-surface.sexp`.

> **⚠ Infrastructure defect surfaced (affects ALL `sp500-2010-2026`
> experiments).** The index golden `GSPC.INDX` covers only 2017-01-03→
> 2026-04-09 and NYSE A/D breadth only 2017-2020. With no index data
> before 2017 the Weinstein macro gate blocks all buys in 2010-2016, so
> every walk-forward run on this scenario produces ~13 zero-trade folds
> and effectively tests **2017-2026, not 2010-2026** — including the
> exit-timing (#1375) and hysteresis (#1366) verdicts. **Fix before the
> next surface sweep:** extend the index + breadth goldens back to ~2009
> (ops-data EODHD fetch), then re-run.

## Next Steps

1. **Repair the index/breadth golden coverage** (P0 for any further
   surface sweep on `sp500-2010-2026`) — extend `GSPC.INDX` + NYSE A/D
   breadth back to ~2009 so the macro gate runs across the full window.
   Then re-run the early-admission surface on the true distribution to
   settle its INCONCLUSIVE verdict (the 2017-2026 signal is promising).
2. **Wire DSR into the BO tuner** — the `backtest_stats` lib is shared;
   the BO program can adopt `Deflated_sharpe` for its own best-of-N
   correction (deferred to that program).
3. [x] **Commit a `rank-variants` CLI** — landed via
   `trading/trading/backtest/walk_forward/bin/rank_variants.{ml}` (+
   `test/test_rank_variants.ml`). Pure consumer of `aggregate.sexp`
   (+ optional `fold_actuals.sexp` for DSR), computes per-variant
   Deflated Sharpe via `Backtest_stats.Deflated_sharpe`, renders via
   `Walk_forward.Variant_ranking.{rank,render}`. Replaces the ad-hoc
   throwaway exe used in #1375 / #1379 verdicts; future rankings are
   reproducible. Verify:
   `dune exec trading/backtest/walk_forward/bin/rank_variants.exe -- --aggregate <path> [--fold-actuals <path>] [--baseline-label <label>] [--output <path>]`
   and `dune runtest trading/backtest/walk_forward/test/` (5/5 new tests).

## Out of scope (PR-3)

- The skill (Gap F).
- Wiring `Variant_ranking` / `Deflated_sharpe` into the WF runner or the
  BO tuner (this PR ships the pure libs + tests only).
- Any change to the WF runner / gate / report (reused unchanged).
- Promotion automation (stays manual, ledger-backed).
