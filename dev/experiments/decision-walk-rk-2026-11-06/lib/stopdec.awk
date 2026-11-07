# records.txt (one audit record per line) -> stopdec.tsv, one row per recorded stop decision:
#  1 pid  2 sym  3 date  4 state_before  5 state_after  6 stop_before  7 stop_after  8 candidate
#  9 cc_before  10 cc  11 trend_extreme  12 correction_extreme  13 ma  14 reason
function v(p, k) { if (match(p, "\\(" k " [^()]*\\)")) return substr(p, RSTART + length(k) + 2, RLENGTH - length(k) - 3); return "" }
function w(p, k) { if (match(p, "\\(" k " \\([^()]*\\)\\)")) return substr(p, RSTART + length(k) + 3, RLENGTH - length(k) - 5); return "" }
{
  if (!match($0, /\(position_id [^()]*\)/)) next
  pid = substr($0, RSTART + 13, RLENGTH - 14); sym = pid; sub(/-wein-.*/, "", sym)
  i = index($0, "(stop_decisions"); if (i == 0) next
  n = split(substr($0, i), P, /\(\(date /)
  for (k = 2; k <= n; k++) {
    p = "(date " P[k]
    print pid "\t" sym "\t" v(p, "date") "\t" v(p, "state_before") "\t" v(p, "state_after") "\t" v(p, "stop_before") "\t" v(p, "stop_after") "\t" \
      w(p, "candidate") "\t" v(p, "correction_count_before") "\t" v(p, "correction_count") "\t" w(p, "last_trend_extreme") "\t" \
      w(p, "last_correction_extreme") "\t" v(p, "ma_value") "\t" v(p, "reason")
  }
}
