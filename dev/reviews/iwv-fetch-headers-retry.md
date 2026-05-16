Reviewed SHA: 66f30750d9e6f1e11ae8ebaf70a0f6c3dd9a8a60

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No formatting violations |
| H2 | dune build | PASS | All targets build successfully |
| H3 | dune runtest | PASS | 64 tests, 64 passed, 0 failed (9+17+17+21 across 4 test modules in ishares/) |
| P1 | Functions ≤ 50 lines (linter) | PASS | fn_length_linter passed as part of H3; longest functions are ~25 lines |
| P2 | No magic numbers (linter) | PASS | magic_numbers linter passed as part of H3 |
| P3 | Config completeness | PASS | Backoff intervals and retry thresholds are parameterized in the executable; no hardcoded tuning constants leaking into library |
| P4 | Public-symbol export hygiene (linter) | PASS | mli_coverage linter passed as part of H3 |
| P5 | Internal helpers prefixed per convention | PASS | All private helpers prefixed with `_` (e.g. `_attempt_fetch`, `_retry_loop`, `_file_exists_and_nonempty`, `_browser_headers`) |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | 36 assert_that calls across test file; all use Matchers composition (elements_are, field, all_of, is_ok_and_holds, is_error); no nested assert_that inside callbacks; one assert per value; retry tests use mock fetch/sleep for unit-testability |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; feature isolated to analysis/data/sources/ishares/ |
| A2 | No new `analysis/` imports into `trading/trading/` outside exception surface | PASS | No imports from analysis/ into trading/trading/; all changes are within analysis/data/sources/ishares/ |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only files touched are in ishares/bin/: fetch_iwv_history_lib.{ml,mli}, fetch_iwv_history.ml, bin/dune, test/test_fetch_iwv_history_lib.ml, test/dune |

## Verdict

APPROVED

## Summary

PR #1131 implements browser-like HTTP headers (User-Agent, Accept, Accept-Language, Referer) and exponential-backoff retry logic (503/429/502/504, 5s/30s/120s, 3 retries max) for the IWV fetcher to overcome Akamai WAF blocking. The implementation is architecturally clean:

- **Library-executable separation**: `fetch_iwv_history_lib.mli` exports a pure retry abstraction with injectable `fetch` and `sleep` functions; the executable wires concrete HTTP and timing. Tests mock both, avoiding network dependency.
- **Test coverage**: 4 retry scenarios (success, recovery after one error, exhaustion, fatal error) plus 17 date-enumeration and cache-management tests.
- **Code quality**: All internal helpers prefixed, functions ≤50 lines, no magic numbers, proper error classification (Retryable vs Fatal).
- **Scope isolation**: Feature entirely within `analysis/data/sources/ishares/`; no core-module drift.

All build gates pass; all tests pass.

---

# Behavioral QC — iwv-fetch-headers-retry
Date: 2026-05-16
Reviewer: qc-behavioral
Reviewed SHA (actual branch tip): 66f30750c2c9950e3442b8897d486c46aca77454
  (NB: the structural section's `Reviewed SHA: 66f30750d9e6f1e11ae8ebaf70a0f6c3dd9a8a60`
  does not resolve to any git object; the 8-char prefix `66f30750` matches the
  actual branch tip, suggesting a transcription typo in the structural agent
  output. Behavioral review confirms the actual branch tip.)

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | `fetch_iwv_history_lib.mli` lines 104–134 add `type fetch_attempt` + `val retry_with_backoff`. Claim → test pin: (a) "1 + List.length backoff_seconds attempts" → `test_retry_returns_ok_on_first_attempt` (1) + `test_retry_recovers_after_one_503` (2) + `test_retry_gives_up_after_max_attempts` (1+3=4); (b) "first attempt runs immediately" → `test_retry_returns_ok_on_first_attempt` (intervals = empty); (c) "On Retryable_error, sleeps for next backoff interval and re-attempts" → `test_retry_recovers_after_one_503` (one sleep at 5.0); (d) "On Ok_body, returns Ok body immediately" → both Ok tests pin the body string ("payload-body" / "after-retry"); (e) "On Fatal_error, returns the error immediately without retrying" → `test_retry_does_not_retry_fatal_error` (1 call, 0 sleeps, Status.Internal); (f) "After exhausting the backoff list … surfaces … as the final error" → `test_retry_gives_up_after_max_attempts` (Status.Internal). Minor under-pin: the last-message claim is asserted only by error-class, not message text, but the contract phrasing is loose ("as the final error"), so PASS. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body §"Test plan" enumerates four tests by name; all four are present in `test_fetch_iwv_history_lib.ml`: `retry_returns_ok_on_first_attempt` (line 316), `retry_recovers_after_one_503` (line 326), `retry_gives_up_after_max_attempts` (line 339), `retry_does_not_retry_fatal_error` (line 359). Each pins the exact behavior the PR body claims (call count, sleep schedule, final result). Test-count claim "17 → 21" verified (`grep -c '^         "' ...` = 21 entries in suite). |
| CP3 | Pass-through / identity / invariant tests pin identity (not just size_is) | NA | No pass-through / identity semantics in this feature. All retry tests pin (a) result value or error class, (b) call count via `equal_to N`, and (c) sleep intervals via `elements_are [float_equal 5.0; …]` — not size-only. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | (a) Inline comment on `test_retry_does_not_retry_fatal_error`: "Guards against a future regression where the classifier might accidentally mark a 4xx as retryable." → test directly exercises a `Fatal_error` outcome and asserts call_count=1 + intervals=empty. (b) `.mli` Retryable_error docstring (line 107) cites "HTTP 503 / 429 / 502 / 504"; `_is_retryable_status` (`fetch_iwv_history.ml` lines 45–49) maps exactly that set, and the retry-on-Retryable contract is exercised end-to-end by the four retry tests. No other explicit guard claims appear in docstrings. |

## Authority cross-check — `dev/notes/iwv-scrape-akamai-block-2026-05-16.md`

The blocker note is not currently in the tree at this SHA (lives only on the
parent worktree's main snapshot at `b187919c…`), but its content is the
governing authority for this PR per the PR body. Verified line-by-line:

- **Note §"What needs to happen" item 1 — browser headers (UA / Accept /
  Accept-Language / Referer).** Implementation `_browser_headers`
  (`fetch_iwv_history.ml` lines 27–37) matches exactly: Chrome 120 on macOS
  10_15_7 UA, `text/csv,application/csv,*/*;q=0.8` Accept,
  `en-US,en;q=0.9` Accept-Language, IWV product-page Referer. The Chrome 120
  release (Dec 2023) is a real, publicly-known version — satisfies the
  "plausible UA" requirement.
- **Note §"What needs to happen" item 2 — 3 retries with 5/30/120 sleep.**
  Implementation `_retry_backoff_seconds_5xx = [5.0; 30.0; 120.0]`
  (`fetch_iwv_history.ml` line 43) matches exactly; 3-retry budget
  enforced by `_retry_loop` (`fetch_iwv_history_lib.ml` lines 166–175).
- **Note's retryable-status set (503 / 429).** Implementation
  `_is_retryable_status` covers 503 / 429 / 502 / 504 — a superset of the
  note's requirement (the extra 502/504 are reasonable transient-failure
  classes; the docstring also enumerates them). PASS.

## Behavioral Checklist

Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file
entirely": this is a pure data-foundation tooling PR (HTTP retry + headers
for an iShares scraper). Weinstein domain checklist (S*/L*/C*/T*) is NA —
no stage logic, no portfolio logic, no screener logic touched.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1; no core-module changes |
| S1–S6 | Stage definitions / buy criteria | NA | Pure infra / data-foundation PR; domain checklist not applicable |
| L1–L4 | Stop-loss rules | NA | Pure infra / data-foundation PR; domain checklist not applicable |
| C1–C3 | Screener cascade / macro / sector | NA | Pure infra / data-foundation PR; domain checklist not applicable |
| T1–T4 | Domain test coverage | NA | Pure infra / data-foundation PR; domain checklist not applicable |

## Quality Score

5 — Exemplary contract pinning: every `.mli` claim has a named test, every
PR-body claim has a committed test of the same name, retry tests pin both
the value and the side-effect schedule (call count + sleep intervals via
`elements_are`), and the implementation matches the authority blocker
note's recommended parameters verbatim. Library/exec separation with
injectable `fetch` + `sleep` makes the helper unit-testable without HTTP
or wall-clock waits.

## Verdict

APPROVED
