Why-tables for the gate-funnel Results section (README §Why, §Derivations). Written by the results read on
2026-11-15; awk, run by hand, not part of read.sh. Every file here is mark-free (dates, symbols, labels, counts,
ride percentages). The private inputs live in dayfine/trading-results a3a2dadc2 under the same path.

Inputs
  public : ../fridays.tsv, ../../gf-S-k0-s0-macro_trend.sexp, ../../gf-S-k0-s0-entries.tsv
  private: gf-S-k0-s0-trades.csv, gf-S-k0-s0-open_positions.csv, read/crowd_outcomes.tsv.gz, read/pool_outcomes.tsv.gz
  local  : SPY data.csv from the bar store (spyreg.awk); only the regime labels are kept (spyweek.tsv)

Derived tables (committed)
  macro.tsv      date, macro trend, breadth state (from macro_trend.sexp)
  spyweek.tsv    week key, SPY regime UP / MIXED / DOWN known at that week's last close (spyreg.awk)
  held.tsv       entry date, exit date of every S position (trades.csv + open_positions.csv)
  s_placed.tsv   symbol, decision date of every S long ticket placed (entries.tsv)
  fj.tsv         fridays.tsv joined with macro, prior-week SPY regime, gate age, positions held (join.awk);
                 columns: date year trend breadth regime age held, then fridays.tsv's columns
  episodes.tsv   runs of consecutive X-net Fridays: start end Fridays X-net share zero-position-Fridays (epi.awk)
  loo.txt        C* (C) and funded (F) per year: n, mean capped ride, for the leave-one-year-out check
  cstar_keys.txt date|symbol of the 1,411 C* (net) slots

Scripts
  dates.awk   day and week numbers of an ISO date (shared helper, include with -f)
  join.awk    builds fj.tsv
  dec.awk     groups fj.tsv by K (trend, regime, held, age, free cash, year) -> the held / gate-age tables
  epi.awk     builds episodes.tsv
  path.awk    gbc.awk's path() with HOLD and M as variables -> the path and sizing sensitivities
  cstar.awk   C* rows from crowd_outcomes, deduped, grouped by G (year or Friday context) -> C* by period / regime
  cstar2.awk  C* rank-1 slice by year and regime
  funded.awk  walk Funded rows from crowd_outcomes, grouped like cstar.awk
  mod5.awk    score multiple-of-5 split (the post-hoc overhead-supply note)
  spyreg.awk  SPY regime from data.csv

Not scripted: the rank-band table (A+ share and buyable share by cut rank) and the regime-by-period exposure table
were one-off awk over pool_outcomes and fj.tsv; their inputs are above.
