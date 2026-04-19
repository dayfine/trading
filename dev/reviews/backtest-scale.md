Reviewed SHA: 8c58cf8a83460c2cf9183a19c8a5e8f5818719c4

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; no formatting diff |
| H2 | dune build | PASS | Exit 0; all modules compile |
| H3 | dune runtest | PASS | 7 tests (bar_loader), 7 passed, 0 failed. Full-repo exit code 1 is pre-existing linter noise (runner.ml:193 fn-length, weinstein_strategy.ml file-length, trace.ml magic-number, nesting linter — all in files untouched by this PR; confirmed by zero diff against origin/main for all flagged paths) |
| P1 | Functions ≤ 50 lines — covered by fn_length_linter (dune runtest) | PASS | No new functions in bar_loader exceed 50 lines; fn_length_linter failure is pre-existing on runner.ml:193 which is unchanged in this PR |
| P2 | No magic numbers — covered by linter_magic_numbers.sh (dune runtest) | PASS | bar_loader.ml contains only ordinal constants (0, 1, 2 in _tier_rank), semantic zeros (0 counts in stats init), and None sentinels — none are domain tunables. Magic-number linter failures are pre-existing on weinstein_strategy.ml and trace.ml, both unchanged in this PR |
| P3 | All configurable thresholds/periods/weights in config record | NA | Bar_loader 3a has no domain thresholds or tunable parameters. It is a data structure (tier-keyed map + Price_cache wrapper). No config surface needed at this increment. |
| P4 | .mli files cover all public symbols — covered by linter_mli_coverage.sh (dune runtest) | PASS | bar_loader.mli declares all 8 public values: create, promote, demote, tier_of, get_metadata, get_summary, get_full, stats. No public symbol is missing. |
| P5 | Internal helpers prefixed with _ | PASS | Internal helpers: _tier_rank, _load_metadata, _promote_one_to_metadata, _unimplemented_tier — all correctly prefixed. Public API (create, promote, demote, tier_of, get_metadata, get_summary, get_full, stats) are all declared in the .mli. |
| P6 | Tests use the matchers library (per CLAUDE.md) | PASS | test_metadata.ml opens Matchers and uses assert_that, is_ok, is_error, is_error_with, is_none, is_some_and, all_of, field, equal_to, float_equal throughout |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | Zero diff in trading/trading/orders/, trading/trading/portfolio/, trading/trading/engine/, trading/trading/strategy/ |
| A2 | No imports from analysis/ into trading/trading/ | PASS | bar_loader.ml imports: Core, Trading_simulation_data.Price_cache, Status, Types (Fpath via dune). No analysis/ modules imported. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only files changed: dev/status/backtest-scale.md (status update — appropriate), and 5 new files under trading/trading/backtest/bar_loader/ (all new, no existing module touched). Plan-forbidden modules Bar_history, Weinstein_strategy, Simulator, Price_cache, Screener confirmed unmodified (zero diff). |

## Scope Verification

- **Scope honored**: Only 3a is implemented. Summary.t and Full.t do not exist as real implementations — get_summary and get_full return `unit option = None` (placeholders). promote to Summary_tier or Full_tier returns `Error Status.Unimplemented`. No scope creep.
- **No forbidden module edits**: Bar_history, Weinstein_strategy, Simulator, Price_cache, Screener — all zero diff vs origin/main.
- **Module boundary**: bar_loader/dune declares `(public_name trading.backtest.bar_loader)` as a standalone library. backtest/lib/dune does not list bar_loader as a dependency. Independent library confirmed per plan §Resolutions #4.
- **Tier variant declared up front**: `type tier = Metadata_tier | Summary_tier | Full_tier [@@deriving show, eq, sexp]` is in both bar_loader.ml and bar_loader.mli. All three variants available to later increments without churn.
- **Test enumeration**: Plan §3a requires: create empty, promote 10 symbols, stats, idempotent re-promote, get_metadata returns data (5). Agent added two extras: missing-symbol error, higher-tier Unimplemented. All 7 are present and passing.

## Documentation Note (non-blocking)

bar_loader.mli line 20 reads: "[promote ~to_:Summary_tier] and [promote ~to_:Full_tier] raise [Failure]". The actual implementation returns `Error { code = Status.Unimplemented; ... }` — it does not raise. The `val promote` docstring (lines 85-87) is accurate. This is a stale phrase in the module-level overview docstring; the val-level contract is correct. Not a structural FAIL — implementation is correct — but the module docstring should be corrected (s/raise [Failure]/return [Error Status.Unimplemented]/) to avoid misleading callers.

## Verdict

APPROVED

No structural FAILs. All hard gates pass. Module boundary, tier variant, and test enumeration verified against the plan. The mli module-level docstring inconsistency (line 20: "raise [Failure]" vs actual Error return) is a minor doc cleanup item, not a rework blocker.

---

# Behavioral QC — backtest-scale Step 3a (Bar_loader scaffold + Metadata tier)
Date: 2026-04-19
Reviewer: qc-behavioral

## Context

This slice is pure plumbing — types + scaffolding for a multi-increment plan
(`dev/plans/backtest-tiered-loader-2026-04-19.md`, §Increments → 3a). The
Weinstein domain axes (stage classification, stops, screener, macro gates,
position sizing) are **not exercised** by this PR. Behavioral review focuses
on plan faithfulness, data semantics (Metadata's `last_close` at/before
`as_of`), idempotency / demote semantics, and the absence of leaks into
existing modules.

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1; zero diff in Portfolio/Orders/Position/Strategy/Engine. New sibling library; no core module touched. |
| S1 | Stage 1 definition matches book | NA | No stage classification logic in this slice. |
| S2 | Stage 2 definition matches book | NA | No stage classification logic. `Summary.t` (which will carry `stage_heuristic`) is deferred to 3b. |
| S3 | Stage 3 definition matches book | NA | Same. |
| S4 | Stage 4 definition matches book | NA | Same. |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | No buy logic; Metadata tier only carries last-close scalars, not signals. |
| S6 | No buy signals in Stage 1/3/4 | NA | Same. |
| L1 | Initial stop below base | NA | No stop logic in this slice. |
| L2 | Trailing stop never lowered | NA | Same. |
| L3 | Stop triggers on weekly close | NA | Same. |
| L4 | Stop state machine transitions | NA | Same. |
| C1 | Screener cascade order | NA | Screener is not wired into `Bar_loader` in 3a; shadow screener is 3f. |
| C2 | Bearish macro blocks all buys | NA | No macro gating in this slice. |
| C3 | Sector RS vs. market, not absolute | NA | `Summary.rs_line` is deferred to 3b. `Metadata.sector` is a string loaded from a caller-supplied map — no RS computation here. |
| T1 | Tests cover all 4 stage transitions | NA | No stage logic to test. |
| T2 | Bearish macro → zero buy candidates test | NA | No macro gate in this slice. |
| T3 | Stop trailing tests | NA | No stops in this slice. |
| T4 | Tests assert domain outcomes | PASS | Tests assert concrete field values (sector = "Tech" vs "", last_close = 100.0 vs 101.0, tier counts, error kinds via `is_error_with Unimplemented`) — not just "no error". Matchers library used throughout per `.claude/rules/test-patterns.md`. |

## Plan-Faithfulness Checklist (scaffolding-specific)

Because this increment is plumbing, the reviewable contract is the plan
(`dev/plans/backtest-tiered-loader-2026-04-19.md` §Increments → 3a, §Approach,
§Resolutions, §Risks). Table below cross-checks the implementation against
those sections.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| PF1 | `Metadata.t` fields match plan sketch (symbol, sector, last_close, avg_vol_30d, market_cap) | PASS | Plan §Approach→Module boundary lines 108-114. Implementation: `bar_loader.mli:36-48`, `bar_loader.ml:10-17` — all five fields present. |
| PF2 | `market_cap` and `avg_vol_30d` typed as `float option`, populated `None` in 3a | PASS | Plan §Risks #4 option (a): "include cap/volume in Metadata.t only when available, treat as None otherwise". `bar_loader.ml:83-84` sets both to `None`. |
| PF3 | `tier` variant declares all three tags (Metadata_tier, Summary_tier, Full_tier) up front | PASS | Plan §Approach→Module boundary line 133. Variant declared in both `.mli` (line 30) and `.ml` (line 6) with full three-way split; later increments extend behaviour without variant churn. |
| PF4 | `promote ~to_:Metadata_tier` reads last bar via `Price_cache` and joins caller-supplied sector map | PASS | Plan §Approach rejects unifying Price_cache (Rejected alternatives #3): "Keep Price_cache as the raw-CSV layer; Bar_loader calls into it for bounded date ranges". `bar_loader.ml:66` calls `Price_cache.get_prices` with `~end_date:as_of`; `bar_loader.ml:75-76` joins `Hashtbl.find t.sector_map symbol` with `""` default — matches the "loader does not synthesize a sector" note in `bar_loader.mli:39-41`. |
| PF5 | Summary / Full promotions return unimplemented (not stubbed succeed, not raise) | PASS | Plan §Increments 3a: "In 3a, promote ~to_:Summary_tier and promote ~to_:Full_tier raise [Failure]". Actual implementation returns `Error { code = Unimplemented; ... }` (bar_loader.ml:101-111), which is functionally equivalent and safer (callers get a typed error). This is a minor deviation in form (Result rather than exn) that qc-structural already flagged as a docstring cleanup item. Covered by test_higher_tier_promotions_unimplemented. |
| PF6 | `get_summary` / `get_full` placeholders return `None` with stable-signature rationale | PASS | `bar_loader.mli:110-117`: "unit option to keep the interface signature stable until 3b introduces Summary.t". Matches plan §Approach principle "tier is a type, not a subset" — keeping 3a's interface stable so 3b replaces only the return type. |
| PF7 | `promote` is idempotent: symbol at tier ≥ to_ is left alone | PASS | Plan §Approach→Module boundary line 150: "Idempotent for symbols already at >= to_". Implementation uses `_tier_rank` (bar_loader.ml:56-59) and the early-return at line 92 — confirmed by `test_promote_is_idempotent` (test_metadata.ml:142-156) which asserts `stats_before = stats_after`. |
| PF8 | `demote` semantics don't introduce Summary-stop path; to_=Metadata means full drop | PASS | Plan §Resolutions #6: "Full demote lands at Metadata (full drop, rebuild Summary on next promote)". For 3a, `demote` is an intentional no-op (bar_loader.ml:120-123); the inline comment acknowledges this and notes the signature is stable so 3b/3c wire real demotion without churn. No accidental Summary-intermediate path introduced. |
| PF9 | Date semantics: `last_close` = close of last bar on or before `as_of` | PASS | `bar_loader.mli:43` explicitly documents this: "Close price of the last bar on or before [as_of]". Implementation at `bar_loader.ml:66-74` calls `Price_cache.get_prices ~end_date:as_of` (inclusive upper bound per `price_cache.mli:36`) and picks `List.last_exn bars` — last in a list "sorted by date (oldest first)" (price_cache.mli:37). Correct for backtest-replay semantics (reconstructing point-in-time metadata), distinct from calendar-today semantics. Test fixture confirms: bars dated 2024-01-03/04/05, as_of = 2024-01-31 → last_close = 100.0 for S01 (the Jan-5 close). |
| PF10 | Failed symbol load is NOT inserted into the loader | PASS | `bar_loader.ml:93-99`: the `Hashtbl.set` only runs on the `Ok metadata` branch. Test `test_promote_missing_symbol_errors` (test_metadata.ml:158-169) asserts `tier_of ~symbol:"NOPE"` is `None` and `stats.metadata = 0` after a failed promote. Matches `bar_loader.mli:91`: "A symbol that fails to load is not added to the loader." |
| PF11 | Dependency direction: bar_loader → simulation/data/price_cache, NOT reversed | PASS | `bar_loader/dune:4` lists `trading.simulation.data` as a dep. Grep of `trading/trading/simulation/` for `bar_loader` — zero references. Matches plan §Approach→Module boundary arrow diagram (lines 97-102). |
| PF12 | Test coverage matches plan's enumerated unit tests | PASS | Plan §Increments 3a lists: "create empty, promote 10 symbols, stats, idempotent re-promote, get_metadata returns data" (5 tests). Implementation has all 5 plus 2 defensive extras: `test_promote_missing_symbol_errors` (exercises error branch), `test_higher_tier_promotions_unimplemented` (pins the Unimplemented return type). Extras are valuable guards against accidental premature implementation of 3b/3c. |
| PF13 | No behaviour leak into Bar_history, Weinstein_strategy, Simulator, Price_cache, Screener | PASS | qc-structural confirmed zero diff in those paths. Plan §Files to change line 579-581 explicitly forbids touching them. Import graph verified: `bar_loader` imports from `simulation.data`; no reverse edge. |

## Quality Score

5 — Exemplary scaffolding slice. Plan faithfulness is meticulous — every
contract in §Approach, §Resolutions, and §Risks is either implemented
or explicitly parked (with a comment pointing to the increment that will
implement it). Date semantics for `last_close` are correctly documented
and tested. Idempotent-promote and fail-without-insert semantics have
dedicated tests. The mli/ml pair is clean, variants are declared full-width
for forward stability, and the `Result`-over-exception choice for
unimplemented tiers is actually a safety upgrade over the plan's
"raise [Failure]" phrasing. (The lingering "raise [Failure]" phrase in the
module-level docstring is a doc cleanup item already noted by
qc-structural — does not affect behavioural correctness.)

## Verdict

APPROVED

Every applicable check is PASS. Domain-axes checks (stage, stops,
screener, macro) correctly marked NA — this scaffolding slice doesn't
exercise any Weinstein domain logic by design. No domain leaks, no
scope creep, faithful to the plan.
