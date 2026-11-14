# cohort.awk -- per-trade return distribution of two cohorts from the S:C keys of one seed (closed legs only):
#   ADM  = C's capped tickets on keys S did not place (PC, cap 1)  -> C's trade
#   DISP = S's tickets C did not place, C skipped for cash or had no list (PS, other skip:Insufficient_cash|nolist) -> S's trade
# Inputs: keys.tsv (pair-prefixed), C tickets, C trades, S tickets, S trades, C equity, S equity. Variable seed.
function navat(a, d,   lo, hi, mid) { if (cd[a, 1] > d) return cv[a, 1]; lo = 1; hi = nc[a]
  while (lo < hi) { mid = int((lo + hi + 1) / 2); if (cd[a, mid] <= d) lo = mid; else hi = mid - 1 } return cv[a, lo] }
FILENAME ~ /keys/ { if ($1 == "S:C" && $3 == seed && $25 == 0) { if ($5 == "PC" && $6 == 1) want["C", $4] = "ADM"
    if ($5 == "PS" && ($20 == "skip:Insufficient_cash" || $20 == "nolist")) want["S", $4] = "DISP" } next }
FILENAME ~ /equity_curve/ { if (FNR == 1) next; a = (FILENAME ~ /-C-k/) ? "C" : "S"; nc[a]++; cd[a, nc[a]] = $1; cv[a, nc[a]] = $2; next }
FILENAME ~ /tickets/ { if (FNR == 1) next; a = (FILENAME ~ /-C-k/) ? "C" : "S"; key[a, $1] = $2 "|" $3; next }
FILENAME ~ /trades/ { if (FNR == 1) next; a = (FILENAME ~ /-C-k/) ? "C" : "S"; k = key[a, $20]; if (!((a, k) in want)) next
  g = want[a, k]; n[g]++; r[g, n[g]] = $10 + 0; w = 100 * $6 * $8 / navat(a, $3); ws[g] += w; c[g] += 100 * ($9 + $25) / navat(a, $3)
  if ($10 + 0 >= 100) big[g]++; if ($9 > 0) win[g]++; next }
END { for (g in n) { m = n[g]; for (i = 1; i <= m; i++) x[i] = r[g, i]
    for (i = 2; i <= m; i++) { v = x[i]; j = i - 1; while (j >= 1 && x[j] > v) { x[j + 1] = x[j]; j-- } x[j + 1] = v }
    printf "%s %-4s n=%d win=%.0f%% ret%%: p10 %.1f p25 %.1f p50 %.1f p75 %.1f p90 %.1f max %.1f >=100%%: %d | mean weight %.1f%% | sum c %.1f NAV-%%\n", seed, g, m, 100 * win[g] / m,
      x[int(m * .1) + 1], x[int(m * .25) + 1], x[int(m * .5) + 1], x[int(m * .75) + 1], x[int(m * .9) + 1], x[m], big[g], ws[g] / m, c[g] } }
