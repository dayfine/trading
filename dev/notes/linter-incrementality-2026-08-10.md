# Linter incrementality — the `devtools/checks` dev-loop tax (2026-08-10)

**Status (final):** fix 1 SHIPPED (PR #2272) — **~35 min → 1.024 s, >2000x**.
**Fix 2 (per-file dune rules) is CLOSED — DO NOT BUILD IT.** See the verdict
below before re-deriving the idea from the dune file.

## ⚠ Fix 2 verdict: NOT WORTH IT — would be a REGRESSION

Once fix 1 landed, the numbers inverted the case entirely:

- Whole-tree cold-cache worst case for the magic-numbers check: **~1 s**.
- Full `devtools/checks/` target: **15.5 s warm**.
- The remaining prize (a warm single-file re-run, ~1 s → a few ms) is
  **sub-second**.
- The cost: 445 generated rules (or a stale static list), and dune's per-rule
  overhead on the **cold-worktree case that motivated the work in the first
  place** plausibly costs **9-22 s** — i.e. *more than the entire current cold
  run*.

So per-file rules would buy milliseconds warm and lose seconds cold, at real
complexity. The cheap fix removed the need for the expensive one. That is a
good outcome, not a consolation prize.

**Better next targets** for the same single-process treatment, measured:
`linter_mli_coverage.sh` (11.83 s), `arch_layer_test.sh` (7.27 s),
`testing_only_check.sh` (5.45 s).

**Where the bottleneck went:** verification is now dominated by the actual test
suites (~15 min), not the linters. Any further dev-loop work should target
those, not `devtools/checks`.

---

*Original analysis below, kept for the reasoning trail.*

## The problem, measured

`dune runtest` is ~50 min in this container; `linter_magic_numbers.sh` alone is
~35-40 min of it. Feat-agents run 3-4 verification cycles per PR, so the check
suite costs **1.5-2.5 h per PR**. On the 2026-08-10 async-v2 build night that was
an estimated 8-10 h across five feature PRs.

It also caused two multi-hour work losses indirectly: agents sit past the ~1 h
worktree-reap window *because* they are waiting on verification, holding
finished but uncommitted work (see
`memory/feedback_cleanup_merged_reaps_unpushed_worktrees`).

## Two independent causes

### 1. Per-line subprocess forks (fix in flight)

`linter_magic_numbers.sh` forks 8-14 processes **per source line** — counting
`(*` / `*)` / quote parity via `printf | grep -o | wc -l | tr -d` pipelines
rather than arithmetic. Over 445 lib files / 57,444 lines that is ~500k process
spawns; under Docker-on-macOS (fork+exec ~3-5 ms) that is the ~35 min.

The `case` statements in the same loop are shell built-ins and cost nothing —
all the expense is three counting idioms that never needed a subprocess.

Fix: single `awk` pass. Acceptance bar is **byte-identical output** over the
whole tree AND over violation-present fixtures (a clean-tree-only diff would
look perfect if the rewrite silently detected nothing).

### 2. Rule granularity defeats dune's cache (QUEUED — the bigger win)

Every check rule in `trading/devtools/checks/dune` has the shape:

```
(rule (alias runtest)
 (deps _check_lib.sh (glob_files_rec %{workspace_root}/*.ml))
 (action (run sh %{dep:linter_magic_numbers.sh} %{dep:linter_exceptions.conf})))
```

**One rule depending on all ~445 source files.** Dune caches at rule
granularity, so editing a single `.ml` invalidates the whole rule and re-scans
everything. An agent in a TDD loop edits source constantly → full cost every
time. Compounding it, agents work in fresh worktrees with no `_build`, so the
first run is always cold.

Note the `glob_files_rec` deps were added deliberately, and correctly — the dune
comments record that without them `dune runtest` "returns a cached PASS on a
clean tree". That fix bought correctness by discarding all incrementality.
**Per-file rules are the same fix at the right granularity.**

#### The queued change

Split each check into **one rule per source file**, each depending only on that
file (+ the script + `linter_exceptions.conf`). Editing one file then re-lints
one file; the other 444 are cache hits.

Preferred over `git diff --name-only` scoping, because unchanged files retain a
*valid cached verdict* rather than being skipped. Diff-scoping reintroduces
exactly the silent-accumulation blind spot that `code-health-discipline.md`
exists to prevent (PR #916: 8 file-length + 5 fn-length + 99 nesting violations
surfaced at once after a cache invalidation).

**Cost to check before committing to it.** These rules are sandboxed — visible
in CI as `(cd _build/.sandbox/<hash>/default/devtools/checks && sh ./linter_*.sh)`
— so each rule invocation is one `mkdir` plus one filesystem entry per declared
dep. Splitting trades 1 sandbox × ~445 materializations for 445 sandboxes ×
~3 materializations, plus 445 extra process spawns: roughly 3× the file ops and
a few seconds of added cold-start. Against 35 min that is immaterial, but it
should be *measured*, not assumed.

**Scope:** `fn_length_linter` and the other `devtools/checks` rules share the
same `glob_files_rec` shape — the split should cover the family, not just the
magic-numbers check.

| | today | + awk (fix 1) | + per-file rules (fix 2) |
|---|---|---|---|
| edit one file, re-verify | ~35 min | ~10-20 s | ~ms (cache hits) |

## Out of scope (deliberately)

Reading `linter_magic_numbers.sh` closely, several heuristics are blunter than
they look — `*'->'*` skips **any** line containing an arrow, `config.` skips any
line merely mentioning config — so the checker likely has a wide false-negative
surface. That is a separate question from making it fast. Changing detection
behaviour and performance in the same PR would make the equivalence test
meaningless. File separately if pursued.

## Why the check is worth keeping at all

It enforces CLAUDE.md's "All parameters in config, never hardcoded" — which is
load-bearing, not stylistic: a hardcoded threshold can never become a
`Variant_matrix` axis, so it silently drops out of the experiment search space
while the backtest still runs green. 23 commits since 2026-05-01 mention
magic-number fixes (~1-2/week); only 5 exceptions granted; main is clean. It is
a live gate. The goal is to keep 100% of the checking at ~0% of the cost.
