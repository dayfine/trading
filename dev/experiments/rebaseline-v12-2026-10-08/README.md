# rebaseline-v12-2026-10-08 — the investor record on pit-v12, total-return basis

Plan: `dev/plans/total-return-and-shorts-phase-b-2026-10-05.md` decisions 1–3 and 5 (queue: #3136 → combined long
baseline re-run, 3 salts → shorts Phase B). This is the "one combined re-baseline" (decision 1). It also carries two
`[after-merge]` items: #3136 (re-run on the rebuilt universe) and #3173 (the guard credits TDG / WING / BCH once).

## Arms (same build, same warehouse, same staged data tree)

| arm | spec | difference |
|---|---|---|
| `rb0-26` | `total-return-26y-2026-10-06/specs/tr0-26.sexp` with the pit-v12 schedule + 3 overrides | `split_dividend_guard true` (#3181), `cash_yield (Series macro/tbill_3m_dtb3.csv)` and `cash_yield_fee_bp 10.0` (the #3184 default, spelled out). No dividends. |
| `rb1-26` | `rb0-26` + 1 override | `dividend_crediting true` |

Window 2000-01-01 → 2026-06-26, PIT top-3000 **v12** schedule (`pit-v12/composition/top-3000-{1999..2025}.sexp`,
true dollar volume, #3182), salts 0/1/2, warehouse `/tmp/snap_top3000_pit_v12pit` (built by
`dev/scripts/build_pit_warehouse_v12.sh`, launched 2026-10-07 17:45 PT; the chain pins its manifest count).
Dividend and split files (EODHD, #3158 fetch) are staged into the run tree's `test_data` by `results/launch.sh`.

The guard is on in **both** arms: a dividend misread as a split creates phantom shares on a price-only run too
(#3173), so it is a correctness fix, not part of the dividend lever. `rb1 − rb0` is then dividends alone.

## Pre-registered reading (decided before launch)

1. **Validity gates.**
   - V6 = 0 on `rb0-26` s0 (first null cell on a new warehouse, per the build script's hand-off line). V6 > 0 →
     stop, trace the twin, rebuild before reading anything.
   - `validator_diff -check V6` rb0 vs rb1 per salt (the chain does it). Exit 1 → that salt's pair is not a
     dividend read; say so.
   - Every cell writes `actual.sexp`; a `<no result>` is traced (OOM vs input) before relaunch.
2. **#3173 after-merge check.** In `rb1` (and `rb0`), TDG 2013-07, WING and BCH show no split event and no
   position-quantity jump on those dates; in `rb1` each event's cash is credited once. Pass/fail per event, with the
   evidence (trades/open positions/equity curve rows) cited.
3. **Dividend implementation check (rb1 vs rb0, per salt).** Report `DividendIncomeTotal`,
   `DividendPaidShortTotal` (0 expected: shorts off), `DividendMissingFileCount`, `DividendSkippedNoAmountCount`,
   and the dividend log contribution computed from the equity curve as in total-return-26y. Split it into
   **ordinary** events (amount < 5 % of the prior close) and **specials** (≥ 5 %), with the 10 largest events by
   dollars listed. **Pass** if the ordinary part lands within ±50 % of the +0.13 log estimate on every salt, coverage
   holds (missing files ≤ 2 % of distinct held symbols; skipped-no-amount = 0 or each one listed), item 2 passes,
   and V6 agrees. Specials are real cash and are reported, not gated; their size is the answer to why the v11 run
   came out at +0.21–0.23.
4. **The re-based record (rb0, and rb1 if item 3 passes).** Per salt: total return, CAGR, max DD, Calmar, Sharpe
   (excess over the net T-bill rate), trades, win rate; SPY on the matching basis (rb0: SPY price + T-bill on its
   uninvested 0 %, i.e. SPY price; rb1: SPY total return with dividends reinvested). The regime split by period
   (`backtest-result-review.md` RV2) on the rb1 basis.
5. **v11 → v12 shift (descriptive, not decomposed).** `rb0` vs total-return-26y `tr0` differs in three ways at once:
   the dollar-volume basis, the candidate set (inventory 5,734 → 11,888 symbols), and cash interest (+0.232 log
   measured on v11, #3178). Report the per-salt gap, subtract the measured interest term as a rough guide, and say
   that the remainder is basis + candidate set **jointly**. Name the largest membership-driven trade differences
   (names held in one universe and absent from the other) for s0.
6. **Path effects.** Trades, open positions at end, and the 3 largest per-trade divergences rb1 vs rb0 per salt
   (dividend cash changes sizing; the #3138 at-fill knife-edge applies).
7. **Review pack** for rb1 s0–s2 (and rb0), built, rendered and looked at before any analysis (RV1–RV3). The reading
   goes to `results-analyst` (direction-class); `qc-results` reviews the PR.

## What the result decides

- Item 3 passes → a PR flips `dividend_crediting` and `split_dividend_guard` default-on, citing this result
  (plan decision 3), and `rb1` is the record. Item 3 fails → `rb0` is the record, the failure is traced, and the
  flip waits.
- The record arm is the long baseline for shorts Phase B (decision 7), which runs on the same warehouse.
- The 19 regression goldens pinned to `No_yield` in #3184 stay pinned until #3138 lands; re-pinning them is not
  part of this run.

## Known gaps (stated up front)

- #3138: an at-fill cash shortfall cancels an entry outright, so small cash differences fork paths. Pairs diverge
  for that reason as well as for the lever.
- #3174: resting sell stops are not reduced by the dividend on the ex-date, so a large special can trigger a stop
  at the open in rb1 that the price-adjusted series would not have.
- #3175: per-trade P&L in `trades.csv` excludes dividends; per-trade reads of rb1 understate dividend payers.
- Foreign withholding on ADR dividends is not modelled (credited gross); pay-date is not in the data (cash arrives
  on the ex-date, ~2–4 weeks early).
- #3176: some dividend files are mis-scaled by a later reverse split (CMRE) or empty (UN).
- #3183: foreign-currency series and warrants still rank high in some vintages (as in v11).

## Files

- `specs/rb0-26.sexp`, `specs/rb1-26.sexp`
- `results/launch.sh` (stages data, pins the warehouse count, launches), `results/chain-rb12.sh` (the chain)
- Run artifacts land in `/tmp/sweeps/rebaseline-v12` (host `.sweep-output/rebaseline-v12`) and are committed under
  `results/` per arm and salt.
