# Dry-run stand-in for the fresh agent (NOT a strategy; it only exercises the loop). Reads the state and the
# symbol's weekly CSV up to the cut, writes one decision (key=value, chart scale) to stdout:
#   flat, no order (or an order due for re-issue): buy_stop 0.1 % above the 52-week weekly high, stop at the 30w MA
#     (skipped when the MA is not below the trigger);
#   long: raise the stop to the 30w MA when the MA is above it; else none.
# Usage: awk -F, -f dummy_agent.awk <state> <weekly.csv>
BEGIN { CONVFMT = "%.10g"; FS = "," }
FNR == 1 { fi++ }
fi == 1 { p = index($0, "="); if (p) st[substr($0, 1, p - 1)] = substr($0, p + 1); next }
fi == 2 && FNR > 1 && $1 <= st["cut"] { n++; hi[n] = $3 + 0; ma = $7; if ($5 + 0 > 0) k = $9 / $5 }
END {
  if (n == 0 || ma == "") { print "action=none"; exit }
  ma += 0; h = 0; for (i = (n > 52 ? n - 51 : 1); i <= n; i++) if (hi[i] > h) h = hi[i]
  if (st["pos"] == "long") {
    if (ma > st["stop"] + 0) printf "action=set_stop\nstop=%.4f\nreason=dummy: stop to the MA\n", ma * k
    else print "action=none"
    exit
  }
  if (st["pos"] == "none" && (st["ord"] == "none" || st["due"] == 1) && ma < h * 1.001)
    printf "action=buy_stop\ntrigger=%.4f\nstop=%.4f\nreason=dummy: 52-week high\n", h * 1.001 * k, ma * k
  else print "action=none"
}
