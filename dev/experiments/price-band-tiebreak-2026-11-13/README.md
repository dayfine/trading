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
