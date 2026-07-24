Reviewed SHA: 9fcf3d1980b6ecb349e0ab11eb549f8fc7391478

## Structural QC — tax-lens (PR #2073)

Branch is 0 commits behind `main` at review time — no staleness flag.

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Verified via GitHub check-runs API: `build-and-test` completed/success on reviewed SHA. That job runs `dune build @fmt` as one of its steps. |
| H2 | dune build | PASS | Same `build-and-test` run; `mergeable_state: clean`. |
| H3 | dune runtest | PASS | Same run; `build-and-test` also runs the full linter suite (`fn_length_linter`, `nesting_linter`, `linter_magic_numbers.sh`, `file_length_linter`, `linter_mli_coverage.sh`, `status_file_integrity_linter`, `no_python_check.sh`) plus `perf-tier1-smoke`, both completed/success. |
| P1 | Functions ≤ 50 lines (linter) | PASS | H3 passed; largest new function (`_trade_of_line`) is ~10 lines. |
| P2 | No magic numbers (linter) | PASS | H3 passed. New literals are test fixture data (dates/prices/counts), which the magic-numbers linter treats as test-context exempt per existing convention; no new tunables introduced. |
| P3 | All configurable thresholds/periods/weights in config record | NA | No new tunable threshold/period/weight introduced. The 9-field minimum for a well-formed `trades.csv` row is a structural format invariant tied to `result_writer.ml`'s fixed 13-base-column schema, not a tunable — same class as the pre-existing column-index comment it replaces. |
| P4 | Public-symbol export hygiene (.mli coverage) | PASS | H3 passed. `loader.mli`'s `load_exn` signature is unchanged (`string -> Tax_types.run_data`); only the implementation and its raise behavior changed. No new public symbols added. |
| P5 | Internal helpers prefixed per convention | PASS | All new/changed helpers (`_trade_of_line`, `_write_file`, `_raised_message`) use the `_`-prefix convention. |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | Checked `test_loader.ml` against all three greppable sub-rules — zero hits for each: no `List.exists ... equal_to (true\|false)`, no unassigned `let _ = ...on_market_close/.run` pattern, no bare `Ok`/`Error` match without `assert_that`/`is_ok_and_holds`. Every test uses exactly one `assert_that` per asserted value, composed via `all_of`/`field`/`elements_are`/`pair`/`is_some_and` (both `pair` and `contains_substring` are real exports of `base/matchers/lib/matchers.mli`, confirmed at this SHA — lines 124 and 241). The 4 raise-path tests pin a specific substring of the raised message (`"No such file or directory"`, `"trades.csv"` + same, `"malformed trades.csv row"`, `"unparseable first equity row"`) via `_raised_message`, not a catch-all `_ -> true` — an unrelated failure with a different message would correctly fail these tests. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | None. All code changes are confined to `trading/trading/backtest/tax_lens/` (a leaf report module per its own `dev/status/tax-lens.md` framing); `dev/status/tax-lens.md` is a docs-only change. No FLAG warranted — not a core module. |
| A2 | No new `analysis/` → `trading/trading/` imports outside the allow-listed exception surface | PASS | Both touched `dune` files reviewed (`tax_lens/lib/dune`, `tax_lens/test/dune`). `lib/dune` libraries: `core`. `test/dune` libraries: `ounit2 core core_unix.filename_unix matchers tax_lens` (the only diff is adding `test_loader` to `names` and `core_unix.filename_unix` to `libraries`, both non-`analysis/` deps). Zero `analysis/`-path library references anywhere in this diff. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | `$PR_FILES` (from `gh pr view 2073 --json files`, confirmed against the Files API response) = `dev/status/tax-lens.md`, `trading/trading/backtest/tax_lens/lib/loader.ml`, `trading/trading/backtest/tax_lens/test/dune`, `trading/trading/backtest/tax_lens/test/test_loader.ml`. All 4 are within scope of the stated tax-lens CP4 follow-up (loader implementation fix + its new test file + the test-target `dune` stanza + status-file record). No cross-feature drift. |

### Scrutiny item — is the `loader.ml` behavior change the smallest fix, and does it risk breaking real scenario dirs?

Verified by reading `trading/trading/backtest/lib/result_writer.ml` at this SHA (`_trades_csv_header`, lines ~93-108): the real writer's `trades.csv` always emits **13 base columns** (`symbol, side, entry_date, exit_date, days_held, entry_price, exit_price, quantity, pnl_dollars, pnl_percent, entry_stop, exit_stop, exit_trigger`) plus `Trade_context.csv_header_fields` appended on top — i.e. real writer output is never fewer than 13 fields. The loader's parser only reads columns 0/1/3/4/8 and now raises when a row has fewer than 9 fields (`_trade_of_line`'s new `fields -> failwithf ...` branch, replacing the old silent-drop `_ -> None`). Since 13 > 9, **no real `result_writer.ml` output can ever trigger the new raise path** — the fix only changes behavior for genuinely malformed input (which is exactly what the `.mli` contract promises to reject). This is the minimal change consistent with the documented contract: `List.filter_map` → `List.map`, plus one new `failwithf` arm; no other logic touched. Confirmed no regression risk against real scenario dirs.

### Fixture hygiene

Fixtures are written to a fresh `Filename_unix.temp_dir` per test (5 separate temp dirs across the 6 tests, each independent — no shared mutable state, no ordering dependency). No explicit `rm -rf`/cleanup call is present, but this is intentional and documented (per-process OS-reclaimed temp dirs) and does not affect test hermeticity or correctness — each test creates its own fresh directory rather than reusing one, so there is no cross-test interference risk either way.

## Verdict

APPROVED

## NEEDS_REWORK Items

None.

---

## Behavioral QC — tax-lens (PR #2073)

Scope classification: pure infrastructure / report-layer PR (`tax_lens` is a
post-run report surface over `trades.csv` + `equity_curve.csv`; no stage
classifier, stops, screener cascade, or macro/sector gating touched). Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely",
the domain checklist (S1–S6, L1–L4, C1–C3, T1–T4) is marked **NA** in full
below. Review is the generic CP1–CP4 contract-pinning checklist.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in `loader.mli`'s `load_exn` docstring has an identified test that pins it | **FAIL** | `loader.mli` is not new to this PR, but this PR's entire stated purpose (PR body + `dev/status/tax-lens.md`) is to pin its contract — evaluated on that basis, not marked NA. Contract: *"parses `dir/trades.csv` and `dir/equity_curve.csv`. Raises if either file is missing or malformed."* Clauses: (a) dir missing → raises: `test_load_exn_raises_when_dir_missing` ✓. (b) `trades.csv` missing → raises: `test_load_exn_raises_when_trades_csv_missing` ✓. (c) `equity_curve.csv` missing → raises: `test_load_exn_raises_when_equity_csv_missing` ✓. (d) `trades.csv` malformed row → raises: `test_load_exn_raises_on_malformed_trades_row` ✓ (and the underlying `List.filter_map`→`List.map` fix genuinely makes this hold for *every* row, not just the first — verified by reading `_load_trades`, `loader.ml:32-35`). (e) `equity_curve.csv` malformed row → raises: only tested (`test_load_exn_raises_on_malformed_equity_row`) for the **first** data row, and the PR body itself scopes the claim that way ("Malformed `equity_curve.csv` **first row**"). But `_load_equity` (`loader.ml:52-64`) still parses subsequent rows via `List.filter_map rows ~f:_equity_row` (`loader.ml:56`), and `_equity_row` (`loader.ml:37-40`) returns `None` — silently dropped, not raised — for any row that doesn't split into ≥2 comma-fields. Concrete counterexample: `equity_curve.csv` = `"date,portfolio_value\n2021-01-01,1000.00\ngarbage_no_comma\n2022-01-01,1300.00\n"` → `load_exn` returns successfully with the malformed row silently dropped, contradicting the unqualified `.mli` clause "Raises if either file is ... malformed." This is the same bug class (`filter_map`-silently-drops-malformed-rows) the PR explicitly found and fixed in `_trade_of_line`/`_load_trades` for `trades.csv` — left unfixed one function over in `_load_equity`/`_equity_row`. Unpinned by any test in this diff. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body's 6-item "Contract clauses now pinned" list is honestly scoped — item 5 explicitly says "first row," matching the actual test and actual code guarantee. All 6 listed claims map 1:1 to the 6 tests in `test_loader.ml` (`load_exn_happy_path`, `..._dir_missing`, `..._trades_csv_missing`, `..._equity_csv_missing`, `..._malformed_trades_row`, `..._malformed_equity_row`). No overclaim within the enumerated list itself — the overclaim (see CP1) is in the PR's opening summary line, not the itemized test-coverage list. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | NA | `load_exn` is a transform (CSV rows → typed `run_data`), not an identity/pass-through operation. The happy-path test (`test_load_exn_happy_path`) does the right thing anyway — spot-checks real field values (symbol, side, exit_year, days_held, pnl per trade; year-end equity values; `initial_capital`; `span_years` to 1e-6) rather than only asserting row counts, satisfying the spirit of CP3/test-patterns.md even though the row is technically NA. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | The one explicit in-code guard claim is the comment above `_trade_of_line` (`loader.ml:19-22`): "A row with fewer than 9 fields is malformed and raises — it is never silently dropped." This is exercised by `test_load_exn_raises_on_malformed_trades_row`. No comparable guard claim exists in the code comments above `_load_equity`/`_equity_row` (`loader.ml:37-40, 50-51`) — those comments describe shape/return value only, make no raise-guarantee claim, and (per CP1) the code does not in fact provide that guarantee for non-first rows. Scored PASS here narrowly because the one claim that *is* made in code comments is fully tested; the missing guarantee for equity rows is captured under CP1 (it's a `.mli`-level claim, not a code-comment claim). |

## Behavioral Checklist

Pure infra / report-layer PR; domain checklist not applicable — no stage
classifier, stops, screener cascade, or macro/sector gating logic in this
diff (`tax_lens` is a post-run report surface, per `dev/status/tax-lens.md`
§Scope). All rows NA.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1 (no core-module touch). |
| S1–S6 | Stage definitions / buy criteria | NA | No stage-classifier logic in this diff. |
| L1–L4 | Stop-loss rules / state machine | NA | No stops logic in this diff. |
| C1–C3 | Screener cascade / macro gate / sector RS | NA | No screener logic in this diff. |
| T1–T4 | Domain-outcome test coverage | NA | Covered generically by CP2/CP3 above instead. |

## Quality Score

2 — Below standard: the PR is well-executed on its own stated scope (honest PR-body wording, hermetic fixtures, good assertion style, real fix for the trades.csv bug it found), but it left an identical bug class (silent-drop-via-`filter_map` on malformed rows) unfixed in `_load_equity`, one function over from the one it fixed — while its own summary claims the full `.mli` "raises if malformed" contract is now pinned. The fix is small (mirror the `_trade_of_line` pattern: replace `_equity_row`'s `None` catch-all with an explicit raise, or otherwise make `List.filter_map` in `_load_equity` a `List.map`/raising equivalent) and one more test (non-first malformed equity row) closes the gap.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### CP1: `_load_equity` silently drops malformed non-first `equity_curve.csv` rows, contradicting the `.mli` "raises if malformed" contract
- Finding: `_load_equity` (`loader.ml:52-64`) parses all data rows via `List.filter_map rows ~f:_equity_row` (`loader.ml:56`). `_equity_row` (`loader.ml:37-40`) returns `None` (silently dropped, not raised) for any row that doesn't split into ≥2 comma-separated fields. Only the *first* data row is separately guarded via `Option.value_exn` (`loader.ml:57-59`). Any malformed row at position 2+ is silently excluded from `equity_year_ends`/span computation rather than raising — this is the exact `filter_map`-swallows-malformed-input defect this PR explicitly found and fixed in `_trade_of_line`/`_load_trades` for `trades.csv`, left unaddressed in the twin function for `equity_curve.csv`.
- Location: `trading/trading/backtest/tax_lens/lib/loader.ml:37-40` (`_equity_row`), `loader.ml:56` (`List.filter_map` call site in `_load_equity`).
- Authority: `loader.mli` — `load_exn dir` docstring: *"parses `dir/trades.csv` and `dir/equity_curve.csv`. Raises if either file is missing or malformed."* No qualifier limiting this to the first row of either file.
- Required fix: Either (a) make `_equity_row` raise (e.g. `failwithf`) instead of returning `None` on an unparseable row, and switch `_load_equity`'s `List.filter_map` to `List.map`, mirroring the `_trade_of_line`/`_load_trades` fix already applied in this PR to `trades.csv`; or (b) if a deliberate design choice to tolerate blank/malformed trailing rows in `equity_curve.csv` specifically, narrow the `.mli` docstring to say so explicitly and add a test pinning the *tolerate* behavior (not just the first-row raise). Either way, add a test exercising a malformed **non-first** `equity_curve.csv` row (e.g. valid first row, garbage second row, valid third row) and assert the documented behavior.
- harness_gap: LINTER_CANDIDATE — a golden scenario test with a known non-first malformed equity row (analogous to the existing `test_load_exn_raises_on_malformed_trades_row`/`..._malformed_equity_row` fixtures already in this same file) would catch this deterministically; the test pattern already exists in the diff, it's just scoped to the wrong row index.


---

## Structural QC — delta re-review at 9fcf3d19 (rework iteration 1)

Prior structural APPROVE was at `cd8a3ba8bc2be937a5f7c676d9755dc6a0c9d856` (zero
findings). This is a **delta review** of the rework that addressed
qc-behavioral's CP1 NEEDS_REWORK finding (see the "Behavioral QC" section
above): `_equity_row` silently dropped malformed non-first `equity_curve.csv`
rows via `List.filter_map` instead of raising. This section supersedes the
prior structural verdict; it does not re-litigate anything unchanged.

Incremental diff reviewed: `git diff cd8a3ba8bc2be937a5f7c676d9755dc6a0c9d856..9fcf3d1980b6ecb349e0ab11eb549f8fc7391478`.
Touches exactly 3 files: `dev/status/tax-lens.md`, `trading/trading/backtest/tax_lens/lib/loader.ml`,
`trading/trading/backtest/tax_lens/test/test_loader.ml`. `loader.mli` and
`test/dune` are byte-identical between the two SHAs (confirmed via targeted
`git diff -- <path>`, both empty).

H1–H3: PASS, per CI. `build-and-test` = success, `perf-tier1-smoke` = success
on `9fcf3d19` (both required checks). Per dispatch instructions, not re-run
locally; the full linter suite runs inside `build-and-test`.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | CI `build-and-test` success at `9fcf3d19`. |
| H2 | dune build | PASS | Same run. |
| H3 | dune runtest | PASS | Same run; full linter suite included. |
| P1 | Functions ≤ 50 lines | PASS | `_equity_row` (~8 lines) and `_load_equity` (~10 lines) both well under limit; net change is a like-for-like restructure, no growth. |
| P2 | No magic numbers | PASS | No new numeric literals; `List.length fields` in the new `failwithf` is a computed value, not a magic number (mirrors the pre-existing `_trade_of_line` pattern). |
| P3 | Config completeness | NA | No new tunable introduced — same class as the prior review's P3 NA (structural format invariant, not a tunable). |
| P4 | .mli coverage / public-symbol export hygiene | PASS | `loader.mli` unchanged (confirmed empty diff for that path between the two SHAs) — `load_exn : string -> Tax_types.run_data` signature and docstring untouched. No public surface change from this rework. |
| P5 | Internal helpers prefixed per convention | PASS | `_equity_row`, `_load_equity` retain `_` prefix; no new helper introduced without one. |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | Applied the three greppable sub-rules to `test_loader.ml` at `9fcf3d19`: zero hits for `List.exists .* equal_to (true\|false)`, zero hits for unassigned `let _ = ...on_market_close/.run`, zero hits for bare `Ok`/`Error` match without `assert_that`/`is_ok_and_holds`. Both new tests use exactly one `assert_that` each. `test_load_exn_raises_on_malformed_non_first_equity_row` pins a specific substring (`"malformed equity_curve.csv row"`) via `is_some_and (contains_substring ...)` — not a catch-all — consistent with the 6 already-approved raise-path tests. `test_load_exn_tolerates_trailing_newline` asserts `field (fun r -> List.length r.trades) (equal_to 2)` on the successful `Loader.load_exn dir` result — single assert, correct compositional style. |
| A1 | Core module modifications | PASS | None; all changes confined to `trading/trading/backtest/tax_lens/`. |
| A2 | No new disallowed `analysis/` imports | PASS | `test/dune` unchanged in this delta (empty diff); no dune file touched at all in the incremental diff. |
| A3 | No unnecessary modifications to existing modules | PASS | Delta touches exactly the 3 files expected for this rework (`dev/status/tax-lens.md`, `loader.ml`, `test_loader.ml`) — matches the dispatch brief's expected scope exactly. No `dev/reviews/*.md` committed in this diff (reviews are working-tree-only, as expected), no `dev/status/_index.md` touch. |

### List.hd_exn robustness (dispatch item 5) — checked, not a finding

`_load_equity`'s outer match is `[] | [ _ ] -> failwithf "empty equity curve" ...`
before falling through to `_header :: rows -> ...`. Because that guard already
rejects any file with 0 or 1 total lines, `rows` is provably non-empty in the
`_header :: rows` branch (a file reaching that branch has ≥2 lines, so `rows`
has ≥1 element). `parsed = List.map rows ~f:_equity_row` therefore has the same
non-empty length as `rows`, making `List.hd_exn parsed` safe by construction —
not merely by convention. The in-code comment above `_load_equity` states this
invariant explicitly and correctly. Not a finding; `List.hd_exn`'s generic
`Failure "hd_exn"` message is never reachable here, so there's no informativeness
regression to flag either.

## Verdict

APPROVED

This delta re-review supersedes the prior verdict at `cd8a3ba8bc2be937a5f7c676d9755dc6a0c9d856`
(also APPROVED, zero findings). The rework is a clean, minimal, symmetric fix —
`_equity_row` now raises on any malformed row via the same `failwithf` pattern
already used in `_trade_of_line`, `List.filter_map` → `List.map` closes the
silent-drop path, and `List.hd_exn` replaces a redundant separate first-row
parse with a comment explaining why it's safe. No new structural issues
introduced. Zero findings.

---

## Behavioral QC — re-review at 9fcf3d19 (rework iteration 1)

Prior behavioral verdict at `cd8a3ba8bc2be937a5f7c676d9755dc6a0c9d856`: **NEEDS_REWORK**,
Quality Score 2/5, single CP1 finding — `_load_equity` silently dropped malformed
*non-first* `equity_curve.csv` rows via `List.filter_map`, contradicting the
unqualified `.mli` "raises if malformed" contract.

Scope unchanged: pure infrastructure / report-layer PR. Domain checklist
(S1–S6, L1–L4, C1–C3, T1–T4) remains **NA** in full per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely".

### Prior CP1 finding — closed

Read `loader.ml` at `9fcf3d19`. `_equity_row` now raises directly:

```
let _equity_row line : Date.t * float =
  match _fields line with
  | date :: value :: _ -> (Date.of_string date, Float.of_string value)
  | fields ->
      failwithf
        "malformed equity_curve.csv row (expected >= 2 fields, got %d): %s"
        (List.length fields) line ()
```

`_load_equity` switched `List.filter_map` → `List.map`, and `first_date, initial`
now comes from `List.hd_exn parsed` (parsed via the same uniform `List.map`,
no more separate first-row-only `Option.value_exn` guard). This is exactly the
`_trade_of_line`/`_load_trades` pattern already accepted in the prior review,
now mirrored for equity — the fix is structurally symmetric, not a special
case.

The new test `test_load_exn_raises_on_malformed_non_first_equity_row` uses
the exact counterexample from the prior finding (`"date,portfolio_value\n2021-01-01,1000.00\ngarbage_no_comma\n2022-01-01,1300.00\n"`)
and asserts `load_exn` raises with `contains_substring "malformed equity_curve.csv row"`.
Confirmed this is not vacuous: with the old `filter_map`-based code, this
exact input would have returned successfully (silently dropping the garbage
row); with the new `map`-based code it raises, per the fix. **CP1 finding is
closed** — every data row in both `trades.csv` and `equity_curve.csv` is now
uniformly checked, not just the first.

### `List.hd_exn` on the empty-data-rows path — checked, no regression

Traced `_load_equity`'s outer match: `[] | [ _ ] -> failwithf "empty equity
curve: %s" path ()` fires for 0 or 1 total lines (i.e. header-only or fully
empty file), *before* reaching the `_header :: rows -> ...` branch that calls
`List.hd_exn parsed`. So a header-only `equity_curve.csv` (zero data rows)
never reaches `List.hd_exn` — it hits the explicit `failwithf "empty equity
curve: ..."` arm instead, exactly as it did before this rework (this branch
was not touched by the fix). In the `_header :: rows` branch, `rows` is
therefore provably non-empty (≥2 total lines reached that branch), and
`parsed = List.map rows ~f:_equity_row` preserves that non-empty length
(`List.map`, unlike `List.filter_map`, never shrinks the list) — so
`List.hd_exn parsed` cannot raise `Failure "hd_exn"` in practice. This
mirrors qc-structural's independent finding in the "List.hd_exn robustness"
section above (same SHA, same conclusion). Agree: not a new gap. The
empty-data-rows case itself is unchanged behavior from before this rework and
was not a target of iteration 1, so no new test was required for it.

### Trailing-newline regression guard — verified, but weaker than advertised

Confirmed `_trades_csv` and `_equity_csv` (the fixtures reused by both
`test_load_exn_happy_path` and `test_load_exn_tolerates_trailing_newline`)
each end in exactly one `\n` after the last data row — the normal shape any
`Out_channel`/text-editor-written file has. Confirmed the author's
`In_channel.read_lines` claim is consistent with what's observable in this
diff: `_load_trades`/`_load_equity` have relied on this since before this PR
(the pre-existing `test_load_exn_happy_path`, unchanged by this rework, was
already passing against trailing-`\n` fixtures under the *old* `_trade_of_line`
direct-match code path, which raised on any non-matching row shape — a phantom
empty final line would have raised there too, and didn't). So the "no phantom
trailing empty line" behavior was already implicitly established before this
rework; `test_load_exn_tolerates_trailing_newline` re-exercises it through the
*new* `List.map`-based equity path specifically, which is the genuinely new
thing this rework needs proof of (before the fix, `filter_map` would have
silently swallowed any phantom trailing element regardless; after the fix,
`map` would surface it as a raise). So the test does pin real, non-duplicate
coverage of the risk the dispatch brief called out — it is not purely
redundant with the happy path, even though it reuses the same fixture bytes.

Two adjacent cases are **not** covered and are not called out as an explicit,
documented gap anywhere in the diff (code comments, PR body, or test-file
docstring):

1. **A blank final line** (`equity_curve.csv` ending in `\n\n` rather than
   `\n`) — if `In_channel.read_lines` treats that as an extra zero-length
   line (plausible; distinct from the single-trailing-newline case actually
   tested), `_fields ""` → `[""]` → the `fields` catch-all in `_equity_row`
   → raises "malformed equity_curve.csv row (expected >= 2 fields, got 1)".
   This would already have been true for `trades.csv` before this rework
   too (its `_trade_of_line` strictness predates this PR), so this rework
   does not introduce a new asymmetry — it just extends existing,
   previously-accepted strictness to the twin function. Not a regression
   from this PR; still an untested edge case.
2. **CRLF line endings** — a `\r` surviving into the last field would fail
   `Float.of_string "1300.00\r"` with a `Failure` whose message doesn't
   contain "malformed equity_curve.csv row", silently changing the raised
   message shape. Also pre-existing (unrelated to this rework), not
   introduced by it.

Both are real gaps in the "raises if malformed" contract's edge-case
coverage, but neither is **new** — both existed identically for `trades.csv`
since before this PR, and this rework's job (per the prior finding) was
narrowly to make `equity_curve.csv` match `trades.csv`'s existing strictness,
which it did. Treating these as out-of-scope for this iteration is
reasonable; flagging as informational only, not a blocking CP1/CP4 gap.
`harness_gap: ONGOING_REVIEW` if ever prioritized — these are shape/encoding
edge cases in real scenario-dir output, not something a golden fixture alone
would surface without deliberately corrupting a file.

### CP2 — PR body re-checked against actual tests, no overclaim

Re-read the PR body at `9fcf3d19`. All 8 enumerated "Contract clauses now
pinned" items map 1:1 to the 8 tests in `test_loader.ml`:

| PR body item | Test |
|---|---|
| 1. dir missing → raises | `test_load_exn_raises_when_dir_missing` |
| 2. trades.csv missing → raises | `test_load_exn_raises_when_trades_csv_missing` |
| 3. equity_curve.csv missing → raises | `test_load_exn_raises_when_equity_csv_missing` |
| 4. malformed trades.csv row (any position) → raises | `test_load_exn_raises_on_malformed_trades_row` |
| 5. malformed equity_curve.csv **first** row → raises | `test_load_exn_raises_on_malformed_equity_row` |
| 6. malformed equity_curve.csv **non-first** row → raises | `test_load_exn_raises_on_malformed_non_first_equity_row` |
| 7. trailing newline tolerated | `test_load_exn_tolerates_trailing_newline` |
| 8. happy path | `test_load_exn_happy_path` |

The opening summary line's prior overclaim (calling the whole `.mli` contract
"pinned" while equity's non-first-row case was unpinned) is now accurate —
the rework closed exactly that gap. No new overclaim introduced. **CP2: PASS.**

One minor observation, not a FAIL: item 4's parenthetical "(wrong column
count, **any row position**)" is asserted by a test whose single malformed
data row happens to be the *first* row (`"AAPL,LONG,only_three_fields"` is
the only data line in that fixture) — there's no dedicated "non-first
malformed trades.csv row" test analogous to item 6's equity test. This is
low-risk because `_load_trades`/`_trade_of_line` never special-cased the
first row the way the *old*, buggy `_load_equity` did — `List.map` applies
uniformly to every row by construction, so there's no structural reason a
non-first malformed trades row would behave differently. Still, the literal
test evidence for "any row position" on the trades side is a code-structure
argument, not a fixture, unlike the now-fixed equity side. Noting for
completeness; not required for this PR's stated scope (which was specifically
the equity twin-bug).

### CP1 — `.mli` module-header clause re-examined

Dispatch item 5 asks me to restate judgment on: *"No other file is
consulted; open positions are deliberately ignored under the realization
basis"* (the module-level comment in `loader.mli`, distinct from `load_exn`'s
own val-docstring). Confirmed unchanged at `9fcf3d19` (`loader.mli` has an
empty diff between both reviewed SHAs, verified independently of structural
QC's P4 note). This clause is a **scope/design statement**, not a
raise-on-malformed-input contract — `load_exn` structurally only calls
`Filename.concat dir "trades.csv"` and `Filename.concat dir "equity_curve.csv"`,
with no third file read anywhere in `loader.ml`. There is no "positions" file
format defined anywhere in `tax_lens` to open in the first place, so this
isn't a testable behavior in the CP1/CP4 sense (no malformed-input or
guarded-scenario to pin) — it's an absence-of-behavior invariant verifiable
only by code inspection, which I did. Judgment unchanged from before:
**NA for CP1 purposes**, correctly reflected in the checklist below.

### CP3 / CP4 — regression check

**CP3 (NA, unchanged):** `test_load_exn_happy_path` is byte-identical to the
prior SHA (confirmed via the incremental diff summary above — only
`loader.ml` and `test_loader.ml`'s *additions* changed; the happy-path test
body itself was not touched). Still spot-checks real field values
(symbol/side/exit_year/days_held/pnl per trade, year-end equity, initial
capital, span_years), not just `size_is`. No regression.

**CP4 (PASS):** The in-code guard claim above `_equity_row` — "it is never
silently dropped, mirroring `_trade_of_line`'s contract for trades.csv, so
`load_exn`'s 'raises on malformed input' contract holds for every data row,
not just the first" — is now directly exercised by
`test_load_exn_raises_on_malformed_non_first_equity_row`. This closes the
CP4 gap the prior review narrowly avoided flagging (it was captured under
CP1 instead, since the missing guarantee was `.mli`-level at the time, and no
code comment yet claimed the stronger guarantee). Both `_trade_of_line`'s and
`_equity_row`'s guard claims are now symmetric and both tested.

## Contract Pinning Checklist (re-review)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in `loader.mli`'s docstrings has an identified test that pins it | **PASS** | Prior FAIL closed. All `load_exn` val-docstring clauses now pinned symmetrically for both files (missing-dir/file ×3, malformed-row ×2 files × first-and-non-first). Module-header clause ("no other file consulted") re-affirmed NA — scope statement, not a testable raise/malformed-input contract. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" has a corresponding test | PASS | All 8 enumerated claims map 1:1 to the 8 committed tests. No overclaim (see table above). Minor observation (non-blocking): item 4's "any row position" for trades.csv is evidenced structurally (uniform `List.map`) rather than by a dedicated non-first-row fixture, asymmetric with item 6's equity coverage. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | NA | Unchanged from prior review; `load_exn` is a transform, not identity. Happy-path test still spot-checks real field values (confirmed unchanged). |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Both `_trade_of_line`'s and (now) `_equity_row`'s explicit in-code raise-guarantee comments are each exercised by a dedicated test. |

## Behavioral Checklist

Unchanged from prior review — pure infra/report-layer PR, all domain rows NA.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1 at either SHA. |
| S1–S6 | Stage definitions / buy criteria | NA | No stage-classifier logic in this diff. |
| L1–L4 | Stop-loss rules / state machine | NA | No stops logic in this diff. |
| C1–C3 | Screener cascade / macro gate / sector RS | NA | No screener logic in this diff. |
| T1–T4 | Domain-outcome test coverage | NA | Covered generically by CP1–CP4 above. |

## Quality Score

4 — Good: the rework closes the prior finding cleanly and symmetrically (same
`failwithf` + `List.map` pattern mirrored from the already-accepted
trades-side fix, not a bespoke patch), adds a genuinely new regression test
for the risk class the fix could have introduced (trailing-newline handling
under `List.map`), and the PR body's claims now match the tests exactly.
Docked one point, not for any CP FAIL, but for accumulated minor rough edges
that a careful pass would have caught: the test file's own top-of-file module
docstring still says "Five raising cases ... plus one happy path" (stale —
actual count is now 8: six raising + happy path + trailing-newline-tolerate),
the trailing-newline test's fixture is identical to the happy-path fixture
(real but easy-to-miss-as-redundant coverage rather than a fixture visibly
engineered to isolate the newline-handling risk, e.g. a minimal 1-row file),
and the blank-final-line / CRLF edge cases remain silently untested rather
than explicitly called out as accepted gaps anywhere in the diff.

## Verdict

APPROVED

## NEEDS_REWORK Items

None. (Non-blocking observations captured inline above: test-file module
docstring stale count, trades.csv "any row position" claim evidenced
structurally rather than by a dedicated non-first-row fixture, blank-final-line/
CRLF edge cases undocumented. None rise to a CP1–CP4 FAIL.)
