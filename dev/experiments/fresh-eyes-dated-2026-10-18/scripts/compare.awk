# compare.awk: plan §6 reads 1-4 from compare_dates.sh's trades.csv and overlap.csv; writes <out>/paired.csv and
# <out>/shared.csv, prints the report. Usage: awk -F, -v out=DIR -f compare.awk <trades.csv> <overlap.csv>
FNR == 1 { fi++; next }
fi == 1 {
  if ($3 != "r0") next   # repeats (plan §6 read 5) feed consistency.csv only
  w = $1; nw[w]++; ex[w, nw[w]] = $11; an[w, nw[w]] = $13; who[w] = 1
  k = $2 SUBSEP $3
  if (w == "reader") { rn[k]++; rs[k] += $11; R[k, $4] = $6 "," $7 "," $8 "," $9 "," $14 }
  if (w == "ours-s0") { on[$2]++; os[$2] += $11; Q[$2, $4] = $6 "," $7 "," $8 "," $9 "," $14 }
  next
}
fi == 2 { nd++; od[nd] = $1; orp[nd] = $2; ov_side[nd] = $3; ov_ord[nd] = $4; ov_top[nd] = $8; ov_ent[nd] = $9; ov_sl[nd] = $10; ov_sln[nd] = $6; ov_tn[nd] = $7 }
function sortv(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } }
function q(a, n, p,   x) { if (n == 0) return ""; x = 1 + (n - 1) * p; return a[int(x)] + (x - int(x)) * (a[int(x) + 1 < n ? int(x) + 1 : n] - a[int(x)]) }
function stats(lbl, w, kind,   i, n, v, s) {
  n = nw[w]; delete v; s = 0
  for (i = 1; i <= n; i++) { v[i] = (kind == "ann" ? an[w, i] : ex[w, i]) + 0; s += v[i] }
  sortv(v, n)
  if (n == 0) { printf "  %-10s %-10s n 0\n", w, lbl; return }
  printf "  %-10s %-10s n %3d  mean %+7.1f%%  median %+7.1f%%  p10 %+7.1f%%  p25 %+7.1f%%  p75 %+7.1f%%  p90 %+7.1f%%\n", \
    w, lbl, n, 100 * s / n, 100 * q(v, n, 0.5), 100 * q(v, n, 0.1), 100 * q(v, n, 0.25), 100 * q(v, n, 0.75), 100 * q(v, n, 0.9)
}
END {
  print "read 1, pick overlap per date (orders = the reader's step-D orders; ours = our screener's list, all salts):"
  printf "  %-10s %-3s %-7s %6s %9s %8s %9s %12s %13s\n", "date", "rep", "side", "orders", "shortlist", "ours_top", "ord∩top", "ord∩entries", "short∩top"
  for (i = 1; i <= nd; i++) {
    printf "  %-10s %-3s %-7s %6d %9d %8d %9d %12d %13d\n", od[i], orp[i], ov_side[i], ov_ord[i], ov_sln[i], ov_tn[i], ov_top[i], ov_ent[i], ov_sl[i]
    if (ov_ord[i] > 0) { m++; mo += ov_top[i] / ov_ord[i]; if (ov_top[i] == 0) z++ }
  }
  if (m) printf "  dates with orders: %d; mean share of orders in our list %.0f%%; dates with zero overlap %d\n", m, 100 * mo / m, z
  print ""; print "read 2, per-trade excess vs SPY over the same holding period (filled trades):"
  for (w in who) { stats("excess", w, "ex"); stats("annualised", w, "ann") }
  print ""; print "read 3, paired per date: mean reader excess minus mean ours-s0 excess (paired.csv):"
  print "date,rep,reader_n,reader_mean_excess,ours_n,ours_mean_excess,diff" > (out "/paired.csv")
  for (i = 1; i <= nd; i++) {
    if (orp[i] != "r0") continue
    k = od[i] SUBSEP orp[i]; rm = (rn[k] ? rs[k] / rn[k] : ""); omn = (on[od[i]] ? os[od[i]] / on[od[i]] : "")
    df = (rm != "" && omn != "") ? rm - omn : ""
    printf "%s,%s,%d,%s,%d,%s,%s\n", od[i], orp[i], rn[k], rm, on[od[i]], omn, df > (out "/paired.csv")
    if (df != "") { np++; if (df > 0) pos++; dv[np] = df }
  }
  sortv(dv, np)
  if (np) printf "  paired dates %d, reader ahead on %d (%.0f%%), median diff %+.1f%%, p25 %+.1f%%, p75 %+.1f%%\n", np, pos, 100 * pos / np, 100 * q(dv, np, 0.5), 100 * q(dv, np, 0.25), 100 * q(dv, np, 0.75)
  else print "  no date with trades on both sides"
  print ""; print "read 4, shared names (traded by both the reader and ours-s0 from the same date; shared.csv):"
  print "date,rep,symbol,reader_entry,reader_exit,reader_how,reader_ret,reader_r104,ours_entry,ours_exit,ours_trigger,ours_ret,ours_r104" > (out "/shared.csv")
  for (x in R) { split(x, p, SUBSEP); if ((p[1], p[3]) in Q) { ns++; printf "%s,%s,%s,%s,%s\n", p[1], p[2], p[3], R[x], Q[p[1], p[3]] > (out "/shared.csv") } }
  printf "  %d shared trades\n", ns
}
