# total-return-26y-2026-10-06 — cash interest + dividends on the 26y investor preset (#3137 after-merge)

Plan: `dev/plans/total-return-and-shorts-phase-b-2026-10-05.md` decisions 1, 3, 3a. Issue #3137 `[after-merge]`:
"Paired pre-registered 3-salt 26y A/B (implementation check: ≈ +0.24 log; V6 agree; path effects reported);
restate the SPY comparison on a total-return basis."

## Arms (same build, same warehouse, same staged data tree)

| arm | spec | difference |
|---|---|---|
| `tr0-26` | byte-copy of `entry-anchor-recovery-2026-10-02/specs/ia0-26.sexp` | null: price-only accounting (today's record basis) |
| `tr1-26` | `tr0-26` + 3 overrides | `cash_yield (Series macro/tbill_3m_dtb3.csv)`, `cash_yield_fee_bp 10.0`, `dividend_crediting true` |

Window 2000-01-01 → 2026-06-26, PIT top-3000 schedule (v11), salts 0/1/2, warehouse `/tmp/snap_top3000_pit_v11pit`
(9,364 entries). Dividend files (EODHD, fetched 2026-10-06 by #3158's fetcher, 7,438 symbols with events) are staged
into the run tree's `test_data` by `results/launch.sh` (untracked; both arms see the same tree).

This is an **implementation check plus a re-basing**, not a strategy verdict: the accounting changes no rule, but
extra cash changes position sizing, so paths can diverge (path effects are reported, not judged).

## Pre-registered reading (decided before launch)

1. **Implementation check (per salt).** Report `CashInterestTotal` and `DividendIncomeTotal` (tr1), and the
   terminal log-NAV gap ln(NAV_tr1 / NAV_tr0). The 26y deep-dive estimated ≈ +0.24 log from interest and ≈ +0.13 log
   from dividends on s0 (49 % average cash). **Pass** if each salt's interest and dividend totals, expressed as a
   log contribution (ln(1 + total / NAV path), computed from the equity curve), land within ±50 % of those
   estimates; outside that band → trace before quoting anything (a wiring or data defect is the first suspect).
2. **Coverage.** `DividendMissingFileCount` and `DividendSkippedNoAmountCount` reported per salt; a missing count
   above 2 % of distinct held symbols, or any skipped-no-amount count above 0, is traced and listed.
3. **V6 gate.** `validator_diff -check V6` tr0 vs tr1 per salt (chain does this). Exit 1 → the paired gap is not an
   accounting read for that salt; report it as such.
4. **Path effects.** Trades, win rate, open positions at end, and the realised-P&L difference between arms, per salt,
   with the 3 largest per-trade divergences traced (sizing from the larger cash base).
5. **Re-based record + SPY.** Per salt: CAGR, max DD, Calmar, Sharpe (tr1 Sharpe is on excess return over the
   net T-bill rate), and SPY restated on a total-return basis (SPY price + EODHD dividends reinvested, from
   `data/S/Y/SPY/{data,dividends}.csv`) over the same window, alongside SPY price-only. The regime split by period
   (`backtest-result-review.md` RV2) is repeated on the total-return basis.
6. **Review pack** for tr1 s0 (and the pair), rendered and looked at before any analysis (RV1–RV3). The reading
   goes to `results-analyst` (direction-class, `model-routing.md`); a second blind read is not required (no
   promotion). The default-on flip of total-return accounting is a separate PR citing this result
   (plan decision 3: accounting realism, implementation-check approval).

## Known gaps (stated up front)

- `#3136` dollar-volume look-ahead is NOT fixed in this run — both arms use the same (biased) universe and
  liquidity gates; the measurement is in flight. If it leads to a rebuild, this pair is re-run on it.
- Dividends are credited on the ex-date (pay-date not in the data): cash arrives ~2–4 weeks early.
- Shorts are off in this preset; the short-side dividend charge is exercised in the shorts Phase B pair.
