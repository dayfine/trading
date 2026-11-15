# fy.awk -- descriptive read (1), the funnel by year (README §Descriptive reads): names entering the long cascade and
# removed at each gate, summed over the year's screened Fridays (name-Fridays, not distinct names). POSIX awk.
#
# usage: awk -F'\t' -v TSV=funnel_year.tsv -f fy.awk open.tsv cs.tsv rows.tsv
#   open.tsv  date open live_blocked                                  (check.awk OPEN)
#   cs.tsv    date cah lma lba lsa lga lta entered macro_trend        (summ.awk; trade_audit cascade_summaries)
#   rows.tsv  every Long row of candidates.sexp                       (cands.awk)
# Entering = candidates_after_held (the universe after phase 1, the sector pre-filter and held names). Macro removes
# all of them on a Friday that is not open (the trace omits a blocked side, so these come from the counts), and
# candidates_after_held - long_macro_admitted on an open one. Every later gate is counted from the trace's rows on open
# Fridays: the #2533 breakout sub-gate, sector, grade, the top-N cut, then the walk outcome of each Admitted row.
# Counts only.
FILENAME == ARGV[1] { OP[$1] = $2; next }
FILENAME == ARGV[2] {
  y = substr($1, 1, 4); YS[y] = 1; C["fridays", y]++; C["entering", y] += $2
  if (OP[$1] == 1) { C["open", y]++; C["macro", y] += $2 - $3 } else C["macro", y] += $2
  next
}
{
  if (OP[$1] != 1) next
  y = substr($1, 1, 4)
  if ($3 == "Dropped_at_breakout") k = "brk_" $4
  else if ($3 == "Dropped_at_sector") k = "sector"
  else if ($3 == "Dropped_at_grade") k = "grade"
  else if ($3 == "Dropped_at_top_n") k = "topn_cut"
  else if ($3 == "Admitted") {
    if ($7 == "Funded") k = "funded"; else if ($7 == "Not_reached") k = "not_reached"
    else if ($7 == "Skipped_No_structural_stop") k = "w_no_structural_stop"
    else if ($7 == "Skipped_Stop_too_wide") k = "w_stop_too_wide"
    else if ($7 == "Skipped_Insufficient_cash") k = "w_cash"
    else if ($7 == "Skipped_Already_held") k = "w_held"
    else k = "w_other"
    C["admitted", y]++
  } else k = "other_" $3
  C[k, y]++; seen[k] = 1
}
END {
  n = split("fridays open entering macro brk_Price_floor brk_Stage_setup brk_Breakout_volume brk_Rs_declining brk_Failed_breakout brk_Volume_band sector grade topn_cut admitted not_reached w_no_structural_stop w_stop_too_wide w_cash w_held w_other funded", K, " ")
  for (k in seen) { f = 0; for (i = 1; i <= n; i++) if (K[i] == k) f = 1; if (!f) K[++n] = k }
  printf "year" > TSV; for (i = 1; i <= n; i++) printf "\t%s", K[i] > TSV; print "" > TSV
  for (y = 1990; y <= 2030; y++) if (y in YS) {
    printf "%s", y > TSV; for (i = 1; i <= n; i++) { printf "\t%d", C[K[i], y] > TSV; T[K[i]] += C[K[i], y] }; print "" > TSV
  }
  printf "total" > TSV; for (i = 1; i <= n; i++) printf "\t%d", T[K[i]] > TSV; print "" > TSV
  print "== Descriptive read 1: the funnel, name-Fridays summed over the window (README §Descriptive reads; per year in funnel_year.tsv) =="
  printf "screened Fridays %d, open %d | entering %d\n", T["fridays"], T["open"], T["entering"]
  left = T["entering"]
  for (i = 4; i <= n; i++) {
    k = K[i]; if (k == "admitted") { printf "  %-24s %10d  (reaches the walk)\n", k, T[k]; continue }
    printf "  %-24s %10d  = %6.2f %% of entering", k, T[k], (T["entering"] ? 100 * T[k] / T["entering"] : 0)
    if (k !~ /^(not_reached|w_|funded)/) { printf ", %6.2f %% of what reached it", (left ? 100 * T[k] / left : 0); left -= T[k] }
    else printf ", %6.2f %% of admitted", (T["admitted"] ? 100 * T[k] / T["admitted"] : 0)
    print ""
  }
}
