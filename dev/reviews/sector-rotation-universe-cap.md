Reviewed SHA: 753ec3c47742d3a1f41353419ff61b8839329721

## Structural QC — sector-rotation-universe-cap (rework)

Re-review of PR #1438 after test-only rework commit `753ec3c4`. The delta since prior approval (tip `2400505c`) is **one test function** (+37 lines) in `trading/trading/weinstein/strategy/test/test_sector_rotation_weinstein_strategy.ml`: `test_sector_cap_unmapped_survives`.

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No formatting violations |
| H2 | dune build | PASS | Entire project builds cleanly |
| H3 | dune runtest trading/weinstein/strategy/test/ | PASS | All tests pass; linters (fn_length, magic_numbers, mli_coverage, nesting) clean |
| P1 | Functions ≤ 50 lines (linter) | PASS | Linter passed as part of H3 |
| P2 | No magic numbers (linter) | PASS | Linter passed as part of H3 |
| P3 | Config completeness | NA | No new config fields added in this rework |
| P4 | Public-symbol export hygiene (linter) | PASS | Linter passed as part of H3 |
| P5 | Internal helpers prefixed per convention | NA | Test-only; no new internal helpers |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | New test `test_sector_cap_unmapped_survives`: single `assert_that` with proper matcher composition; no nested `assert_that`. Conforms fully. |
| A1 | Core module modifications | NA | No modifications to core modules (test-only rework) |
| A2 | Dependency-direction rules respected | NA | Test-only; no new cross-module imports |
| A3 | No unnecessary existing module modifications | PASS | Only the test file touched; no drift to other modules |

### Verdict

**APPROVED**

---

## Behavioral QC — sector-rotation-universe-cap (rework re-review)

Re-review of PR #1438 after test-only rework commit `753ec3c4`, which adds one test (`test_sector_cap_unmapped_survives`) to close the prior CP4 finding (review 4415175931, tip `2400505c`: NEEDS_REWORK, quality 4 — the single open finding was the untested unmapped-symbol-singleton-sector guard).

Verified natively (`TRADING_IN_CONTAINER=1`, `eval $(opam env)`): `dune runtest trading/weinstein/strategy/test/` green; the sector-rotation runner reports **15 tests, OK** (14 prior + 1 new). The guarded code (`sector_rotation_signals.ml` `_sector_key`/`_admit`) is unchanged since the prior approval; CP1–CP3 and all domain rows remain PASS as previously assessed.

**Mutation verification of CP4:** I injected a regression making the `None` arm of `_sector_key` collide with the binding real sector key (`"sector:Information Technology"` instead of `"symbol:" ^ symbol`) and re-ran the suite — `test_sector_cap_unmapped_survives` FAILED (1 failure / 15). Restoring the source returned the suite to 15 OK. This confirms the new test genuinely pins the "unmapped symbol is never capped away" guard rather than passing vacuously.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial `.mli` docstring claim has an identified test | **PASS** | Unchanged from prior approval. `rank_top_k_capped` `None` ⇒ `rank_top_k` (uncapped suite, `test_k3_holds_top_three`); `Some n` cap → `test_sector_cap_one_per_sector`; unmapped-singleton guard (mli 42-44) → now `test_sector_cap_unmapped_survives`. |
| CP2 | PR-body "Test coverage" claims have a matching committed test | **PASS** | All advertised tests present, including the rework's unmapped-survives scenario. |
| CP3 | Pass-through / identity / no-op tests pin identity, not just size | **PASS** | Outcome assertions use whole-list `equal_to [...]`, not `size_is`. |
| CP4 | Each guard named in docstrings has a test exercising the guarded scenario | **PASS** | The guard "a symbol that maps to `None` is its own singleton sector and is never capped away" (`sector_rotation_signals.mli` lines 42-44) is now pinned by `test_sector_cap_unmapped_survives`: AAPL+MSFT→Information Technology (mapped, cap binding), UNK→`None` (unmapped); RS ranks MSFT > UNK > AAPL; `sector_cap = Some 1`, `k = 3`. The asserted held-set `equal_to ["MSFT"; "UNK"]` (sorted) admits the higher-RS IT name plus the unmapped name, with the second IT name (AAPL) dropped to the cap. Whole-list domain assertion. Mutation test (above) confirms a shared-key regression fails this test. |

### Behavioral Checklist (Weinstein domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core-module change is strategy-agnostic | **NA** | No core module touched (test-only rework). |
| S1–S4 | Stage definitions | **NA** | Reuses `Stage.classify`; unchanged. |
| S5 | Buy only Stage 2, breakout + volume | **PASS** | Cap operates only on `is_stage2_advance` candidates. weinstein-faithful-core spine 2. |
| S6 | No buy in Stage 1/3/4 | **PASS** | Only Stage-2 candidates reach the ranker; `test_no_stage2_no_entry` green. |
| L1–L4 | Stop rules / state machine | **NA** | No stop change. |
| C1 | Screener cascade order | **NA** | Testbed has no cascade by design. |
| C2 | Bearish macro blocks buys | **NA** | Macro gate pre-existing; unchanged. |
| C3 | Sector selection uses RS vs market | **PASS** | Cap reorders within the existing RS order only. weinstein-book-reference §3.2; spine 7. |
| T1–T3 | Stage-transition / macro / trailing coverage | **NA** | Out of scope for this PR. |
| T4 | Tests assert domain outcomes, not "no error" | **PASS** | New test asserts the exact held-set `equal_to ["MSFT"; "UNK"]`. |

### Weinstein-faithful-core & experiment-flag-discipline

Unchanged from prior approval: W1/W2 PASS (universe-override + sector cap are config-expressed dials; spine intact), R1/R2/R3 PASS (default-off `sector_cap : int option [@sexp.default None]`, `sector_of` default `fun _ -> None`; searchable; no default flipped).

## Quality Score

5 — The one open finding (CP4 unmapped-singleton guard) is now pinned by a sharp, deterministic domain-outcome test; mutation-verified to fail on the guard regression. All CP rows and domain rows PASS.

## Verdict

APPROVED
