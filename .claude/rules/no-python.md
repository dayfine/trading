# No Python — OCaml only

The codebase is OCaml + Dune. Do not add new Python scripts to this
repository — not in source code, not in tooling under `dev/scripts/`,
`analysis/scripts/`, `trading/devtools/`, or anywhere else.

## Why

- One language across the codebase. Type discipline carries through
  build tooling, perf reports, and one-off scripts the same way it
  carries through trading logic.
- No second toolchain to install, lint, or version-pin. CI doesn't
  need a Python interpreter.
- Agents and humans don't have to context-switch between OCaml's
  module system and Python's import semantics for sibling code.

## What to do instead

| If you'd reach for | Use |
|---|---|
| Python script reading sexp/CSV → emitting Markdown | OCaml exe under `trading/<area>/scripts/` or `dev/lib/<name>/` with a Dune target |
| Python one-liner (jq-style data shaping) | `jq` in a `dev/lib/*.sh` POSIX shell script |
| Python CLI orchestrator | POSIX shell (`dev/lib/*.sh`); the `posix_sh_check.sh` linter already enforces portability |
| Python notebook for exploration | OCaml + `dune utop` for ad-hoc analysis; commit only the resulting OCaml exe if the analysis is durable |

OCaml ports of data-shaping scripts pay off quickly: sexp readers via
`[%of_sexp]` and CSV via the existing `analysis/data/storage/csv` lib
get you most of the way for free.

## Existing exceptions (legacy, time-boxed)

- `dev/scripts/perf_sweep_report.py` (~414 LOC) and
  `dev/scripts/perf_hypothesis_report.py` (~336 LOC) — generate
  Markdown reports comparing **Legacy vs Tiered** RSS / wall-time for
  the perf sweep harness.
- These are scheduled for **deletion** as part of
  `dev/plans/data-panels-stage3-2026-04-25.md` PR 3.4 (delete Legacy
  loader_strategy). Once Stage 3 lands, only Panel mode remains and
  the Legacy-vs-Tiered comparison axis these scripts implement is
  meaningless.
- If a Panel-mode RSS regression dashboard is wanted post-Stage-3,
  re-implement in OCaml from scratch — do not port the Python.

These two scripts are the only legitimate Python in the repository.
Adding more is a NEEDS_REWORK at QC time.

## Enforcement

- Manual: code review / QC structural reviewers flag any new `*.py`
  outside the two grandfathered scripts.
- Future linter (low priority): a one-line check in
  `trading/devtools/checks/` that fails if any `*.py` exists outside
  the two grandfathered paths. Add when the legacy scripts are gone
  so the linter has nothing to grandfather.
