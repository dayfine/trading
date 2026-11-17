# vsb-1 at 96cacbe20: the #3664 paired run (flag none; the mixed basis carried ~0.35 log of the record)

**Arm.** The record config (rk-kK, K = 5 tie seeds) plus `((virgin_supply_basis One_basis))`, paired with S on one
build, 96cacbe20 (#3668's merge, which includes #3666). It is row 5 of `surface.tsv` (`arms_run` 5). Universe:
top-3000 PIT v12 (`universe_size` 9185); no sp500 cell.

**Pre-registration.** #3664 comment 6943210083, written before launch (2026-11-17 ~08:50Z). It fixes what the run
answers (how much of the record band the mixed basis carries: per-seed and median D_end, and each vsb-1 seed against
the record K=5 band, median 2.78, SD 0.225, #3467), says the flag is descriptive for this arm, and sets a size check
before any reading.

**Who read it.** The dispatcher (main session), not `results-analyst`: the week's quota stood at 72 % with the SMALL
suggestion, and the default decision this run feeds was taken by the user on correctness before the paired read
(§4; #3664 comment 6960893659). The RESULT lines of 8 of the 10 cells were already in the lane log by then, which does
not bear on option (a): it does not depend on returns. The read is the pre-registered numbers plus the supply-path
count of §2; it does not decompose which trades the look-ahead selected.

**Files.**
- Public, branch `observatory/lane-results` at 750b58480: `surface.tsv` row 5, `events.tsv`,
  `lane-logs/96cacbe20-vsb-1.log`, `runs/96cacbe20/{S,vsb-1}/` (summaries, params, validator logs, v6diff logs).
- Private, `dayfine/trading-results` at 8bf9a49: the same `runs/` with `trades.csv` and `equity_curve.csv`, and
  `reads/vsb-1@96cacbe20/` (`seeds.tsv`, `years-kK.tsv`, `steps-kK.tsv`, `firstdiff-kK.tsv`).
- Supply-path count (§2): public `reads/vsb-1-supply-count.{tsv,sh}`; private `reads/vsb-1@96cacbe20/supply-count/`
  in `dayfine/trading-results` at b868865.

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
possible collapse first; check the admission counts".

**The count that reads the knob.** `virgin_supply_basis` reaches only the continuous supply path
(`Stock_analysis_supply.results`, `stock_analysis.ml:330-334`). Its two outputs, the supply score and the virgin
readmission, need the same mapped breakout (`stock_analysis_supply.ml`), so an entry with a supply score also had
its virgin test run. When the path returns a score, the screener writes "Overhead supply (continuous)" into the
entry's `cascade_rationale`. When it returns none — what a `One_basis` path that lost its breakout or raw close
produces — the screener falls back to the binary v1 grade (`screener_scoring.ml:183-187`). The lane keeps no
`trade_audit.sexp`, so a short k0 pair was re-run with it kept: same build (96cacbe20) and stage, the lane's k0 specs
with only the window changed (2019-01-01 to 2021-12-31).

| arm | round trips | entry decisions (audit records) | graded by the supply path | v1 grade Clean / Moderate / Virgin / Heavy |
|---|---:|---:|---:|---|
| S | 80 | 114 | 114 (100 %) | 87 / 15 / 11 / 1 |
| vsb-1 | 68 | 103 | 102 (99 %) | 77 / 10 / 15 / 1 |

- **The path is live, not collapsed.** Under `One_basis` 102 of 103 entry decisions carry a supply score, against
  114 of 114 under S. A collapsed path would show ~0. One entry fell back to the v1 grade; its cause is not traced
  here. The one route to that fallback that only `One_basis` has is a missing current raw close on the panel path,
  which the open panel-path `current_raw_close` follow-up covers.
- **One seed covers all five.** The tie seed orders equal-scored candidates. It does not touch the inputs of the basis
  mapping (the 520-week sketch, the breakout, the raw and adjusted closes), so whether a name gets a supply score
  does not depend on it.
- **The window is three years, not 26.** The mapping is per symbol and per week, with no state that changes by era, so
  the check covers the mechanism, not every name the 26-year cells graded.
- Files: `vsb-1-supply-count.tsv`, from `vsb-1-supply-count.sh` over the two `trade_audit.sexp` files in private
  `dayfine/trading-results` at b868865, under `dev/experiments/observatory/reads/vsb-1@96cacbe20/supply-count/`
  (`S/`, `vsb-1/`, with the specs, `trades.csv`, summaries, params and runner logs).

**The other legs agree but would not separate a fix from a collapse on their own:** in a slot-limited book a dead
admission route also leaves the slots full.
- vsb-1 trades per seed 559, 536, 540, 557, 555 against S's 576, 568, 562, 562, 548 (median change −3.0 %;
  `n_round_trips`). `a_new` (193) ≈ `s_out` (202).
- `s_out` for the four earlier arms is 261, 187, 441 and 237 (`surface.tsv`); 202 sits inside that range.
- **V7 does not read the knob.** It counts the audit's `resistance_quality`, the v1 grade
  (`trade_audit_recorder.ml:129-131`), computed with no basis input. Its rise (47, 35, 44, 44, 47 `Virgin_territory`
  entries under vsb-1 against 36, 33, 32, 39, 38 under S) says nothing about the supply path. The first draft of
  this read used it as the collapse check (QC R1 on #3671).

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
- In wealth terms the median seed ends ~29 % lower without the mix (e^−0.35 ≈ 0.71 of S's final value; seed range
  19–40 %). That is the whole paired effect of the basis change, knock-on churn and path noise included; this read
  does not decompose it.
- Max drawdown is worse on 4 of 5 seeds (median +6.35 pp, `d_maxdd_pp`; `d_ulcer` +1.27).

**The flag, as written: none.** UP and HARM need four seeds with ≥ 60 % of years carrying the flag's sign. Each seed is
negative in 13, 15, 16, 14, 14 of 27 years (`seeds.tsv`), 48–59 %, so `seeds_neg60` is 0 and HARM fails that clause
(median D_end −0.35 ≤ −0.20 and `step_max_med` 0.385 < 0.5 both hold). The loss is spread across regimes
(`d_mac_bull` −0.17, `d_mac_neut` −0.08, `d_mac_bear` −0.09) rather than a steady yearly drag, with the largest single
week carrying 13–43 % of a seed's |D_end|. Per the pre-registration the flag is descriptive here: a HARM row would have
measured a defect's share of the record, not a dial, and "none" does not make the 0.35 smaller.

## 4. What follows

- **The default decision is the user's, taken 2026-11-17 11:00 PT: option (a), flip `virgin_supply_basis` to
  `One_basis` on correctness** (#3664 comment 6960893659). The run is valid (§1), and the supply-path count shows
  `One_basis` live (§2: 102 of 103 entries graded, against 114 of 114 under S). Those were the only stops (a) named.
- **vsb-1's five cells become the new record band** at the flip HEAD, with no re-run: ln(1+R) 2.546, 2.531, 2.332,
  2.070, 2.481 (median 2.481, sample SD 0.20). The record figure 2.78 (#3467) carried the look-ahead. The flip PR
  carries the tripwire for "no re-run": the flipped default must reproduce vsb-1 k0's `trades.csv` (md5
  `3ee10dca319e54a85f5e0a7842d8c537`) at the flip HEAD.
- **Earlier observatory rows stay as reads on the mixed basis.** msd-12, msd-18, fbt-05 and cap-40 were paired against
  an S that carries this look-ahead; their D_end values are not re-based. Arms run after the flip pair against the new S.
- #3664's `[after-merge]` item is half met by this run (the band share); the other half, the default decision under
  `config-default-blast-radius.md`, lands with the flip PR. #3664 stays open with `verify/pending` until then.
