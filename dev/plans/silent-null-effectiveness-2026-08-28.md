# Plan: mechanical check for silent-null config threads (issue #2567)

## Context

qc-behavioral on #2563 (2026-08-26) named a recurring defect class: a
`Weinstein_strategy.config` field claims to thread into a sub-config
(`Rs.config`, `Volume.config`, a resistance anchor knob, ...) via an
adapter function (`_stock_analysis_config_for`, `_rs_config_for`, ...),
the thread is severable (e.g. `field = config.field && false`) with the
**entire test suite staying green**, and the failure mode is a **silent
null**: an armed axis sweep measures the baseline and the experiment
ledger records a REJECT for a mechanism that never ran. Per
`.claude/rules/experiment-flag-discipline.md` Rule 4, a terminal REJECT
marked do-not-revive gets the mechanism's code **deleted** — so this
defect class can delete working code on false evidence.

Three prior instances: `Volume.config` (#2459), the rt anchor knob
(`project_rt_needs_its_anchor_knob`), and `enable_rs_positive_declining`
→ `Rs.config.enable_positive_declining` (#2563, caught only because the
reviewer hand-wrote a severing mutation during review).

The issue proposes two enforcement options and asks this session to pick
one with evidence:

- **(a) A linter** that greps adapters for `field = config.field` pairs
  and demands a matching `#<issue>:`-tagged effectiveness test.
- **(b) A convention + a `qc-structural` row** (manual, per-PR
  vigilance).

The issue's own closing line: "The per-PR-vigilance alternative has now
failed three times." `.claude/rules/code-health-discipline.md` and
`.claude/rules/pr-gate-loop.md`/`daily/2026-08-27.md` both document a
related, very fresh lesson: the last two harness PRs on this track
(#2580, and the #2563 rework) were reworked specifically because a
"guard" turned out to be either non-existent (pure convention) or
vacuously green (a regex that could be silently narrowed to match
nothing). That lesson bears directly on option (b): a convention has no
existence check at all, so it cannot even fail loudly when abandoned.

## Census (the load-bearing input)

Grepped the two domain roots the defect class actually lives in
(`trading/trading/weinstein/`, `trading/analysis/weinstein/`), excluding
`test/` and `bin/`, for the literal shape a field-copy-into-a-sub-config
takes: a record-construction line whose right-hand side is a bare
`config.<field>` access (`<module-prefix>?<field> = config.<field>;`):

```sh
grep -rnE '^\s*[A-Za-z_][A-Za-z0-9_.]*\s*=\s*config\.[a-z][A-Za-z0-9_]*\s*;?\s*$' \
  trading/trading/weinstein trading/analysis/weinstein --include=*.ml \
  | grep -v '/test/' | grep -v '/bin/'
```

Result: **17 field-copy lines, 15 distinct field names, across 6
files**:

| file | fields |
|---|---|
| `weinstein_strategy_screening.ml` | `enable_rs_positive_declining`, `overhead_supply`, `virgin_crossing_readmission`, `entry_anchor_local_range_weeks`, `entry_freshness_basis`, `resistance_min_history_bars`, `neutral_blocks_longs`, `neutral_blocks_shorts`, `enable_slow_grind_short_gate` |
| `entry_stop_width_order.ml` | `stop_width_mode`, `stop_width_size_down_max_pct` |
| `entry_walk.ml` | `stop_width_mode`, `stop_width_size_down_max_pct` (same fields, second site) |
| `snapshot/gen/lib/rename_detector.ml` | `match_fraction`, `ret_epsilon` |
| `stock_analysis.ml` | `require_breakout_volume` |
| `resistance/lib/resistance_supply.ml` | `insufficient_score` |

Two things this census settles:

1. **The population is not "a handful."** 15 distinct fields today, and
   the two files with the highest count (`weinstein_strategy_config.ml`,
   `weinstein_strategy_screening.ml`) had **42** and **23** commits
   respectively in the last 60 days — this is one of the highest-churn
   corners of the codebase. New field-copy pairs land routinely, not
   rarely.
2. **The defect is not confined to `_config_for`-named adapters.**
   `_run_screener` (not named `*_config_for`) threads
   `neutral_blocks_longs` / `neutral_blocks_shorts` /
   `enable_slow_grind_short_gate` into `Screener.config` with the exact
   same shape. A check that only looked at functions named `_config_for`
   would have missed 3 of the 17 lines outright — i.e. even the
   mechanically-narrower version of option (a) would already have a
   false-negative gap on the CURRENT tree. This is the concrete argument
   for a **shape-based** trigger (any `field = config.field2` line, any
   function) over a **name-based** one (only `*_config_for` functions).
3. **Manually checking today's 15 fields for adequate coverage found a
   16th, currently-live gap**: `entry_freshness_basis` (F1, the
   range-top-breakout admission clock) has no test anywhere that sets
   `Weinstein_strategy.config.entry_freshness_basis` away from its
   default and observes the built `Stock_analysis.config` differ. This
   is exactly the defect class, live on `main` today, found by doing the
   census by hand — which is itself evidence for (a): a human doing this
   audit once, by hand, still missed it in every prior PR that touched
   this file (23 commits), and only surfaces it when someone sits down
   and greps every field systematically. That is what a linter does on
   every PR for free; a convention does it only when someone remembers
   to re-run the audit.

## Decision: (a) — a linter, not a convention

Given the census: 15 fields today, high and rising churn, an
already-live 16th instance found by the census itself, and a documented
0-for-3 track record for "reviewer notices during read-through" (plus,
this same week, two sibling harness PRs reworked because a "guard" had
no existence check at all or could be silently narrowed to vacuous). The
option (b) convention-only path relies on exactly the mechanism that has
already failed three times reproducibly. Build the linter.

**What the linter checks:** every `field = config.field2` line (shape
above) in the two domain roots must have a matching
`EFFECTIVENESS-PIN: field2` tag somewhere in a `*/test/*.ml` file
repository-wide, OR be listed in an exceptions file with a `review_at`
date (same convention as `universe_deps_exceptions.conf` /
`linter_exceptions.conf`).

**Why a repo-defined tag (`EFFECTIVENESS-PIN: <field>`) instead of the
issue's literal `#<issue>:` suggestion:** the tag needs to be a stable,
mechanically-greppable join key between the adapter's source field and
the test that proves it live. An issue number is not that — it names
*why* the pin was added, not *which field* it proves, and one field can
gain follow-up pins across several issues over time. Keying on the field
name is what actually lets the linter answer "is `entry_freshness_basis`
covered" without a lookup table. The tag comment is free-form after the
field name, so the issue number / rationale still belongs there:
`(* EFFECTIVENESS-PIN: entry_freshness_basis -- #2567, real classifier path *)`.

**Why an exceptions file, not a blocking retrofit of all 17 lines in
this PR:** per `.claude/rules/code-health-discipline.md`, deferring
code-health work indefinitely is not acceptable, but the file's own
"what TO do" section allows a bump/exception when paired with "a
concrete refactor plan ... and a tracking issue with a real owner + date
... landing in the same PR." This PR pays down the highest-value items
directly (6 fields, including the newly-found `entry_freshness_basis`
gap, get a real pin in this PR) and grandfathers the remaining 9 with
`review_at` dates 30-45 days out, so the linter is live and blocking on
every NEW field-copy pair starting now, without this PR growing into an
unbounded test-writing exercise for fields this session cannot verify
carefully (`match_fraction` / `ret_epsilon` in a rename-dedup detector,
`insufficient_score` in resistance-supply scoring, the screener
neutral-blocks gates, the stop-width-mode threads) within budget.

## Approach

1. `trading/devtools/checks/adapter_effectiveness_check.sh` — a POSIX
   shell linter, following the `_check_lib.sh` + `repo_root()` +
   `(universe)` pattern used by `check_universe_deps.sh` /
   `no_python_check.sh` (whole-tree scans that must never go
   cache-stale). Steps:
   - Scan `trading/trading/weinstein` + `trading/analysis/weinstein`
     (excluding `*/test/*` and `*/bin/*`) for lines matching
     `^\s*[A-Za-z_][A-Za-z0-9_.]*\s*=\s*config\.[a-z][A-Za-z0-9_]*\s*;?\s*$`.
   - Extract the RHS field name (the `config.<field>` identifier).
   - For each unique field name: grep every `*/test/*.ml` file
     repo-wide for the literal `EFFECTIVENESS-PIN: <field>` tag. If
     found: OK. Else, check `adapter_effectiveness_exceptions.conf`
     (field name + mandatory `review_at`). If neither: FAIL, printing
     the adapter file:line and the missing field name.
2. `trading/devtools/checks/adapter_effectiveness_check_test.sh` — pins
   the parsing/decision logic against a **synthetic fixture tree**
   (`REPO_ROOT` override, same pattern as
   `check_universe_deps_test.sh`), independent of the real tree's
   current content, so a regression in the real tree's coverage can
   never mask a regression in the checker itself (and vice versa).
   Assertions include the three required mutation break-directions
   (see `Acceptance` in the dispatch prompt) run against the fixture.
3. `trading/devtools/checks/adapter_effectiveness_exceptions.conf` —
   grandfather list, `review_at` dates 30-45 days out, one entry per
   currently-unpinned field name (9 entries — see Census table minus
   the 6 pinned in this PR).
4. Wire both scripts into `trading/devtools/checks/dune` (mirrors the
   `check_universe_deps.sh` / `_test.sh` rule pair, both `(universe)`).
5. Retrofit `EFFECTIVENESS-PIN` tags onto the 6 fields that already have
   an adequate real test:
   - `enable_rs_positive_declining` —
     `trading/trading/weinstein/strategy/test/test_rs_trend_live.ml`
     (`test_positive_declining_needs_the_flag`, already a real
     downstream-behavior pin).
   - `overhead_supply`, `virgin_crossing_readmission`,
     `entry_anchor_local_range_weeks`, `resistance_min_history_bars` —
     `trading/trading/weinstein/strategy/test/test_stock_analysis_config_wiring.ml`
     (existing structural pins on the adapter's own output — sufficient
     for a *direct* field copy: severing the copy changes the built
     value, which the existing `equal_to` assertion already catches).
6. Close the newly-found gap: add a
   `test_threads_entry_freshness_basis` case to
   `test_stock_analysis_config_wiring.ml` (arms
   `entry_freshness_basis = Range_top_breakout`, asserts the built
   `Stock_analysis.config.entry_freshness_basis` equals it — same
   pattern as the existing `entry_anchor_local_range_weeks` test), tag
   it.
7. Add the 9 grandfathered fields to the exceptions file.

## Files to change

- `trading/devtools/checks/adapter_effectiveness_check.sh` (new)
- `trading/devtools/checks/adapter_effectiveness_check_test.sh` (new)
- `trading/devtools/checks/adapter_effectiveness_exceptions.conf` (new)
- `trading/devtools/checks/dune` (wire in both rules)
- `trading/trading/weinstein/strategy/test/test_rs_trend_live.ml` (tag)
- `trading/trading/weinstein/strategy/test/test_stock_analysis_config_wiring.ml`
  (4 tags + 1 new test + tag)
- `dev/status/harness.md` (mark item done)

## Risks / unknowns

- **Regex is syntactic, not semantic.** It only catches the direct-copy
  shape `field = config.field2`. A derived/conditional thread (e.g.
  `require_breakout_volume = not (Weinstein_strategy_config.foo config)`
  in `weinstein_strategy_screening.ml`, or an `if config.x then ... else
  ...`) is invisible to this regex — same residual class
  `goldens_affected_check.sh` documents for its own [@sexp.default]
  scan. Documented as a known limitation in the script header, not
  silently swept under the exceptions file.
- **A tag proves existence, not correctness.** The linter cannot verify
  that the referenced test genuinely exercises the real adapter and
  observes a distinguishing value — that judgment stays with whoever
  writes the tag (and with QC review), the same trust model
  `goldens_affected_check.sh`'s `paired-run-done` label already uses.
- **Exceptions file is a real, if bounded, escape hatch.** Mitigated by
  mandatory `review_at` dates and by this PR closing the
  highest-confidence 6 of 15 outright.
  **Corrected in rework (BQ-1, dev/reviews/harness-2567-2585.md,
  2026-08-28):** this bullet originally claimed the dates were "checked
  by the existing `deep_scan_linter_expiry_check.sh` machinery pattern."
  That was not true as shipped — `check_11_linter_expiry.sh` only ever
  called `_scan_exceptions_conf()` for `linter_exceptions.conf` and
  `universe_deps_exceptions.conf`; `adapter_effectiveness_exceptions.conf`
  was never scanned, so all 8 grandfathered entries' `review_at` dates
  were decorative. PR #2585's rework iteration 1 added a third
  `_scan_exceptions_conf()` call (mirroring the `universe_deps_exceptions.conf`
  precedent) plus a mutation-proof regression test
  (`deep_scan_linter_expiry_check.sh` Part 3) that goes RED if that call
  is ever removed — the claim is accurate now, and pinned.

## Acceptance criteria

- Linter FAILs on a real severed instance (positive control) and on a
  synthetic fixture with a violating + a conforming case.
- Linter is NOT vacuously green: a mutation that reduces the field-copy
  regex to match nothing must itself go RED against the fixture
  (mirrors the #2580 lesson).
- `dune build`, `dune runtest`, `dune build @fmt` all exit 0.
- 6 real fields tagged; `entry_freshness_basis` gap closed with a real
  test; 9 fields grandfathered with `review_at`.

## Out of scope

- Retrofitting real downstream-behavioral tests for the 9 grandfathered
  fields — tracked via the exceptions file's `review_at` dates, not
  this PR.
- The derived/conditional thread residual (documented, not fixed).
- A `qc-structural` row — superseded by the linter; not added, to avoid
  a duplicate, drift-prone manual check for something now mechanically
  enforced.
