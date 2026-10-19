# consist.awk: plan §6 read 5 for two runs of one date: overlap of the order sets (by real symbol) and the gap
# between their initial stops on common names, relative to the trigger.
# Usage: awk -F, -v d=DATE -v a=RUN_A -v b=RUN_B -f consist.awk <A orders.csv> <B orders.csv>
# Prints: date,rep_a,rep_b,orders_a,orders_b,common,jaccard,median_stop_gap
FNR == 1 { fi++; next }
fi == 1 { na++; sa[$2] = ($4 > 0) ? ($4 - $6) / $4 : 0; next }
{ nb++; if ($2 in sa) { c++; g = ($4 > 0) ? ($4 - $6) / $4 - sa[$2] : 0; gv[c] = (g < 0 ? -g : g) } }
END {
  for (i = 2; i <= c; i++) { t = gv[i]; for (j = i - 1; j >= 1 && gv[j] > t; j--) gv[j + 1] = gv[j]; gv[j + 1] = t }
  u = na + nb - c
  printf "%s,%s,%s,%d,%d,%d,%s,%s\n", d, a, b, na, nb, c, (u ? sprintf("%.3f", c / u) : ""), (c ? sprintf("%.4f", gv[int((c + 1) / 2)]) : "")
}
