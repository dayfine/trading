# Daily exposure of ONE position still open at the window end (open_positions.csv),
# over that symbol's daily CSV store file (header: date,open,high,low,close,
# adjusted_close,...). POSIX awk. Issue #3125: without this, every exposure figure
# dropped the holdings the run ended with.
#
# vars: pid ed last qty out_ex
#   ed    entry date; last  the window's last equity date (inclusive: the position
#         is still held on it); qty  shares as the run holds them at the end
#
# The position is marked at the close on the LAST bar's basis: value(d) =
# qty * adjusted_close(d) * close(last) / adjusted_close(last), so on the last
# bar it is exactly qty * close, which is how the simulator marks it into
# actual.sexp's open_positions_value, and a split inside the hold does not jump.
# The value is gross (a short's too): it is exposure. open_json.awk signs shorts
# for the last-day check against open_positions_value (#3144).
#
# No bar on `last` (a holiday at the window end, a halted or delisted name): the
# simulator still marks the position at its last known close, so a row for `last`
# carries the last bar's value (#3144).
#
# Writes (appending) out_ex : "date<TAB>mtm_value<TAB>pid" per bar in [ed, last].
BEGIN { FS = "," }
NR == 1 { for (i = 1; i <= NF; i++) { if ($i == "date") cd = i; if ($i == "close") cc = i; if ($i == "adjusted_close") ca = i }; next }
{
  d = $cd; c = $cc + 0; a = $ca + 0
  if (c <= 0 || a <= 0 || d < ed || d > last) next
  n++; dt[n] = d; adj[n] = a; f_last = c / a
}
END {
  for (i = 1; i <= n; i++) printf "%s\t%.2f\t%s\n", dt[i], qty * adj[i] * f_last, pid >> out_ex
  if (n > 0 && dt[n] < last) printf "%s\t%.2f\t%s\n", last, qty * adj[n] * f_last, pid >> out_ex
}
