# Local-range entry anchor on the investor preset: re-entering recoveries (2026-10-02)

## Why

The trader-preset rerun's review pack (`../trader-presets-rerun-2026-10-02/`, PR #3081) showed the 2007–12
equity curve flat from January 2008 to August 2009. The user's read: *"we could have done a better job at
investing into the recovery."* The dissection (T1 `tp-t1-5d-s0-v11`):

- **The macro gate was not the bottleneck.** It turned Bullish on 2009-05-08, eight weeks after the March
  low.
- **The screener responded.** It made 91 entry decisions in May–July 2009, and none filled. The first fill
  came in August; 2009 averaged 26 % invested.
- **The tickets were far above the market.** 89 of 91 were placed ≥ 10 % above the close at decision
  (median 60 %, p90 135 %). This is not a split artifact: the gap is 1.93× on unsplit names and 1.66× on
  split ones.
- **The cause is the anchor.** With `entry_anchor_local_range_weeks = 0`, `suggested_entry` is the graded
  resistance top (the max high 8–60 weeks back). After a crash that is the pre-crash level, so a stock had
  to reclaim its whole decline before the buy-stop could trigger.
- **The investor preset is the same.** `tp-i-5d` (09-29 matrix) has **0 entries in May–August 2009 at all
  three salts**. The 26y investor pack reads "eroded 2009: in cash while the market rose, UP days +2.4 % vs
  SPY +21.7 % at 21 % invested".
- **Proxy screen** (not a backtest): the 91 unfilled names, held 26 weeks from the decision close, made a
  median +17.5 % (mean +23 %, 76 of 90 up), against SPY +19–32 % over the same span. They kept pace with
  the rebound, they did not beat it.

**Faithfulness.**
- `weinstein-book-reference.md` (end of §4.1) already records that the book's checklist anchors the
  buy-stop at the top of the *current* trading range ("write down the price that each would need to break
  out"). It names our graded top "a deliberately conservative alternative … an open design axis, not
  book-settled".
- Ch. 3: Stage 2 begins on a move "above the top of its resistance zone".
- Ch. 4 treats overhead supply as a quality grade ("the one with little or no resistance in its path …
  will go further"; "the older the resistance, the less potent it is"), not as the trigger level.
- This experiment is that open axis.
- It is **not reversal timing** (`feedback_no_reversal_timing`): stage classification and the macro gate
  are unchanged. The knob only moves the ticket (and its derived stop/risk) to the current base
  (`weinstein_strategy_config.mli`, "Strictly ticket-level").

## Arms

| arm | change vs null |
|---|---|
| `ia0` (null) | the 09-29 investor preset `tp-i-<w>`, byte-copied except the header and name |
| `ia4` | `((entry_anchor_local_range_weeks 4))` (the arc/record-ladder value) |
| `ia13` | `13`: a quarter, about a Weinstein base |
| `ia26` | `26`: the docstring example |

A surface, not a point (`mechanism-validation-rigor.md` check 5). The null runs at every salt on this
build, so every pair is same-build.

## Windows, salts, phases

- **Phase 1:**
  - windows `5d` (2007-06-01 → 2012-06-29, the recovery window) and `5r` (2021-06-01 → 2026-06-26), PIT
    top-3000;
  - salts 0/1/2;
  - 24 cells, one chain, one build (main at launch), pinned worktree;
  - about 25–45 min per cell, so roughly 12–14 h.
- **Phase 2** (26y, `ia0` plus the phase-1 candidate value(s), 3 salts): launched only per rule 6 below;
  about 3.2 h per cell.

## Reading rule (pre-registered 2026-10-02, before any cell runs)

1. **Gate.** `validator_diff -check V6` exit 0 per pair per salt. The valid-salt thresholds are as in
   `../trader-presets-2026-09-29/README.md` rule 1: 2 of 3, or 2 of 2, else "no reading".
2. **Same-build anchor.** Each `ia0` cell must match the 09-29 `tp-i` cell on the same window and salt
   (`trades.csv` and `actual.sexp` metrics). A mismatch is reported; the in-chain pairs stay valid, since
   both arms share the build.
3. **Liveness (mechanism check, 5d).** Per salt, report entries filled 2009-05-01 → 2009-08-31, and the
   average invested % of NAV from 2009-05-08 → 2009-12-31 (review-pack NAV series).
   - The null has 0 entries in May–August 2009.
   - An arm with 0 there at every salt is "not live in the recovery", whatever its Calmar.
4. **Per value, per window.** The four outcomes as in the 09-29 rule 3 ("adds" / "mixed" / "dilutes" / "no
   reading"), arm vs `ia0`: Calmar ≥ the null at the required number of valid salts, and max DD never
   > 5 pp worse.
5. **Per-trade check for every "adds".** Join to the null on (entry date, symbol): the shared trades'
   `pnl_percent` change, the unshared trades' counts, P&L and wins. Also name the top unshared trade and
   its share of the delta. A delta carried by one trade is reported as such (the #3081 lesson).
6. **Phase-2 trigger.** A value goes to the 26y phase if it is "adds" at 5d **and** not "dilutes" at 5r.
   - If several qualify, take the one with the highest median Calmar across both windows, plus its
     neighbour if that neighbour also qualifies.
   - If none qualify, there is no phase 2, and the record says why.
7. **Exposure statements** carry the regime split per period (`backtest-result-review.md` RV2). The
   review packs for the `ia0` arm and each candidate arm are built, rendered and looked at (RV1/RV3).
8. **Verdict calibration.** No default flips from this experiment. A ledger entry only follows phase 2.
   "Adds" in both phase-1 windows plus phase 2 at the required threshold gives Accept(mechanism),
   promotable only through the confirmation grid (`promotion-confirmation.md`).

**Expected costs, stated in advance.** A nearer anchor triggers earlier in every regime, not only after
crashes, so expect more trades. Expect more failed breakouts in choppy markets, a higher stop-exit share,
and possibly a worse 5r. Expect the stop derived from the ticket to move with it. Report the trade
count, the stop-exit share and the median holding period per arm.

## Files

- `specs/`: `ia{0,4,13,26}-{5r,5d,26}`. The 26y specs are written now, so phase 2 runs specs fixed before
  phase 1.
- `results/chain-anchor.sh`: a copy of the trader rerun chain with paths moved to `/tmp/anchor-run` and
  `/tmp/sweeps/entry-anchor-recovery`.
- `results/launch.sh`: `PREREG=<this commit> sh launch.sh`, phase 1.
