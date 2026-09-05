# yearly-trade-review-2026-09-04 — scripts and small artifacts behind `dev/notes/yearly-trade-review-2000-2026.md`

- `grade.sh` — reads the record's `trades.csv` and the CSV store; emits `graded.csv` (every trade
  with its basis-free post-entry / post-exit 13-week path and an A–F grade; rubric in the note).
- `px_extract.sh` — half-year adjusted-close snapshots (last bar ≤ each Jun 30 / Dec 31, 1999–2026)
  for every symbol in the union of the per-year `top-3000-<year>.sexp` compositions (~10k names,
  260k rows → `/tmp/yr-run/px.csv`, not committed: regenerable in ~25 min on the host).
- `sector_signal.sh` — builds the symbol-year table (`sy.csv`, 58k rows, not committed): year-start
  and mid-year 26-week RS vs `GSPC.INDX`, calendar-year and H2 return, sector, traded flag, trade P&L.
  Stale last-bars (> 45 days before the key) are dropped.
- `sector_agg.sh` — within-(year, sector) ranks and the per-sector-year summary `sector_year.csv`
  (committed, raw means) and `sector_year_winsorized.csv` (committed; the note's tables use this one): n, mean return, Spearman(RS, return), top-by-signal / top-by-return names and whether
  the record traded them, top-5 catch counts. The note's robust tables use the winsorized variant
  (`syc.csv`, returns clipped to [−95%, +300%], 0.6% artifact symbol-years excluded).
- `yr_sectors.txt` — per year: market-best sector (median return), signal-best sector, our best sector.

All host-side POSIX sh + awk (`.claude/rules/no-python.md`); nothing runs in the container.
