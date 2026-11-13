# validate.awk -- replay checks before any read: the run's fill inside the store's raw bar (basis), the replay's
# 30-week WMA vs the audit's ma_value (as close/MA extensions), and the null control (the code's own E through the
# replay fill model) against the actual fill. usage: awk -F'\t' -f validate.awk replay.tsv
$4 == "NODATA" { nod++; next }
{ n++; ok += $10; if ($11 != "" && $12 != "") { m++; d = $11 - $12; if (d < 0) d = -d; if (d < 0.01) ma1++ }
  if ($19 == $5) { rep++; r = $20 - 1; if (r < 0) r = -r; if (r < 0.005) repx++ } else if ($19 == "-") nof++; else if ($19 < $5) early++; else late++ }
END { printf "trades with bars %d (no store bars: %d)\n", n, nod
  printf "run fill inside the store's raw bar: %d (%.1f%%)\n", ok, 100 * ok / n
  printf "replay MA extension within 1pp of the audit's: %d of %d\n", ma1, m
  printf "null control: same fill day %d (%.1f%%), of which price within 0.5%% %d; replay fills earlier %d, later %d, never %d\n", rep, 100 * rep / n, repx, early, late, nof }
