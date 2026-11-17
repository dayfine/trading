# vsb-1 at 96cacbe20: the #3664 paired run (flag none; the mixed basis carried ~0.35 log of the record)

**Arm.** The record config (rk-kK, K = 5 tie seeds) plus `((virgin_supply_basis One_basis))`, paired with S on one
build, 96cacbe20 (#3668's merge, which includes #3666). It is row 5 of `surface.tsv` (`arms_run` 5). Universe:
top-3000 PIT v12 (`universe_size` 9185); no sp500 cell.

**Pre-registration.** #3664 comment 6943210083, written before launch (2026-11-17 ~08:50Z). It fixes what the run
answers (how much of the record band the mixed basis carries: per-seed and median D_end, and each vsb-1 seed against
the record K=5 band, median 2.78, SD 0.225, #3467), says the flag is descriptive for this arm, and sets a size check
before any reading.

**Who read it.** The dispatcher (main session), not `results-analyst`: the week's quota stood at 72 % with the SMALL
suggestion, and the default decision this run feeds was taken by the user on correctness before the run read (§4).
The read is the pre-registered numbers only; it does not decompose which trades the look-ahead selected.

**Files.**
- Public, branch `observatory/lane-results` at 750b58480: `surface.tsv` row 5, `events.tsv`,
  `lane-logs/96cacbe20-vsb-1.log`, `runs/96cacbe20/{S,vsb-1}/` (summaries, params, validator logs, v6diff logs).
- Private, `dayfine/trading-results` at 8bf9a49: the same `runs/` with `trades.csv` and `equity_curve.csv`, and
  `reads/vsb-1@96cacbe20/` (`seeds.tsv`, `years-kK.tsv`, `steps-kK.tsv`, `firstdiff-kK.tsv`).

## 1. Validity, checked before the read

| check | result | source |
|---|---|---|
| same build | `code_version` 96cacbe20 in every `params.sexp`; the arm's spec is S's plus the one overlay line | `runs/96cacbe20/*/…-params.sexp` |
| tripwire | `TRIPWIRE MATCH S k0 trades.csv md5 0928cfe4…` (S@ecd77c760) | lane log |
| drift | `drift-none S vs ecd77c760`: S at this HEAD is the S that msd-12, msd-18, fbt-05 and cap-40 read against | `events.tsv` |
| V6 | `V6 OK vsb-1 (k0-k4 against S)` | lane log, `*.v6diff-S.log` |
| liveness | `LIVE vsb-1: trades.csv differs from S on 5 of 5 seeds` | lane log |
| validator config | `VALIDATOR CONFIG vsb-1 default (no -config)` | lane log |

## 2. Size check: fix, not collapse

The pre-registration's threshold reads "median `s_out` > about 840 (30 % of S's trades)". **That threshold mixes
units:** 2,816 is the K=5 *total* of S's trades in the #3659 audit, while `s_out` is a per-seed median. Read per seed,
30 % of S's ~563 trades is ~169, and `s_out` (202) is above it. So the check's second branch applies — "treat it as a
possible collapse first; check the admission counts" — and the counts rule a collapse out:

- **Admissions held.** vsb-1 trades per seed 559, 536, 540, 557, 555 against S's 576, 568, 562, 562, 548 (median
  change −3.0 %; `n_round_trips`). `a_new` (193) ≈ `s_out` (202): the arm swaps names, it does not lose them.
- **The churn is ordinary for a paired arm.** `s_out` for the four earlier arms is 261, 187, 441 and 237
  (`surface.tsv`); 202 sits inside that range. Path dependence through the cap and cash moves ~200 names per seed for
  any live overlay.
- **Virgin admissions are live on every seed.** The V7 report lists `Virgin_territory` entries with under 520 weekly
  bars of history: 47, 35, 44, 44, 47 under vsb-1 against 36, 33, 32, 39, 38 under S (`*.validator.log`). A
  `One_basis` path that lost its breakout or raw close would grade no name `Virgin_territory`
  (`stock_analysis_supply.ml`), so these counts would be ~0.

## 3. The pre-registered numbers

**D_end, per seed (vsb-1 against S, log growth):** −0.2098, −0.3475, −0.3317, −0.5106, −0.3752; **median −0.3475**
(`d_end_seeds`). All five seeds are negative.

**Against the record band.** From `final_portfolio_value` / 1,000,000 in each `summary.sexp`:

| seed | S ln(1+R) | vsb-1 ln(1+R) | D | S max DD % | vsb-1 max DD % |
|---|---:|---:|---:|---:|---:|
| k0 | 2.755 | 2.546 | −0.21 | 27.2 | 39.6 |
| k1 | 2.878 | 2.531 | −0.35 | 24.6 | 35.2 |
| k2 | 2.664 | 2.332 | −0.33 | 32.1 | 28.5 |
| k3 | 2.580 | 2.070 | −0.51 | 25.6 | 31.9 |
| k4 | 2.856 | 2.481 | −0.38 | 25.1 | 26.2 |
| median | 2.755 | 2.481 | −0.35 | 25.6 | 31.9 |

- S reproduces the record band (median 2.755 against 2.78).
- Every vsb-1 seed sits below S's lowest seed (2.580). The vsb-1 median, 2.48, is 1.3 record SDs below the record
  median; k3 (2.07) is 3.2 SDs below.
- In wealth terms the median seed ends at e^−0.35 ≈ 0.71 of the record's final value: about 29 % of the record's
  26-year outcome rested on selecting names by their future splits and dividends.
- Max drawdown is worse on 4 of 5 seeds (median +6.35 pp, `d_maxdd_pp`; `d_ulcer` +1.27).

**The flag, as written: none.** UP and HARM need four seeds with ≥ 60 % of years carrying the flag's sign. Each seed is
negative in 13, 15, 16, 14, 14 of 27 years (`seeds.tsv`), 48–59 %, so `seeds_neg60` is 0 and HARM fails that clause
(median D_end −0.35 ≤ −0.20 and `step_max_med` 0.385 < 0.5 both hold). The loss is spread across regimes
(`d_mac_bull` −0.17, `d_mac_neut` −0.08, `d_mac_bear` −0.09) rather than a steady yearly drag, with the largest single
week carrying 13–43 % of a seed's |D_end|. Per the pre-registration the flag is descriptive here: a HARM row would have
measured a defect's share of the record, not a dial, and "none" does not make the 0.35 smaller.

## 4. What follows

- **The default decision is the user's, taken 2026-11-17 11:00 PT: option (a), flip `virgin_supply_basis` to
  `One_basis` on correctness.** The run is valid (§1) and not a collapse (§2), which were the only stops (a) named.
- **vsb-1's five cells become the new record band** at the flip HEAD, with no re-run: ln(1+R) 2.546, 2.531, 2.332,
  2.070, 2.481 (median 2.481, sample SD 0.20). The record figure 2.78 (#3467) carried the look-ahead.
- **Earlier observatory rows stay as reads on the mixed basis.** msd-12, msd-18, fbt-05 and cap-40 were paired against
  an S that carries this look-ahead; their D_end values are not re-based. Arms run after the flip pair against the new S.
- #3664's `[after-merge]` item is half met by this run (the band share); the other half, the default decision under
  `config-default-blast-radius.md`, lands with the flip PR.
