# Index-short overlay screen — pre-registration (2026-10-11)

**Status: CONFIRMED by the user (design 2026-10-11 14:10 PT; hold lifted 2026-10-12 11:35 PT). Runs on the breadth-fix N arm after its results PR merges.**
Sequencing (user, 2026-10-11): #3238 breadth fix + paired rb1 rerun first, then this screen.

## Question

Shorts Phase B round 1 (#3237) failed its stopping rule, and decision 10 of
`dev/plans/total-return-and-shorts-phase-b-2026-10-05.md` hands bear protection to "the index-hedge question".
The question: **does an SPY short, held alongside the record long book, earn its keep over 26 years?** By that we
mean: does it cut the record's drawdown and protect the bear periods without giving back the long book's return?

## What we already know (do not re-measure)

- An SPY short on Phase B's exposure path (short in macro-Bearish weeks, 25–27 % average exposure) made
  +0.094 / +0.229 / −0.025 log in the 2000–02, 2008–09 and 2022 bears. It lost about −0.30 log over 26 years:
  the gate stays short through bear rallies and V-rebounds. Source: `results-2026-10-10.md` §8.2 item 1.
- The barbell was closed 06-27 and the idle-cash SPY sleeve was user-declined (`project_barbell_on_stocks`).
  That was a *long* SPY sleeve. This screen is the short side, which is a separate question.
- `Spy_only_weinstein` with `enable_stage4_short` (`spy-longshort.sexp`) already trades SPY long/short on its own
  30-week stage. It is standalone, though, not an overlay on the stock book.

## Book basis

Read locally 2026-10-11; only chapter and phrase are cited.

- **Ch. 9, "stock index futures".** The S&P contract is a vehicle traded with stage analysis on the index's own
  chart: the 1987 top was visible "if you did your technical homework".
- **Ch. 7.** "keep it simple": buy when the major trend is bullish, sell short when the climate is "clearly
  negative".
- **Ch. 9.** Static hedging strategies are "half-measures". So the faithful form is a **directional index short on
  the index's own breakdown**, sized off NAV. A permanent hedge ratio on the long book is not the faithful form.

This makes **SPY's own Stage 4** the primary gate. That gate does not depend on breadth. The macro composite stays
as a conjunction variant, and so does the Phase B path, which serves as the known-negative reference.

## Stage 1: offline overlay screen (no build)

This is a proxy screen (`mechanism-validation-rigor.md`). It may only conclude **"escalate to a built mechanism"**
or **"no-build decision"**.

- **Base:** the rb1 record NAV path per salt, rerun on the fixed breadth (the #3238 after-merge cell), with total
  return and interest on. The salts are rb1's three.
- **Overlay:**

  ```
  ln V*_T = ln V_T + Σ_t ln(1 − h · g_{t−1} · r_SPY,t) − borrow
  ```

  - `r_SPY` is the total-return daily change from adjusted closes, so the short pays dividends. Use the host `data/`
    SPY (test_data starts 2009).
  - `borrow` = 0.25 %/yr on the notional.
  - Short proceeds get no interest credit in the primary read. A sensitivity read credits the record's cash rate.
- **Gates** `g`, all weekly and lagged one week:
  - **G1** (primary): SPY's 30-week Stage 4, price below a falling MA, from the same stage classifier as the
    strategy.
  - **G2:** G1 and the macro gate Bearish.
  - **G3** (reference): macro gate Bearish alone, which is the Phase B path.
- **Sizing:** `h` ∈ {0.25, 0.5, 1.0} × NAV at t−1. This is a surface, not one point.

## Decision rule (pre-registered; applied per salt, then 2 of 3 salts)

A (gate, h) cell **escalates** when all four of these hold in at least 2 of 3 salts:

1. **Return cost.** The 26-year combined log return is at least the base's minus 0.05 log.
2. **Drawdown.** The combined max drawdown is at least 3 pp smaller than the base's.
3. **Bear periods.** The combined result beats the base in at least 2 of the 3 bear periods. These are the Phase B
   windows: 2000-03-24 → 2002-10-09, 2007-10-09 → 2009-03-09 and 2022-01-03 → 2022-10-12.
4. **Neighbours.** The adjacent `h` values for the same gate agree in sign on criteria 1 and 2.

If no cell escalates, there is no build: single-name and index shorts both stay off. In that case the short-side
flags (`enable_short_side` plus the four short-fix flags) are classified for Rule 4 retirement in the ledger. If a
cell escalates, the next step is to build the overlay behind a default-off flag and run the real 26-year paired test.

## Reported regardless of verdict

These are the eight checks from `mechanism-validation-rigor.md`:

- the per-episode table: every G1 episode, with its entry and exit, SPY move and overlay P&L;
- the distribution of episode P&L (n, mean, median, p10–p90);
- the bleed from bear rallies and V-rebounds, split by regime;
- the year table and the running ratio of combined NAV to base.

The why comes out as three parts, the same way Phase B's did: gate lateness, rebound bleed and costs.
