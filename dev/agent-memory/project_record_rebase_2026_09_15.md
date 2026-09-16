---
name: record-rebase-2026-09-15
description: ⭐ RECORD BAND on the PIT universe (`_v11pit`, 27-entry yearly top-3000 schedule, V6 = 0): 152 / 188 / 457 % (salts 2/1/0), maxDD 40.6–53.0, 732–766 trades — supersedes the 2000-vintage 312 / 383 / 640 band as THE baseline; not comparable to it (construction + warehouse + path). Salt 0's 457 is the lottery top; quote the band. Cells cost ~6.3 h.
metadata:
  type: project
---

**Cells** (`dev/experiments/pit-universe-2026-09-14/step4/results/a0-pit-null-s{0,1,2}-v11-*`; spec = the a0 null with
a 27-entry `universe_schedule` 1999–2025, D1/D2 dating; run tree sweep-pit @ 3a20f4987 = #2816; warehouse `_v11pit`
9,364 entries after the cross-chunk twin fix; lists committed under `test_data/backtest_scenarios/pit-v11/composition/`):

| salt | return | trades | Sharpe | maxDD | realised | unrealised | open |
|---|---:|---:|---:|---:|---:|---:|---|
| 0 | 457.01 | 732 | 0.482 | 40.64 | $3.85M | $0.92M | 5 |
| 1 | 188.05 | 766 | 0.329 | 53.05 | $1.67M | $0.41M | 7 |
| 2 | 152.03 | 762 | 0.297 | 51.32 | $1.40M | $0.29M | 5 |

V6 = 0 every salt (`validator_diff -check V6` agree). V16: CLE 2014 force_liquidation every salt, ASPS 2017 on s0/s2.
Exit mix stable (stop_loss 495–530, laggard 221–223); `delisted` exits 4–6 are new (D4). Ledger:
`2026-09-15-pit-universe-record-baseline` (verdict Inconclusive = baseline entry).

**Rules:** every arm from now pairs against THIS band at the same salt on `_v11pit`, gated by `validator_diff -check V6`.
Never quote 457 alone; never compare a PIT level to a 2000-vintage level (different construction: ~2,800 effective
names/yr dated membership vs one survivor-tilted list; `[[warehouse-vintage-coverage]]` −12 to −23pp on 5y). Grid
universe axis = breadth tier of the same construction (`promotion-confirmation.md`, #2828). A PIT cell takes ~6.3 h
single-worker at 5.5–6.5 GB — one lane only; #2839 for perf, membership pruning rejected (prior-stage continuity).

Supersedes [[record-rebase-2026-09-09]] (keep it: every pre-09-16 verdict is a relative read on that construction).
Related: [[pit-universe-migration]], [[pit-chunked-twin-miss]], [[edge-is-the-fat-tail]].
