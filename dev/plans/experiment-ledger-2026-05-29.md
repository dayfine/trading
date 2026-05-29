# Experiment ledger — PR-2 of the experiment platform (2026-05-29)

PR-2 of the systematic experiment-platform program
(`dev/plans/experiment-platform-2026-05-29.md` §"Gap D"). PR-1
(`Walk_forward.Variant_matrix` + `axes` on `Spec`, #1369) landed; this
adds the append-only **experiment ledger** so the search has memory and
can dedup before running.

## Problem

We keep re-testing or nearly re-testing rejected configs (hysteresis
×2). There is no machine record of *every* experiment + verdict. The
ledger fixes this: an append-only per-experiment sexp + a flat
machine-readable index, keyed by a **config hash** computed from the
*effective* config (so two logically-equal override blobs dedup).

## Module surface — `Experiment_ledger`

New pure lib `trading/trading/backtest/experiment_ledger/lib/` (sibling
to `walk_forward`). Sexp I/O + hashing + dedup; no simulation. Deps:
`core`, `weinstein_trading.strategy`, `backtest` (for
`Overlay_validator.apply_overrides`).

Types (records ≤ 7-9 fields):
- `verdict = Accept | Reject | Inconclusive [@@deriving sexp, eq]`
- `fold_aggregate = { mean_sharpe; mean_calmar; mean_return_pct;
  mean_max_drawdown_pct } [@@deriving sexp]` — the four axes the WF
  report already emits; OPTIONAL on a variant so seed entries without
  machine aggregates still record.
- `variant_record = { label; config_hash; aggregate : fold_aggregate
  option }`
- `entry = { date; slug; hypothesis; base_scenario; window_id;
  baseline_label; variants; verdict; notes } [@@deriving sexp]`
- `index_row = { config_hash; base_scenario; window_id; verdict;
  entry_slug }`

Functions:
- `config_hash : Sexp.t list -> string` — **the dedup key.** Apply the
  overrides onto the canonical default config via
  `Overlay_validator.apply_overrides`, `sexp_of_config` the result,
  `Sexp.to_string_mach` for a stable canonical form, `Md5.digest_string`
  → hex. Effective-config based so logically-equal overrides hash
  identically.
- `save_entry : dir:string -> entry -> unit` — `<dir>/<date>-<slug>.sexp`;
  RAISES on overwrite (append-only discipline).
- `load_entry : string -> entry`.
- `load_index : dir:string -> entry list` — all `*.sexp` entry files,
  skipping `index.sexp`.
- `build_index : entry list -> index_row list` — one row per (variant,
  entry).
- `save_index : dir:string -> entry list -> unit` — `<dir>/index.sexp`.
- `lookup : index_row list -> config_hash:string -> base_scenario:string
  -> window_id:string -> verdict option` — the dedup query.

## config_hash design decision

The key is computed from the **effective** config, not the raw override
text. Two specs that write the same override with different whitespace,
or that reorder independent override blobs, produce the same effective
config and so the same hash. The hash is stable because
`Sexp.to_string_mach` is a canonical (no-whitespace) form and the config
record has a fixed field order. The placeholder `universe` /
`index_symbol` are held constant, so they do not perturb the hash across
variants.

## Seed entries (`dev/experiments/_ledger/`)

- `2026-05-29-stage3-hysteresis-wf-cv.sexp` — full machine aggregates
  for `h1-m0` (baseline, empty overrides) and `h2-m02`
  (`stage3_force_exit_config.hysteresis_weeks=2` + `stage3_exit_margin_pct=0.02`),
  verdict Reject. Cites `dev/notes/stage3-hysteresis-walkforward-cv-2026-05-29.md`.
- Minimal seeds (aggregate = None) for the other known rejections:
  continuation-buy combined-axis, M5.5 single-lever exhaustion,
  laggard-disable retraction. Where a clean override blob is derivable
  the hash is real; otherwise a nominal empty-overrides hash + a note.
- `index.sexp` regenerated from the entries.

## Test plan (`.../test/test_experiment_ledger.ml`, OUnit2 + Matchers)

- Round-trip save/load entry.
- `config_hash` stable + EQUAL for two logically-equal-but-differently-
  written override blobs, DIFFERENT for different configs.
- `save_entry` RAISES on overwrite (fail-loud contract — pinned per the
  PR-1 lesson).
- `lookup` returns the recorded verdict for a seeded (hash, base, window)
  and `None` for an unknown one.
- `load_index` / `build_index` round-trip.

## Scope

~250-350 LOC + tests + seed data, single PR. NOT DSR/Pareto ranking
(PR-3) or the skill (Gap F).
