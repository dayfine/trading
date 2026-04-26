---
harness: project
---

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

## Enforcement

- `trading/devtools/checks/no_python_check.sh` — wired into `dune runtest`;
  fails if any `*.py` file exists anywhere in the repo (outside `.git/`,
  `_build/`, `node_modules/`, `vendor/`, `.devcontainer/`). No exceptions.
- Manual: code review / QC structural reviewers flag any new `*.py`.
