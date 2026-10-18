# ours_top.awk: the screener's weekly decision list for the week of `want`, from a record trade_audit.sexp.
# Usage: awk -v want=YYYY-MM-DD -v salt=K -f days.awk -f ours_top.awk <trade_audit.sexp>
# The cascade_summaries section holds one record per week, "((date D) (total_stocks ...", then its decisions, one
# "((symbol X) (side S) (outcome O))" per line, in list order. The week matches when D and want fall in the same
# Saturday..Friday week (a holiday Friday's record is dated the Thursday). Prints salt,rank,symbol,side,outcome
# with outcome Placed or the skip reason (e.g. No_structural_stop).
BEGIN { wz = friday(days(want)) }
/\(\(date [0-9-]+\) \(total_stocks/ { match($0, /date [0-9-]+/); wd = substr($0, RSTART + 5, 10); on = (friday(days(wd)) == wz); r = 0; next }
on && hdr != "" && /macro_trend/ { match($0, /macro_trend [A-Za-z]+/); mt = substr($0, RSTART + 12, RLENGTH - 12) }
on && hdr != "" && /long_top_n_admitted/ { match($0, /long_top_n_admitted [0-9]+/); lt = substr($0, RSTART + 20, RLENGTH - 20) }
on && hdr != "" && /\(entered / { match($0, /short_top_n_admitted [0-9]+/); st = substr($0, RSTART + 21, RLENGTH - 21); match($0, /entered [0-9]+/); print salt "," wd "," mt "," lt "," st "," substr($0, RSTART + 8, RLENGTH - 8) >> hdr }
on && /\(outcome / {
  if (!match($0, /symbol [^)]+/)) next
  s = substr($0, RSTART + 7, RLENGTH - 7)
  sd = ""; if (match($0, /side [A-Za-z]+/)) sd = tolower(substr($0, RSTART + 5, RLENGTH - 5))
  o = substr($0, index($0, "(outcome ") + 9); gsub(/[()]/, "", o); sub(/^Skipped /, "", o); gsub(/ +$/, "", o)
  print salt "," ++r "," s "," sd "," o
}
