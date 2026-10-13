# Filled shorts by entry sector_rating x rs_trend. Files: 1 entry-attribute csv (position_id,sector_rating,rs_trend),
# 2 trades.csv (position_id col 20, pnl_percent col 10, pnl_dollars col 9).
NR == FNR { k[$1] = $2 "/" $3; next }
FNR > 1 { c = k[$20]; n[c]++; s[c] += $10; d[c] += $9; if ($10 > 0) w[c]++ }
END { for (c in n) printf "%-30s n=%3d win=%3.0f%% mean=%+5.1f%% pnl=$%+.0fk\n", c, n[c], 100 * w[c] / n[c], s[c] / n[c], d[c] / 1000 }
