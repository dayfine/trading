# Next-session priorities — 2026-06-27 (investigation & understanding plan)

**Supersedes** `next-session-priorities-2026-06-26.md` (the short-realism P0, now
resolved: margin already built + non-deflating; the real artifact was illiquid
junk → liquidity overlay merged #1760; see `project_liquidity_realism_overlay`).

**Mode for next session: derive understanding, explore options & directions.**
Do **NOT** jump to a strategy change, a new mechanism, or WF-CV hypothesis testing.
The goal is to *understand why* the patterns below exist and *map the option space*,
so that any future build is well-grounded (per `weinstein-faithful-core`,
`mechanism-validation-rigor`, and the standing caution against over-explorative
mechanic changes). Each thread should output **understanding + a menu of options**,
not a committed change.

---

## The organizing finding (this session, 2026-06-26): the edge is regime-conditional

Per-year long-only broad (top-3000 PIT-1998, 0.14) vs SPY total return, 1999-2026:

- **Strategy WINS when SPY is down/turbulent, LOSES in melt-ups.** Big wins:
  2000 (+36pp), 2002 (+18.5), **2008 (strategy −11.6% vs SPY −36.8% = +25pp)**,
  2009 (+16.5), 2022 (+20.6). Big losses: 2017 (−11.5), 2019 (−16.2), 2021 (−15),
  2023 (−27.7), **2024 (−43.6)**. Textbook Weinstein/trend signature: defensive in
  bears (stage-4 exits, cash), whipsawed/cash-dragged in strong bulls.

- **A realizable annual macro-barbell beats both pure legs.** Switch on last
  year-end SPY 30-week-MA state (no lookahead): **bull → hold SPY, bear → run the
  strategy.** Compounded 1999-2026:

  | | Return | Mult |
  |---|---|---|
  | Pure strategy (long-only) | +622% | 7.2× |
  | Pure SPY | +874% | 9.7× |
  | **MA-barbell (realizable, lagging)** | **+1295%** | **14.0×** |
  | Contemporaneous-regime (cheat) | +3450% | 35.5× |
  | Perfect foresight | +7785% | 78.9× |

- **This is a single-path screen, NOT a verdict.** Caveats already identified:
  (a) edge concentrated in the big bears (2008/dot-com) → likely regime-dependent,
  a bull-only window would probably show the barbell losing; (b) the lagging signal
  errs both ways — misses the *first* bear year (2000, 2022) and overstays into
  recoveries (2003, 2019, 2023); (c) reconciles with the "regime-gating is dead"
  memory only because the bull leg here is **SPY, not cash**.

Data: long-only equity curve `dev/backtest/scenarios-2026-06-27-034110/`, SPY
`data/S/Y/SPY/data.csv`, scenarios `dev/experiments/short-realism-deep-2026-06-26/`.
Headline numbers recorded in `dev/backtest/DEEP_RESULTS.md`.

---

## Investigation threads (understanding-first — analysis, not building)

### Thread A — Characterize the regime-edge precisely (the linchpin)
The barbell result raises questions to *understand* before anyone builds a macro
allocation:

1. **Why** does the strategy lose in bulls? Decompose the per-year LO−SPY gap into
   mechanisms — cash drag (avg cash %), whipsaw (stop-out churn), late re-entry
   after a bear, laggard-rotation in chop. Is the bull-lag one dominant mechanism
   or several? (Use the existing trade records + equity/cash series; this is
   attribution, not a fix.)
2. **Is the bear-edge broad or 2008-dependent?** Re-derive the per-year table on
   sp500-515 and on a non-GFC sub-window; see whether the bear-outperformance
   holds without the two giant bears. Characterize the distribution of the edge
   across bears (dot-com vs GFC vs 2018 vs 2020 vs 2022), not just the sum.
3. **Real-time regime detectability.** The lagging annual MA signal has known
   errors. *Explore* (don't optimize) alternative regime signals and characterize
   their lead/lag: monthly/weekly SPY MA, A-D breadth (we already compute it), the
   strategy's own cash level as an endogenous signal, sector breadth. For each,
   map which barbell error-cells (2000/2022 missed-bear, 2003/2019/2023 overstay)
   it would or wouldn't have caught — to understand the *detectability ceiling*,
   not to pick a winner.
4. **Output:** a written understanding of "where the strategy's regime-edge comes
   from and how detectable the regime is in real time," plus an options menu (annual
   vs monthly switch; MA vs breadth vs cash signal; SPY vs long-only as bull leg).

### Thread B — Decision quality: where is alpha lost? (#1, #4)
Understand the *shape* of the opportunity cost — not to fix entries/exits, but to
know whether decision-timing is even a lever vs the regime-allocation lever.

1. **Verify the MFE/MAE harness gap first** (`project_harvest_rotate_rejected` /
   trade forensics noted audit fields reading 0). #1 needs realized MFE/MAE per
   trade; confirm it's populated before any missed-trade analysis.
2. **Missed/late/early (#1):** characterize, on the deep run, (a) entries we
   skipped because the name wasn't in a top sector / cash-gated, (b) entries that
   were late vs the breakout, (c) exits that left MFE on the table. Produce the
   *distribution* of opportunity cost (how concentrated, how large), echoing the
   trade-realism lens. This tells us if there's recoverable structure or if it's
   the irreducible fat-tail unpredictability (`project_accuracy_is_unreachable...`).
3. **Scoring faithfulness (#4) — extend, don't re-litigate.** The known result:
   cascade score is anti-predictive at the top grade, winners≈losers at entry.
   Extend the scoring to the **near-misses** (cash-rejected fills): were the
   would-be trades systematically better/worse than the ones taken? Understand
   *whether the cash-allocation order* (which candidate gets the scarce cash) is
   itself a lever — this is new ground vs the prior score-vs-outcome work.
4. **Output:** "is entry/exit decision-timing a real lever, or is the regime
   allocation the only one that matters?" — a directional read, no mechanism.

### Thread C — The short leg under the regime lens (#3, #5 — understanding only)
Static long-short adds ~nothing (long-only +721% ≈ liquidity-armed long-short
+774%). The open *understanding* question:

1. **Is the short leg's value regime-conditional?** Decompose short-leg P&L by
   regime (bull vs bear years). If shorts only pay in bears — and the barbell would
   only run the strategy in bears — then macro-conditional long-short is the
   coherent frame (and the path by which long-short could earn a ledger ACCEPT that
   static long-short can't). If shorts don't even pay in bears, the short leg is
   dead and #5 should be dropped.
2. Cross-reference the merged margin model + liquidity overlay: short realism is now
   honest, so a regime-decomposition of short P&L is finally trustworthy.
3. **Output:** "does the short leg earn its keep in bear regimes specifically?" —
   the precondition for any macro-conditional long-short exploration. **Do not build
   the allocation mechanism**; just establish whether the precondition holds.

### Thread D — Operational consistency + documentation (#6, #7; concrete, anytime)
Lower-risk deliverables, not blocked on the research above:

1. **#6 — PIT vs live universe liquidity consistency (audit).** The liquidity
   overlay added an entry $-ADV gate to the strategy. Verify the *universe
   construction* (broad PIT top-3000 build + the live universe path) applies a
   consistent tradeability/liquidity standard — i.e. the backtest universe isn't
   admitting names the live pipeline would exclude (or vice-versa). Write up any
   gap. (Read `analysis/data/universe/`, the PIT composition build, and the live
   universe wiring; compare against the overlay's `min_entry_dollar_adv`.)
2. **#7 — margin-safety doc + README.** Document the margin safety features now on
   main (Reg-T 150% initial collateral, FINRA-style maintenance, margin-call
   force-liquidation, `short_min_price`, borrow fee, and the liquidity-degradation
   exit/gate) and how each maps to real broker requirements (Schwab/IBKR per
   `dev/notes/long-short-margin-mechanics-2026-06-12.md`). Separate doc (e.g.
   `docs/design/margin-safety.md` or `dev/notes/`) + a short summary section in
   `README.md`. Pure docs.

---

## Guardrails for next session
- **Understanding before mechanism.** No new config flag, no WF-CV, no goldens
  re-pin until the threads above have produced a clear, written understanding +
  an options menu the user has reviewed.
- **The barbell is a hypothesis, not a result.** +1295% is one path; treat it as a
  direction to *understand*, not a number to chase. If/when it graduates to a
  build, it goes through the full default-off → WF-CV → macro-diverse confirmation
  grid pipeline (`experiment-gap-closing`, `promotion-confirmation`).
- **Keep it Weinstein-faithful.** A macro-regime allocation between "the Weinstein
  strategy" and "SPY" is arguably faithful (the macro gate is already in the spine),
  but the framing must be derived from the book, not invented.

## State at handoff
- Main green; all 2026-06-26 PRs merged (#1759 deep-acceptance, #1760 liquidity
  overlay, #1762 deep results-of-record, #1763 agent-memory).
- Deep warehouse `/tmp/snap_top3000_1998_2026_v2` (ephemeral); scenarios committed
  under `dev/experiments/short-realism-deep-2026-06-26/`.
- `dump_snap` (`.snap` OHLCV inspector) available for data forensics.
