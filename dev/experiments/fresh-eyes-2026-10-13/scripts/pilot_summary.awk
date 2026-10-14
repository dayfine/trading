# pilot_summary.awk: one line per symbol from <calls.csv> <trades.csv> <log.csv> (see pilot_summary.sh).
FNR == 1 { fi++; next }
fi == 1 { s = $1; n++; i += $4; cr += $5; cc += $6; o += $7; c += $8; w += $9; a[$11]++; tu += $10 }
fi == 2 { nt++; side[$2]++; ex += $10; r = r sprintf(" %s %s->%s %s ret %+.1f%% exc %+.1f%%;", $2, $3, $5, $7, 100 * $8, 100 * $10) }
fi == 3 { ncp++ }
END {
  t = i + cr + cc + o
  printf "%s checkpoints=%d calls=%d tokens=%d (in %d, cache_read %d, cache_write %d, out %d) per_call=%d usd=%.2f wall=%ds turns_per_call=%.2f actions:", \
    s, ncp, n, t, i, cr, cc, o, (n ? t / n : 0), c, w, (n ? tu / n : 0)
  for (k in a) printf " %s=%d", k, a[k]
  printf " | trades=%d long=%d short=%d sum_excess=%+.1f%%\n", nt, side["long"], side["short"], 100 * ex
  if (r != "") print "  " r
}
