# cands.awk -- stream candidates.sexp (Backtest.Candidate_log, written with Sexp.save_hum) into flat TSV. POSIX awk.
#
# Input: the file's atoms one per line, from `tr '()' '\n\n' < candidates.sexp` (so a 1 GB file never sits in memory).
# Each record field arrives as a line "key value". Candidate fields come in record order: symbol, side, outcome,
# breakout_gate (present only on Dropped_at_breakout rows, #2533), then signals, whose first field is score.
#
# stdout: one row per Long candidate:  date  symbol  outcome  gate  score     (gate "-" unless Dropped_at_breakout)
# WEEKS:  one row per screened date:   date  n_long_rows                       (0 = no Long rows: longs macro-blocked)
{
  sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "")
  sp = index($0, " "); if (sp == 0) next
  k = substr($0, 1, sp - 1); v = substr($0, sp + 1); gsub(/"/, "", v)
  if (k == "date") { flush(); d = v; nl = 0; next }
  if (k == "symbol") { sym = v; side = ""; out = ""; gate = "-"; next }
  if (k == "side") { side = v; next }
  if (k == "outcome") { out = v; next }
  if (k == "breakout_gate") { gate = v; next }
  if (k == "score" && sym != "") {
    if (side == "Long") { print d "\t" sym "\t" out "\t" gate "\t" v; nl++ }
    sym = ""
  }
}
function flush() { if (d != "") print d "\t" nl > WEEKS }
END { flush() }
