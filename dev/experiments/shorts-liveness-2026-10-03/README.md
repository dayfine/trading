# Shorts liveness on the investor preset, 5d (2026-10-03)

## Why

User decision 2026-10-03: run the next-session item 4(d) first — one liveness pair, not a programme
(`dev/notes/next-session-priorities-2026-10-03.md` §4(d)). The investor preset runs with
`enable_short_side false`. Weinstein shorts Stage 4 breakdowns in a bear tape (book reference §Short-Selling
Rules); the question here is only whether the short leg **fires at all** on the broad PIT universe once the
faithful gates and the margin model are on.

Prior record, and why this is not evidence for or against shorts as a lever:
- `project_p0_levers_no_build_2026_06_20`: a reserved short sleeve lost at every fraction on broad deep; short
  supply was gated by Stage-4 signal count and `short_min_price 17`, not by cash.
- `project_p1a_deep_short_screens`: hedge value appeared only ungated, on sp500 — not a broad measurement
  (`universe-discipline.md`).
- `project_short_realism_p0`: margin model, short stop fixes and short round-trips in `trades.csv` are on main.

## Arms

| arm | spec | difference |
|---|---|---|
| `sh0` | `specs/sh0-5d.sexp` | byte-copy of `entry-anchor-recovery-2026-10-02/specs/ia0-5d.sexp` (investor preset, shorts off) |
| `shB` | `specs/shB-5d.sexp` | `sh0` + `enable_short_side true`, `neutral_blocks_shorts true` (already the default), `enable_slow_grind_short_gate true`, `short_min_price 17.0`, `short_borrow_min_dollar_adv 1e6`, margin model on (maintenance 0.30, FINRA-shaped borrow-rate and maintenance tiers below $5 / $17 — the block from `staging-margin-m4-stress/*`, without `short_buyin_stress_mode`) |

The margin model is on in `shB` only. With `initial_long_margin_req 1.0` nothing on the long side is borrowed,
so it should not touch long P&L (the 06-26 acceptance measured margin off vs on at < 0.06 pp); rule 2 checks it.

## Window, salt

5d = 2007-06-01 → 2012-06-29, PIT top-3000 schedule (2006–2011 lists), warehouse `_v11pit` (9,364 entries).
Salt 0 only. Two cells, ~25 min each (`perf-long-cells.csv`: ia0-5d 1,405–1,457 s). Pinned worktree at
`origin/main`, specs read from this pre-registration commit (`results/launch.sh`).

## Reading rule (pre-registered 2026-10-03, before any cell runs)

1. **Gate.** `validator_diff -check V6` exit 0 for the pair. A mismatch → "no reading" for any P&L delta;
   the liveness counts in rule 3 are still reported.
2. **Long leg unchanged.** Report the long trades shared between arms on (`position_id`-independent) entry
   date + symbol, and those unshared. Shorts compete for cash, so some divergence is expected; report its
   size, do not interpret it.
3. **Liveness (the question).** From `shB` `trades.csv` (`side = SHORT`) and the trade audit:
   - number of short entries filled, by year, and how many fall in 2007-10 → 2009-03;
   - short P&L total, win count, median holding days, exit-reason split (stop / cover / force-cover);
   - number of margin force-covers (`force_liquidations.sexp`).
   - **Live** = ≥ 1 short entry filled. **Sparse** = 1–9. **Active** = ≥ 10.
   - If 0: report what blocked it — weeks the macro read Bearish, weeks the slow-grind gate admitted shorts,
     Stage-4 short candidates screened and their rejection reasons — so the record says *which gate*.
4. **Portfolio read (descriptive only).** Return, max DD, Calmar, and NAV at 2009-03-31 for both arms, and the
   SPY-regime split (`backtest-result-review.md` RV2) of the NAV gap. One salt and one pair: no verdict on the
   lever from these numbers.
5. **Review pack.** Build, render and look at the `shB` pack (`backtest-result-review.md` steps 1–4); record
   what the look found.
6. **Verdict calibration.** This pair can say "live / sparse / active / dead under the faithful gates" and
   name the binding gate. It cannot accept or reject shorts. No default changes, no ledger entry. What comes
   next (a surface over the gates, more salts, or nothing) is a user decision.

**Expected, stated in advance.** Sparse shorts (`short_min_price 17` plus the grind gate), concentrated in
2008; possibly a few force-covers in the March–May 2009 rebound. A higher max DD in `shB` is plausible if
shorts are caught in the 2009 rebound.

## Files

- `specs/` — the two arms.
- `results/chain-shorts.sh`, `results/launch.sh` — the chain (copy of the anchor chain, paths moved) and launcher.
- `results/` — per-arm artifacts and the chain log, committed with the results.

## Log

- 2026-10-03 — pre-registered.
