# audit.awk -- two extracts from trade_audit.sexp (Backtest.Trade_audit), streamed as atoms one per line
# (`tr '()' '\n\n'`). POSIX awk.
#
# WALK (stdout): the weekly decision record (#3139), every Long top-N name the entry walk classified, in walk order:
#   date  idx  symbol  outcome            (outcome = Placed or the skip reason)
#   Read from cascade_summaries only: each summary opens with its date, and its decisions field holds
#   ((symbol X) (side Long) (outcome Placed)) or (outcome (Skipped Reason)) rows.
# ENTRIES (file): one row per audit record's entry decision (filled positions):
#   symbol  entry_date  side  suggested_entry  close_at_decision      ("NA" when close_at_decision is absent)
{
  sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "")
  if ($0 == "") next
  sp = index($0, " "); k = (sp == 0) ? $0 : substr($0, 1, sp - 1); v = (sp == 0) ? "" : substr($0, sp + 1)
  if (k == "cascade_summaries") { flush_entry(); in_cs = 1; next }
  if (!in_cs) {
    if (k == "entry") { flush_entry(); in_e = 1; es = ""; ed = ""; eside = ""; se = ""; cd = "NA"; next }
    if (!in_e) next
    if (k == "symbol" && es == "") es = v
    else if (k == "entry_date" && ed == "") ed = v
    else if (k == "side" && eside == "") eside = v
    else if (k == "suggested_entry" && se == "") se = v
    else if (k == "close_at_decision" && cd == "NA") cd = v
    else if (k == "alternatives_considered") flush_entry()
    next
  }
  if (k == "date") { d = v; in_dec = 0; idx = 0; next }
  if (k == "decisions") { in_dec = 1; next }
  if (!in_dec) next
  if (k == "symbol") { sym = v; side = ""; next }
  if (k == "side") { side = v; next }
  if (k == "outcome" && side == "Long") {
    if (v != "") emit(v); else want = 1
    next
  }
  if (want && k == "Skipped") { emit(v); want = 0 }
}
function emit(o) { idx++; print d "\t" idx "\t" sym "\t" o }
function flush_entry() {
  if (in_e && es != "" && se != "") print es "\t" ed "\t" eside "\t" se "\t" cd > ENTRIES
  in_e = 0
}
END { flush_entry() }
