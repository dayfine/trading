# Findings registry -- every backtest finding names a guard that still exists

`dev/findings/registry.sexp` has one row per finding (a backtest surprise found
by reading run output), naming what pins it. `trading/devtools/checks/findings_registry_check.sh`
(dune runtest) fails when a named guard is gone. Issue #3001: findings used to be
pinned, or not, in writeups and PR comments, and nothing noticed when a guard
was renamed or deleted.

## Row shape

```
((issue 2982) (ref "optional label") (finding "stop raise mixes adjusted MA with raw bars")
 (guard ((unit ("<repo-relative test file>" "<test name>")) (validator V13)))
 (reason "required only for guard none")
 (status fixed-behind-flag))
```

- `guard`: `none`, or one or more `(unit (FILE NAME))` / `(validator Vn)` entries.
  Kind is derived: unit, validator, both, none.
- `none` requires a `reason` (strategy observations, "record only", a validator
  planned but not built -- name the issue).
- `status`: `open | fixed | fixed-behind-flag | wontfix | observation`.
- A row needs an `issue` or a `ref`.

## What the check verifies

- a `unit` file exists and contains the test name as a literal substring;
- a `validator` id appears in `validator_checks.ml` `_registry` (read from that
  file, not a copied list) -- never cite a validator that is not on main;
- `guard none` has a reason; status is in the enum.

It does not run the test or judge whether the guard is adequate.

## Closing rule

A PR that says `Closes #N` on a finding issue adds or updates that finding's
registry row in the same PR. qc-behavioral row F1 FAILs the PR when the row is
missing. Use the test name exactly as it appears in the file (grep it). When the
guard is a validator that lands later, use `none` with a reason naming the
issue, then update the row when the validator merges.
