# Fresh-eyes stepper: the plain-text status block the agent reads with each page, on the chart's price basis.
# Usage: awk -F, -f status.awk <state> <weekly.csv> <trades.csv>
# Levels in the state are adjusted; they are shown x k(cut) (k = raw / adjusted close of the cut week), the same
# scale as the chart and the last-bar JSON. Closed trades are shown as dates and percentage returns only (their
# prices would need an older cut's scale).
BEGIN { CONVFMT = "%.10g"; FS = "," }
FNR == 1 { fi++ }
fi == 1 { p = index($0, "="); if (p) st[substr($0, 1, p - 1)] = substr($0, p + 1); next }
fi == 2 { if (FNR > 1 && $1 <= st["cut"] && $5 + 0 > 0) k = $9 / $5; next }
fi == 3 { if (FNR > 1) { nt++; tr[nt] = $0 }; next }
function px(v) { return (v == "") ? "-" : sprintf("%.2f", v * k) }
END {
  if (k == "") k = 1
  printf "cut: %s\n", st["cut"]
  if (st["status"] == "done") print "run: finished"
  if (st["pos"] == "none") print "position: none"
  else printf "position: %s since %s, entry %s, protective stop %s\n", st["pos"], st["edate"], px(st["epx"]), px(st["stop"])
  if (st["ord"] == "none") print "order: none"
  else printf "order: %s trigger %s%s, stop on fill %s, placed %s\n", st["ord"], px(st["trig"]), (st["lim"] == "" ? "" : " limit " px(st["lim"])), px(st["ostop"]), st["placed"]
  if (st["due"] == 1) print "ATTENTION: the order has rested 8 weeks. Re-issue it (buy_stop / short_stop) or it is cancelled."
  if (st["msg"] != "") printf "since the last checkpoint: %s\n", st["msg"]
  printf "closed trades: %d\n", nt
  for (i = (nt > 3 ? nt - 2 : 1); i <= nt; i++) {
    split(tr[i], f, ","); printf "  %s %s -> %s (%s) return %+.1f%%\n", f[2], f[3], f[5], f[7], 100 * f[8]
  }
}
