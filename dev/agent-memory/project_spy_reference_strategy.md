---
name: project_spy_reference_strategy
description: "SPY-only Weinstein stage-timing strategy (PR #1397) — a new separate testbed module (long/flat, reuses Stage.classify + Weinstein_stops, strips screener/sizing/macro). Direction-finder for the main strategy + realizable bound on the autopsy."
metadata:
  node_type: memory
  type: project
  originSessionId: 06e65263-c45b-4e42-8886-80b198264969
---

**PR #1397 (`feat/spy-only-strategy`):** a NEW single-instrument Weinstein
stage-timing strategy that trades only SPY (long/flat, no shorting in v1). A
testbed/reference, NOT a change to the main multi-symbol strategy. Purpose: the
cleanest possible signal (no selection/sizing/sector/macro confound) to (a) find
direction for the main strategy and (b) put a realizable floor under the
trade-autopsy's perfect-hindsight headroom.

**Build:** new module `trading/trading/weinstein/strategy/lib/spy_only_weinstein_strategy.{ml,mli}`
+ `spy_only_transitions.{ml,mli}` (extracted for nesting). Reuses
`Strategy_interface.STRATEGY`, `Stage.classify` (pure, symbol-agnostic),
`Weinstein_stops`. Wired via a `Strategy_choice.Spy_only_weinstein` variant
(mirrors `Bah_benchmark`). Scenario `spy-only-stage2.sexp` (2009-06-01→2025-12-31)
+ `-bah` companion. The main `Weinstein_strategy` is too entangled with N-symbol
screening to run on a 1-symbol universe — a fresh module was the clean path.

**Run mechanism:** `scenario_runner --dir <dir-of-scenarios>` writes per-scenario
`trades.csv` + `equity_curve.csv` + `summary.sexp` to a timestamped output root.
TRADING_DATA_DIR must point at the test_data with SPY bars (`S/Y/SPY/`, 2009-2026).

**Result + trade analysis:** see [[project_trader_investor_modes]] +
`dev/notes/spy-stage-timing-trades-2026-05-31.md`. Headline: investor preset 70%
win, Calmar 0.48 > BAH 0.37, MaxDD 18.8% < 34%, but final NAV trails BAH (fast-V
whipsaws). This is investor-mode (30wk); trader-mode (10wk) is the next test.

**QC notes:** qc-structural caught file-length (rework 1: 312→258, 302→299) then
CI caught nesting (rework 2: scoped `dune runtest` MISSES the whole-tree nesting
linter — always run full `dune runtest` or the nesting target). Both fixed.
Related: [[project_panel_runner_tmp_leak]], [[feedback_weinstein_faithful_core]].
