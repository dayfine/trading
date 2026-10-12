# Gate episodes from a days.awk table. -v g=6|7|8 picks the G1|G2|G3 column.
# Row: n,first exposed day,last exposed day,SPY sessions,SPY TR move % (close before the first day -> last exposed
# close),SPY drawdown % from its running TR high at entry,h=1 short log (daily rebalanced, no borrow),h=0.25 overlay log
# (with 0.25 %/yr borrow per session) -- the pre-registered daily-rebalanced form.
BEGIN { FS = ","; lvl = 1; hi = 1 }
{ pre = lvl; lvl = lvl * (1 + $3); on = $(g)
  if (on && !inep) { ne++; es[ne] = $1; e0[ne] = pre; ddent[ne] = 1 - pre / hi; inep = 1 }
  if (on) { ee[ne] = $1; e1[ne] = lvl; s1[ne] += log(1 - $3); s25[ne] += log(1 - 0.25 * $3) - ($5 ? 0.25 * 0.0025 / 252 : 0); td[ne] += $5 }
  else inep = 0
  if (lvl > hi) hi = lvl }
END { print "n,first,last,sessions,spy_pct,spy_dd_at_entry_pct,short_log_h1,overlay_log_h025"
  for (i = 1; i <= ne; i++) printf "%d,%s,%s,%d,%+.2f,%.1f,%+.4f,%+.4f\n", i, es[i], ee[i], td[i], 100 * (e1[i] / e0[i] - 1), 100 * ddent[i], s1[i], s25[i] }
