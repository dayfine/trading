Reviewed SHA: 900546f183df0cc71203675909554069e2c583a1

## Structural QC — declining-ma-gate

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | CI green on tip SHA (build-and-test SUCCESS) |
| H2 | dune build | PASS | CI green on tip SHA (build-and-test SUCCESS) |
| H3 | dune runtest | PASS | CI green on tip SHA (build-and-test SUCCESS); full linter suite included |
| P1 | Functions ≤ 50 lines (linter) | PASS | All functions under 50 lines: declining_ma_gate.ml (15 lines, 2 fns), entry_assembly.ml (16 lines, 1 fn). CI linters clean. |
| P2 | No magic numbers (linter) | PASS | CI linters clean (no magic-numbers violations) |
| P3 | Config completeness | PASS | New mechanism `reject_declining_ma_long_entry` is a real bool config field with `[@sexp.default false]` (R1 satisfied: no-op default). Documented in config.mli with rationale + experiment-ledger reference. |
| P4 | Public-symbol export hygiene (linter) | PASS | .mli files present (declining_ma_gate.mli, entry_assembly.mli); CI mli-coverage linters passed |
| P5 | Internal helpers prefixed per convention | PASS | declining_ma_gate.ml has `_keep` prefixed; entry_assembly.ml has all public functions (`assemble`). No violations. |
| P6 | Tests conform to test-patterns.md | PASS | test_declining_ma_gate.ml: opens Matchers, uses assert_that + elements_are matcher composition. No List.exists(equal_to bool), no dropped Result assertions, no nested assert_that in callbacks. 2 unit tests, both domain-focused assertions (tickers retained/dropped). |
| A1 | Core module modifications | PASS | No edits to trading/trading/{portfolio,orders,position,strategy,engine}/. All work under trading/trading/weinstein/strategy/. Entry_assembly, declining_ma_gate are new feature sub-modules. |
| A2 | No analysis→trading imports outside allow-list | PASS | No analysis/ imports in dune files. All dependencies are within weinstein and trading.base/trading.portfolio/trading.strategy (which are fine). |
| A3 | No unnecessary modifications to existing modules | PASS | PR file list (12 files): 4 new (declining_ma_gate.{ml,mli}, entry_assembly.{ml,mli}), 8 edits to strategy feature modules (config, screening, dune, test). All edits support the feature. screening.ml refactor reduces 500→490 lines (honest extraction, not scope creep). |

## Verdict

APPROVED

All structural checks pass. Build gates covered by CI (green on 900546f1). Config flag properly defaults-off per experiment-flag-discipline R1/R2. Test patterns conform. No core module leakage. Architecture clean.

## Behavioral QC — declining-ma-gate

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial .mli docstring claim pinned by a test | PASS | `declining_ma_gate.mli`: reject=false identity → `test_default_is_noop` (3 retained, in order); reject=true drop-Long-Declining/keep-Rising-Long+Shorts → `test_drops_declining_longs_only`. `entry_assembly.mli` no-op default pinned by `test_default_is_noop` + existing integration tests (CI green). Minor: the `Flat`-MA-Long sub-claim has no distinct candidate but shares the tested `Rising` code path (`not (equal Declining)`). |
| CP2 | Each PR-body claim has a test | PASS | default-off, drops declining-MA longs, shorts unaffected, bit-identical-with-flag-off — all pinned by the two committed tests. No advertised test missing. |
| CP3 | Identity/pass-through tests pin identity not size | PASS | `test_default_is_noop` uses `elements_are [equal_to ...]` on the full ordered ticker list, not `size_is`. |
| CP4 | Each docstring guard exercised | PASS | "Shorts never touched" guard → `SHORT_DECLINING` retained in `test_drops_declining_longs_only`; drop-guard → `LONG_DECLINING` dropped. |

### Behavioral Checklist (domain — most NA, this is an entry-gate tightening)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| S5 | Buy criteria: Stage-2 entry on rising-MA breakout | PASS | Tightens the buy rule toward the book's Stage-2 = "price above a rising 30-week MA"; drops misclassified declining-MA "Stage-2" longs. Volume/breakout untouched. |
| S6 | No buy signals in Stage 1/3/4 | PASS | Strengthens the invariant — a declining-MA "Stage-2" is a Stage-4 bounce; dropping it removes a buy that should not have fired. |
| T4 | Tests assert domain outcomes | PASS | Both tests assert which tickers survive the gate, not "no error". |
| (others) | S1–S4, L1–L4, C1–C3, T1–T3, A1 | NA | Not a stage-classifier / stops / screener-cascade / macro change; qc-structural did not FLAG A1. |

### Weinstein-faithful core

| # | Check | Status | Notes |
|---|-------|--------|-------|
| W1 | Spine intact | PASS | Spine item 2 (buy only in Stage 2) is **tightened**, not violated. No buy outside Stage 2 added; volume confirmation, macro/sector gates, and short logic untouched; every `Short` retained. |
| W2 | Adaptation is a config-expressed, book-faithful dial | PASS | Rising-MA at entry is Weinstein's actual Stage-2 definition (book §Stage 2: Advancing). Real `Weinstein_strategy.config` field. |

### Experiment-flag discipline

| # | Check | Status | Notes |
|---|-------|--------|-------|
| R1 | Default-off no-op = prior behaviour | PASS | `= false` in `default_config`, `[@sexp.default false]`; `~reject:false` is identity. Pinned by `test_default_is_noop`. |
| R2 | Real config field → Variant_matrix axis | PASS | Genuine field; `Overlay_validator.apply_overrides` resolves `((flag reject_declining_ma_long_entry) (values (true false)))` and raises on unresolved keys. |
| R3 | No default flip without ledger ACCEPT | PASS | No default flipped on; field added default-off, baselines bit-identical. No ledger citation needed/claimed. |

## Quality Score

5 — Exemplary: faithful spine-tightening gate behind a default-off, axis-resolvable config flag; order-and-membership-pinning tests; honest `Entry_assembly` extraction mirroring the existing `short_side_gate` seam; `.mli` correctly grounds the change in Weinstein's rising-MA Stage-2 definition.

## Verdict

APPROVED
