# Fresh-eyes stepper: apply one decision at cut t, then simulate daily bars to the next checkpoint (plan §4 (ii)).
# Usage: awk -F, -v end=YYYY-MM-DD -f days.awk -f sim.awk <state> <decision> <weekly.csv> <SPY data.csv> <SYM data.csv>
# Every input has at least one line (the state and the normalised decision always do; the CSVs have headers), so
# files are counted by FNR == 1.
#
# Prices. The agent reads the chart, whose prices are the vendor's adjusted series rescaled so the cut week's
# close is its raw close: chart = adjusted x k(t), k(t) = raw close / adjusted close of the cut week. Its levels
# are converted to the adjusted (total-return) basis with / k(t); the simulation runs on daily adjusted OHLC
# (raw x adjusted_close / close). The state stores adjusted levels; the status block shows them x k(cut).
#
# Fills (plan §4.3). buy_stop: fills when the day's high >= trigger at max(open, trigger); with a limit, a day
# that opens above the limit does not fill. short_stop mirrors it (low <= trigger, min(open, trigger); no fill on
# a day opening below the limit). A protective stop is live from the day after the fill: long exits when low <=
# stop at min(open, stop); short when high >= stop at max(open, stop). exit = the next day's open.
#
# Checkpoints: 4 weeks after the cut (next_look weeks, 1-13, when flat after the decision), or the Friday ending the week of a fill or a stop exit, or the Friday 8
# weeks after an order was placed (then the order must be re-issued, or it is cancelled), whichever is first. The
# run ends at the symbol's last bar or at `end`; an open position is marked to that close and flagged open.
#
# Output (stdout): the new state as key=value lines; TRADE,... rows; one LOG,... row; or REJECT,<message> alone
# (state unchanged, so the caller re-asks the agent at the same cut).
BEGIN { CONVFMT = "%.10g"; OFMT = "%.10g"; FS = "," }
FNR == 1 { fi++ }
fi == 1 { p = index($0, "="); if (p) st[substr($0, 1, p - 1)] = substr($0, p + 1); next }
fi == 2 { p = index($0, "="); if (p) dc[substr($0, 1, p - 1)] = substr($0, p + 1); next }
fi == 3 { if (FNR > 1) { nwk++; wkd[nwk] = $1; wkc[nwk] = $5 + 0; wkr[nwk] = $9 + 0 }; next }
fi == 4 { if (FNR > 1 && $5 + 0 > 0 && $6 + 0 > 0) { f = $6 / $5; spo[$1] = $2 * f; spc[$1] = $6 + 0 }; next }
fi == 5 { if (FNR > 1 && $5 + 0 > 0 && $6 + 0 > 0) { nd++; dd[nd] = $1; f = $6 / $5
            dop[nd] = $2 * f; dhi[nd] = $3 * f; dlo[nd] = $4 * f; dcl[nd] = $6 + 0 }; next }

function num(k) { return (st[k] == "") ? 0 : st[k] + 0 }
function kat(cut,   i, k) { k = 1; for (i = 1; i <= nwk; i++) if (wkd[i] <= cut && wkc[i] > 0) k = wkr[i] / wkc[i]; return k }
function fri(s) { return civil(friday(days(s))) }
function plus(s, n) { return civil(days(s) + n) }
function reject(m) { print "REJECT," m; exit_now = 1; exit }
# SPY on a day: the last SPY bar at or before it (o = 1 for the open).
function spy(d, o,   z, s) { for (z = days(d); z >= days(d) - 10; z--) { s = civil(z); if (s in spc) return o ? spo[s] : spc[s] }; return 0 }
function trade(how, xd, xp, xo,   r, sr, s0, s1) {
  s0 = spy(st["edate"], 1); s1 = spy(xd, xo)
  if (st["pos"] == "long") { r = xp / num("epx") - 1; sr = (s0 > 0) ? s1 / s0 - 1 : 0 }
  else { r = 1 - xp / num("epx"); sr = (s0 > 0) ? 1 - s1 / s0 : 0 }
  ntr++
  printf "TRADE,%s,%s,%s,%.6f,%s,%.6f,%s,%.6f,%.6f,%.6f\n", st["sym"], st["pos"], st["edate"], num("epx"), xd, xp, how, r, sr, r - sr
  st["pos"] = "none"; st["edate"] = ""; st["epx"] = ""; st["stop"] = ""; st["xpend"] = 0
}

function validate(   a, k, t, l, s, last, x) {
  a = dc["action"]; k = kat(st["cut"])
  x = dc["next_look"]
  if (x != "" && (x !~ /^[0-9]+$/ || x + 0 < 1 || x + 0 > 13)) reject("next_look must be a whole number of weeks, 1 to 13")
  t = (dc["trigger"] == "") ? "" : dc["trigger"] / k; l = (dc["limit"] == "") ? "" : dc["limit"] / k
  s = (dc["stop"] == "") ? "" : dc["stop"] / k
  if (a == "buy_stop" || a == "short_stop") {
    if (st["pos"] != "none") reject(a " needs no open position (you hold a " st["pos"] "); use set_stop or exit")
    if (t == "" || s == "") reject(a " needs trigger and stop")
    if (t + 0 <= 0 || s + 0 <= 0) reject("trigger and stop must be positive")
    if (a == "buy_stop" && s >= t) reject("a long stop must be below the trigger")
    if (a == "short_stop" && s <= t) reject("a short stop must be above the trigger")
    if (l != "" && a == "buy_stop" && l < t) reject("a buy limit must be at or above the trigger")
    if (l != "" && a == "short_stop" && l > t) reject("a short limit must be at or below the trigger")
    st["ord"] = a; st["trig"] = t; st["lim"] = l; st["ostop"] = s; st["placed"] = st["cut"]; st["due"] = 0
    return
  }
  # An order at its 8-week checkpoint is still the open order here: cancel and set_stop act on it like on any
  # other (the 8-week auto-cancel runs after the decision, in END). Pilot 2 VOLC 2007-07-13: the auto-cancel used to
  # run first and rejected an explicit cancel of the order the status block showed.
  if (a == "none") return
  if (a == "cancel") { if (st["ord"] == "none") reject("cancel: no open order"); st["ord"] = "none"; return }
  if (a == "exit") { if (st["pos"] == "none") reject("exit: no open position"); st["xpend"] = 1; return }
  if (a == "set_stop") {
    if (s == "" || s + 0 <= 0) reject("set_stop needs a positive stop")
    if (st["pos"] == "long" && s < num("stop")) reject("a long stop may not be lowered")
    if (st["pos"] == "short" && s > num("stop")) reject("a short stop may not be raised")
    if (st["pos"] == "none") {
      if (st["ord"] == "none") reject("set_stop: no position and no order")
      if (st["ord"] == "buy_stop" && s >= num("trig")) reject("a long stop must be below the trigger")
      if (st["ord"] == "short_stop" && s <= num("trig")) reject("a short stop must be above the trigger")
      st["ostop"] = s; return
    }
    st["stop"] = s; return
  }
  reject("unknown action " a " (none, buy_stop, short_stop, cancel, set_stop, exit)")
}

END {
  if (exit_now) exit
  if (st["status"] == "done") { print "REJECT,run is finished"; exit }
  st["msg"] = ""
  validate()
  if (exit_now) exit
  # The 8-week rule: an order still due after the decision (not re-issued, not cancelled) is cancelled now.
  if (st["due"] == 1 && st["ord"] != "none") { st["ord"] = "none"; st["msg"] = "order not re-issued after 8 weeks: cancelled; " }
  cut = st["cut"]; ntr = 0; ev = ""
  # Adaptive look (plan amendment, user decision 2026-10-13): next_look weeks, honoured only when flat (no
  # position and no open order after this decision); otherwise the 4-week cadence.
  nl = 4
  if (st["pos"] == "none" && st["ord"] == "none" && dc["next_look"] != "") nl = dc["next_look"] + 0
  cp = civil(days(cut) + 7 * nl)
  if (st["ord"] != "none" && fri(plus(st["placed"], 56)) < cp) cp = fri(plus(st["placed"], 56))
  stopd = (end < dd[nd]) ? end : dd[nd]
  for (i = 1; i <= nd; i++) {
    d = dd[i]; if (d <= cut) continue
    if (d > cp || d > stopd) break
    last = i
    if (st["pos"] != "none" && st["xpend"] == 1) { trade("exit", d, dop[i], 1); ev = ev "exit " d "; "; if (fri(d) < cp) cp = fri(d) }
    if (st["pos"] == "long" && st["edate"] < d && dlo[i] <= num("stop")) {
      trade("stop", d, (dop[i] < num("stop")) ? dop[i] : num("stop"), 0); ev = ev "stopped " d "; "; if (fri(d) < cp) cp = fri(d)
    } else if (st["pos"] == "short" && st["edate"] < d && dhi[i] >= num("stop")) {
      trade("stop", d, (dop[i] > num("stop")) ? dop[i] : num("stop"), 0); ev = ev "stopped " d "; "; if (fri(d) < cp) cp = fri(d)
    }
    if (st["pos"] == "none" && st["ord"] == "buy_stop" && dhi[i] >= num("trig") && !(st["lim"] != "" && dop[i] > st["lim"] + 0)) {
      st["pos"] = "long"; st["edate"] = d; st["epx"] = (dop[i] > num("trig")) ? dop[i] : num("trig")
      st["stop"] = st["ostop"]; st["ord"] = "none"; ev = ev "bought " d "; "; if (fri(d) < cp) cp = fri(d)
    } else if (st["pos"] == "none" && st["ord"] == "short_stop" && dlo[i] <= num("trig") && !(st["lim"] != "" && dop[i] < st["lim"] + 0)) {
      st["pos"] = "short"; st["edate"] = d; st["epx"] = (dop[i] < num("trig")) ? dop[i] : num("trig")
      st["stop"] = st["ostop"]; st["ord"] = "none"; ev = ev "shorted " d "; "; if (fri(d) < cp) cp = fri(d)
    }
  }
  # The 8-week re-confirm flag for the next checkpoint.
  st["due"] = (st["ord"] != "none" && fri(plus(st["placed"], 56)) <= cp) ? 1 : 0
  if (cp >= stopd || last == nd) {
    if (st["pos"] != "none") trade("open_at_end", dd[last ? last : nd], dcl[last ? last : nd], 0)
    st["status"] = "done"; st["ord"] = "none"; cp = (last ? dd[last] : cut)
  }
  st["cut"] = cp; st["msg"] = st["msg"] ev
  printf "LOG,%s,%s,%s,%s,%s,%s\n", cut, dc["action"], dc["trigger"], dc["stop"], cp, ev
  n = split("sym cut pos edate epx stop ord trig lim ostop placed due xpend status msg", K, " ")
  for (j = 1; j <= n; j++) print K[j] "=" st[K[j]]
}
