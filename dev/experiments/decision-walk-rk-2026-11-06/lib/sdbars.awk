# stopdec.tsv sorted by sym (then pid, date) -> stopdec.tsv + raw close, raw low, adjusted close, factor (close/adj)
# of the decision date's bar (the last bar on or before it). Needs ./data.
function load(sym,  f, line, a) { delete D; delete C; delete Lw; delete A; nb = 0; f = "data/" substr(sym, 1, 1) "/" substr(sym, length(sym), 1) "/" sym "/data.csv"
  while ((getline line < f) > 0) { if (line ~ /^date/) continue; split(line, a, ","); if (a[5] + 0 <= 0) continue; nb++; D[nb] = a[1]; C[nb] = a[5]; Lw[nb] = a[4]; A[nb] = a[6] } close(f) }
{ if ($2 != cur) { cur = $2; load(cur) }
  lo = 1; hi = nb; i = 0; while (lo <= hi) { m = int((lo + hi) / 2); if (D[m] <= $3) { i = m; lo = m + 1 } else hi = m - 1 }
  if (i == 0 || A[i] + 0 <= 0) { print $0 "\tNA\tNA\tNA\tNA"; next }
  printf "%s\t%s\t%s\t%s\t%.4f\n", $0, C[i], Lw[i], A[i], C[i] / A[i] }
