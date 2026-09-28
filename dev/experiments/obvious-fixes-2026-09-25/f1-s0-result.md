# f1-stoplimit-fresh, salt 0 — Fix A alone (2026-09-28)

Answers item 1 of `salt0-analysis.md` §3 in part: at salt 0, **which of the two fixes moved the
result?** Fix A = `sim_entry_stoplimit_fresh_bar_only` (entry stop-limit fills only on the fresh
bar); Fix B = `sim_stop_exit_fill_on_trigger_bar` (#2964/#2967, stop exits fill on the trigger bar).
`f2-fills-faithful` turns both on; `f1-stoplimit-fresh` turns on Fix A only.

26y, top-3000 PIT schedule, `_v11pit` warehouse, $1,000,000 start, salt 0.

| arm | fixes on | return | max DD | Calmar | trades | V6 vs null | V6 vs f2 |
|---|---|---:|---:|---:|---:|---|---|
| `a0-pit-null` | none | 457.01 % | 40.64 % | 0.165 | 732 | — | — |
| `f1-stoplimit-fresh` | A | 464.83 % | 49.71 % | 0.136 | 752 | agree (0/0) | agree (0/0) |
| `f2-fills-faithful` | A + B | 132.78 % | 54.57 % | 0.059 | 724 | agree (0/0) | — |

Sources: `results/f1-stoplimit-fresh-s0-v11-actual.sexp`,
`results/f2-fills-faithful-s0-v11-actual.sexp`,
`../pit-universe-2026-09-14/step4/results/a0-pit-null-s0-v11-actual.sexp`; V6 logs
`results/f1-stoplimit-fresh-s0-v11.vs-a0.v6diff.log` (the chain's automatic check) and
`results/f1-stoplimit-fresh-s0-v11.vs-f2.v6diff.log` (run by hand; `chain-fixes.sh` pairs only
against the null). Chain log: `results/chain-F1.log`.

## Reading

- **At salt 0, Fix B carries the whole drop.** Fix A alone leaves the return where the null has it
  (+7.8 pp, inside one salt's noise); adding Fix B takes it from 464.8 % to 132.8 %. That matches
  `salt0-analysis.md`'s per-trade finding that Fix B is the one real per-trade cost (a stop that
  fills on the trigger bar instead of the next open).
- Fix A alone does raise max drawdown by 9 pp (40.6 → 49.7 %). One salt; not interpreted further.
- **Limits.** One salt. The null's own salt band is 457 / 188 / 152 %, so a level read needs
  salts 1–2 of f1 (~11 h of container time, not queued). And the build differs: `a0` and `f2` ran
  on the `sweep-fixes` worktree (#2964 tip), `f1` on `sweep-post2996` (main `f5507ad86`). The code
  between them adds default-off flags (#2995, #2996) and audit / trade-record changes (#2986,
  #2987, #2988) that do not touch the default trading path by their own descriptions, and every V6
  pair agrees; but no same-build rerun of `f2` s0 exists to prove the default path is
  bit-identical. #2988 also changes how the `n_stop_raises` column of `trades.csv` is counted, so
  that column must not be compared across the two builds.
