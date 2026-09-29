# Obvious fixes, salt 0: result and full decision walkthrough (2026-09-26)

**Status: salt 0 only — not a verdict.** Salts 1 and 2 of `f2-fills-faithful` and the
Fix-A-only arm `f1-stoplimit-fresh` s0 are still running (chain A,
`/tmp/fixes-run/chain-A.log`). Anything that separates the two arms below may still be
salt luck: the null's own band is 457 / 188 / 152 % across salts 0–2.

Review pack (published): https://claude.ai/artifact/AEKnAbPUqth16b1Ye7nKiA
(fixed s0 next to the null at all three salts).

## Setup

- **Null:** `a0-pit-null` — the 26y PIT top-3000 record config, 2000-01-01 → 2026-06-26,
  yearly `universe_schedule`, `_v11pit` warehouse.
- **Arm `f2-fills-faithful`:** the null plus both fill-model fixes:
  - `sim_entry_stoplimit_fresh_bar_only` (#2963): a StopLimit entry no longer fills
    against the stale Friday bar the engine retains on the Saturday step.
  - `sim_stop_exit_fill_on_trigger_bar` (#2967, issue #2961): a stop exit fills on the
    bar that traded the stop (resting sell-stop, book §5.7), not at the next open.
- **Build:** pinned worktree `sweep-fixes` @ fe082e788.
- **Reproduction check:** the null s0 reproduced the committed band exactly (457.0069 %,
  732 trades, identical `trades.csv`).

| cell | return | trades | Sharpe | maxDD | Calmar | V6 vs null | wall |
|---|---:|---:|---:|---:|---:|---|---:|
| null s0 | 457.01 % | 732 | 0.482 | 40.64 % | 0.165 | — | 19,146 s |
| f2 s0 | 132.78 % | 724 | 0.276 | 54.57 % | 0.059 | PASS (exit 0) | 19,088 s |

## 1. Why salt 0 dropped from 457 % to 133 %

Paired by symbol + entry date (`position_id` matches on only 287 of the 433 shared trades, so it is not the join key across arms):

- **Mostly path divergence (58 % of the $2.62M gap; the other 42 % is on the 433 shared trades — the −0.61 % stop-fill cost below plus, likely, NAV-path sizing, not decomposed).** The Saturday gate changes the first entry (NOV,
  2000-01-22) and every later decision follows a different path.
  - 433 trades are shared by both arms (they made $2.41M in the null and $1.31M in the
    arm).
  - 299 null-only trades made +$1.43M: ECHO $647k, GME, GLNG, TRN, FND, CHDN.
  - 291 arm-only trades made −$0.09M: IRTC $319k, KOD, PCYC, ENSG, CRI, ORCL.
- **The lottery is visible in the totals.** The arm's top-10 trades made $2.39M and the
  other 714 lost $1.17M. The null's top-10 made $3.59M and the rest made +$0.26M.
  Missing ECHO / GME / GLNG / CHRW is the gap.
- **One real per-trade cost, from Fix B.** Take the 284 positions stopped in both arms
  where the null sold at the next open. The arm's same-bar fill is −0.61 % mean /
  −0.43 % median (better 109, worse 175) — prices tend to bounce the morning after a stop
  trades. Stop-loss exits average −4.03 % vs −2.88 %. The earlier replay estimate
  ("P&L-neutral", −$51k) covered unraised initial stops only; #2961 was updated.
- **Same entry prices on shared trades** (mean diff 0.00 %) → Fix A changes which trades
  happen, not their fill price.

Year by year, the arm has the lower NAV return in 21 of 27 years (yearly return from `equity_curve.csv`, each year based on the prior year-end; by realized P&L the count is 23/27 by exit year, 20/27 by entry year). The biggest gaps (2021, 2025, 2026,
2016, 2011) each trace to one or two monsters only one arm caught.

## 2. Decision walkthrough (arm f2 s0, every weekly screen)

Built from `trade_audit.sexp`:
- `cascade_summaries` for all 1,335 weeks, including weeks with no entry;
- 1,284 placements (724 filled), each with its cash-rejected alternatives;
- exits.

Rebuild with `walk.sh` (below). Weekly stop decisions are **not** recorded (#2977).

### 2a. The macro gate is probably not where the money went (one arm, one salt)

Returns in the week after each screen, compounded by the macro state of that screen:

| era | macro | weeks | SPY | NAV | invested |
|---|---|---:|---:|---:|---:|
| 2000–08 | Bearish | 242 | −26 % | +6 % | 27 % |
| 2000–08 | Bullish | 147 | −17 % | +23 % | 80 % |
| 2009–19 | Bearish | 133 | +65 % | +1 % | 33 % |
| 2009–19 | Bullish | 340 | +93 % | +72 % | 81 % |
| **2020–26** | **Bullish** | **260** | **+83 %** | **+2 %** | **77 %** |
| 2020–26 | Neutral | 41 | +18 % | −15 % | 51 % |

From 2020 on, the fund was mostly invested in bullish tape and earned nothing. The
Bearish-week cost in 2009–19 is real but secondary.

### 2b. The picks look fine (one arm, one salt)

Paired per screen week, funded placements vs the cash-rejected alternatives on 26-week
forward adjusted return from the screen date. The funded mean beat the alternatives'
mean in **48 %** of weeks in every era (134 / 252 / 190 weeks). Selection is a coin flip
against its own near-misses, as `project_decision_audit_faithful` found on sp500.
2020–26 funded names rose +15.3 % on average over the 26 weeks after placement — the
stocks worked; the trades did not.

### 2c. Where it went: stops that shake out working stocks

| initial stop | trades | P&L | mean / trade | stopped out | quick-fail | typical width |
|---|---:|---:|---:|---:|---:|---:|
| automatic % (`Buffer_fallback`) | 562 (78 %) | +$1.05M | +1.00 % | 72 % | 38 % | 4.7 % |
| below support (`Support_floor`) | 162 | +$0.18M | +2.08 % | 44 % | 10 % | 13.3 % |

*Quick-fail* = stopped within 20 days with the best excursion < 3 %.

Stop width against the stock's own noise (20-day ATR before the fill, median 2.9 %):

| stop distance / ATR20 | trades | quick-fail |
|---|---:|---:|
| < 1 | 100 | 48 % |
| 1–2 | 319 | 41 % |
| 2–3 | 157 | 27 % |
| ≥ 3 | 148 | 6 % |

58 % of trades carry a stop inside two normal days of movement. After being stopped, the
2020–26 quick-fail names rose +8.7 % over the next 13 weeks (62 % higher); 2023 +8.2 %
(CLS −5 % → +63 %, EQT −4 % → +64 %, SAIA −5 % → +43 %). P&L is not monotone in stop
width (the fat tail dominates), so this is a cohort observation, not a causal claim. The
causal test is `require_structural_stop` (#2966), queued as the broad investor preset.

The two stop cohorts differ in more than the stop, so the table above is a comparison of
populations, not an ablation.

### 2d. Year walks

Week-by-week files `walk-2021.txt`, `walk-2022.txt`, `walk-2023.txt` are not committed; regenerate them with
`walk.sh`.

- **2021** (fund −6.9 %, SPY +28.7 %; macro Bullish every week):
  - 44 fills, 30 stop exits (−$720k); 13 stopped within 7 days of filling (−$386k), 8 of
    those names higher 13 weeks later.
  - The installed stop is trigger × 0.96 while the audit's `suggested_stop` is about 8 %
    (EQT, SAIA, BEAM) — #2975.
  - BEAM was bought 49 % above its 30-week MA with a 4 % stop and gapped −25 %.
  - Only 4–8 positions at ~14 % each, so one quick-fail costs 2–4 % of NAV (Jan 22: NAV
    −10.5 % vs SPY −3.3 %).
  - Jun–Aug exposure was 29–58 % while placed tickets rested unfilled.
- **2022** (−27.7 % vs −18.2 %): 39 fills, 35 stop exits (−$698k), 16 within 7 days.
  - Here the stops were **right**: names fell a further −3.6 % over 13 weeks. The damage
    is entering at all:
    - about 30 buys in Neutral weeks during the bear-market rallies (Mar–Apr, Aug, Nov);
    - three fills on Feb 11 at 95 % invested, the week before the Bearish flip, then 5
      stops on Feb 25;
    - resting tickets filling in Bearish weeks (EOG 186 w old, HLIT 745 w).
- **2023** (−2.4 % vs +26.2 %): 49 fills, 37 stop exits (−$747k), 20 within 7 days.
  - Stopped names then rose +8.2 % (CLS +63 %, STVN +32 %, ERIE +27 %, CCJ +29 %).
  - Only the Nov–Dec stretch — fully invested, fresh fills that were not shaken out —
    worked.

### 2e. Other findings

- **Resting tickets never expire.** The record spec pins `entry_order_max_rest_weeks 0`
  (the default is 52 since #2587).
  - 202 of 724 fills came from tickets ≥ 26 weeks old; 30 from tickets > 5 years old;
    the maximum is 885 weeks. A (placed 2014-06-13) filled 2017-07-14 on 2014 stage and
    macro context.
  - The stale cohorts were net profitable (0–4 w −$488k; 5–25 w +$892k; ≥ 26 w
    +$817k), consistent with `project_stale_order_fills_are_not_an_edge` being a lottery
    read. Faithfulness, not P&L, is the objection.
- **Resting tickets bypass the macro gate.** 103 fills (14 %) happen while the last
  screen read Bearish; the stale ones are net −$264k. Book / C2: a bearish tape blocks
  buys. #2976.
- **Trailing stops rarely rise.** 675 of 724 trades never had a stop raise (−$2.55M);
  the 49 that did made +$3.77M. Among trades held ≥ 13 weeks, 20–26 % were raised. The
  book's investor rule raises only after an 8–10 % correction plus recovery (§5.2), so
  this may be faithful plus the 4 % initial stop firing first. #2974 asks for the trace.
- **Laggard rotation sells names that keep going.** Of 234 rotation exits, 148 were
  higher 13 weeks later (75 by > 10 %; mean +4.1 %). Rotation is still the profit engine
  (+$6.0M), and book Ch. 4 endorses it ("lighten up on that position even if the
  sell-stop isn't hit"). Open question, no action yet.
- **The record config is a hybrid**, not an investor or trader preset: 30-week MA and
  base breakouts (investor) with trader dials:
  - the automatic 4 % fallback stop;
  - full size on the breakout;
  - the Stage-3 force exit;
  - the extension stop;
  - a 10 % catastrophic stop.

  This is the mixing `weinstein-faithful-core.md` warns about. The broad investor preset
  is written and queued (`../investor-preset-2026-09-26/`).
- **Audit basis mismatch.** `close_at_decision` is raw while `ma_value` is split-adjusted
  (NVDA 2021-04-23: 610.61 vs 13.67; adjusted close 15.21). Reporting only; the strategy
  compares on one basis. It motivated #2973 (split corpus).

## 3. Issue list and where each is tracked

| # | finding | tracked |
|---|---|---|
| 1 | stop exits filled at next open | fixed behind a flag, #2967 / #2961 |
| 2 | Saturday entries filled on Friday's bar | fixed behind a flag, #2963 |
| 3 | same-bar stop fill costs −0.6 % per shared stop exit | #2961 comment (cost of the faithful fix) |
| 4–5 | automatic 4 % stop on 78 % of trades; stops inside 2 ATR | #2966 flag; investor preset queued (QUEUE item 3) |
| 6 | installed stop ≈ half of `suggested_stop` | #2975 |
| 7 | trailing stops rarely rise | #2974 |
| 8 | shakeouts: stopped names recover | consequence of 4–7 |
| 9 | tickets never expire in the record spec | investor preset uses the 52 w default |
| 10 | tickets fill in Bearish weeks | #2976; QUEUE item 6 |
| 11 | Neutral macro admits buys in bear rallies | record only — index-stage veto REJECT-as-default 09-21 |
| 12 | idle cash while tickets rest | record only |
| 13 | result = a few monsters | salt band pending (chain A) |
| 14–15 | 2020–26 invested but flat; picks ≈ alternatives | explained by 4–8 |
| 16 | 4–8 positions at 14 % | record only — concentration surface memory |
| 17 | laggard rotation exits names that keep rising | open question |
| 18 | record config is a hybrid | investor preset, QUEUE items 3, 4, 7 |
| 19 | split basis keeps recurring | #2973 |
| 20 | weekly stop decisions not recorded | #2977 |
| 21 | `review_pack.sh --no-container` sed noise | #2978 |
| 22 | runtime scaling 5y vs 26y | QUEUE item 8 |

## 4. Reproduce

```sh
# review pack (host only)
sh dev/scripts/review_pack.sh --out .sweep-output/review-fixes-s0 --no-container \
  fixed-s0=.sweep-output/obvious-fixes/f2-fills-faithful-s0-v11- \
  null-s0=.sweep-output/obvious-fixes/a0-pit-null-s0-v11- \
  null-s1=.sweep-output/pit-null/a0-pit-null-s1-v11- \
  null-s2=.sweep-output/pit-null/a0-pit-null-s2-v11-

# walkthrough tables + year walks (~2 min, needs ./data)
sh dev/experiments/obvious-fixes-2026-09-25/walk.sh \
  .sweep-output/obvious-fixes/f2-fills-faithful-s0-v11- \
  .sweep-output/review-fixes-s0/site/data:fixed-s0 OUT 2021 2022 2023
```

`walk.sh` reproduced every number in §2 byte-for-byte from the artifacts
(`OUT/tables.txt`).

## 5. Still to do

1. Salts 1–2 and `f1-stoplimit-fresh` s0 → the verdict, and Fix A vs Fix B attribution.
2. Commit per-arm artifacts (`results/`) with the verdict (qc-results lane).
3. Walk the remaining years (2000–20, 2024–26).
4. #2974 trace, then decide whether the trailing stop needs work.
