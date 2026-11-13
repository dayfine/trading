# extra.awk -- the follow-up reads: H1 band skips (perturbation of the 30-50 % band), the stale-E cap (H2')
# per seed with a k0 bootstrap CI, and the >= +100 % trades by screen extension.
# usage: awk -F'\t' -f extra.awk pct.tsv replay.tsv
FNR == NR { P[$1, $2] = $3; next }
$4 == "NODATA" { next }
{ k = $1; c = 100 * $8 / $9; e = $11 + 0
  for (a = 1; a <= 3; a++) for (b = 1; b <= 5; b++) if (e > LO[a] && e <= HI[b]) { s[a, b, k] += c; if (k == 0) nn[a, b]++; if (P[k, $2] >= 100) m[a, b]++ }
  if (P[k, $2] >= 100) mon[++nm] = sprintf("k%d %-14s screen %s ext %+5.1f%%  trade %+6.1f%%  NAV-%% %+5.1f", k, $2, $4, 100 * e, P[k, $2], c)
  if ($10 == 1 && $19 != "-" && $21 != "" && !($14 < $15 * 1.005 - 1e-9)) {   # stale E: the cap applies
    d = 100 * ($32 - $22) / $9; cn[k]++; cs[k] += d; if (d > 1e-9) cp[k]++; else if (d < -1e-9) cm[k]++; ce[k] += ($29 < $19)
    if (k == 0) ca[++na] = d }
}
BEGIN { split("0.25 0.30 0.35", LO, " "); split("0.40 0.45 0.50 0.60 9", HI, " ") }
END {
  print "== H1 band skip: drop trades with lo < screen extension <= hi. NAV-% change k0..k4 | trades skipped in k0 | >= +100 % trades lost (all seeds)"
  for (a = 1; a <= 3; a++) for (b = 1; b <= 5; b++) { printf "%.2f-%-4s |", LO[a], HI[b]; for (k = 0; k <= 4; k++) printf " %+6.1f", -s[a, b, k]; printf " | n_k0 %3d | monsters %d\n", nn[a, b], m[a, b] }
  print "\n== H2' cap a stale E at the 4-week high x 1.005 (only when the code's E is above it), vs the null"
  for (k = 0; k <= 4; k++) printf "k%d n=%3d delta %+6.1f NAV-%%  better %3d worse %3d  filled earlier %d\n", k, cn[k], cs[k], cp[k], cm[k], ce[k]
  srand(3); for (b = 1; b <= 1000; b++) { t = 0; for (i = 1; i <= na; i++) t += ca[1 + int(rand() * na)]; v[b] = t }
  for (i = 2; i <= 1000; i++) { x = v[i]; j = i - 1; while (j > 0 && v[j] > x) { v[j + 1] = v[j]; j-- }; v[j + 1] = x }
  printf "k0 90%% bootstrap CI of the sum [%+.1f, %+.1f]\n", v[50], v[951]
  for (i = 1; i <= na; i++) { w5 += (ca[i] < -0.5); q[i] = ca[i] }
  printf "k0 trades worse than -0.5 NAV-%%: %d\n", w5
  print "\n== trades >= +100 % (all seeds)"; for (i = 1; i <= nm; i++) print mon[i]
}
