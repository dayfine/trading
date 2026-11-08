# uq.tsv (date sym, sorted by sym) -> date sym r13 r26 r52: adjusted-close return from the last bar on or before the
# screen date to 65 / 130 / 260 bars later (to the last bar when the series ends sooner). Needs ./data.
function load(sym,  f, line, a) { delete D; delete A; nb = 0; f = "data/" substr(sym, 1, 1) "/" substr(sym, length(sym), 1) "/" sym "/data.csv"
  while ((getline line < f) > 0) { if (line ~ /^date/) continue; split(line, a, ","); if (a[6] + 0 <= 0) continue; nb++; D[nb] = a[1]; A[nb] = a[6] } close(f) }
function fr(i, h) { return (i + h <= nb) ? A[i + h] / A[i] - 1 : A[nb] / A[i] - 1 }
{ if ($2 != cur) { cur = $2; load(cur) } if (nb == 0) { print $1 "\t" $2 "\tNA\tNA\tNA"; next }
  lo = 1; hi = nb; i = 0; while (lo <= hi) { m = int((lo + hi) / 2); if (D[m] <= $1) { i = m; lo = m + 1 } else hi = m - 1 }
  if (i == 0) { print $1 "\t" $2 "\tNA\tNA\tNA"; next }
  printf "%s\t%s\t%.4f\t%.4f\t%.4f\n", $1, $2, fr(i, 65), fr(i, 130), fr(i, 260) }
