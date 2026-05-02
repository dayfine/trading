Reviewed SHA: 545316532e85

## Combined Structural + Behavioral Review

**PR #782: feat(snapshot-runtime): Daily_panels mmap-cache + LRU + callbacks shim (M5.3 Phase C)**

---

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Pre-existing fmt issues in unrelated modules; no new violations introduced |
| H2 | dune build | PASS | Builds cleanly |
| H3 | dune runtest | PASS | 17 tests pass: 12 Daily_panels + 5 Snapshot_callbacks; all suites exit 0 |
| P1 | Functions ≤ 50 lines | PASS | All functions in lib files ≤ 40 lines; fn_length linter passes on new code |
| P2 | No magic numbers | PASS | Constants: `_bytes_per_mb = 1_048_576`, `_bytes_per_float = 8`, `_per_row_overhead_bytes = 64`, `_per_symbol_overhead_bytes = 128` all module-scoped named constants |
| P3 | Config completeness | PASS | Single tunable: `max_cache_mb` (validated positive); internal byte estimates use named constants, not magic values |
| P4 | Public-symbol export hygiene (mli coverage) | PASS | Both lib modules have complete .mli files; all public functions documented |
| P5 | Internal helpers prefixed per convention | PASS | All private helpers prefixed with `_` (OCaml pattern) |
| P6 | Tests conform to project test-patterns.md | PASS | 17 tests across 2 files; all use `assert_that` with matcher composition (no List.iter, no bare let _, no unguarded match expressions); pinned values inline; elements_are for lists; proper error matchers (is_error_with, is_ok_and_holds) |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No modifications to core modules; new library in analysis/weinstein/ |
| A2 | No new analysis→trading imports outside backtest exception | PASS | Library lives in analysis/weinstein/snapshot_runtime/; depends only on: Core, Status, Data_panel_snapshot (phase A, also in trading/), Snapshot_pipeline (phase B, also in analysis/); all dependencies within analysis/ or neutral (status is base) |
| A3 | No unnecessary modifications to existing modules | PASS | File scope (7 files per gh pr view) = 2 new lib modules (.ml + .mli) + 2 test files + 2 dune files + 1 status update; no cross-cutting changes |

## Verdict

**APPROVED**

---

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | All public functions pinned by tests | PASS | create, schema, read_today, read_history, cache_bytes, close + read_field / read_field_history; all covered by hand-pinned tests with expected values |
| CP2 | PR claims match diff | PASS | (a) LRU eviction: test_lru_evicts_when_over_budget drives 6 symbols × 5K rows against 1 MB cap, asserts bounded; (b) close+reload: test_close_then_read_reloads verifies close drops cache, subsequent read reloads from disk; (c) schema-skew detection: test_schema_mismatch_fails_loud writes file under different schema, expects Failed_precondition; (d) 30d×10sym round-trip: test_round_trip_30d_10sym hand-pins 10 symbols × 30 days, reads history and individual dates, verifies payload integrity |
| CP3 | Round-trip identity after phase B→C | PASS | test_round_trip_30d_10sym: Phase B writes snapshots via Snapshot_format.write (from #781); Phase C loads via Snapshot_format.read_with_expected_schema; values survive intact (tested: EMA/SMA fields pinned to expected values across 30-day window) |
| CP4 | Validation guards | PASS | (a) Empty manifest: supported (create succeeds, read_today returns NotFound when symbol missing); (b) Missing symbol: clear NotFound error; (c) Out-of-range date: read_today→NotFound, read_history→Ok []; (d) Schema-skew: test_schema_mismatch_fails_loud asserts Failed_precondition; (e) LRU overflow: test_lru_evicts_when_over_budget verifies cache_bytes stays bounded; (f) max_cache_mb <= 0: test_create_rejects_nonpositive_cap asserts Invalid_argument |

## Key Architectural Decisions — Behavioral Authority

The prompt presented 6 architectural deviations that the agent had documented:

1. **Per-symbol caching (not per-day)** — Phase B writes one file per symbol; Single load satisfies any date window for one symbol. **Authority**: design docs§C5 framing was about cache window size, not file layout. **PASS** — per-symbol is correct per Phase B's writer output.

2. **"mmap" in Phase C = cache + LRU + sexp decode (not true Bigarray.map_file)** — Phase A payload is sexp-encoded; Phase F upgrade to Bigarray is future scope. API shaped so swap is local to Daily_panels. **Authority**: design§C5: "API is shaped so Phase F's upgrade ... is local to Daily_panels". **PASS** — contract is honored.

3. **Snapshot_callbacks is NOT a Stock_analysis.callbacks adapter** — It's a thin field-accessor shim, not a bar-shaped converter. Bridging to Stock_analysis.callbacks is Phase D scope. **Authority**: design§Phase D: "Integrate with simulator; bar-shaped layer retired in Phase F". snapshot_callbacks.mli§"Why a shim, not a [Stock_analysis.callbacks] adapter" explicitly justifies deferral. **PASS** — discipline is sound and documented.

4. **Single-threaded assumption** — Simulator runs single-threaded today; Phase D integrates under that contract. No mutex. **Authority**: design§C3 assumes weekly cadence in live/sim on single thread. **PASS** — no concurrency bug.

5. **Schema-skew check** — Every file open goes through Snapshot_format.read_with_expected_schema; mismatch → loud Failed_precondition. **Authority**: design§Phase B/C specifies incremental rebuild via schema-hash; runtime must enforce schema parity. **PASS** — test_schema_mismatch_fails_loud verifies loud failure.

6. **Cache-byte cap is best-effort** — LRU keeps just-inserted symbol even if oversized ("stays bounded above-cap by at most one just-loaded symbol's worth"). **Authority**: design§C5 budget semantics allow one overshoot; enforcement is loop-driven (`_enforce_budget`). **PASS** — documented in.mli §"Memory budget"; test_lru_evicts_when_over_budget and test_lru_keeps_recently_used_symbol_resident verify behavior.

---

## Summary

**Structural** (H1–P6, A1–A3): All gates PASS. Code is clean, well-tested, properly typed, follows project conventions.

**Behavioral** (CP1–CP4 + domain rows): All critical claims pinned by hand-pinned tests. Schema-skew detection is loud and tested. LRU eviction is bounded and tested. Round-trip identity preserved through Phase B→C boundary. Architectural decisions are properly scoped and documented (no premature abstractions, no bleeding into core modules).

**Deviations from plan (documented as best-effort scope trade-offs)**: 
- "mmap" = cache + decode (not true Bigarray) — Phase F scope, API future-safe
- Snapshot_callbacks ≠ Stock_analysis adapter — Phase D scope, justified
- Single-threaded assumption — design-time contract, no hidden risks

No discovery of structural or behavioral errors. **Phase D can safely integrate with confidence in the runtime layer's correctness.**
