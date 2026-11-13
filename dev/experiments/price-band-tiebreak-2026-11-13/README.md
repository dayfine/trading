# Price-band tiebreak (2026-11-13): pre-registration

**Status: pre-registered, no runs.** Written before the first result of either arm. The rule below is applied as
written.

## Why

The 2026-11-13 population screen (`screen/`, pre-registration `screen/PREREG.md`) covered every book-style weekly
breakout of a PIT top-3000 member from 2000 to 2025: 20,195 events. A breakout is a close above the 26-week high on
≥ 2× the prior 4 weeks' volume, above a rising 30-week WMA, at a raw price ≥ $5. Of 12 decision-time traits, two
cells passed the pre-registered rule (monster-rate lift ≥ 1.5 and a mean ride above the population's, in both halves;
`screen/results/ytrait-capped.txt`):

- **Price Q1 (≤ $14.12).** It passed with a monster rate of 15.9 % / 13.6 % (2000–12 / 2013–25) against 8.0 % / 7.3 %.
- **ath_gap Q1 (≥ 63 % below the all-time high).** It passed narrowly: 13.2 % / 14.0 %, with a capped mean ride of
  +3.9 % / +3.4 % against +1.7 % / +3.1 %. It overlaps with low price and is not tested here.

Split by the tiebreak's fixed bands (`screen/results/price-bands.txt`), price is monotone, and the win rate does not
move:

- **Doubling.** Breakouts at $5–8 doubled 21.1 % / 19.5 % of the time, against 4.9 % / 5.6 % above $33.
- **Win rate.** Every band wins 38–41 % of the time (all breakouts: 38.1 % / 40.6 %).
- **Fatter right tail.** The $5–8 capped mean ride was +8.1 % / +8.6 %, against +1.7 % / +3.1 % for all breakouts.

The strategy under-samples these names. 11.3 % of the record's trades enter at ≤ $14 (k0–k4 pooled, 2,789 trades),
against 16.2 % of breakouts (3,277 of 20,195 below $14). The 08-23 monster funnel, split by price (`screen/results/funnel-by-price.txt`), says
where they are lost:

| raw price at the monster's start | dropped at breakout | dropped at the top-N cut | admitted |
|---|---:|---:|---:|
| < $8 (n = 702) | 50.6 % | 36.9 % | 3.7 % |
| $8–14 (n = 248) | 52.4 % | 37.1 % | 3.2 % |
| > $33 (n = 351) | 33.6 % | 49.9 % | 5.1 % |

The top-N cut is where this mechanism acts. The breakout-gate loss is a separate question (which sub-gate drops
them), not touched here.

## Mechanism under test

`candidate_ranking = Price_band_seeded` (#3587, default-off). The cascade score stays primary. Among equal scores,
the cheaper price band goes first, by the raw ticket price `suggested_entry`, with band edges
`ranking_price_band_edges` = [8; 14; 33] (the field default). Within a band, the existing seeded draw orders the
names. Every gate, the sizing and the exits are unchanged. Only two things move: which tied names make the top-20
cut, and the order in which they meet the cash limit.

Faithfulness. W1: no spine item changes. W2: the book has no price rule. Several of Ch. 5's big winners broke out at
low prices (Blocker Energy at about $1, Keystone from under $5), and the book warns that a low-priced stock's large
percentage moves look "miniscule" on the chart. #3587 wrote this back to `docs/design/weinstein-book-reference.md`
§4.5. The tiebreak is the weakest place to express it.

## Design

- **Arms.**
  - S = the record config, `specs/pb-S-k<K>.sexp`: identical to `../record-kseed-2026-10-27/specs/rk-k<K>.sexp`
    except the name and description.
  - P = S plus `((screening_config ((candidate_ranking Price_band_seeded))))`, `specs/pb-P-k<K>.sexp`.
  - Seeds: K = 0..4 for both arms.
  - `chain.sh` checks both relations before it runs anything.
- **Same build, same data.** Both arms of all seeds run at one `origin/main` SHA that contains #3587, in Claude cloud
  sessions. Data: the R2 warehouse `v12wk-9236` plus corporate actions `corpact-2026-10-27`; the validator's data dir
  is built as in `../chain-w-2026-11-10/README.md` §Data.
  - S is re-run at that SHA rather than reusing the record cells (built at `fc78391dd`).
  - `chain.sh` logs whether S matches the record cell; that comparison is information only.
  - The five sessions must log the same `HEAD=`. A seed run at a different SHA is re-run.
- **Window and universe.** 2000-01-01 → 2026-06-26, top-3000 PIT v12 yearly schedule, `TRADING_PATH_SEED_SALT=0`.
- **Pairs.** 10 cells. Arm P seed K pairs with arm S seed K, and both run in the same session.
- **V6 gate.** `validator_diff.exe -check V6` of P-kK against S-kK must exit 0 (the `v6diff:` field of the
  `RESULT pb-P-kK-s0` line). A mismatched pair is left out of the read and reported.

## Decision rule (applied as written)

Per seed, Δk = ln(1 + R_P,k) − ln(1 + R_S,k), where R is the total return over the window (`total_return_pct` / 100).

- **Liveness first.** Take entries = the `trades.csv` rows plus the `open_positions.csv` rows. P's share of entries
  with entry price ≤ $14 must be at least 1.3× S's, pooled over the V6-passing seeds. The record's share is
  11.3 %, so the bar is about 14.7 %.
  - If it fails, the verdict is **NOT LIVE**: the tiebreak rarely binds, and no return read is made.
- **ESCALATE** (to a walk-forward surface and the promotion grid) when all three hold:
  - the median Δ is at least +0.20 log;
  - Δk > 0 in at least 4 of 5 seeds;
  - the median `max_drawdown_pct` of P is worse than S's by no more than 3 pp.
- **NO-BUILD** (keep as a default-off axis) when the median Δ ≤ 0, OR Δk > 0 in 2 seeds or fewer.
- **INCONCLUSIVE:** anything else. Then trace the gap per seed: which trades differ, and what they carried.
- **Fewer than 5 seeds.** If V6 or a failed cell leaves fewer than 5 seeds, the 4-of-5 test becomes "all but one",
  and fewer than 4 seeds makes the read INCONCLUSIVE whatever the medians.

Why +0.20: the 26y seed band has SD 0.225 (`dev/agent-memory/project_record_kseed_band.md`), and an untraced
difference under 0.2 log is one draw (`dev/agent-memory/project_26y_path_noise_floor.md`).

## Reported regardless of the verdict

- **Per seed and arm:**
  - R, ln(1 + R), max drawdown, Sharpe, trade count;
  - the number of trades at ≥ +100 %;
  - the share of entries at ≤ $14 and at ≤ $8;
  - the five largest NAV contributors present in one arm only.
- **Capacity:** for P's entries at ≤ $14, position value ÷ the 20-day mean dollar volume at the fill (p50 / p90 / max).
- **Cash displacement:** S's tickets that P skipped for `Insufficient_cash` (`pb-P-kK-s0-entries.tsv`), and what
  they made in S.
- **Anchors:** entries per arm by `entry_anchor` (`trades.csv`). An `Ma_fallback` anchor prices off the adjusted MA,
  so its band can carry later splits (#3587 behavioral review). All 2,789 of the record's entries anchored on
  `breakout`.

## Not claimed

A single 26y K = 5 read cannot promote. Even an ESCALATE only opens the walk-forward and grid program
(`dev/rules/promotion-confirmation.md`). Nothing here changes a default.

## Files

- `specs/`: the 10 cells.
- `chain.sh run K`: one seed's pair in one cloud session. It stages the data, builds, checks the specs, preflights
  both arms over the last 3 months, then runs S, then P (V6 against S). Last, it writes the keyed trade diff
  (`pb-P-kK-s0-firstdiff.txt`) and the entry extracts.
- `screen/`: the population screen behind the idea. `screen.sh` re-runs it on the host (reads the gitignored
  `data/`). `results/` holds the aggregate tables only, never bar data.
- `results/k<K>/` (after the runs): `chain.sh collect` output per seed.

## Launching (one cloud session per seed, K = 0..4, side by side)

The dispatcher picks one SHA on `origin/main` that contains #3587 and this pre-registration, and puts it in all five
briefs as `<PB_SHA>`. `chain.sh` refuses to run at any other HEAD, and refuses to resume at a HEAD different from the
one its `chain.log` already records.

```
Repo checkout of dayfine/trading. Run: git fetch origin main && git checkout <PB_SHA>. Do not edit tracked files. Run:
  PB_SHA=<PB_SHA> sh dev/experiments/price-band-tiebreak-2026-11-13/chain.sh run K
in the background with its output going to .sweep-output/price-band/run.out, and re-run the same command after any
restart (it resumes). Never print R2 or EODHD credentials. When "PRICE-BAND kK DONE" appears in
.sweep-output/price-band/chain.log, copy .sweep-output/price-band/results/kK into
dev/experiments/price-band-tiebreak-2026-11-13/results/kK on a new branch experiment/price-band-kK, commit and push
that branch. Do not open a PR, merge, label or push to main. If the chain logs ABORT, push the log the same way and
stop.
```

After the runs:
1. The dispatcher gathers the five branches into one results PR.
2. It builds one review pack of the ten cells with `dev/scripts/review_pack.sh` and renders it with
   `review_pack_render.sh`, as `../record-kseed-2026-10-27/chain.sh` `phase_pack` does
   (`dev/rules/backtest-result-review.md` RV1). This runs on the host, from the R2 warehouse.
3. `results-analyst` reads the PR and the pack.
4. `qc-results` reviews the PR (`dev/rules/model-routing.md`).

## Results

**NOT LIVE as written.** The rule's first step decides the read. P's pooled share of entries priced at or below $14 is
14.11 % (389 of 2,756). S's is 11.58 % (329 of 2,842). That is 1.219×, below the 1.3× bar of 15.05 %. The README's
illustrative bar, 14.7 % from the record's 11.3 %, also fails. No seed reaches 1.3× (1.16–1.26×). By the rule, no
return read is made. Every return figure below is description and carries no verdict.

The label is right by the rule. Its gloss, "the tiebreak rarely binds", is not. The artifacts show the opposite:

- **Lists.** On the 2,011 Friday-pairs where both arms recorded a post-cut list (about 400 per seed), the band order
  changed the top-20 on 67 % of them. The swaps follow the band order: of the names S kept and P cut, 86 % were
  priced at $33 or more. Of the names P kept and S cut, 94 % were below $33.
- **Tickets.** 21.5 % of P's tickets were not placed by S on the same Friday.

The proxy failed for two reasons:

- **It measured the smallest side.** The order mostly demotes names at $33 or more (59.3 % of S's entries, 51.7 % of
  P's) in favour of $14–33 names. The ≤ $14 share captured only the cheap end, which has the fewest names.
- **The 1.3× bar was a headline multiplier.** It was not derived from the mechanism's per-decision footprint. The
  floor-nearest arm made the same mistake (`memory/project_floor_and_refresh_screens`).

Described without a verdict, P ends above S in 5 of 5 seeds:

- median Δ ln(1+R) is +0.348, about +1.3 %/yr;
- every P seed ends above every S seed.

Most of the gap was made by positions entered in 2010–2012. Five names that P catches in 4–5 seeds and S in 0–1
carry it, plus ADMA in two seeds.

Had liveness passed, the rule as written would still have returned **INCONCLUSIVE**, not ESCALATE. P's median max
drawdown is 5.64 pp worse than S's, against a 3 pp limit.

**Paths.**

- **Per-arm artifacts.** `results/k{0..4}/pb-{S,P}-kK-s0-*`, plus `chain-kK.log` per seed. All five chain logs
  carry `HEAD=1034b458e` and image `sha256:3865e48e8a61`.
- **Derived tables.** `results/read/`, written by the scripts named in each section. They read only `results/`,
  except where a section says it reads the bar store. Those scripts print bands and ratios only, never a bar.
  The per-row files some sections cite (`read/positions.tsv`, `read/channels.tsv`, `read/list_bands.tsv`,
  `read/basis_check.tsv`) are regenerated, not committed: they need the local `data/`, and two of them would let a reader
  recover raw closes. Their committed summaries reproduce byte for byte from a regeneration (#3595 qc-results).
- **Capacity and the per-arm table.** `results/read/capacity.sh` writes `cap-{P,S}.txt`, and `results/read/metrics.sh`
  writes `metrics.txt`. Both read the per-arm artifacts; `capacity.sh` also reads the bar store and prints ratios only.

### The rule, as written

**Validity.**

- **Build and inputs.** All ten cells ran at one SHA and one image, on one data stage: warehouse `v12wk-9236` with
  9,236 entries, 11,880 `dividends.csv`, and `corpact-2026-10-27` exact (`chain-kK.log`, the `HEAD=` and `STAGE OK`
  lines).
- **Spec relations.** The check passed for every seed: `SPEC CHECKS OK`.
- **Override.** The preflight confirmed `Price_band_seeded` in P's `params.sexp` and its absence in S's. The full
  cells' `params.sexp` differ by exactly that override, and `tiebreak_seed` equals K in both arms.
- **Restarts.** The k0 and k1 sessions restarted once during the warehouse pull (13:30Z, then 13:35Z) and resumed
  under the same `HEAD=`.
- **V6.** `validator_diff -check V6` of P-kK against S-kK exits 0, "agree", for all five pairs
  (`pb-P-kK-s0.v6diff-S.log`). All five seeds enter the read.

**Liveness.** Entries are `trades.csv` rows plus `open_positions.csv` rows. Price is `entry_price`. Source:
`read/arm_table.tsv`, from `read/arm_table.sh`.

| seed | S entries | S ≤ $14 | S share | P entries | P ≤ $14 | P share | P / S |
|---|---:|---:|---:|---:|---:|---:|---:|
| k0 | 581 | 68 | 11.70 % | 557 | 80 | 14.36 % | 1.227 |
| k1 | 573 | 69 | 12.04 % | 557 | 78 | 14.00 % | 1.163 |
| k2 | 568 | 64 | 11.27 % | 536 | 76 | 14.18 % | 1.258 |
| k3 | 567 | 63 | 11.11 % | 558 | 76 | 13.62 % | 1.226 |
| k4 | 553 | 65 | 11.75 % | 548 | 79 | 14.42 % | 1.227 |
| **pooled** | **2,842** | **329** | **11.58 %** | **2,756** | **389** | **14.11 %** | **1.219** |

The bar is 1.3 × 11.58 % = 15.05 %, and it fails. The result is **NOT LIVE**.

**The return rule is not applied.** For the record only, here is what it would have read:

- **Median Δ.** +0.348 (≥ +0.20): would pass.
- **Seeds positive.** 5 of 5: would pass.
- **Drawdown.** The README asks that "the median `max_drawdown_pct` of P is worse than S's by no more than 3 pp".
  - The arm medians are P 31.20 % and S 25.56 %, so the difference is +5.64 pp. On this reading the clause fails, and
    the rule would return INCONCLUSIVE.
  - The median of the per-seed differences is +1.28 pp. On that reading the clause passes, and the rule would return
    ESCALATE.
  - The text supports the first reading. Its subject is P's median, set against S's median. The #3588 qc-results
    review (R1) also read it as median(P) − median(S) ≤ 3.
  - This point is moot under NOT LIVE. But it rules out "would have escalated but for a mis-set bar".

**Reported regardless of the verdict.** Per seed and arm:

- **Main table.** From `actual.sexp`, `trades.csv` and `open_positions.csv`, via `read/arm_table.tsv`. The ≥ +100 %
  count is closed trades with `pnl_percent` ≥ 100.
- **Anchors.** Every closed trade in all ten cells anchors on `breakout`: 2,816 in S and 2,732 in P (`trades.csv`
  column 24). Open rows carry no anchor. No `Ma_fallback` entry exists, so the #3587 band-basis caveat does not arise.

| seed | arm | R | ln(1+R) | Δk | max DD | Sharpe | Calmar | closed trades | ≥ +100 % | ≤ $14 | ≤ $8 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| k0 | S | +1,472.8 % | 2.7554 | | 27.22 % | 0.634 | 0.403 | 576 | 9 | 11.70 % | 3.79 % |
| k0 | P | +2,661.8 % | 3.3185 | **+0.5631** | 32.01 % | 0.744 | 0.417 | 552 | 11 | 14.36 % | 4.31 % |
| k1 | S | +1,678.3 % | 2.8783 | | 24.55 % | 0.661 | 0.468 | 568 | 8 | 12.04 % | 4.19 % |
| k1 | P | +2,093.9 % | 3.0883 | **+0.2100** | 25.19 % | 0.700 | 0.491 | 552 | 11 | 14.00 % | 5.03 % |
| k2 | S | +1,335.0 % | 2.6637 | | 32.08 % | 0.615 | 0.330 | 562 | 8 | 11.27 % | 3.35 % |
| k2 | P | +2,085.4 % | 3.0844 | **+0.4207** | 32.09 % | 0.699 | 0.385 | 531 | 10 | 14.18 % | 4.66 % |
| k3 | S | +1,220.1 % | 2.5803 | | 25.56 % | 0.604 | 0.400 | 562 | 8 | 11.11 % | 4.23 % |
| k3 | P | +1,770.3 % | 2.9287 | **+0.3484** | 31.20 % | 0.657 | 0.375 | 553 | 10 | 13.62 % | 4.48 % |
| k4 | S | +1,639.5 % | 2.8562 | | 25.11 % | 0.651 | 0.454 | 548 | 9 | 11.75 % | 4.16 % |
| k4 | P | +1,906.5 % | 2.9990 | **+0.1428** | 26.39 % | 0.678 | 0.454 | 544 | 11 | 14.42 % | 3.83 % |

**Medians and scale.**

- **S.** ln 2.7554, about 11.0 %/yr over 26.5 years. Sharpe 0.634, max DD 25.56 %.
- **P.** ln 3.0844, about 12.3 %/yr. Sharpe 0.699, max DD 31.20 %.
- **Spread.** The seed SD of ln(1+R) is 0.127 for S and 0.147 for P. The record's band SD was 0.225.
- **Paired Δ.** Mean +0.337, SD 0.167. A t4 interval at 90 % would be +0.18 to +0.50, but it treats the five P
  cells as independent. P's cross-band order is the same in every seed, so the interval is too narrow (§Why 5).
- **The ≤ $8 share** is 3.94 % for S and 4.46 % for P, pooled (1.13×).

**The five largest one-arm-only NAV contributors** (`read/positions.tsv`, `read/positions.sh`):

- **Join.** Positions are joined on `symbol|entry_date`, the `firstdiff` key. Open positions are included.
- **Ranking.** By contribution ÷ the arm's NAV on the entry date, which is roughly additive in ln(1+R).
- **Contribution.** `pnl_dollars` + `dividends_received`.
- **Price and band.** The price is `entry_price`. The band follows #3587's `price_band` on it.
- **† The two daggered names.** DECK and EME were held through a split, so their `entry_price` is restated (§Defects
  found). Both were priced at $33 or more at the decision.
- **‡ DINO** was also held through a split, so its $15.90 is restated. Its decision-time price was in the same $14–33
  band.

| seed | P-only (entry, price, band, P&L, ÷ entry NAV) | S-only (same) |
|---|---|---|
| k0 | ADMA 2023-12-19 $4.35 (< 8) +300 % 28.6 %; MERC 2010-11-15 $6.39 (< 8) +111 % 15.9 %; WAL 2012-05-01 $8.72 (8–14) +64 % 9.2 %; HOS 2003-12-30 $24.89 (14–33) +76 % 8.1 %; SAGE 2017-12-04 $93.08 (≥ 33) +56 % 8.0 % | CVNA 2024-07-08 $129.99 (≥ 33) +80 % 7.7 %; EME† 2005-02-25 $23.12 +89 % 7.6 %; DECK† 2009-11-02 $29.51 +53 % 7.5 %; MIME 2021-06-25 $54.69 (≥ 33) +46 % 3.1 %; ATI 2024-04-23 $49.12 (≥ 33) +20 % 2.9 % |
| k1 | MERC (as k0) 15.9 %; AVGO 2013-09-10 $39.39 (≥ 33) +200 % 15.3 %; HURN 2006-03-13 $29.16 (14–33) +131 % 10.1 %; WAL 9.2 %; HOS 8.1 % | LAD 2012-08-13 $28.69 (14–33) +117 % 17.0 %; DECK† 7.5 %; WSM 2020-09-28 $88.84 (≥ 33) +79 % 6.9 %; AMED 2014-10-02 $19.17 (14–33) +38 % 5.5 %; CHDN 2017-03-28 $157.95 (≥ 33) +77 % 5.4 % |
| k2 | MERC 15.9 %; AVGO 15.3 %; INVX 2005-10-12 $38.61 (≥ 33) +93 % 12.2 %; FOSL 2010-08-16 $43.82 (≥ 33) +83 % 11.5 %; WAL 9.2 % | CRM 2010-02-05 $60.56 (≥ 33) +126 % 18.6 %; SAGE 8.0 %; DECK† 7.5 %; BWA 2010-02-03 $37.06 (≥ 33) +87 % 7.0 %; WSM 6.9 % |
| k3 | ADMA 28.6 %; FOSL 11.5 %; DINO‡ 2010-10-13 $15.90 (14–33) +117 % 8.4 %; SAGE 8.0 %; IPHI 2015-01-06 $17.61 (14–33) +44 % 6.5 % | GLNG 2022-02-07 $14.66 (14–33) +70 % 9.7 %; FCNCA 2020-11-16 $555.00 (≥ 33) +48 % 4.8 %; GDI1 2005-09-14 $21.69 (14–33) +60 % 4.4 %; NJDCY 2017-05-30 $24.99 (14–33) +58 % 4.3 %; WDFC 2013-07-22 $58.36 (≥ 33) +20 % 3.0 % |
| k4 | MERC 15.9 %; HURN 10.1 %; WAL 9.3 %; DINO‡ 8.4 %; HOS 8.1 % | CMG 2010-02-08 $99.24 (≥ 33) +150 % 16.2 %; EME† 7.6 %; AMED 5.3 %; PBSOQ 2004-05-10 $8.46 (8–14) +33 % 4.9 %; FCNCA 4.8 % |

**Capacity** (`read/cap-P.txt`, `read/cap-S.txt`). The measure is position value ÷ the mean dollar volume (raw close × volume)
over the 20 bars ending on the fill date, for entries at or below $14.

| arm | n | p50 | p90 | max |
|---|---:|---:|---:|---:|
| P | 389 | 0.038 | 0.190 | 0.949 (TCPC 2021-12-20 k0; TRTX 2021-08-17 k1 0.939, k4 0.929) |
| S | 329 | 0.027 | 0.146 | 0.749 (TRTX 2021-08-17 k1) |

- **The ≥ 0.25 tail.** 18 P entries and 7 S entries reach 0.25 of a day's dollar volume.
- **The names that carry the gap** sit at 0.17–0.34: MERC 0.17–0.21, ADMA 0.22–0.34 (P), WAL 0.18–0.21.

**Cash displacement** (`read/channels.tsv`, from `read/channels.sh`).

- **Method.** Each S ticket (a `placed` row in S's `entries.tsv`) is matched to P's `entries.tsv` row with the same
  symbol and decision date. The table keeps the tickets P skipped for `Insufficient_cash`.
- **Outcome.** Each ticket is joined to its S outcome: a closed trade by `position_id`, or an open position by symbol
  and the first entry date on or after the decision.
- **The dispatcher's figures.** Closed trades with `pnl_dollars` only. They reproduce exactly.
- **This draft's figures.** They add dividends and the open positions.
- **The symmetric side.** P's tickets that S skipped for cash, with their P outcome, are needed to read the channel and
  are shown too.

| seed | S tickets P skipped for cash: placed / filled | their S P&L (closed, pnl only) | with dividends and open, ÷ entry NAV summed | named | P tickets S skipped for cash: placed / filled | their P P&L incl. dividends, ÷ NAV summed | net ÷ NAV |
|---|---:|---:|---:|---|---:|---:|---:|
| k0 | 49 / 36 | 35 closed, +$343,879 | +$560,209, 5.5 % | INGM (open) | 36 / 31 | +$1,269,875, 13.3 % | +7.8 |
| k1 | 43 / 33 | 33, +$647,351 | +$734,973, 21.0 % | LAD +117 % | 45 / 37 | +$1,009,630, 23.4 % | +2.4 |
| k2 | 48 / 36 | 35, +$394,280 | +$624,242, 9.9 % | | 27 / 21 | +$1,400,309, 36.0 % | +26.1 |
| k3 | 51 / 40 | 39, +$1,107,550 | +$1,343,766, 12.4 % | | 40 / 30 | +$1,066,090, 10.3 % | −2.1 |
| k4 | 41 / 33 | 32, +$534,424 | +$993,015, 22.8 % | CMG +150 % | 35 / 29 | +$809,407, 7.8 % | −15.0 |

P's side holds AVGO +200 % in k1 and k2. Displacement runs both ways and nets about +4 points of entry NAV per seed. It
is not where the gap comes from (§Why 3).

### The verdict, calibrated

- **What this run establishes.**
  - At this window (2000-01 → 2026-06), universe (top-3000 PIT v12, deduped lists) and build, the pre-registered
    proxy does not clear its bar. The verdict is **NOT LIVE as written**, and no return verdict follows.
  - Nothing escalates, and nothing changes a default. That holds by the rule and by the README's own §Not claimed:
    even an ESCALATE would only have opened the walk-forward and grid program.
- **What NOT LIVE cannot mean here.**
  - It cannot mean "the tiebreak does nothing". The order binds on two thirds of the Fridays we can see, and it
    re-draws about a fifth of each arm's tickets (§Why 1).
  - It is a statement about a mis-specified proxy, not about the mechanism.
  - It is not a NO-BUILD decision either. `Price_band_seeded` stays a default-off axis, as it was.
- **What the description can and cannot support.**
  - **Supports.** In this window, P's 26-year outcome sits above S's by more than tie-order noise, at about 2–2.4 SD
    (one-sided p ≈ 0.01–0.02 under a shared-draw bound, §Why 5). Five S re-draws never reach any P re-draw.
  - **Does not support.** It cannot say the band order is better in expectation. Its five seeds replicate one set of
    systematic swaps rather than testing it (§Why 5).
  - **Effective sample.** The deciding events are a handful of distinct names, about 70 % of the gap entered in
    2010–2012.
  - **In-sample.** The screen that motivated the lever used the same 2000–2025 history.
  - **Drawdown.** The rule's own clause counts it as worse.
  - **Calibration.** A single 26-year K = 5 read cannot promote (`dev/rules/promotion-confirmation.md`), and this one
    is not even a passing read.

### Why

#### 1. The tiebreak binds often; the proxy watched its smallest footprint

`entries.tsv` holds, for every Friday on which an arm placed at least one ticket, the whole post-cut list its entry walk
saw: the placed rows plus every skipped alternative and its reason. A Friday with no placement records nothing. A
name cut at the top-20 never appears, and `entries.tsv` drops the score. So the cut is visible only on Fridays where
both arms recorded a list. That is 2,011 Friday-pairs over the five seeds, about 400 per seed.

Bands below use the raw close on the decision date, a proxy for the ticket price `suggested_entry`, from
`read/list_bands.sh`, which reads the bar store. On filled trades it agrees with the band of `entry_price` in
96.2–97.3 % of cases.

- **Lists.** P's and S's top-20 lists are identical on only 667 of the 2,011 Friday-pairs (33.2 %). On average 1.47 S names per
  Friday are missing from P's list, and 1.40 P names from S's (`read/lists_compare.txt`, from `read/lists_compare.sh`).
  The swaps are band-shaped:

  | names | n | < $8 | $8–14 | $14–33 | ≥ $33 |
  |---|---:|---:|---:|---:|---:|
  | in S's list, not P's | 2,948 | 0.3 % | 1.0 % | 13.0 % | **85.7 %** |
  | in P's list, not S's | 2,819 | 14.2 % | 26.0 % | **54.2 %** | 5.6 % |

  Names held in one arm drop out of its pool before the cut. That is a path effect, not the order. It explains little:
  - **Measured directly** (`read/held_confound.txt`, from `read/held_confound.sh`). Only 2.2–6.2 % of the names
    missing from one arm's list were held, or pending as a ticket, in that arm that Friday. Each such removal can pull
    in one replacement, so the held set accounts for at most about a tenth of the differences.
  - **Not reconstructed.** Cooldown after a stop-out.
  - **Off-signature swaps.** 159 P-side names at $33 or more, and 38 S-side names below $14, are of the same order.

- **List composition.** Across all recorded list slots (S 46,196, P 45,199), P's lists hold 49.0 % names at $33 or
  more against S's 55.3 %. They hold 34.3 % at $14–33 against 31.1 %, 10.1 % at $8–14 against 8.0 %, and 6.6 % under
  $8 against 5.6 %.

- **Tickets.** Of P's 3,283 placed tickets, 2,578 (78.5 %) were placed by S on the same Friday (`read/channels.tsv`).
  The other 705 split by what S did with the name that Friday:
  - **Not in S's list (the cut, or held in S):** 193 (5.9 %). 30 % of these are under $14, against 13 % of P's tickets
    overall.
  - **In S's list but skipped for cash:** 183 (5.6 %).
  - **Unresolved:** 327 (10.0 %). S placed nothing that Friday, so its list was not recorded.

  Mirror image: of S's 176 tickets that were not in P's list, 144 (82 %) are priced at $33 or more.

So the order changes the top-20 on two thirds of the visible Fridays and re-draws about a fifth of the tickets. "Rarely
binds" is wrong. These figures are the binding rate the README should have pre-registered as liveness.

What would measure it exactly is one S cell re-run with `--emit-candidates`. Its `candidates.sexp` logs every screened
Friday, including Fridays with no placement and the `Dropped_at_top_n` rows with their scores. It does not carry the
ticket price. The re-rank therefore needs the decision close, whose band agreed with the fill band 96–97 % of the time
here, or a `suggested_entry` field added to the signals. Re-ranking that list offline under `Price_band_seeded` gives,
on one path, with no divergence:

- the share of Fridays whose top-20 changes;
- the share whose first funded names change.

#### 2. The order acts on both ends; the four-band composition

Entries by `entry_price` band, pooled (`read/positions.tsv`):

| band | S entries | S share | P entries | P share | P − S | P / S share | ≥ +100 % trades, S → P |
|---|---:|---:|---:|---:|---:|---:|---:|
| < $8 | 112 | 3.94 % | 123 | 4.46 % | +11 (+9.8 %) | 1.13 | 9 → 15 |
| $8–14 | 217 | 7.64 % | 266 | 9.65 % | +49 (+22.6 %) | 1.26 | 10 → 10 |
| $14–33 | 828 | 29.13 % | 941 | 34.14 % | +113 (+13.6 %) | 1.17 | 8 → 13 |
| ≥ $33 | 1,685 | 59.29 % | 1,426 | 51.74 % | **−259 (−15.4 %)** | **0.87** | 15 → 15 |

The largest move is out of the top band, about 52 fewer entries per seed. Most of the freed slots go to $14–33,
because that is where most of the cheaper tie-group members are.

Perturbing the cut-off moves the P/S share ratio only between 1.07 and 1.22 at every cut from $6 to $33. It peaks at the
pre-registered $14: 1.066 at $6, 1.132 at $8, 1.193 at $10, 1.203 at $12, **1.219 at $14**, 1.205 at $16, 1.150 at $20,
1.151 at $25 and 1.185 at $33.

So no cut-off would have read LIVE at 1.3×. A tiebreak only reorders ties; it cannot create cheap candidates.

P closed about 55 % of the gap between S's ≤ $14 share and the population's 16.2 % (11.58 % → 14.11 %). The bar
demanded about 75 % of it.

Tail access moved where the screen says it should. Comparing P with S:

- **Under $8:** +6 trades at ≥ +100 % (MERC +4, ADMA +2).
- **$14–33:** +5 (DINO +4, HURN +2, LAD −1).
- **$33 or more:** 0 (AVGO +2, CRM −1, CMG −1).

The win rate does not rise. One-arm positions win 39.6 % in P and 43.0 % in S (`read/positions.tsv`).

#### 3. Where the gap sits

**Shared positions earn the same in both arms.** 421–437 positions per seed are shared; they make 286.7 % and
287.8 % of entry NAV in k0, and within 1.5 points in every seed. The whole difference sits in the 21–27 % of each arm's
positions that the other arm does not hold (`read/onearm_split.txt`, from `read/onearm_split.sh`):

| seed | Δk | P-only n / Σ ÷ entry NAV | S-only n / Σ | net | net after trimming the top 1 / 2 / 3 of each side |
|---|---:|---:|---:|---:|---|
| k0 | +0.563 | 120 / +91.9 | 144 / +21.2 | **+70.7** | +49.8 / +41.6 / +39.9 |
| k2 | +0.421 | 112 / +99.8 | 144 / +53.5 | **+46.3** | +49.0 / +41.8 / +37.1 |
| k3 | +0.348 | 128 / +67.4 | 137 / +25.8 | **+41.6** | +22.7 / +16.0 / +12.0 |
| k1 | +0.210 | 136 / +83.8 | 152 / +57.6 | **+26.3** | +27.4 / +19.6 / +16.4 |
| k4 | +0.143 | 122 / +69.0 | 127 / +46.5 | **+22.5** | +22.8 / +20.4 / +16.4 |

The net ranks the seeds exactly as Δk does. Within each seed it survives trimming the three largest names from both
sides.

The distribution is a tail, not a shift. Pooled, P-only positions return:

- mean +6.1 %, median −3.8 %;
- p10 −12.9 %, p90 +33.6 %;
- 6.5 % of positions at +50 % or more, and 2.3 % at +100 % or more.

S-only positions return:

- mean +2.5 %, median −2.5 %;
- p10 −12.2 %, p90 +19.7 %;
- 2.7 % at +50 % or more, and 0.4 % at +100 % or more.

P's median and win rate are slightly worse. Its right tail is fatter. This is the screen's low-price profile.

**By band** (pooled one-arm net, P-only minus S-only, in points of entry NAV):

| band | net |
|---|---:|
| < $8 | +154.3 (P 39 positions, S 28) |
| $8–14 | +16.1 |
| $14–33 | +65.2 |
| ≥ $33 | −28.2 |
| total | +207.4 |

**By era.** Two different clocks are used here. The one-arm net groups positions by their entry date. The gap
change is the calendar change in the year-end gap ln(NAV_P / NAV_S) over the same years (`read/curves.txt`).

| era | one-arm net, positions entered in the era | year-end gap change over the era: k0 / k1 / k2 / k3 / k4 | seeds positive |
|---|---:|---|---:|
| 2000–09 | +18.5 | +0.036 / +0.030 / −0.015 / −0.011 / +0.149 | 3 / 5 |
| **2010–12** | **+147.0** | +0.238 / +0.241 / +0.246 / +0.208 / +0.149 | **5 / 5** |
| 2013–17 | +34.3 | +0.214 / +0.036 / +0.234 / +0.068 / −0.025 | 4 / 5 |
| 2018–23 | +16.7, of which ADMA +57.2 | −0.090 / −0.075 / −0.055 / −0.126 / −0.039 | **0 / 5** |
| 2024–26 | −9.0 | +0.165 / −0.023 / +0.011 / +0.210 / −0.090 | 3 / 5 |

Positions entered in 2010–2012 carry about 70 % of the gap. In every seed the year-end gap jumps +0.14 to +0.22 during
2011 alone.

2018–2023 runs against P in all five seeds. ADMA's 2024 exit (k0 and k3) restores it. Split into the screen's own
halves, the gap grows in 2000–2012 in 5 of 5 seeds (+0.20 to +0.30) and in 2013–2026 in 3 of 5 (median +0.15). In
2013–2026, the two ADMA seeds account for two of the three positives.

**The same names, seed after seed** (`read/recurrence.txt`, from `read/recurrence.sh`). Group every position key
(`symbol|entry_date`) by nP − nS, the number of P seeds holding it minus the number of S seeds:

- **P ≥ S + 3:** 63 keys, net +179.6. These carry most of the pooled +204.6 (P minus S over all positions, shared
  included).
- **S ≥ P + 3:** 39 keys, net −19.4.
- **1 ≤ |nP − nS| ≤ 2:** 567 keys, net +45.5. Most of this is ADMA, with P 5 and S 3.
- **Held in equal numbers of seeds:** 378 keys, net −1.1.

The largest systematic names, both ways:

| name | entry | price, band | result | ÷ entry NAV | P seeds | S seeds |
|---|---|---|---:|---:|---:|---:|
| MERC | 2010-11-15 | $6.39, < $8 | +111 % | 15.9 % | 5 | 1 |
| ATML | 2010-09-01 | $6.10, < $8 | +81 % | 5.4 % | 5 | 1 |
| WAL | 2012-05-01 | $8.72, $8–14 | +64 % | 9.2 % | 4 | 0 |
| DINO | 2010-10-13 | $14–33 at the decision ($15.90 restated) | +117 % | 8.1 % | 4 | 0 |
| REGN | 2010-12-07 | $30.74, $14–33 | +70 % | 5.6 % | 5 | 1 |
| HOS | 2003-12-30 | $24.89, $14–33 | +76 % | 8.1 % | 5 | 2 |
| IPHI | 2015-01-06 | $17.61, $14–33 | +44 % | 6.4 % | 4 | 1 |
| DECK | 2009-11-02 | ≥ $33 at the decision ($29.51 restated) | +53 % | 7.5 % | 0 | 3 |
| FCNCA | 2020-11-16 | $555.00, ≥ $33 | +48 % | 4.8 % | 0 | 3 |
| ATI | 2024-04-23 | $49.12, ≥ $33 | +20 % | 2.9 % | 0 | 3 |

Each of the largest P-favoured names is below $33 at the decision, and each of the largest S-favoured ones is at or
above it. Across the whole groups, by `entry_price` band, 54 of the 63 P-favoured keys are below $33, and 26 of the 39
S-favoured keys are at or above it.

Dropping the five largest systematic names (MERC, WAL, DINO, HOS, REGN) leaves the P ≥ S + 3 group at net zero
(+179.6 − 63.5 − 36.8 − 32.5 − 24.3 − 22.5 = 0.0).

#### 4. Four Fridays, end to end

- **2009-10-30 (the cut, both directions).**
  - **The lists.** One large score tie at the cut. S's top-20 holds 11, 9 and 11 names at $33 or more in k0, k1 and
    k2. P's holds 3 in each, with 16 names at $14–33. Every list has 20 names.
  - **What P lost.** S places DECK in k0–k2 (priced at $33 or more at the decision; +53 %; 7.5 % of entry NAV). It is
    absent from P's list, so it was cut.
  - **What P gained.** P places DINO in k1–k4, a name absent from S's list in every seed. The ticket rests 50 weeks.
    It fills 2010-10-13 and gains +117 %, about 8 % of entry NAV (`read/channels.tsv`).
- **2023-08-18, ADMA (the cut, promoting a name under $8).**
  - **The cut.** In k0 and k3, S's 20-name list has PKG and R placed and 18 `No_structural_stop` skips; ADMA is not in
    it. ADMA was in S k0's list the Friday before (2023-08-11, skipped `No_structural_stop`). S never held it, so this
    is the cut, not a held name. P's list has ADMA, PKG and R placed and 17 `No_structural_stop`: ADMA moved to the
    front of its tie and displaced one unfundable name.
  - **The trade.** The ticket filled 2023-12-19 at $4.35. It exited 2024-12-23 at +300 %, 28.6 % of entry NAV. The
    year-end 2024 gap rose +0.204 (k0) and +0.181 (k3).
  - **The other seeds.** In k1, k2 and k4, S's seeded draw admitted ADMA anyway, so it is shared.
  - **What it means.** The record band's single largest draw (`memory/project_record_kseed_band`: ADMA 2023-08-18,
    k1/k2/k4) is a seed lottery in S and a certainty in P.
- **2010-11-12, MERC (unresolved channel).**
  - **The trade.** P places MERC in all five seeds. It fills 2010-11-15 at $6.39 and gains +111 %, 15.9 % of entry
    NAV.
  - **S's side.** S places it only in k3. In k0, k1, k2 and k4, S placed nothing that Friday, so its list was not
    recorded. P's list that Friday had 19 names, so the cut did not bind in P. Whether S was cash-blocked or cut cannot
    be read from the artifacts.
  - **The cluster.** MERC is part of the 2010 cluster above, with ATML, DINO and REGN. The 2011 gap increment comes
    from this cluster in every seed. In k3, where MERC is shared, it comes from ATML, DINO and FOSL.
- **2013-08-30, AVGO (cash, not band).**
  - **The trade.** P places AVGO in all five seeds. It fills 2013-09-10 at $39.39 and gains +200 %, 15.3 % of entry
    NAV.
  - **S's side.** S places it in k0, k3 and k4, and skips it for `Insufficient_cash` in k1 and k2.
  - **Why it differs.** AVGO is priced at $33 or more in both arms, so this is not a band promotion. It is the cash
    state the two paths had reached by then. This is the gate-2 channel, path-dependent, and it is the second-largest
    P-only contributor in k1 and k2.

The pooled gap, split by what the other arm did with each ticket that Friday (`read/channels.tsv`):

| channel | net |
|---|---:|
| same Friday, both arms placed | −17.8 |
| cut / held in the other arm | +83.3 (ADMA ×2 is 57.2) |
| cash in the other arm | +19.3 |
| other arm recorded nothing | +121.6 (MERC ×4 is 63.5) |
| structural-stop skip in the other arm | −1.8 |
| total (P minus S over all positions) | +204.6 |

This total differs from the one-arm net (+207.4) by the −2.9 that shared positions make. A ticket both arms placed
can still fill in one arm only, so the two decompositions classify a few positions differently.

The unresolved channel carries the same band signature. 64 % of S's tickets in it are priced at $33 or more, against
35 % of P's. Most of it is therefore also the order's work, through the cut or the cash order, without a recorded
witness.

#### 5. The reshuffle null, and what 5/5 can claim

Any change to tie order re-draws the tails, as a seed change does (`memory/project_26y_path_noise_floor`,
`memory/project_path_stability_seeded_noise`). The pairs bear that out (`read/pairs_null.txt`, from
`read/pairs_null.sh`):

- **Divergence.** Each P−S pair diverges within days to months: first differing equity row 2000-01-11 to 2000-09-05
  (`pb-P-kK-s0-firstdiff.txt`).
- **Position overlap.**

  | pair | overlap of positions |
  |---|---:|
  | P vs S, same seed | 74.5–77.4 % |
  | two S seeds | 69.6–72.5 % |
  | two P seeds | 75.7–80.9 % |

- **Correlation.** P_k and S_k correlate at only +0.26. The paired SD, 0.167, is close to √2 × S's SD (0.179). Pairing
  by seed removes almost no variance.
- **Same seed against cross seed.** P−S at the same seed is +0.143 to +0.563 (median +0.348). The ten cross-seed S
  differences are |0.022| to |0.298| (median 0.149). Three of the five P−S gaps exceed the largest S−S gap. All 25 P
  vs S comparisons, same seed or not, favour P (minimum +0.050).

**Permutation and sign tests: floors, not values.** If the ten values were exchangeable draws, each of the
C(10,5) = 252 labellings would be equally likely. Exactly one puts all five P above all five S, so p would be 1/252 =
0.004, one-sided. The paired sign test, 5 of 5 positive, would give 1/32 = 0.031. Both treat the five P cells as
independent draws. They are not: P's cross-band order is the same in every seed, so a "just another fixed tie order"
null gives the five P cells one shared draw (below). The 1/252, the 1/32 and the t4 interval are therefore floors on
the p-value, not its value.

**A shared-draw bound.** Treat S's whole seed variance (SD 0.127) as the component the five P cells share, plus
per-seed noise. The gap in means (+0.337) is then about 2.2–2.4 SD: 2.2 with P's own seed spread (0.147) added as
independent noise, 2.4 without it. One-sided p is about 0.01–0.02.

**What that supports.** In this window, universe and build, P's outcome differs from S's by more than tie-order noise, at
the strength of the shared-draw bound (about 2–2.4 SD), not at 1/252.

**What it cannot support.**

- **That the order is better in expectation, or for another history.** The seeds re-draw tie order, not the market.
  P's order is the same in every seed for every tie that spans bands. So the same names recur across P's seeds, and
  P's seeds overlap more with each other than S's do. The five P values are five noisy draws around one systematic set
  of swaps. Counted as distinct events, the systematic swaps are few:
  - **Swapped in.** The 63 P-favoured keys hold 2 trades at +100 % or more, MERC and DINO. At the strategy's own
    per-band rates in S (8.0 %, 4.6 %, 0.97 % and 0.89 % of entries by band), about 1.5 were expected.
  - **Swapped out.** The 39 S-favoured keys hold 0, against about 0.6 expected.
  - **Reading.** That is about what the screen's base rates predict, plus modest luck: net +2 against +0.8
    expected. The NAV gap is those few outcomes, each replicated in four or five of five P seeds.
- **The size.** The 90 % interval above (+0.18 to +0.50) covers seed noise only.
- **Out of sample.** The trait was chosen on the same 2000–2025 population this run trades. Its cut-offs held out
  2013–25, but the trait selection did not.

#### 6. Drawdown, concentration, cash, capacity

- **Concentration: no.** Mean position weight at entry is 0.098 of NAV in both arms, and 0.097–0.106 in every band.
  Mean initial stop distance by band is equal to within 0.002. P runs 3 % fewer entries (2,756 against 2,842) and ends
  with 4–5 open positions, as S does.
- **Drawdown: yes, modestly.**
  - **Ulcer index.** Higher in P in 5 of 5 seeds, by 0.48 to 1.61 (P 10.20–12.18, S 9.72–11.39; `actual.sexp`).
  - **Max DD.** Deeper in P in 5 of 5 seeds by sign, 4 of 5 by more than 0.1 pp: +4.79, +0.64, +0.01, +5.64 and
    +1.28 pp for k0–k4.
  - **Where the gaps come from** (`read/curves.txt`). The two large ones, k0 and k3, are the 2018–2020 episode: P
    falls from its own Jan-2018 peak, S from mid-2018. P gave back part of its 2017 run-up (the k0 gap fell from +0.488
    at end-2017 to +0.444 at end-2018).
  - **The open episode.** The 2024-11 → 2026-06 drawdown is deeper in P in 4 of 5 seeds (P 21.3–26.0 %, S
    19.6–22.4 %; k3 is the exception, 22.1 % against 22.4 %).
- **Risk-adjusted.**
  - **Sharpe** is higher in P in 5 of 5 seeds (+0.028 to +0.110), and so is Sortino.
  - **Calmar** is higher in 3 of 5, equal in k4 and lower in k3.
  - **The gain** is bought with the volatility of the names it buys, not with position size.
- **Cash displacement** runs both ways and nets about +4 points of entry NAV per seed (table above). The README's
  one-sided measure shows only S's loss.
- **Capacity.** The ≤ $14 entries sit at higher fractions of daily dollar volume in P: p50 0.038 against 0.027, p90
  0.190 against 0.146. In part P's NAV is larger: on shared names the ratio scales roughly with NAV (ADMA k4: 0.265
  against 0.218, at a P/S NAV ratio of 1.26 on the entry date). In part the names are thinner. The deciding monsters
  filled at 0.17–0.34 of a day's dollar volume. That is inside the $1M ADV realism gate. But it is not free at a larger
  book, and any confirmation should report it at the late-run NAV.

### The pre-registration's §Why, corrected (#3588 qc-results notes)

- **The ath_gap overlap, now measured** (`screen/results/athgap_overlap.txt`, from `screen/athgap_overlap.sh` over the screen's
  `events.tsv`; aggregates only).
  - **Overlap.** 54.6 % (2000–12) and 40.7 % (2013–25) of ath_gap Q1 events are also price Q1.
  - **Monster rate.** ath_gap Q1 lifts the monster rate inside both price strata. Price Q1: 16.6 % against 15.0 %,
    and 17.1 % against 9.3 %. Price Q2–5: 9.2 % against 5.6 %, and 11.9 % against 5.7 %.
  - **Ride.** Outside price Q1, its capped ride does not beat the stratum: +1.0 % against +0.7 %, and +2.1 % against
    +3.1 %.
  - **Reading.** "Overlaps with low price" is true. Its monster lift is partly independent of price; its EV edge is
    not.
- **"Price is monotone"** holds for the doubling rate in both halves: 21.1 > 13.8 > 7.1 > 4.9 % and
  19.5 > 10.7 > 8.2 > 5.6 %. It holds for the 2000–12 ride. It fails for the 2013–25 ride ($8–14 +1.9 % against
  $14–33 +3.8 %). The exact statement is "the doubling rate falls as price rises".
- **The ath_gap Q1 cut** is −0.6349, so the bucket is ≥ 63.5 % below the all-time high, not ≥ 63 %.
- **Two more facts from the band table** bear on this result.
  - The $14–33 band also beats the top band on doubling rate in both halves: 7.1 and 8.2 % against 4.9 and 5.6 %,
    about 1.45×. So the order's largest move, from $33 or more to $14–33, is in the screen-favoured direction too.
  - The 08-23 funnel (`screen/results/funnel-by-price.txt`) cuts expensive monsters at the top-N more often (49.9 %)
    than cheap ones (36.9 %).

### How it fits what we know

- **Confirms `project_record_kseed_band` and `project_path_stability_seeded_noise`.** Gate 1 (the tie at the binding
  top-20) and gate 2 (cash at placement) decide which tails a seed catches. The band order acts on exactly those gates.
  It converts some of the seed lotteries, ADMA 2023-08-18 above all, into certainties.
- **Confirms `project_edge_is_the_fat_tail`.** P's whole gain is a fatter right tail at a slightly lower win rate,
  carried by a handful of names.
- **Refines `project_entry_selection_closed_powered` and the three tiebreak ledger rejections** (`2026-06-29-candidate-
  ranking-tiebreak-grid`, `2026-06-29-earliness-ranking-tiebreak-grid`, `2026-06-30-tiebreak-noise-floor`: "no
  equal-score tiebreak on any entry feature adds return").
  - Those features (RS, earliness) load on the heat factor, which trades win rate for tail. Price does not, in the
    population screen.
  - Here, for the first time, an informative tiebreak ends above every baseline seed (26-year, K = 5).
  - The earlier rejections came from 13-fold walk-forward on Alphabetical; this is a single 26-year window.
  - That is **a contradiction to dig into, not settled evidence**. The noise-floor row showed that arbitrary
    tiebreaks swing results widely across breadth cells, so a single-window gap is exactly what that row warns about.
- **Refines `project_trait_y_low_price`.** The strategy can harvest the trait through the tie order. But in this
  history the harvest is about five names, and it is concentrated in the 2010–2012 recovery.
- **Repeats the floor-nearest liveness error** (`project_floor_and_refresh_screens`: "set liveness bars from a
  screen's per-decision rate, never its headline multiplier"). The lesson did not reach this pre-registration.
- **Fits `project_26y_path_noise_floor`.** The median Δ (+0.35) is above the 0.20 bar and below the 0.45 single-cell
  floor. Only the five draws per arm lift it out of noise; the pairing itself removes almost no variance. The trades
  are traced, and the trace says the gap is a few names.
- **The level.** The S band here (median 2.7554, SD 0.127) is the first K = 5 band on the deduped lists (#3475, #3483).
  Every P seed except k0 sits inside the record's band on the old lists (2.559–3.144; `rk-k*`). The P−S comparison
  holds only within this tree.

### What it implies next

**Recommendation.** Do not re-read this run. The next step is one S cell (k0) re-run with `--emit-candidates`: one
26-year cell, about 2–2.5 hours of cloud, before any new grid. It answers two questions:

- **How often the band order binds.** The exact rate on a single path, re-ranked offline: the liveness this README
  should have had.
- **Where low-priced monsters are lost.** The funnel loses them mainly upstream of this lever. The breakout gate
  drops 50.6 % of monsters under $8, against 33.6 % above $33. The top-N cut already drops cheap monsters less often
  (36.9 % against 49.9 %; `screen/results/funnel-by-price.txt`, from the 08-23 funnel on an older record config).
  `candidates.sexp` names the sub-gate on every `Dropped_at_breakout` row (#2533). That is the open "which sub-gate"
  question in `project_trait_y_low_price`.

If the binding rate and the sub-gate read still favour the tiebreak, pre-register it fresh, with four parts:

- **Liveness bar.** Set it from the measured per-decision binding rate.
- **Drawdown clause.** Fix its reading in the text now: arm medians or paired.
- **Name-concentration check.** For example, the gap must survive removing the three largest systematic names, and
  the 2013–2026 increment must be reported on its own.
- **Confirmation cells** required by `dev/rules/promotion-confirmation.md`, broad-vs-broad only, each K = 5 paired,
  never sp500:
  - a period cell that excludes the 2010–2012 recovery: 2013–2026 on the same top-3000 schedule;
  - a top-1000 schedule cell over the full window;
  - a pre-2000 window, if the deep-history lists support one. It would be the only period outside the screen's
    history.

This read alone does not justify a grid. One window, about five deciding names and a worse drawdown make "nothing
further" a defensible choice. What argues for one more step is that price is the first trait to move the tail without
the heat trade-off, both in the population and in the portfolio. The `--emit-candidates` cell is cheap enough to settle
the next decision on evidence rather than on this read.

**Ruled out by this read:**

- flipping the default;
- escalating to walk-forward on this run;
- adding seeds on the same window, which would replicate the same swaps.

### Defects found

1. **The liveness proxy was mis-specified (pre-registration design).** It measured the ≤ $14 share of entries, which
   sits downstream of the cash and structural-stop gates and covers only the cheap side. The 1.3× multiplier had no
   per-decision basis. Specimen: README lines 74–76; the cut-off sweep in §Why 2; the list-swap table in §Why 1.
2. **`trades.csv` `entry_price` is restated for splits during the hold.** Tracked in #3384. It is not the decision-time price
   (`read/basis_check.tsv`, from `read/basis_check.sh`, which reads the bar store and prints ratios only). Of 1,050
   distinct positions across the ten cells, 1,032 match the raw close on the entry date. The other 18 all held through
   a split, and each ratio equals the product of the in-hold splits:

   | name | entry | ratio | in-hold split |
   |---|---|---:|---|
   | DINO | 2010-10-13 | 0.490 | 2:1 on 2011-09-01 |
   | DECK | 2009-11-02 | 0.330 | 3:1 on 2010-07-06 (the 2024 6:1 is not applied) |
   | ADSK | 2003-09-15 | 0.501 | 2:1 on 2004-12-21 |
   | DUK | 2012-06-01 | 2.985 | 1:3 reverse on 2012-07-03 |

   - **Bands.** Six positions change band: DECK, EME, ENB and AVD should be at $33 or more; DUK and ADSK should be
     $14–33.
   - **The ≤ $14 count.** ADSK is the only one affected, and it is shared by all ten cells (1.219 → 1.220).
   - **The mechanism is not affected.** It prices the raw `suggested_entry` at the decision. This is an analysis
     trap, not a simulator bug.
   - **Fix.** Document it in the `trades.csv` column notes, or add a raw `decision_price` column.
3. **`entries.tsv` cannot see the cut on Fridays with no placement, and drops the score.** Tracked in #3384. The alternatives hang off a
   placed entry (`chain.sh` `entries_extract`). 327 of P's 705 one-arm tickets (46 %) and 385 of S's 793 are
   therefore channel-unresolved. `trade_audit.sexp` (with scores) was not collected. A future tiebreak arm should run
   with `--emit-candidates` on at least one cell.
4. **The README's cash-displacement measure is one-sided.** It counts S's tickets lost to P's cash and not P's
   tickets gained from S's (§Reported). Read alone, it suggests a cost the symmetric figure does not show.
5. **Minor artifact notes.**
   - `open_positions.csv` has no `position_id`, so open rows join by symbol and date.
   - The equity curve and the open marks end 2026-06-25, against the spec's `end_date` 2026-06-26. The marks at
     06-25 reproduce `open_positions_value` exactly for k0 S and P.
6. **Parity checks: no defect.**
   - pb-S-k0 is byte-identical to chain-w's cw-W0-s0, run at b54e44ea9 before #3587: `trades.csv`, `equity_curve.csv`,
     `splits.csv`, `entries.tsv` and `actual.sexp`. So #3587 is inert when off, and cloud cells reproduce across
     sessions.
   - The validator audit is clean: `audit join` matched 100 % in all ten cells, and the per-trade checks (V7, V9,
     V13, V14, V21–V23) move with the trade list in both arms.

### Review-pack look

The pack covers all ten cells, with charts on P-k0. It was built with `review_pack.sh --run-kind arm --charts-run 0
--no-container` at b54e44ea9 and rendered with `review_pack_render.sh` (27 slices). It was looked at by the dispatcher
(RV1–RV3).

The pack is **not published or committed, by design**. Its site (46 MB) embeds per-trade daily price series read from
the local EODHD bar store, and those may not be shared, published or committed (EODHD terms). The pack figures quoted
below (KPI strip, concentrated-gain peaks, era read, stop signal) can be rebuilt from the committed per-arm artifacts
plus a local `data/` with:

```
R=dev/experiments/price-band-tiebreak-2026-11-13/results
sh dev/scripts/review_pack.sh --out <dir> --title "Price-band tiebreak, K=5 paired (2000-2026, pit-v12)" \
  --run-kind arm --charts-run 0 --no-container --data-dir data \
  P-k0=$R/k0/pb-P-k0-s0- S-k0=$R/k0/pb-S-k0-s0- ...   # all ten, P-kK and S-kK for K = 0..4
sh dev/scripts/review_pack_render.sh --site <dir>/site
```

- **KPI strip (P-k0).** +2,662 %, CAGR 13.4 %, max DD −32.0 %, Sharpe 0.74, 552 trades, 5 open at the end. These match
  `actual.sexp`. The arms list reads +2,662 / +1,473 / +2,094 / +1,678 / +2,085 / +1,335 / +1,770 / +1,220 / +1,906 /
  +1,640 %, matching the per-arm table.
- **Window.** The charts span 2000-01-03 → 2026-06-25, over 9,185 symbols.
- **Concentrated gain before a drawdown (P-k0), confirmed.** The signal flags three NAV peaks:
  - 2011-07-19, then −21.1 % to 2011-10-03, with FOSL at 16.5 % of peak NAV;
  - 2021-04-13, then −25.7 % to 2023-10-27, with APPS at 30.4 %;
  - 2024-11-28, then −23.8 % through 2026-06-23, with MMYT at 15.0 % and ADMA at 23.3 %.

  The 2011 flag names FOSL, not MERC; MERC's gain was banked before that peak. The 2024 flag is ADMA, as §Why 4
  traces. These are the drawdowns behind P's higher Ulcer index (§Why 6).
- **Era read (P-k0).** P-k0 lagged SPY with holdings, not with exposure, in 2018–2019, 2021 and 2025–2026. Its worst
  three-year stretch is 2017–2019, +16.6 % against SPY's +52.4 %. This matches the 2018–2023 era that runs against P in
  5 of 5 seeds.
- **Initial stop under 2 % below E: not P-specific.** The signal fires on 13–21 trades in every cell, S and P alike
  (P-k0 19 trades, −$1.10M; S-k0 18, −$535k). The names (GME, APPF, AAON, TCOM, UPWK) recur in both arms. This is the
  known decision-walk D4 item, not a band-order effect. P does lose more dollars on it in all five seeds (P −$0.72M to
  −$1.10M; S −$0.47M to −$0.63M, and S-k2 +$42k), partly because P's NAV is larger.
- **Audit-dependent cards read n/a**, as `--no-container` implies: E ≥ 10 % below the decision close, trail never
  raised, fallback stops. The missed-winners table reads "unknown (screen evidence absent)" for the same reason.
- **Validator.** V13 counts 39 violations (4 skipped) on P-k0. That is a per-trade check that moves with the trade list
  (§Defects found 6). V6 gates the read.

Nothing in the pack contradicts the reading above. The one correction is the 2011 peak name (FOSL, not MERC).
