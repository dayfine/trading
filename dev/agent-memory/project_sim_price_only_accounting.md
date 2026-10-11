---
name: project_sim_price_only_accounting
description: "10-05→10-07: sim WAS price-only; #3156+#3160 add default-off cash_yield + dividend_crediting; 26y A/B (#3178): interest +0.232 log (on estimate), dividends +0.21–0.23 (specials; #3173 double count), TR CAGR 9.1–9.8 % vs SPY TR 8.2 %"
metadata:
  type: project
---

26y investor deep-dive (results-analyst, 2026-10-05): the simulator accrues nothing on positive cash (only margin debit + short borrow, `margin_runner.ml:116-121`; Sharpe rf = 0) and credits no dividends (raw-close marks). At ~49 % average cash, T-bill interest ≈ +0.24 log (×1.27) and dividends ≈ +0.13 log (×1.14) over 2000–26 → s0/s2 ≈ 9.3 % CAGR on a total-return basis vs SPY ~8.1–8.2 % (s1 ≈ 7.8 %). SPY benchmark rows (#3130) are price-only too (SPY TR +706 % vs sim BAH +401 %).

s1's gap to s0 (~$1.6M) is ONE at-fill cash cancellation (ADMA, 96 % funded, log only) — 34–35 such per salt (#3138), not path luck.

**Why:** the merged "investor trails SPY / idle cash costs" readings ([[project_investor_preset_broad]]) compared a zero-interest price-only sim with SPY total return.

**How to apply:** quote SPY comparisons on a matched basis (both price-only, or both TR with cash yield). A T-bill / money-market sweep (book Ch. 9 "safe harbor") is NOT the declined SPY sleeve ([[project_barbell_on_stocks]]) — no equity risk; default-off `cash_yield` + dividends per #3137, paired 3-salt A/B as an implementation check. Also: dollar-volume look-ahead in PIT ranking/liquidity gates (#3136) — split-adjusted volume × raw close.

**10-07 measured (PR #3178, total-return-26y-2026-10-06, 3 salts, V6 clean, tr0 = record fill-for-fill):** interest +0.232 log every salt (estimate 0.24 — PASS); dividends +0.233/0.210/0.232 (estimate 0.13 — outside band, traced): ordinary stream ≈ 0.12 (≈ 1 %/yr on invested), excess = 5 large events (AD $23 special +0.046) + ADR gross +0.018. Upstream defect **#3173**: TDG/WING/BCH specials read as SPLITS → phantom shares in both arms (≈ 0.03 log) + TR double count → blocks the `dividend_crediting` default flip; `cash_yield` passed. Path term −0.06/+0.25/+0.04 log = at-fill cash knife-edges (#3138: ADMA/GLNG), not better decisions. DD 31 → 23 % (≈ half credits, half path). Sharpe headline 0.58 vs 0.60 compares excess vs raw; same basis tr1 +0.11–0.18. Re-read rule of thumb: interest bias ≈ Δ(avg cash) × era price of cash (whole window 10 pp ≈ +0.05 log); only verdicts within ≈ 0.05 log can flip (index-stage veto s2 is the one candidate). Follow-ups #3174 (ex-div stop adjust: AD/BKE stopped at the open on special ex-dates), #3175, #3176, #3177.

**Update 2026-10-09 (rebaseline-v12, #3219): item 3 PASSED on every salt.**
- Ordinary dividends +0.142 log (band 0.065–0.195); specials +0.065–0.093 (AD $23 alone +0.0465); interest +0.235.
- Crediting reconstructs to < $1. The guard rejected 2–3 events per path (WING, DHLGY ticket, TDG); BCH not tested.
- Consequence: a default-flip PR for `dividend_crediting` + `split_dividend_guard`.
- New gap: spin-offs are not credited (BBWI→VSCO, ~0.06 log, #3215). #3174 (ex-div stops) is still default-off.
