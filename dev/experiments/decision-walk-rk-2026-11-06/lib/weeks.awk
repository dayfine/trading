# Input: the flattened cascade_summaries text split one screen per line (each line starts "YYYY-MM-DD) ...").
# Writes weeks.tsv (stdout): date macro breadth candidates_after_held long_breakout long_grade long_top_n entered
#   n_placed n_nss n_cash n_sized0 n_other
# and decisions.tsv (to file DEC): date symbol outcome floor_distance_pct
function f(k,   r) { if (match($0, "\\(" k " [^()]*\\)")) return substr($0, RSTART + length(k) + 2, RLENGTH - length(k) - 3); return "" }
{
  d = $1; sub(/\)$/, "", d)
  np = 0; nn = 0; nc = 0; nz = 0; no = 0
  i = index($0, "(decisions")
  if (i > 0) {
    n = split(substr($0, i), P, /\(\(symbol /)
    for (k = 2; k <= n; k++) {
      p = P[k]; sym = p; sub(/\).*/, "", sym)
      oc = ""; if (match(p, /\(outcome \(Skipped [A-Za-z_]+\)/)) { oc = substr(p, RSTART + 18, RLENGTH - 19) } else if (match(p, /\(outcome [A-Za-z_]+\)/)) { oc = substr(p, RSTART + 9, RLENGTH - 10) }
      dist = ""; if (match(p, /\(distance_pct [^()]*\)/)) dist = substr(p, RSTART + 14, RLENGTH - 15)
      side = ""; if (match(p, /\(side [A-Za-z]+\)/)) side = substr(p, RSTART + 6, RLENGTH - 7)
      if (side != "Long") continue
      if (oc == "Placed") np++; else if (oc == "No_structural_stop") nn++; else if (oc == "Insufficient_cash") nc++; else if (oc == "Sized_to_zero") nz++; else no++
      print d "\t" sym "\t" oc "\t" dist > DEC
    }
  }
  print d "\t" f("macro_trend") "\t" f("breadth_state") "\t" f("candidates_after_held") "\t" f("long_breakout_admitted") "\t" f("long_grade_admitted") "\t" f("long_top_n_admitted") "\t" f("entered") "\t" np "\t" nn "\t" nc "\t" nz "\t" no
}
