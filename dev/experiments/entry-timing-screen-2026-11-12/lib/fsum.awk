# fsum.awk -- F1 cell table: per (N, M) and seed, NAV-% change vs the baseline (gate on | gate off) and status counts.
# usage: awk -F'\t' -f fsum.awk pct.tsv floor.tsv
FNR == NR { P[$1, $2] = $3; next }
{ k = $1; nav = $6; base = $7; nb[k]++; tb[k] += 100 * base / nav
  for (c = 1; c <= 9; c++) { o = 7 + (c - 1) * 4; st = $(o + 1)
    dg = 100 * ($(o + 3) - base) / nav; dn = 100 * ($(o + 4) - base) / nav
    G[c, k] += dg; Nn[c, k] += dn; cnt[c, k, st]++
    if (st == "D" && P[k, $2] >= 100) mon[c, k]++
    if (st == "D") { dropped[c, k] += -100 * base / nav } } }
END { split("8 13 26", NS, " "); split("2 4 8", MS, " ")
  printf "baseline (model) NAV-%%:"; for (k = 0; k <= 4; k++) printf " k%d %.1f", k, tb[k]; print ""
  print "cell        | gate on: delta NAV-% k0..k4                | gate off: delta k0..k4                     | k0 kept/dropped/nobreak/invalid | monsters dropped k0..k4"
  for (c = 1; c <= 9; c++) { a = int((c - 1) / 3) + 1; b = (c - 1) % 3 + 1; printf "N=%2d M=%d |", NS[a], MS[b]
    for (k = 0; k <= 4; k++) printf " %+7.1f", G[c, k]; printf " |"; for (k = 0; k <= 4; k++) printf " %+7.1f", Nn[c, k]
    printf " | %3d/%3d/%3d/%2d |", cnt[c, 0, "K"], cnt[c, 0, "D"], cnt[c, 0, "U"], cnt[c, 0, "I"]
    for (k = 0; k <= 4; k++) printf " %d", mon[c, k]; print "" } }
