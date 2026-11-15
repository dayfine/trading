# cands.awk -- stream candidates.sexp (Backtest.Candidate_log, Sexp.save_hum) into flat TSV, top-N view included
# (#3625/#3626: rank, walk, shadow; per week tickets_placed, long_cash_left_pct, long_resting_reserved_pct). POSIX awk.
# Derived from ../../../price-band-binding-2026-11-13/read/lib/cands.awk, which stops at score: the top-N fields come
# after signals, so a row is emitted when the next row, the week's own fields or the next week begins.
#
# Input: the file's atoms one per line, from `tr '()' '\n\n' < candidates.sexp` (a 1 GB file never sits in memory).
# A record field arrives as "key value"; a field whose value is itself a list arrives as a bare "key" line followed by
# the payload's line. The shapes read here:
#   rank 23                                   walk -> result Funded | result Not_reached | result + "Skipped <reason>"
#   stop_distance_pct 0.08 (inside walk)      shadow No_structural_stop | shadow Already_held
#                                             shadow + "Buyable 0.08" | shadow + "Stop_too_wide 0.21"
# stdout: one row per Long candidate, columns
#   1 date  2 symbol  3 outcome  4 gate  5 score  6 rank  7 walk  8 walk_dist  9 shadow  10 shadow_dist  11 grade
#   (gate "-" unless Dropped_at_breakout; rank/walk/shadow "-" when absent; walk is Funded, Not_reached or
#   Skipped_<reason>; distances "-" when absent). Columns 1-5 are the price-band-binding shape, so its funnel.awk
#   reads this file unchanged.
# WEEKS: one row per screened date:
#   date  n_long_rows  tickets_placed  long_cash_left_pct  long_resting_reserved_pct   ("NA" when a field is absent)
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
{
  line = trim($0); if (line == "") next
  sp = index(line, " ")
  if (sp == 0) { k = line; v = "" } else { k = substr(line, 1, sp - 1); v = trim(substr(line, sp + 1)) }
  gsub(/"/, "", v)
  if (k == "date") { emit(); flush(); d = v; nl = 0; tp = "NA"; cl = "NA"; rr = "NA"; next }
  if (k == "symbol") { emit(); sym = v; side = ""; out = ""; gate = "-"; sc = ""; gr = "-"; rk = "-"; wk = "-"; wd = "-"; sh = "-"; sd = "-"; ctx = ""; next }
  if (k == "tickets_placed") { emit(); tp = v; next }
  if (k == "long_cash_left_pct") { emit(); cl = v; next }
  if (k == "long_resting_reserved_pct") { emit(); rr = v; next }
  if (sym == "") next
  if (k == "side") { side = v; next }
  if (k == "outcome") { out = v; next }
  if (k == "breakout_gate") { gate = v; next }
  if (k == "score" && sc == "") { sc = v; next }
  if (k == "grade" && gr == "-") { gr = v; next }
  if (k == "rank") { rk = v; next }
  if (k == "walk") { ctx = "walk"; next }
  if (k == "result" && ctx == "walk") { if (v != "") wk = v; next }
  if (k == "Skipped" && ctx == "walk") { wk = "Skipped_" v; next }
  if (k == "stop_distance_pct" && ctx == "walk") { wd = v; next }
  if (k == "shadow") { ctx = "shadow"; if (v != "") sh = v; next }
  if ((k == "Buyable" || k == "Stop_too_wide") && ctx == "shadow") { sh = k; sd = v; next }
}
function emit() {
  if (sym != "" && side == "Long") { print d "\t" sym "\t" out "\t" gate "\t" sc "\t" rk "\t" wk "\t" wd "\t" sh "\t" sd "\t" gr; nl++ }
  sym = ""
}
function flush() { if (d != "") print d "\t" nl "\t" tp "\t" cl "\t" rr > WEEKS }
END { emit(); flush() }
