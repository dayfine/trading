# Leave-episodes-out on criterion 1 from an episodes.awk table (h = 0.25 column): drop the worst episodes one at a time
# and report d_log after each drop, to show how far the cell is from the -0.05 threshold in episodes, not just in log.
BEGIN { FS = "," }
FNR > 1 { n++; x[n] = $8 + 0; lab[n] = $2 "->" $3; s += $8 }
END { for (i = 2; i <= n; i++) { v = x[i]; l = lab[i]; j = i - 1; while (j >= 1 && x[j] > v) { x[j+1] = x[j]; lab[j+1] = lab[j]; j-- } x[j+1] = v; lab[j+1] = l }
  printf "all %d episodes: %+.4f\n", n, s
  for (k = 1; k <= 5 && k <= n; k++) { s -= x[k]; printf "drop worst %d (%s %+.4f): %+.4f%s\n", k, lab[k], x[k], s, (s >= -0.05 ? "  <- clears -0.05" : "") } }
