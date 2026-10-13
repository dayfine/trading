# Short-candidate pool from a trade_audit.sexp: every ranked short candidate (the filled entry's alternatives_considered
# rows), keyed to its decision's placement_date. Out: symbol,placement_date,score (deduped on symbol+date by the caller).
/placement_date [0-9]/ { match($0, /placement_date [0-9-]+/); pd = substr($0, RSTART + 15, 10) }
/\(symbol [^)]*\) \(side Short\) \(score [0-9]+\)/ {
  match($0, /\(symbol [^)]*\)/); s = substr($0, RSTART + 8, RLENGTH - 9)
  match($0, /score [0-9]+/); sc = substr($0, RSTART + 6, RLENGTH - 6)
  if (pd != "") print s "," pd "," sc }
