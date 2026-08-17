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

---

## Behavioral QC — PR #2364 `docs/walk-order-docstrings` (2026-08-17 run 2)

Reviewed SHA: f79d3a3a7b7cc9707b9b061d8329d99188819459
Reviewer: qc-behavioral
Track: simulation. Closes **R-a** (filed by qc-behavioral on PR #2352).

**CI at this tip:** `build-and-test` **completed/success**, `perf-tier1-smoke`
**completed/success**. qc-structural approved while `build-and-test` was still
`in_progress`; that gap is now closed — CI settled green under this review, not
inherited.

### What is under review

Nothing executes here. The artifact is a **claim**, three times over, so CP1–CP4
reduces to one question per docstring: *is it exactly true of the code as it
stands — no broader, no narrower?* Every premise below was re-derived from source
rather than taken from the PR body.

### The premise the whole PR rests on: the demotion is the only reordering

| link | evidence | verdict |
|---|---|---|
| `Entry_stop_width_order.prefer_narrow_stops` stably partitions narrow-first | `List.partition_tf` (order-preserving within each group) then `List.append narrow wide`; guarded by `Stop_width_mode.demotes` | confirmed |
| called from `Entry_walk._prepare_candidates`, which feeds the walk | `_prepare_candidates` = `Entry_freeze.apply … |> prefer_narrow_stops`; `entries_from_candidates` rebinds `candidates` to its output before the walk | confirmed |
| `Entry_freeze.apply` does not permute | body is `List.map candidates ~f:(_freeze_one ~pending)` (and returns `candidates` unchanged when disabled) | confirmed |
| `_sleeve_decisions` does not permute either | `List.mapi` then re-sort by that index — restores the *handed* order | confirmed |
| `Stop_width_mode` has exactly 3 constructors; `demotes` true only for `Demote_over_max` | `Drop_over_max | Size_down | Demote_over_max` | confirmed |

So **the demotion is the only reordering**, and the `funded` docstring's "every
mode except `Demote_over_max`" is *exhaustively* correct rather than merely
true-so-far.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified pin | PASS (by trace) | No new `.mli` *files*; three rewritten docstrings on existing types. Nothing executable is asserted, so the pin is a source trace, performed per claim below. Ordering behaviour itself is pinned by `test_entry_stop_width_order.ml` (shipped with #2352). |
| CP2 | Each PR-body claim has corresponding evidence in the committed diff | PASS | Every load-bearing body claim re-derived independently: 10 `skip_reason` constructors; 1 production caller of `entries_from_candidates`; `.ml` zero-diff; `_index.md` untouched. All hold. |
| CP3 | Pass-through / identity claims pin identity, not size | PASS | The identity claim here is `prefer_narrow_stops` returning the input **physically unchanged** off-mode; `demotes` short-circuits before `partition_tf`, so it is a true identity, not a same-length rebuild. |
| CP4 | Each guard named in a docstring has a test exercising it | NA | No new guard claims; the three rewrites *narrow* existing claims rather than adding guarded behaviour. |

### Claim-by-claim verification

**1. `funded` (`screen_record.mli`) — names two producers with different behaviour.**
Both limbs confirmed, and the "there are two" universal was itself enumerated:

- `of_audit_records` → `_record_of_screen`: `Hashtbl.add_multi` accumulation then
  `List.rev`, i.e. insertion order = `emit_entries` emission order = the order
  the walk charged the budget. Post-demotion on that arm. ✔
- `Weekly_adapter._record_of_snapshot`: `List.split_n snap.long_candidates
  displayed_k |> List.map` — preserves `long_candidates` order, documented
  score-desc at `weekly_snapshot.mli`; **no entry walk on that path**. ✔
- **Exactly two producers.** The only other site returning `Screen_record.t list`
  is `decision_audit_bin._screens_of_mode`, a CLI dispatcher between those two
  (mutually exclusive `--audit` / `--weekly-picks-dir`). `counterfactual.ml` and
  `report.ml` are consumers. The docstring's own "because there are two" holds.

**2. `inversion` (same file) — the causal clause was already an incomplete enumeration.**
Confirmed, and worse than "stale-from-#2352": the old "sizing / sector-cap"
pairing was wrong *before* `Demote_over_max` existed.

- `alternatives_of_decisions` = `List.filter_map … (_alternative_of_decision)`,
  which returns `Some` for **every** `Skipped reason` — no filter, no top-N cut. ✔
- **`Trade_audit.skip_reason` constructor count: 10** — `Insufficient_cash`,
  `Already_held`, `Below_min_grade`, `Sized_to_zero`, `Sector_concentration`,
  `Top_n_cutoff`, `Short_notional_cap`, `Stop_too_wide`, `Sector_exposure_cap`,
  `Long_exposure_cap`. Matches the PR's count. Pointing at the *type* instead of
  re-listing ten names that would drift is the right call.
- The new text's examples map onto real constructors, and `Stop_too_wide` is
  genuinely reachable under the `Drop_over_max` default (that mode is precisely
  the one that reads §5.1 as a ban) — so the example set is not over-broad.
- **Third case verified.** `summary_of` computes `inversion` as `exists near_miss.
  score > min funded score`. Under `Weekly_adapter`, `funded` is the top-`displayed_k`
  longs while `near_misses` is long overflow **plus every short**
  (`List.map snap.short_candidates`, no cut). A short outscoring the lowest
  displayed long therefore fires `inversion` benignly, exactly as documented. ✔

**3. `short_sleeve_fraction` (`weinstein_strategy_config.mli`).**
`_sleeve_decisions` does `List.mapi candidates` where `candidates` is already
`_prepare_candidates`' output (rebound at the top of `entries_from_candidates`).
The re-sort therefore restores the **post-demotion** order, not the screener's.
The old "re-emitted in original screener order" was false under an armed
demotion; the new "restores whichever order it was handed … does not recover the
screener's" is exactly right. ✔

### "No fourth site" — the universal, re-derived and stress-tested

This is the defect class that has rejected eight PRs in eight days, so it got the
enumeration rather than the assertion.

- **`entries_from_candidates` production callers: 1** — `weinstein_strategy_screening.ml:419`.
  `weinstein_strategy.ml:55` is an alias re-export (`let entries_from_candidates =
  Entry_walk.entries_from_candidates`); `entry_walk.ml:153` is the definition;
  every other hit is a test or a `{!…}` doc reference. Third independent
  derivation, agrees with author and structural.
- **Corroborated structurally, not just by count:** the entire
  `trading/trading/weinstein/snapshot/gen/lib/` subtree references
  `Weinstein_strategy` only for `Bar_reader`, `config` and
  `Weekly_sidetable_reader` — never `Entry_walk`. The demotion genuinely cannot
  reach the snapshot path.
- **Two "correct as written" claims spot-checked** (the ask was to find a site the
  sweep never considered, not to re-audit the count):
  - `weekly_snapshot.mli:253/255` — "Ranked long/short candidates,
    score-descending" on `Weekly_snapshot.t`, populated from the screener with no
    walk in between. Correct, rightly untouched.
  - `pick_diff.mli:17` — rank as "1-based positional index in `long_candidates`
    (already score-descending per the screener contract)", reading the same
    snapshot record. Correct, rightly untouched.
- **I swept wider than the PR's list and found three further score-desc sites the
  body does not name:** `weekly_adapter.mli:48` ("already score-descending"),
  `trade_audit_ratings.mli:374` ("cascade-score-descending quartiles"),
  `report_renderer.mli:80` ("candidates arrive score-descending with an
  alphabetical tie-break"). **All three are non-stale**: the latter two describe
  sorts the *report* performs on its own inputs (quartile bucketing, display
  ordering), not walk-emission order; the first describes the snapshot path and
  in fact *corroborates* the new `funded` docstring's second limb. The
  conclusion "no fourth stale site" therefore survives a wider sweep than the one
  the author ran — noted as a scoping nit on the body's prose, not a finding.
- **Converse check — does the new prose over-claim?** No. Each rewrite is
  narrower than what it replaced, and each names the mode under which it holds.
  The one phrase worth flagging is "inversions fire systematically on that arm":
  strictly, a demoted high-scorer becomes a near-miss only once cash runs out, so
  this reads as a characterisation of the class ("systematic-by-design rather
  than anomalous") rather than a per-screen guarantee. In context — immediately
  after "is the mechanism working as designed" — it is not misleading. Nit only.
- **No `:NNN` line-number citations** in any added prose (grep of added `.mli`
  lines for `\w+\.mli?:[0-9]+` is empty). Symbolic `{!…}` references throughout.
  The status file's *old* text used `L73` / `L62-65` / `L423`; the replacement
  prose is symbolic.

### Experiment-flag / faithfulness rows

| # | Check | Status | Notes |
|---|-------|--------|-------|
| W1 | Spine intact | PASS | Docstrings only. No stage rule, entry gate, volume confirmation, stop or macro gate touched. |
| W2 | Adaptation is a config-expressed dial | NA | No mechanism added or changed. |
| R1 | Default-off preserved | PASS | `weinstein_strategy_config.ml` is a **zero-byte diff**; `stop_width_mode` remains `[@sexp.default Stop_width_mode.Drop_over_max]` and the default record still sets `Drop_over_max`. No `[@sexp.default]` line added or removed anywhere in the diff. |
| R3 | No default flipped without a ledger ACCEPT | PASS | Nothing flipped; no ACCEPT claimed. `Demote_over_max` stays default-off. Correctly framed: these claims only become load-bearing *if* it earns one. |
| A1 | Core-module change strategy-agnostic | NA | qc-structural raised no A1 FLAG; no `.ml` under a core module changed. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Domain logic rows | NA | Docstring-only PR with zero executable change; no stage, stop, screener-cascade or macro logic touched. Domain-adjacent by file location, not by behaviour. |

### Status file and follow-ups

- `dev/status/simulation.md` completion note matches what shipped: the three
  files, the mechanism, the caller count, and the zero-diff invariant all agree
  with the diff I read. Item correctly checked `[x]`.
- **R-c remains open** and untouched — still listed as an unchecked follow-up
  ("the demoted-wide cohort is not greppable from the trace"). Correctly out of
  scope.
- **New follow-up confirmed real and correctly filed, not silently fixed.**
  `trade_audit.mli:247` documents `alternatives_considered` as "**Top-N**
  candidates from the same screen call that were not entered", but
  `alternatives_of_decisions` applies no top-N cut whatsoever — it emits every
  `Skipped` decision. Genuine inaccuracy. `trade_audit.mli` was a sibling agent's
  file this run, so filing it rather than editing it was the right call under
  worktree-isolation discipline.
- Incidental observation, not a finding: `_alternative_of_decision`'s `Kept` arm
  is `if String.equal … then None else None` — both branches `None`, so the
  `exclude_position_id` comparison is dead. Pre-existing, outside this diff, and
  behaviourally inert. Worth a future cleanup ticket; not this PR's business.

## Quality Score

5 — Exemplary. The author traced the mechanism end to end *before* rewriting, and
every premise I re-derived independently held: the caller count, the 10-constructor
enumeration, the two-producer set, the stable partition, the zero-byte `.ml` diff.
The rewrites are strictly narrower than what they replaced, point at a *type*
where a name-list would drift, and correctly discovered that one clause was
already wrong before `Demote_over_max` existed. Out-of-scope inaccuracies were
filed rather than absorbed. Only nits: the body's "five snapshot-side claims"
under-enumerates the sites carrying score-desc language (three more exist, all
non-stale, so the conclusion stands), and "inversions fire systematically" is a
class characterisation rather than a per-screen guarantee.

## Verdict

APPROVED

(Derived mechanically: CP1–CP3 PASS, CP4 NA; W1/R1/R3 PASS; all domain rows NA.
No FAILs.)

behavioral_qc: APPROVED
