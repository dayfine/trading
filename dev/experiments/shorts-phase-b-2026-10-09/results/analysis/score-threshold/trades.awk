# Filled shorts by screener_score_at_entry (trades.csv col 19), cumulative "score >= T".
FNR > 1 { n++; sc[n] = $19 + 0; p[n] = $10 + 0; d[n] = $9 + 0 }
END { for (t = 40; t <= 110; t += 10) { c = 0; s = 0; dd = 0; w = 0
    for (i = 1; i <= n; i++) if (sc[i] >= t) { c++; s += p[i]; dd += d[i]; if (p[i] > 0) w++ }
    if (c) printf "score>=%3d n=%3d win=%3.0f%% mean=%+5.1f%% pnl=$%+.0fk\n", t, c, 100 * w / c, s / c, dd / 1000 } }
