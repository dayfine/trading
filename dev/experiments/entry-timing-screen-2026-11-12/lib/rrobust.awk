# rrobust.awk -- robustness of the no-gate re-entry result (13-week window): k0's top re-entries, each seed's total
# without its top 3 / top 10 fills, the two halves of the window, and the result by shakeout depth (pooled).
# usage: awk -F'\t' -f rrobust.awk reentry_nogate.tsv     (13-week fields: 12 status, 13 fill date, 14 trade %, 15 NAV-%, 16 stop dist)
$12 == "F" { k = $1; n[k]++; v[k, n[k]] = $15; y = substr($13, 1, 4) + 0; if (y <= 2012) a[k] += $15; else b[k] += $15
  if (k == 0) top[++nt] = sprintf("%+9.2f\t%-6s stopped %s  re-bought %s  trade %+7.1f%%  stop %.0f%% below", $15, $3, $4, $13, $14, 100 * $16)
  s = $16; g = (s <= 0.15) ? "a <=15%" : (s <= 0.25) ? "b 15-25%" : (s <= 0.40) ? "c 25-40%" : "d >40%"
  gn[g]++; gt[g] += $15; gw[g] += ($14 > 0); gh[g] += ($14 >= 50) }
END { print "== k0, 13-week window: top 10 re-entries by NAV-%"
  cmd = "sort -gr | head -10"; for (i = 1; i <= nt; i++) print top[i] | cmd; close(cmd)
  print "\n== per seed (13-week window): total | minus top 3 | minus top 10 | fills 2000-2012 | fills 2013-2026"
  for (k = 0; k <= 4; k++) { m = n[k]; for (i = 2; i <= m; i++) { x = v[k, i]; j = i - 1; while (j > 0 && v[k, j] < x) { v[k, j + 1] = v[k, j]; j-- }; v[k, j + 1] = x }
    t = 0; for (i = 1; i <= m; i++) t += v[k, i]; t3 = t; for (i = 1; i <= 3; i++) t3 -= v[k, i]; t10 = t; for (i = 1; i <= 10; i++) t10 -= v[k, i]
    printf "k%d %+7.1f | %+7.1f | %+7.1f | %+7.1f | %+7.1f\n", k, t, t3, t10, a[k], b[k] }
  print "\n== by shakeout depth (stop distance), 5 seeds pooled, 13-week window"
  split("a <=15%|b 15-25%|c 25-40%|d >40%", G, "|")
  for (i = 1; i <= 4; i++) { g = G[i]; if (gn[g]) printf "%-9s fills %4d  NAV-%% %+7.1f  per fill %+.2f  win %4.1f%%  +50%% trades %d\n", g, gn[g], gt[g], gt[g] / gn[g], 100 * gw[g] / gn[g], gh[g] } }
