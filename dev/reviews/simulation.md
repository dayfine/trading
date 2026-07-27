# QC Structural Review: simulation

Date: 2026-04-07
Reviewer: qc-structural
Branch reviewed: feat/simulation

## Scope

New files:
- `analysis/weinstein/data_source/lib/synthetic_source.ml/.mli` — deterministic DATA_SOURCE (4 bar patterns)
- `analysis/weinstein/data_source/test/test_synthetic_source.ml` — 8 unit tests
- `trading/weinstein/strategy/test/test_weinstein_strategy_smoke.ml` — 3 smoke tests (Daily x2, Weekly x1)
- `trading/weinstein/strategy/test/dune` — updated to include smoke tests
- `devtools/checks/linter_exceptions.conf` — added `nesting analysis/scripts` exception

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune fmt --check | PASS | No format violations |
| H2 | dune build | PASS | Clean build |
| H3 | dune runtest | PASS | All linters pass (fn_length, magic_numbers, mli_coverage, nesting, arch_layer, fmt_check); all test suites pass |
| P1 | Functions ≤ 50 lines | PASS | Verified by fn_length linter |
| P2 | No magic numbers | PASS | Verified by magic_numbers linter; named constants are implementation constants |
| P3 | Config completeness | PASS | User-facing parameters in `config` record |
| P4 | .mli coverage | PASS | `synthetic_source.mli` added; verified by mli_coverage linter |
| P5 | Internal helpers prefixed with `_` | PASS | Only public symbol is `make` |
| P6 | Tests use matchers library | PASS | Both test files use `assert_that` with matchers throughout |
| A1 | Core module modifications | PASS | No modifications to Portfolio/Orders/Position/Strategy/Engine |
| A2 | No analysis/ → trading/ imports | PASS | arch_layer linter passes |
| A3 | No unnecessary existing module modifications | PASS | `linter_exceptions.conf` and strategy test dune changes both appropriate |

**FLAG**: Branch is 7 commits behind main@origin — rebase recommended before merge. Below 10-commit block threshold; non-blocking.

## Verdict

APPROVED

---

# QC Behavioral Review: simulation

Date: 2026-04-07
Reviewer: qc-behavioral
Branch reviewed: feat/simulation

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | PASS | `strategy_cadence` is strategy-neutral; no Weinstein-specific logic in shared simulator |
| S1–S6 | Stage definitions and buy criteria | NA | Stage classifier not in this feature |
| L1–L4 | Stop-loss rules | NA | Not in this feature |
| C1–C3 | Screener cascade | NA | Not in this feature |
| T1–T3 | Stage/macro/stop tests | NA | Not in this feature |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | `test_weinstein_weekly_cadence` uses `Weekly` cadence over Jan 2–19 2024 (two Fridays); confirms Friday gate wired end-to-end per eng-design-4 §4.3 |

## Verdict

APPROVED

---

## Combined Result (Slice 1)

overall_qc: APPROVED
Both structural and behavioral QC passed on 2026-04-07.

---

# QC Structural Review: simulation (Slice 3)

Date: 2026-04-10
Reviewer: lead-orchestrator (inline QC)
Branch reviewed: feat/simulation (commits adfc5902, 3c71f99e)

## Scope

Modified files:
- `trading/weinstein/strategy/lib/weinstein_strategy.ml` — prior_stage accumulation
- `trading/weinstein/strategy/test/test_weinstein_strategy_smoke.ml` — breakout pattern test + doc update
- `dev/status/simulation.md` — status update

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune fmt | PASS | No format violations |
| H2 | dune build | PASS | Clean build |
| H3 | dune runtest | PASS | All tests pass (13 strategy tests: 9 unit + 4 smoke) |
| P1 | Functions ≤ 50 lines | PASS | No new functions; existing functions unchanged in length |
| P2 | No magic numbers | PASS | `base_weeks=40`, `breakout_volume_mult=8.0` are test parameters |
| P3 | Config completeness | PASS | No new user-facing parameters |
| P4 | .mli coverage | PASS | No new public API; .mli unchanged |
| P5 | Internal helpers prefixed | PASS | All existing helpers retain `_` prefix |
| P6 | Tests use matchers | PASS | `assert_that`, `gt`, `not_`, `is_empty` used |
| A1 | Core module modifications | PASS | No modifications to Portfolio/Orders/Position/Strategy/Engine |
| A2 | No analysis/ → trading/ imports | PASS | No cross-layer changes |
| A3 | No unnecessary modifications | PASS | Only strategy impl + test + status file |

## Verdict

APPROVED

---

# QC Behavioral Review: simulation (Slice 3)

Date: 2026-04-10
Reviewer: lead-orchestrator (inline QC)
Branch reviewed: feat/simulation

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| B1 | Prior stage accumulation correct | PASS | Hashtbl stores stage after each `Stage.classify`; next call receives it |
| B2 | Stock_analysis receives prior_stage | PASS | `Hashtbl.find prior_stages ticker` passed to `analyze` |
| B3 | Index prior stage wired to Macro | PASS | `Hashtbl.find prior_stages config.index_symbol` → `Macro.analyze ~prior_stage` |
| B4 | Side effects contained in closure | PASS | `prior_stages` Hashtbl created in `make`, same pattern as `stop_states` and `bar_history` |
| B5 | Test exercises full pipeline | PASS | Breakout pattern → Stage1→Stage2 → screener → orders → trades → assertions |
| B6 | Test assertions meaningful | PASS | Verifies orders submitted, trades executed, positive portfolio value |
| T1 | Domain correctness | PASS | Prior stage accumulation matches Weinstein's weekly stage progression concept |

## Verdict

APPROVED

---

## Combined Result (Slice 3)

overall_qc: APPROVED
Both structural and behavioral QC passed on 2026-04-10.
Feature is in Integration Queue — ready to merge to main pending human decision.

---

## Behavioral QC — simulation split-day PR-4

Date: 2026-04-29
Reviewer: qc-behavioral
Reviewed SHA: 56520d0b8d76beffb704494066c420f2d5812754
Branch: feat/split-day-pr4
PR: #667

### Scope

Verification + decisions / status / docs cleanup PR. Three commits on top of main:

- 61f3e2c — `dev/decisions.md` Direction Change entry promoting the broker model
- 343b8b9 — `dev/status/simulation.md` Completed entry + Follow-up
- 56520d0 — `dev/notes/split-day-broker-model-verification-2026-04-29.md` (NEW) + `dev/notes/sp500-2019-2023-baseline-canonical-2026-04-28.md` status update + `dev/status/backtest-perf.md` cross-link

No source code changes. The broker-model mechanism was implemented + QC'd in PR-1 (#658), PR-2 (#662), PR-3 (#664). PR-4's behavioral surface is the verification record's claims about smoke parity, the deferral justification for sp500, and the accuracy of the promoted decision.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No new .mli files in this PR — pure docs / verification / decisions promotion |
| CP2 | Each claim in PR body "Test plan" / "What it does" sections has a corresponding test or verifiable evidence in the committed file | PASS | All seven test-plan claims pin to specific evidence: (1) `dune build` exit 0 — verification note §"What this PR establishes" item 1; (2) `dune runtest` exit 0 — same; (3) `dune build @fmt` clean — same; (4) `test_split_day_mtm` 3/3 PASS — verified: `trading/trading/simulation/test/test_split_day_mtm.ml` contains exactly 3 tests at lines 192/267/332 (`portfolio_value_continuous_through_split`, `no_split_window_unchanged`, `split_day_with_no_position_held`), matching the file count claimed in the verification matrix and the §Completed entry; (5) smoke parity (`panel-golden-2019-full` 7 round-trips / +2.3% / 33.3% win, `tiered-loader-parity` 5 round-trips / +9.6% / 60.0% win, bit-identical to pre-#641 main) — pinned to specific numeric metrics in the verification matrix; the `panel-golden` "7 round-trips" matches the pre-#641 number cited in `dev/notes/session-followups-2026-04-28.md` §1 (which records 7→6 under the failed band-aid, so PR-3's broker model preserves the 7); (6) all five smoke goldens PASS — matrix lists all five with PASS within pinned ranges; (7) sp500 deferral — explicitly marked DEFERRED in test plan with maintainer recipe in §"Why sp500-2019-2023 must wait". |
| CP3 | Pass-through / identity / invariant tests pin identity (not just size) | NA | This PR adds no new tests. The "non-split-window bit-identical" invariant is verified by reported numeric metrics in the verification note (round-trip counts + return % + win rate %) — stronger than count-only pinning. The originating test (`test_split_day_mtm.ml`) lives in PR-3 (#664) and was structurally + behaviorally reviewed there. |
| CP4 | Each guard called out in code docstrings has a test that exercises the guarded-against scenario | NA | No new code or docstring guards in this PR. The split-day guard tests (4:1 forward, no-split window, no-held-position split day) live in PR-3 (#664) and PR-2 (#662) and were reviewed there. |

### Verification-specific behavioral checks

| # | Check | Status | Notes |
|---|-------|--------|-------|
| V1 | Smoke parity claim is pinned to specific numeric metrics (not just "passes") | PASS | Verification note matrix pins `panel-golden-2019-full` to "7 round-trips, +2.3% return, 33.3% win" and `tiered-loader-parity` to "5 round-trips, +9.6% return, 60.0% win". The pre-#641 numbers for `panel-golden-2019-full` (7) match `session-followups-2026-04-28.md` §1. (Minor nit: `tiered-loader-parity` pre-#641 numeric pin is qualitative ("HD→JPM") in the followups note rather than an explicit "5 round-trips" — verifying "bit-identical" against pre-#641 main on that specific gate requires consulting PR-3's review evidence, not just this note. Non-blocking; the bit-identity claim is testable.) |
| V2 | sp500 deferral is well-justified with reproducible maintainer recipe | PASS | Justification cites the same data-availability blocker as the tier-4 release-gate (`tier4-release-gate-checklist-2026-04-28.md`); 22-symbol GHA fixture cannot resolve a 491-symbol universe. Recipe at lines 78-85 of the verification note is complete: container name, `cd`, `eval $(opam env)`, `dune build`, exact runner path, `--dir`, `--fixtures-root`. Two explicit follow-up steps listed: (1) supersede canonical baseline note, (2) re-pin sp500 sexp `expected` ranges. Tracked in `dev/status/simulation.md` §Follow-up with the same recipe + expected metrics (trades ≈ 134, return ≈ +71%, win rate ≈ 38%, MaxDD ~5%). |
| V3 | goldens-small failure attribution is correct (not a PR-3 regression) | PASS | The note explains the goldens-small ranges were authored against the local 302-symbol fixture, not the 22-symbol GHA fixture. The smoke ranges for the same 2019h2 / 2020h1 / 2023 windows pass within their pinned ranges in the same run, confirming the strategy code is fine and the goldens-small ranges are sized for a different fixture size. This matches the `dev/notes/goldens-performance-baselines-2026-04-28.md` documented full-fixture numbers (e.g. bull-crash +80% / 83 trips full vs −1% / 21 trips here). The reasoning is sound. |
| V4 | Promoted decision in `dev/decisions.md` accurately reflects the plan's invariants | PASS | Direction Change entry at line 46 of decisions.md states (a) "All consumers (Simulator MtM, engine fills, screener `get_price`, resistance, breakout) read raw OHLC straight from `Daily_price.t`"; (b) "`adjusted_close` is reserved for back-rolled smoothness on relative-strength, MAs, momentum, and breakout-vs-historical-resistance only"; (c) "On a split day the position's quantity multiplies by the split factor and per-share cost basis divides — total cost basis preserved exactly, realized P&L unchanged"; (d) closure trail with all four PR numbers and the 97.69% MaxDD root cause. Each clause maps 1:1 to plan §"Core invariants" (1)-(4) and §"Worked example — AAPL 2020-08-31 4:1". |
| V5 | sp500 canonical baseline note is updated to point at this verification | PASS | Front-matter status block at lines 3-15 of `dev/notes/sp500-2019-2023-baseline-canonical-2026-04-28.md` cross-links to the verification log and explains the supersession plan. Action item 1 reflects "MERGED 2026-04-28" for plan #656; action item 2 ("Local rerun") flagged with ⏳ and tracking pointer. |
| V6 | `dev/status/simulation.md` Completed entry accurately summarizes the four PRs | PASS | §Completed §"Split-day OHLC redesign" entry at lines 55-101 documents PR-1/-2/-3/-4 with PR numbers, what each delivered (Split_detector / Split_event / Simulator wire-in / verification), and the verification commands. The Follow-up entry at lines 112-130 captures the deferred sp500 rerun with the reproduction recipe. |

### Behavioral Checklist (project-specific Weinstein rows)

Per `.claude/rules/qc-behavioral-authority.md`: "For pure infrastructure / library / refactor / harness PRs that touch no domain logic — the generic CP1-CP4 alone constitute the full review. Mark every domain row NA with one explanatory note."

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1 for this PR (no source-code changes). |
| S1-S6 | Stage definitions / buy criteria | NA | Pure docs / verification / decisions PR; no Weinstein domain logic touched. |
| L1-L4 | Stop-loss rules | NA | Same. |
| C1-C3 | Screener cascade | NA | Same. |
| T1-T4 | Domain test coverage | NA | Same. The split-day mechanism's domain-correctness tests live in PR-1/-2/-3 and were reviewed there. |

## Quality Score

4 — Clean verification record with specific numeric pinning of the smoke parity invariant, well-justified deferral with complete maintainer recipe, and a decision entry that accurately mirrors the plan's invariants. Minor nit: the `tiered-loader-parity` pre-#641 baseline reference in the followups note is qualitative (symbol-identity) rather than a specific round-trip count, so the "bit-identical" claim on that gate requires forward-reference to PR-3's review evidence; not blocking.

## Verdict

APPROVED

(Derived mechanically: CP1 NA, CP2 PASS, CP3 NA, CP4 NA, V1-V6 PASS, all domain rows NA. No FAILs.)

---

## PR #2115 — `fix/lh-phantom-short` (2026-07-27 run 2) — MERGED `5ff998d9`

**Format note:** `record_qc_audit.sh` matches `^(structural|behavioral|overall)_qc: (APPROVED|NEEDS_REWORK)`
at column 0 and takes the **last** occurrence, plus the bare integer under the
last `## Quality Score`. Keep these unadorned; a "prettier" rendering parses to
`SKIPPED / null` while exiting 0.

Closes issue **#2059** — a `bug`-labelled correctness defect that sat **unowned
across five consecutive orchestrator runs**. First agent dispatched on it.

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 0.

### The bug, and the single root cause behind all three symptoms

A long-only record run (`enable_short_side false`) emitted, in `trades.csv`:
a LONG round trip, then a **phantom SHORT** held **8,459 days** (2001→2024),
**duplicated byte-for-byte**, double-counting −$303,450 twice against $71.7M net
realized.

`Metrics.extract_round_trips` was **not quantity-faithful**. `_pair_step` popped
an *entire* open entry for *any* opposing trade regardless of quantity, so a
**partial exit** (a) booked the **full entry quantity** at the **partial exit
price**, and (b) silently dropped the residual shares — leaving the *next*
closing `Sell` with no open entry, whereupon it fell into the "open a new entry"
arm and became a **SHORT open**. One cause, all three symptoms:

| defect | disposition | mechanism |
|---|---|---|
| 1 — SHORT with short-side disabled | CLOSED | orphaned residual `Sell` re-read as a short *open* |
| 2 — 8,459-day zombie | CLOSED | *same emission*; never a portfolio zombie — the position exists only inside the pairing fold, which is precisely **why** no exit channel ever re-evaluated it |
| 3 — exact duplicate row | CLOSED for the orphan cause; genuine-over-sell variant characterised-and-filed | each orphaned `Sell` opens its own phantom short; two orphans with identical date/price/qty produce byte-identical rows |

### The reconstruction — and why it is more than a plausible story

**The record warehouse does not exist in the GHA container**, so neither author
nor reviewer could reproduce from the original run. The fix is justified by a
reconstruction, which makes verifying that reconstruction the whole review.

qc-behavioral hand-traced the pre-fix code against the reported stream and
reproduced **all nine fields of both rows**, not a subset:

- LONG row: `_pop_matching_entry` compares `entry.quantity * factor` (3868)
  against `exit_qty` (1934), fails to match, FIFO-pops the entire entry;
  `_make_trade_metric` then uses `entry.quantity *. factor` → `qty 3868`,
  `entry 69.72`, `exit 68.30`, `days_held = Date.diff 2001-06-12 2001-06-09 = 3`,
  `pnl −5482.5`, `pct −2.03`.
- SHORT row: the next `Sell` hits `open_entries = []` → the `| _ ->` arm → short
  open. `days_held 8459` independently recomputed (8401 to 2024-06-13 including
  six leap days, +58); `pnl −303450.4`, `pct −232.80`. Exact.

Two constraints make it forced rather than fitted: **`3868 = 2 × 1934`** is
compelled by LabCorp's real 2-for-1 split effective **2001-06-12** — exactly the
LONG row's `exit_date`, i.e. landing precisely on the `split_date <= exit_date`
boundary; and the phantom's quantity being exactly half the LONG's is a
**prediction** of the residual mechanism, not an input to it.

**A premise in my own dispatch brief was wrong, and the author corrected it.** I
told the agent the shared `position_id` (`LH-wein-536`) was "the single strongest
clue — it says these are the same position record". It is the opposite:
`Trade_context._position_id_for_trade` matches `(symbol, entry_date)` over a
**7-day backward window**, so the phantom (4 days later) merely *inherits* the
id. It proves the short has **no audit record** — the strategy never decided to
open it. `extract_round_trips` never reads portfolio state at all; it
reconstructs positions purely by folding `step.trades`, so a SHORT row implies
nothing whatsoever about the portfolio.

### The changed existing test — correction, not weakening

`mismatched_qty_falls_back_to_fifo` asserted `quantity = 100` for a 70-share
sell; it is now `70`. This is the exact shape of an illegitimate test weakening,
so it got the sharpest scrutiny. qc-behavioral judged it a correction on three
independent grounds: (1) the old expectation booked `(15−10)×100 = $500` on a
**70-share** sale with the 30-share residual silently dropped — an uncompensated
over-count, not an alternative convention; (2) the test's actual purpose (FIFO
*selection*) is pinned by `entry_price = 10.0`, retained unchanged, as is the row
count; (3) **the new expectation is strictly stronger** — mutation M4 emits 100,
which the old assertion would have *passed* and the new one kills. It adds
mutation coverage, the opposite of the weakening signature.

### No new leak

A retained-but-unclosed residual is not new: pre-fix those shares also went
unreported (consumed whole, vanished from the fold); only the over-count is gone.
`sum(take_i × factor_i)` telescopes exactly to the exit quantity, `remaining` is
monotone decreasing, and the `unconsumed > 0` return is reachable only from the
`| [] ->` arm — which is what keeps `_pair_step`'s head-only `_opposes` guard
sound. Downstream consumers (`summary_computer.ml`,
`trade_aggregates_computer.ml`) are per-row folds with no one-row-per-position
assumption.

### Structural

`metrics.ml` crossed the 300-line limit, so the pairing logic was **extracted**
into a new `Round_trip_pairing` module per `code-health-discipline.md` — no
`@large-module` marker, no limit bump, no `linter_exceptions.conf` change.
`metrics.ml` 287 → 119; `round_trip_pairing.ml` 248 with a 110-line `.mli`.
`Metrics` re-exports the type as a **type equality**, so field access and
`[@@deriving]` output are unchanged and no consumer changed — qc-structural
confirmed this is a true type abbreviation rather than a fresh nominal type,
which is the difference between "no consumer changed" and a silent break. All
functions ≤23 lines. `weinstein_strategy.ml`, the core stop-machine, `Portfolio`,
`Position`, `Orders` and `Engine` are all untouched, per `dev/decisions.md`.

Mutations, 4 run, each red: M1 whole-entry consumption (pre-fix behaviour) →
tests 25–28; M2 drop the over-close leftover → 29; M3 FIFO → LIFO → 25; M4
full-entry quantity in `_make_trade_metric` → 25–29.

### Non-blocking FLAGs carried to `dev/status/cleanup.md`

1. **Defect-1 closure is understated.** The reconstruction that explains defect 3
   *requires* a genuine over-sell (two byte-identical orphans cannot arise from
   one 3868-share position otherwise) — and under a genuine over-sell **one SHORT
   row still prints post-fix**, correctly, because `Portfolio` has an explicit
   direction-change branch and the portfolio really would be short. This is
   disclosed in the PR body, test 27's docstring and `dev/status/simulation.md`,
   but the disposition table says "CLOSED" unqualified and `Fixes #2059`
   auto-closes the issue. **The caveat should be carried into the issue-closing
   comment.**
2. Stale docstring on the updated FIFO test (cites `_pop_matching_entry`, now
   `_select_entry_index`; omits the 30-share residual from its end-state).
3. `_residual_qty_epsilon`'s sliver guard is unpinned — every split factor in the
   suite divides exactly, so mutating the epsilon to `0.0` reddens nothing.

### Deliberately not done

A "no single fill may flip a position's sign" invariant was **filed, not
executed**: it changes simulation behaviour, wants its own default-off flag per
`experiment-flag-discipline.md`, and could not be confirmed from this container.
The proposed non-core enforcement point (`Cancel_handler.apply_trades_best_effort`,
already the single fill funnel) is recorded in `dev/status/simulation.md`. The
`position_id` join is also filed: any per-trade forensic grouping by
`position_id` is suspect until it threads the real position link instead of
re-deriving by date proximity.

## Quality Score

4

## Verdict

APPROVED
