# One line per screening Friday from a trade_audit.sexp's cascade_summaries:
#   DATE TOTAL_STOCKS CANDIDATES_AFTER_HELD LONG_TOP_N ENTERED MACRO SYM:OUTCOME,SYM:OUTCOME,...
# OUTCOME is Placed or the skip reason (No_structural_stop, Insufficient_cash, Sized_to_zero, ...). The list is the entry
# walk's recorded decisions in rank order; top-N names dropped silently after the cap (declining-MA, liquidity, recency,
# delisted gates in Entry_assembly.assemble) are not in it, so LONG_TOP_N can exceed the list length.
# Usage: awk -f cascade-decisions.awk <arm>-trade_audit.sexp > <arm>-decisions.txt
function flush() { if (d != "") print d, ts, cah, topn, ent, mt, dec; d = ""; ts = ""; cah = ""; topn = ""; ent = ""; mt = ""; dec = ""; nd = 0; dsym = "" }
/\(cascade_summaries/ { on = 1 }
!on { next }
/\(\(date [0-9-]+\) \(total_stocks/ {
  flush()
  match($0, /\(date [0-9-]+\)/); d = substr($0, RSTART + 6, RLENGTH - 7)
  match($0, /\(total_stocks [0-9]+\)/); ts = substr($0, RSTART + 14, RLENGTH - 15)
  match($0, /\(candidates_after_held [0-9]+\)/); cah = substr($0, RSTART + 23, RLENGTH - 24)
}
/\(macro_trend [A-Za-z]+\)/ && mt == "" { match($0, /\(macro_trend [A-Za-z]+\)/); mt = substr($0, RSTART + 13, RLENGTH - 14) }
/\(long_top_n_admitted [0-9]+\)/ { match($0, /\(long_top_n_admitted [0-9]+\)/); topn = substr($0, RSTART + 21, RLENGTH - 22) }
/\(entered [0-9]+\)/ { match($0, /\(entered [0-9]+\)/); ent = substr($0, RSTART + 9, RLENGTH - 10) }
/\(\(symbol [^)]*\) \(side [A-Za-z]+\)/ { match($0, /\(symbol [^)]*\)/); dsym = substr($0, RSTART + 8, RLENGTH - 9) }
/\(outcome / && dsym != "" {
  o = $0; sub(/.*\(outcome /, "", o); gsub(/[()]/, "", o); gsub(/ /, "_", o); sub(/_+$/, "", o); sub(/^Skipped_/, "", o)
  dec = dec (nd ? "," : "") dsym ":" o; nd++; dsym = ""
}
END { flush() }
