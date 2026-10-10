# shorts-phase-b-2026-10-09 — does a short-only Weinstein book make money by itself over 26 years?

Plan: `dev/plans/total-return-and-shorts-phase-b-2026-10-05.md`, decisions 6–10 and the progress note "Phase B
stop arms". This is queue item (3) of decision 9: the 26y shorts pair, on the same warehouse and accounting as the
long record (`../rebaseline-v12-2026-10-08/`, PR #3219). It is **round 1** of the decision-10 round cap. Phase A
(`../short-only-liveness-2026-10-04/`) was a liveness check, not a round. This pre-registration replaces the "Phase C
(26y, 3 salts, M1–M5)" that Phase A's README named: plan decision 7 folded that 26y run into Phase B, and decision 8's
stopping rule replaces M1–M5.

**Pre-registration only.** Nothing has run. Every rule below is fixed before any cell launches.

## Arms

Both arms are short-only: `max_buy_candidates 0`, `enable_short_side true`. Window 2000-01-01 → 2026-06-26. PIT
top-3000 **v12** schedule (`pit-v12/composition/top-3000-{1999..2025}.sexp`). Warehouse
`/tmp/snap_top3000_pit_v12pit`, pinned at 9,236 manifest entries. Salts 0, 1, 2.

| arm | spec | what it is |
|---|---|---|
| `v0-26` | `specs/v0-26.sexp` | Phase A's `soTs-5d` (structural stop, `Nearest`) moved to 26y, v12 and the long record's accounting, with every merged short fix armed (below). The short-only baseline. **Can launch now.** |
| `v1-26` | `specs/v1-26.sexp` | `v0-26` + the two #3218 flags: cancel resting short tickets the first week the macro screen is not Bearish, and a 4-week rest limit for short tickets. **Launches after #3218 merges.** The field names in the spec (`short_cancel_on_non_bearish`, `short_entry_order_max_rest_weeks`) are the ones #3218 *proposes*. They are confirmed against the merged `.mli` before launch, and any rename is a pre-launch commit with a Log line here. `launch.sh B` refuses to start unless both v1-only keys exist in the run tree. |

**v0's fixes (all merged, all default-off, armed in the spec):**

| issue | override | what it changes |
|---|---|---|
| #3131 / #3133 | `sim_entry_trigger_at_suggested true` + `short_min_price_on_order_price true` with `short_min_price 17.0` | The short ticket is a sell-stop at `breakdown_price` (book Ch. 7, ref §6 and §7), not at the decision close (Phase A) and not at the base top (pre-#3133). The $17 floor gates that order price. |
| #3145 | `stops_config.tightened_can_ratchet true` | A Tightened short buy-stop is lowered above each failed rally of ≥ 8 % (`ratchet_tightened_swing`). That is the book's short trail (ref §6.3, resolved 2026-10-06). `short_tightened_ratchet_follows_decline` is **not** armed: it is a stop-study arm, not the baseline (plan, "Phase B stop arms"). |
| #3146 | `share_class_gate_covers_shorts true` (with `max_one_share_class_per_issuer true`) | One share class per issuer on the short book (HEI/HEI-A, Phase A V6). |
| #3148 | `margin_config.short_maintenance_finra true` | FINRA 4210(c) short maintenance, max($5/p, 30 %), replacing Phase A's $5–17 step at 0.83 (which margin-called winning shorts, UBSI). |

**Accounting = the long record's (`rb1-26`):** `split_dividend_guard true`, `dividend_crediting true` (open shorts
**pay** each dividend on its ex-date, reported as `DividendPaidShortTotal`), `cash_yield (Series
macro/tbill_3m_dtb3.csv)` with `cash_yield_fee_bp 10.0`. The simulator's interest base is
`max 0 (cash − long margin debit − short proceeds)` (`cash_yield.mli`): short proceeds earn no rebate. Interest is in
the run, so the NAV path and sizing are those of a real account. It is **excluded** from the decision-8 return as
defined below.

Everything else is Phase A's short-only shape, unchanged: `neutral_blocks_shorts true` (shorts only in a Bearish
tape, ref §6.1 item 1), slow-grind gate off (not a book rule; ledger `2026-06-22-slow-grind-adlive-wfcv` Reject),
`require_structural_stop true` with `support_floor_anchor_scope Nearest` (initial buy-stop above the prior rally peak,
ref §6.3), borrow ADV floor $1M, borrow tiers 25 %/yr under $17 and 100 %/yr under $5, `max_short_candidates 20`,
short exposure and notional caps 0.60, `max_position_pct_short 0.10`, `entry_order_max_rest_weeks` 52 (default). The
long-side knobs carried over (`max_position_pct_long`, laggard rotation, ...) are inert with longs off.

## Stopping rule (plan decision 8), pre-registered exactly

### The return the rule reads: total return, cash interest excluded

For each cell, from the committed artifacts:

- V_t = `portfolio_value` in `<cell>-equity_curve.csv`; V_0 = $1,000,000.
- x_t = cash interest credited over (row_{t−1}, row_t]. The simulator reports only the total (`cashinteresttotal`
  in `<cell>-summary.sexp`), so x_t is reconstructed per calendar day and then scaled to that total:
  - interest_d = max(0, B_{d−1}) × max(0, DTB3_d − 0.10) / 100 / 360, DTB3 forward-filled from
    `trading/test_data/macro/tbill_3m_dtb3.csv` (the method of `../total-return-26y-2026-10-06/results-2026-10-07.md`
    §1);
  - the base B_d = V_0 + realised short P&L of positions closed by d (`trades.csv` `pnl_dollars`) − commissions −
    borrow (tiered estimate from the bars, as in Phase A) − dividends paid (reconstructed from `dividends.csv` per
    open short, split-scaled as in `tr_reconstruct.awk`) + interest accrued so far. For a short-only book this is
    cash minus short proceeds, the simulator's base.
  - **Gate:** the unscaled reconstruction must land within ±2 % of `cashinteresttotal`. Outside that, the cell's A/B
    read waits until the gap is traced. Inside it, each x_t is multiplied by `cashinteresttotal` / reconstructed
    total.
  - The script is committed as `results/analysis/` with the results, and qc-results re-runs it.
- **R_ex (log) = ln(V_T / V_0) − L_int**, with L_int = Σ_t ln(V_t / (V_t − x_t)). This is the log of what the book
  would have ended at with every interest credit withheld and the book scaled down accordingly: the interest and its
  compounding are both removed.
- **R_ex ($) = (V_T − `cashinteresttotal` − V_0) / V_0**, the plain dollar subtraction, as a second reading.
- Dividends paid by shorts, borrow and commissions **stay in**. They are costs of the short book.

**A condition holds on a cell only if both R_ex (log) and R_ex ($) are > 0.** If the two differ in sign, A does not
hold and the writeup says so.

### A: positive total return over 26 years (ex interest)

R_ex over the full window (2000-01-01 → the last equity-curve row, 2026-06-26 or the last trading day before it).

### B: positive in ≥ 2 of the 3 bear periods (ex interest)

Each period runs from the S&P 500's closing high to its closing low:

| period | start (SPX closing high) | end (SPX closing low) |
|---|---|---|
| 2000–02 | 2000-03-24 | 2002-10-09 |
| 2008–09 | 2007-10-09 | 2009-03-09 |
| 2022 | 2022-01-03 | 2022-10-12 |

V at a bound = the last equity-curve row on or before that date. The period return is R_ex over those rows, with
L_int summed over the period's rows only and R_ex ($) = (V_end − V_start − interest in the period) / V_start. B holds
on a cell when ≥ 2 of the 3 period returns pass both readings (> 0).

**Give-back (diagnostic, not a gate).** For each period also report trough → trough + 26 weeks (2003-04-09,
2009-09-07, 2023-04-12), because Phase A's main loss mechanism was crash gains given back in the rebound. If B
passes but the give-back exceeds the bear-period gain in ≥ 2 periods, the writeup says so in its verdict section.
Calendar-year returns (2000, 2001, 2002, 2008, 2009, 2022) are reported descriptively too.

### Decision per arm and overall

- **An arm passes decision 8** when A and B both hold, jointly, in **≥ 2 of its 3 salts**, counting only valid
  salts (§Validity gates). With one salt excluded, both remaining salts must pass. With two or more excluded, the arm
  is not read. The salt spread of R_ex is always reported.
- **The stopping rule passes** if v0 **or** v1 passes. If only v1 passes, v1 is the candidate short book. Its two
  flags stay default-off; this run flips no default (`experiment-flag-discipline.md` R3). Pass → the next step is
  long–short integration, which needs its own pre-registered criteria (plan, Known gaps: not in scope here).
- **If neither arm passes, round 1 has failed.** Round 2 runs only if anatomy C (item 4) names a **specific cause
  with a book-supported fix**, pre-registered in its own directory before it runs (decision 10). If the stopping
  rule still fails after round 2, or if round 1 fails with no such cause: **stop single-name shorts**, record the why
  (a `project_*` memory and a ledger entry under `dev/experiments/_ledger/`), and send bear protection to the
  index-hedge decision as its own question.
- If v1 has not run (#3218 unmerged) when v0 finishes, v0 is read on its own. A v0 pass already passes the rule.
  A v0 fail is a provisional round-1 result until v1 is read.

**C: per-position anatomy** (item 4) is diagnostic only: it names the lever and is never a threshold.

## Validity gates

1. **Lists = warehouse.** `launch.sh` refuses to start unless every symbol in the run tree's top-3000 schedule is in
   the v12 manifest (MEL excepted), and logs the lists md5. rebaseline-v12 ran on md5
   `b62da7e2c4958c42a9805c89222c2d88` (union 9,222). A different md5 is reported with the reason. Each cell's
   `n_symbols_absent` (snapshot cache line) is reported.
2. **V6 = 0 on every cell**, absolute, from each cell's validator report. #3146's fix makes a share-class twin on the
   short book a defect, not a known gap. A cell with V6 > 0 is traced and excluded from the A/B/C reads.
3. **`validator_diff -check V6` v1 vs v0 exits 0 per salt** (the chain runs it). An exit of 1 means the arms hold
   different instrument sets: that salt gives no v1 − v0 delta (`mechanism-validation-rigor.md` check 8). Each arm
   is still read on its own against decision 8.
4. **Same build for the pair.** Lane B runs on a later build than lane A. Its first cell re-runs v0 s0 and the chain
   compares `trades.csv`, `actual.sexp` and `equity_curve.csv` byte for byte with lane A's (`REPLAY_REF`). If they are
   identical, lane A's v0 s1/s2 stand as the partners. If not, every v0 salt re-runs in lane B, and only lane B's v0
   is paired with v1. Lane A's v0 is then reported as the earlier build's reading, and both build SHAs are given.
5. **Every cell writes `actual.sexp`.** A `<no result>` is traced (OOM vs input, `container-capacity-scheduling.md`)
   before any relaunch. `PREFLIGHT=1` runs each spec over 2022-04-01 → 2022-06-30 first, a Bearish stretch, so the
   short path is exercised before the night starts.
6. **Interest reconstruction within ±2 %** of `cashinteresttotal` (above).
7. **Same build, inputs and accounting as the long record** except the short-side overrides: the run-tree SHA, lists
   md5, warehouse count and staged `dividends.csv` / `splits.csv` counts go in the results writeup.

### After-merge verification items this run carries

- **#3131** (`verify/pending`), `[after-merge]`: "the investor-style short-only cell is live (≥ 10 fills, ≥ 5 in
  2008)". The read on v0, per salt: short fills (`trades.csv` + `open_positions.csv`) ≥ 10, and ≥ 5 of them filled in
  calendar 2008. As supporting evidence of the merged gate, zero short tickets placed at an order price below $17
  (`trade_audit.sexp` entry records), and the count of "churn signature" trades (fill < $17, `margin_call` exit within
  4 days), each one traced to a gap through the ticket. The item **passes** when all valid v0 salts are live and no
  ticket was placed below $17. Then #3131 is closed with that evidence. Otherwise it stays `verify/pending` with the
  reason.
- **#3145** (`verify/pending`), `[after-merge]`: "per-trade replay on the short-only Phase A audits, then a
  pre-registered short-side stop study". **This run does not satisfy that item.** It runs the faithful trail, not
  the merged #3145 flag, and it is not a stop study. It reports what bears on it: short positions that reached
  `Tightened` and how many had their stop lowered at least once (`stop_decisions` in `trade_audit.sexp`), and the
  ADSK-shaped freeze count (a short holding one stop for ≥ 26 weekly decisions while the close fell ≥ 30 % below
  it). Expected ~0 with the trail on. #3145 stays `verify/pending`. The issue gets a comment pointing here.
- #3146 and #3148 are closed. Gate 2 (V6 = 0) is #3146's run evidence. For #3148, margin calls are reported with the
  mark and the equity ratio, and any call on a short whose equity ratio was above the FINRA requirement is a defect
  to trace.

## Pre-registered reading (in this order; nothing is analysed before items 1 and 7 run)

1. **Validity gates** above, each with its value per cell.
2. **Liveness, per arm and salt:** short tickets placed, filled, cancelled (by cancel reason: TTL, the v1
   macro-cancel, the v1 rest limit), never filled. Fills by calendar year and by screen week (Bearish / Neutral /
   Bullish at fill, counted over `trades.csv` and `open_positions.csv`, as in Phase A rule 3). Bearish screening weeks
   and how many admitted a short to the top-N (`cascade_summaries`). For v1, the number of stale fills (filled in a
   non-Bearish week) should fall to ~0; every remaining one is traced.
3. **Decision 8**: A and B per cell (both readings), the bear-period table (per salt and arm: R_ex log and $, SPY
   total return over the same rows, mean short exposure, fills, dividends paid by shorts, interest stripped), the
   give-back rows, the arm decisions and the overall call. The v1 − v0 delta per salt (V6-gated, gate 3) with its
   paired per-position read (positions joined on `symbol|entry_date`; `position_id` is not a cross-arm key).
4. **Anatomy C (diagnostic):** win rate × mean win vs mean loss, with n, mean, median and p10/p25/p75/p90 of trade
   return, per salt and pooled, split four ways:
   - **entry:** entry year; macro state at fill; fresh breakdown vs stale fill (rested ≥ 4 weeks); price band
     (≥ $17 at fill vs gapped below).
   - **stop:** exit by the initial stop, the trailed stop or the Tightened stop; planned vs realised stop distance.
   - **squeeze:** exits filled more than 1.5 × the planned stop distance against the position, forced covers and
     margin calls, by date. Clusters on rally days (2008-11-24, March–April 2009, and others the data shows) are
     named.
   - **hold:** holding-period buckets; MFE vs realised for positions with MFE ≥ 20 % (the give-back); open at the end.
   Per-trade P&L in `trades.csv` excludes dividends paid and borrow (#3175 analogue). The anatomy adds each
   position's reconstructed dividends paid and estimated borrow back, and says so. The top 5 and bottom 5 positions
   per salt are traced end to end. The anatomy states which bucket carries the loss or the gain, whether a book rule
   addresses it, and so whether decision 10's round-2 condition is met.
5. **Forced covers and margin calls:** counts per cell by `exit_trigger` (`margin_call` and the #3147 labels),
   `force_liquidations.sexp` entries, the fill price of each, and the sub-$17 churn signature (item #3131 above).
   **The Phase A churn (60 / 40 sub-$17 fills, all margin-called within 1–4 days) must be gone.** Any remaining
   instance is traced.
6. **Dividends paid by shorts:** `dividendpaidshorttotal` per cell, its log cost computed as L_div on the equity
   curve, ordinary (< 5 % of the prior close) vs specials, the 10 largest events, and `dividendmissingfilecount` as a
   share of distinct shorted symbols.
7. **Review pack** for v0 s0–s2 (and v1): built with `dev/scripts/review_pack.sh` from the sweep output, rendered with
   `review_pack_render.sh`, and every image looked at before any analysis (`backtest-result-review.md`, RV1–RV3).
   The pack reads shorts side-aware since #3149. The look checks that it does: grades, breach (`high >= stop`),
   slippage above the stop, give-back from short MFE, and exposure including open positions. Any long-side reading
   left is a pack defect, fixed and pinned. Exposure is read against the SPY regime by period (RV2). The writeup
   confirms, refines or rejects each "What stands out" bullet (RV3).
8. **Reading by `results-analyst`** (direction-class, `model-routing.md`): applies this rule as written, decomposes
   why (`mechanism-validation-rigor.md`: the estimand, distributions, economic scale, paired per-event reads), and
   states the next lever. Because this verdict can close the single-name shorts programme, a second independent read
   (the `blind-judge`-style analyst with no access to the first) is worth its cost when the call is a stop. Any
   disagreement goes to the user. **`qc-results`** reviews the results PR. The analyst never reviews its own reading.
9. **Bookkeeping after the chain:** `sh dev/scripts/perf_long_cells.sh update <chain log>` (the first short-only 26y
   cells in the ledger), per-arm raw artifacts committed under `results/`, the #3131 / #3145 issue updates, the ledger
   entry, and the `project_shorts_liveness_dead` memory updated.

## Known gaps (stated up front)

From the plan's list, as they stand for this run:

- **Bear-period coverage.** This is the first short read of 2000–02 and 2022. Phase A saw 2007–12 only.
- **Squeezes have no mechanism** in v0 or v1. Phase A's largest losers ran through their stops on rally days. If
  anatomy C points there, round 2 needs a book-supported answer (stop placement), not a new invention.
- **Margin realism.** #3147 (labels) and #3148 (FINRA) are fixed, and FINRA is armed here, so margin calls are not
  comparable with Phase A's tier step. Buy-ins from share recall are not modelled (`short_buyin_stress_mode` off).
- **#3136 is fixed in the list ranking only.** The liquidity gates (`min_entry_dollar_adv`, `min_hold_dollar_adv`)
  and the short borrow-ADV floor still compute dollar volume on the mixed basis, as in rebaseline-v12. The book is
  "v12 lists, v11-basis liquidity and borrow gates".
- **#3109 / dividend data quality.** The split-dividend guard is on. Specials are paid by shorts at their gross
  amount, which is right for a short (a manufactured dividend carries no withholding). Cash leaves on the ex-date,
  not the pay date (2–4 weeks early). Some files are mis-scaled or empty (#3176).
- **Re-baseline ripple.** All figures here are total-return basis. Phase A's are price-only on v11 and are quoted
  only with that label.
- **Long–short integration** comes after short-only passes. It is not in scope here.

New, found while writing this:

- **No short rebate.** Interest is credited on cash minus short proceeds. A retail account gets no rebate; a
  professional one would. This understates a real short book slightly, and the rule excludes interest anyway.
- **Resting short tickets are not reduced on ex-dates.** FINRA 5330 reduces sell-stop orders by the dividend.
  `ex_dividend_stop_adjust` (#3174) covers held longs' stops only. The effect on short entry tickets is small and
  is not measured here.
- **No uptick / short-sale-restriction rule** (pre-2007 uptick rule, Rule 201 from 2010). The book's wider short
  limit exists because of it. Fills on down-gaps may be optimistic.
- **Terminal events for shorts** (bankruptcy, delisting, splices) are not separately verified. Phase A's CHMT_old
  splice (D4) marked a short across a bankruptcy emergence. Any v0/v1 short open across a delisting or a
  `terminal_runs` event is traced, and its P&L is shown with and without it.
- **#3138:** an at-fill cash shortfall cancels an entry outright, so small differences fork paths. v1 − v0 diverges
  for that reason as well as for the lever.
- **Preset coherence.** The entry is the book's full position on the breakdown (ref §6.2, the trader's short), the
  stop is the Ch. 7 protective buy-stop walk-through, and the macro gate is the confirmed-bear rule. These are all
  short-side book rules. No long-preset dial is grafted on.
- **The cell guard is sized from long cells** (36,000 s ≥ 1.5 × the slowest rebaseline-v12 cell, 21,249 s) and from
  a 26.5y extrapolation of Phase A's slowest 5y short-only cell (~19,500 s). No 26y short-only cell has been timed.
  If a cell dies on the guard, the guard is resized from the measured progress lines, never reused blindly.
- **v1 depends on #3218's final names and semantics.** If the merged mechanism differs from the issue's description
  (for example, a suspend instead of a cancel), v1's spec and this README are amended in a pre-launch commit, and the
  difference is stated in the results.

## Files

- `specs/v0-26.sexp`, `specs/v1-26.sexp`
- `results/launch.sh` (lane A = v0 × 3 salts; lane B = v1 × 3 salts plus the v0 replay; stages the inputs outside
  the VCS tree and the dividend/split files into the run tree, pins the warehouse count, checks lists = warehouse and
  the knobs, launches)
- `results/chain-spb.sh` (the chain: a copy of `chain-rb12.sh` plus the credit metrics in the RESULT line and the
  lane-B replay)
- Run artifacts land in `/tmp/sweeps/shorts-phase-b` (lane A) and `/tmp/sweeps/shorts-phase-b-v1` (lane B), host
  `.sweep-output/`, and are committed per arm and salt under `results/`.

## Log

- 2026-10-09 — pre-registered (v0 launchable; v1 waits on #3218).
- 2026-10-09 02:39 PT — lane A launched at 904746e8c. **Stopped 07:42 by the dispatcher** after s0 and s1 both
  read V6 = 1 (gate 2): AIG and AIG-WS, the vendor `-WS` series that copies AIG's closes to 2011-01-12, were held as
  two shorts. s2 would follow the same path, so it was not run. The stopped chain log is `results/chain-A-stopped.log`
  (s0 −36.96 %, s1 −37.58 %, 197 trades each; excluded from every read). Fix: #3227 (10f725ffe) groups the copied
  `-WS`/`-WT` series with their parents in `share_classes.sexp`.
- 2026-10-09 09:31 PT — lane A relaunched at 10f725ffe (lists md5 `deca56c7…`, union 9,222, warehouse 9,236,
  11,880 dividends/splits files staged). Done 17:07; V6 = 0 on all three salts.
- 2026-10-09 17:09 PT — #3218 merged as #3221; both v1-only keys (`short_cancel_on_non_bearish`,
  `short_entry_order_max_rest_weeks`) found in the merged `.mli` under the spec's names, so no spec amendment. Lane B
  launched at 27881ae05 (same lists md5). Its v0 s0 replay was byte-identical to lane A's (gate 4), so lane A's
  v0 s1/s2 stand as partners. Done 2026-10-10 05:42; V6 = 0 and `validator_diff -check V6` v1 vs v0 exit 0 on all
  three salts.
