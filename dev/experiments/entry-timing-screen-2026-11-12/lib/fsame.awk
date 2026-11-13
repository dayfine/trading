# fsame.awk -- F1 (N=13, M=4) decomposed: same position size as the run (only the stop and the exit change), plus
# the gate's dropped cohort split into winners and losers, per seed; then k0's largest per-trade effects.
# usage: awk -F'\t' -f fsame.awk pct.tsv replay.tsv floor.tsv
FILENAME ~ /pct/ { P[$1, $2] = $3; next }
FILENAME ~ /replay/ { if ($4 != "NODATA") VA[$1, $2] = $18; next }
{ k = $1; nav = $6; base = $7; st = $24; sd = $25; pn = $27; va = VA[k, $2]; c = 100 * base / nav
  if (st == "D" || st == "K") { vc = 0.01 / sd; if (vc > 0.14) vc = 0.14; same = (vc > 0) ? pn * va / vc : base
    ds = 100 * (same - base) / nav; S1[k] += ds; if (ds > 1e-6) sp[k]++; else if (ds < -1e-6) sm[k]++
    if (k == 0) { n0++; key[n0] = sprintf("%+8.2f\t%s\t%s\t%s\tsd %.0f%%\tbase %+.2f\tsame-size %+.2f", ds, $2, $4, $5, 100 * sd, c, 100 * same / nav) } }
  if (st == "D") { if (c > 0) { dw[k] += c; nw[k]++ } else { dl[k] += c; nl[k]++ }; if (P[k, $2] >= 100) dm[k]++
    if (k == 0) { m0++; dk[m0] = sprintf("%+8.2f\t%s\t%s\tsd %.0f%%\ttrade %+.1f%%", -c, $2, $4, 100 * sd, P[k, $2]) } } }
END {
  print "== F1 N=13 M=4, same size as the run (book stop + hold-through, gate ignored): delta NAV-%, trades better/worse"
  for (k = 0; k <= 4; k++) printf "k%d %+7.1f  better %3d worse %3d\n", k, S1[k], sp[k], sm[k]
  print "\n== the gate's dropped trades: winners (NAV-% they made, n) | losers (n) | >= +100 % trades dropped"
  for (k = 0; k <= 4; k++) printf "k%d winners %+7.1f (%3d) | losers %+7.1f (%3d) | monsters %d\n", k, dw[k], nw[k], dl[k], nl[k], dm[k]
  print "\n== k0 same-size: 8 trades the book stop hurt most / 8 it helped most"
  cmd = "sort -n"; for (i = 1; i <= n0; i++) print key[i] | cmd; close(cmd)
}
