# Breadth series and scripts (27y study, 2026-09-04/05)

Committed 2026-09-05 from the host's `/tmp/yr-run` (the 09-06 priorities doc
assumed they were already here). Consumed by the "Breadth state across 27
years" section of `../../stop-width-cadence-surface-2026-09-05/README.md`.

- `breadth_all.sh` — daily aggregates over the per-year PIT universes
  (`members.csv`, not committed: 788 KB, regenerable from
  `trading/test_data/goldens-custom-universe/composition/top-3000-<year>.sexp`):
  `date, n, n_above150, NH52, NL52, advances, declines`. Runs against the
  host CSV store `data/<A>/<Z>/<SYM>/data.csv`.
- `breadth_all_daily.csv` — its output, 2000-01-03 .. 2026-08, 6,876 rows.
- `breadth_score.sh` — joins `^GSPC` (20-day return, % vs 150d MA) to the
  aggregates → `state_daily.csv` (`date, pct_above, nl_pct, nh, ad_cum,
  idx_4wk, idx_vs_ma150`), filtered to days with n ≥ 500.
- `breadth_rule.sh T_ABOVE T_NL trades.csv…` — level-only state at entry
  (`crash` if pct_above < T_ABOVE or nl_pct > T_NL; `weak` < 50; else `ok`)
  scored against a trades file, cross-tabbed with the macro gate's own label
  (`macro.txt`, per-run `macro_trend.sexp` flattened to `date trend`).

The **direction** rule quoted in the surface README (Deteriorating = pct_above
< 45 AND down ≥ 5 points over 20 trading days, or nl_pct > 8 and rising;
Recovering = below 45 and rising) was applied as an inline awk over
`state_daily.csv` and is not preserved as a script; the thresholds are the
ones the macro-state feature (priorities 2026-09-06 item 2) starts from.
