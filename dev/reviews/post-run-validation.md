Reviewed SHA: 59d9df84b8f3d8316218cfe268e120fdd5e1992f

## Structural QC — V18 store-level implausible-series check

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | 17 tests, 17 passed, 0 failed |
| P1 | Functions ≤ 50 lines (linter) | PASS | fn_length_linter passed as part of H3 |
| P2 | No magic numbers (linter) | PASS | magic-numbers linter passed as part of H3 |
| P3 | Config completeness | PASS | Four new fields (store_median_close_max, store_zero_volume_move_pct, store_zero_volume_max, store_min_bars) all carry [@sexp.default] and are routed through config; docstrings document semantics and defaults (10_000.0, 90.0, 0, 20) |
| P4 | Public-symbol export hygiene (linter) | PASS | mli-coverage linter passed as part of H3 |
| P5 | Internal helpers prefixed per convention | PASS | All V18 implementation helpers prefixed with _v18_* |
| P6 | Tests conform to project test-patterns rules | PASS | test_validator_store_check.ml: 17 tests all use `open Matchers`, all follow one-assert-that-per-value pattern with field/all_of/elements_are composition. Zero instances of the three documented anti-patterns (List.exists, let _ = result, match with assert_failure). |
| A1 | Core module modification FLAG | PASS | No modifications to portfolio/, orders/, position/, strategy/, engine/ |
| A2 | Dependency-direction rules respected | PASS | backtest/validation/lib carries weinstein.types (Tier 2, allowed under backtest/**); types is Tier 1 (allowed everywhere). No violations. |
| A3 | No unnecessary existing module modifications | PASS | Only docstring updates in validator_bar_checks.mli, validator_splice_check.mli, validator_checks.mli/ml — all justified to clarify V18's role. No logic changes to existing code. |

## Skip Discipline Finding (Item 2 from dispatch)

**V18 implements the Skip discipline correctly.** 

Evidence: The _v18_step function (validator_store_check.ml line 131–136) returns Skip (not silent Pass) in all three un-evaluable cases:
- Symbol absent from bar store (line 134)
- Series too short (line 135: `Array.length b.daily < store_min_bars`)
- Un-evaluable pair in phantom-print scan (line 126: `Move_unknown` when `prev_close ≤ 0.0`, admitting no ratio)

The Validator_step._absorb function (validator_step.ml) correctly increments the `skipped` counter for each Skip. Tests verify this: test_v18_skips_a_symbol_absent_from_the_store, test_v18_skips_a_series_shorter_than_the_bar_floor, and test_v18_skips_a_series_with_an_unevaluable_pair all assert `n_skipped = 1` and `passed = true` — demonstrating that Skips are counted and not invisible in the report (the violation is outranked by the level rule when both conditions are present, per test_v18_reports_rather_than_skips_when_the_level_rule_fires).

## Quality Score

5 — Exemplary implementation: all gates pass, comprehensive test coverage (17 cases pinning both rules, all false-negative protection, config routing, skip branches, and mutation-verified volume guard), disciplined module separation with justified naming, and no unnecessary modifications to existing code.

## Verdict

APPROVED

---

## Behavioral QC — V18 store-level implausible-series check

Re-ran `dune runtest --force trading/backtest/validation/test/` from the
`dune-workspace` root: exit 0, `test_validator_store_check.exe` **Ran: 17 tests**.
(Note for future reviewers: a non-`--force` run here returns exit 0 from cache
without executing anything, and invoking dune from `wt-qc-2750/trading/trading`
fails on `weinstein.types`. Both look like greens and are not.)

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test | PASS | `check_v18` .mli claims → tests: level rule → `test_v18_flags_the_mel_series`; phantom rule standalone → `test_v18_flags_a_phantom_print_in_an_ordinary_series`; "volume test evaluated first and short-circuits, a traded bar is clean whatever its move was" → `test_v18_does_not_flag_a_large_move_on_real_volume`; "unit of evaluation is the symbol… keyed to the earliest date" → `test_v18_reports_one_row_per_symbol_not_per_trade`; open positions as subjects → `test_v18_covers_a_symbol_held_only_as_an_open_position`; "a violation outranks an un-evaluable pair" → `test_v18_reports_rather_than_skips_when_the_level_rule_fires`; EXPECTATION registration → `test_v18_is_registered_as_an_expectation`. All four `check_config` field docstrings routed → `test_v18_{median_ceiling,move_threshold,zero_volume_ceiling,bar_floor}_comes_from_config`. |
| CP2 | Each PR-body "Tests" claim has a corresponding committed test | PASS | Verified each of the seven positives/negatives the body advertises exists by name in `test_validator_store_check.ml`. Body says "17 cases" — the runner reports exactly 17. Body's mutation claim (`bar.volume > c.store_zero_volume_max` → `false` turns "exactly the three volume-dependent tests" red) **independently re-verified** — see CP4 note. No advertised-but-absent test (the PR #478 failure mode). |
| CP3 | Identity/content pinned, not just counted | PASS | `test_v18_specimen_names_the_median_and_the_offending_bar` pins specimen **content** via `elements_are` + `field` on symbol, entry_date, and four exact detail substrings ("median close 175002.00", "above the 10000.00 ceiling", "bar 2017-02-08 close 12.20", "on volume 0") — not a bare violation count. `test_v18_reports_one_row_per_symbol_not_per_trade` pins the surviving row's `entry_date` identity (earliest of three), not just `size_is 1`. |
| CP4 | Each documented guard has a test exercising the guarded-against scenario | PASS | All three Skip branches named under the .mli's §Skips are pinned: absent symbol → `test_v18_skips_a_symbol_absent_from_the_store`; short series → `test_v18_skips_a_series_shorter_than_the_bar_floor`; non-positive prior close → `test_v18_skips_a_series_with_an_unevaluable_pair` — each asserting `n_skipped = 1`, not merely `passed`. One documented detail is unpinned (non-blocking, see Note 2). |

### Weinstein domain checklist (S\*/L\*/C\*/T\*)

**NA — all rows.** Per `.claude/rules/qc-behavioral-authority.md` §"When to skip
this file entirely": this is a post-run measurement-integrity check over the bar
store. It classifies no stage, places no stop, admits no candidate, and reads no
strategy config — it runs *after* a run, report-only, exit code always 0. There
is no domain logic for the S/L/C rows to test and no Weinstein authority
document bears on it. No `BOOK-CHECK-NEEDED` items arise. qc-structural did not
flag A1, so A1 is NA as well.

### Note 1 — skip visibility, traced to what a human actually sees

Structural confirmed the branches return `Skip`. Completing that at the report
level: `Validator_step._absorb` maps `Skip -> {acc with skipped = acc.skipped + 1}`
(`validator_step.ml:13`), `validator_checks.ml:48` carries it into
`check_result.n_skipped`, and `validator_report.ml:15` renders
`sprintf "%s (%d skipped)" head r.n_skipped` on the check's own line whenever the
count is non-zero. So a skipped symbol is **visible in the rendered report**, not
merely counted in a record a human never reads — which is the actual content of
`check_v13`'s "no un-evaluable row is invisible in the report", and the .mli's
citation of that precedent is accurate.

### Note 2 — one unpinned documented detail (non-blocking)

`store_min_bars`' docstring states *"At least one bar is always required
regardless of this value."* That guard is real and load-bearing —
`Int.max 1 c.store_min_bars` (`validator_store_check.ml:135`); without it,
`store_min_bars = 0` (a reasonable way to express "no floor") over a
zero-bar store entry reaches `_v18_median_close [||]` and raises on
`sorted.(0)`. Empty `daily` arrays are a contemplated case in this codebase —
`check_v13`'s .mli names "whose store entry carries no daily bars" explicitly.
No test covers it. Recorded as PASS rather than FAIL because every guard the
§Skips section names is pinned, and this clause sits in a *config field's*
docstring describing a floor on the config value rather than a data scenario the
check exists to detect. Suggested follow-up, not a rework condition: one case
with `store_min_bars = 0` and `daily = [||]` asserting `n_skipped = 1`.

Second, smaller: the phantom-only specimen (level rule silent, so
`_v18_level_part` correctly omits ", above the … ceiling") has its content
unpinned — `test_v18_flags_a_phantom_print_in_an_ordinary_series` asserts only
the count. The both-rules-fired detail is pinned thoroughly by the MEL test.

### Note 3 — mutation re-verification (independent)

Re-ran the author's mutation rather than taking it on report. Applied
`bar.volume > c.store_zero_volume_max` → `false`, re-ran with `--force`:

```
FAILED: Cases: 17 Tried: 17 Errors: 0 Failures: 3
  validator_store_check:5 :v18 does not flag a large move on real volume
  validator_store_check:10:v18 zero volume ceiling comes from config
  validator_store_check:14:v18 skips a series with an unevaluable pair
```

Exactly three, and the load-bearing negative is among them — so
`test_v18_does_not_flag_a_large_move_on_real_volume` genuinely pins the volume
condition and would not survive its removal. The author's claim is accurate as
stated. Source restored via `git checkout --`; working tree verified clean, no
`.orig`/`.bak` left behind.

### Note 4 — the judgment call the PR asks for: ship the literal rule

The author asks whether to narrow the level rule by requiring a large max/min
ratio alongside the high median (MEL spans ~20,000×, BRK.A ~1.2×), which would
exclude BRK.A. **My view: ship the literal rule as written, and do not adopt
that refinement as an AND-gate.** Three reasons, in increasing order of weight:

1. **The false-positive rate is not a "noise" problem.** The rule is on the
   **median** over the run window, so transient spikes cannot trip it. On a
   broad US universe the set of symbols with a median close above $10,000 is
   approximately {BRK.A} — NVR, SEB, AZO, pre-split AMZN/GOOG/BKNG all sit an
   order of magnitude below. That is ~1 flagged symbol per run against a
   10-specimen cap, triaged in one second by a human who reads the ticker. The
   "an Expectation nobody reads dies" failure mode needs volume of false
   positives; there is none here.
2. **The refinement would introduce a worse false negative.** A wide max/min
   span is a property of MEL's *mixture* ($170k plateau with $8-12 prints), not
   of mis-scaling as such. A listing uniformly mis-scaled — a foreign listing
   in a currency ~1000× off, with no stray prints — has an ordinary span of
   ~1.2-3× and would be **silently exonerated** by the ratio gate. That defect
   is the more insidious one: it produces no −99.99% blowup to draw attention,
   it just quietly distorts sizing all run (at $175k, one share *is* the
   ticket).
3. **It would collapse the check's orthogonality.** The two rules earn their
   keep by being independent. A wide intra-series span is substantially *what
   the phantom-print rule already detects*; gating the level rule on it makes
   the level rule near-redundant with the phantom rule and surrenders the one
   thing only it can see — a uniformly mis-scaled series. MEL itself would
   still be caught by the phantom half alone, so the refinement's demonstrated
   benefit on the motivating specimen is zero.

The escape hatch already shipped is the correct response to a noisy first run:
raise `store_median_close_max` (per the .mli, this silences the level rule while
the phantom half keeps running), rather than narrowing the predicate. If
calibration on the 26y record does surface real noise, I'd add the span as a
**specimen annotation** (so a triager sees "span 1.2×" and dismisses BRK.A
instantly) or as a separate sub-rule — not as a conjunct on the level rule. The
follow-up already recorded in `dev/status/post-run-validation.md` ("run V18 over
the canonical 26y record … to calibrate whether $10,000 is the right ceiling")
is exactly the right next step and is correctly scoped as calibration, not
redesign.

Deferring asks 1 (quarantine MEL) and 3 (re-run item-3 cells) is right — V18
makes the artifact detectable and explicitly does not restate any affected
number, and the status file records both as open rather than as done.

### `harness_gap`

`ONGOING_REVIEW`. No NEEDS_REWORK items. The level rule's threshold is a
judgment about what a plausible equity price is, which no golden scenario can
settle deterministically; Note 2's guard test is a plain unit-test gap, not a
harness gap.

## Quality Score

4 — Good: every documented contract is pinned, the load-bearing negative
survives independent mutation, and the specimen is content-pinned rather than
counted. Two small documented details go unpinned (Note 2), which is what keeps
it just short of reference-grade.

## Verdict

APPROVED
