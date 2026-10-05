---
name: project_sim_price_only_accounting
description: "10-05: sim credits NO cash interest and NO dividends → 'trails SPY' readings are price-only vs SPY total return; 26y investor ≈ 9.3 % CAGR TR (s0/s2) vs SPY 8.1–8.2 %; #3137"
metadata:
  type: project
---

26y investor deep-dive (results-analyst, 2026-10-05): the simulator accrues nothing on positive cash (only margin debit + short borrow, `margin_runner.ml:116-121`; Sharpe rf = 0) and credits no dividends (raw-close marks). At ~49 % average cash, T-bill interest ≈ +0.24 log (×1.27) and dividends ≈ +0.13 log (×1.14) over 2000–26 → s0/s2 ≈ 9.3 % CAGR on a total-return basis vs SPY ~8.1–8.2 % (s1 ≈ 7.8 %). SPY benchmark rows (#3130) are price-only too (SPY TR +706 % vs sim BAH +401 %).

s1's gap to s0 (~$1.6M) is ONE at-fill cash cancellation (ADMA, 96 % funded, log only) — 34–35 such per salt (#3138), not path luck.

**Why:** the merged "investor trails SPY / idle cash costs" readings ([[project_investor_preset_broad]]) compared a zero-interest price-only sim with SPY total return.

**How to apply:** quote SPY comparisons on a matched basis (both price-only, or both TR with cash yield). A T-bill / money-market sweep (book Ch. 9 "safe harbor") is NOT the declined SPY sleeve ([[project_barbell_on_stocks]]) — no equity risk; default-off `cash_yield` + dividends per #3137, paired 3-salt A/B as an implementation check. Also: dollar-volume look-ahead in PIT ranking/liquidity gates (#3136) — split-adjusted volume × raw close.
