# summ.awk -- two extracts from trade_audit.sexp (Backtest.Trade_audit) that ../../../price-band-binding-2026-11-13/
# read/lib/audit.awk (reused unchanged for the walk record) does not take: the per-Friday cascade counts and each placed
# ticket's cost. Input: atoms one per line (`tr '()' '\n\n'`). POSIX awk.
#
# stdout (CS): one row per cascade_summary, in file order:
#   date  candidates_after_held  long_macro_admitted  long_breakout_admitted  long_sector_admitted
#   long_grade_admitted  long_top_n_admitted  entered  macro_trend
# TICKETS (file): one row per audit record's entry decision (every placed ticket, filled or not):
#   symbol  entry_date  side  initial_position_value
#   initial_position_value is simulator dollars and stays in WORK; the read divides it by the decision-date portfolio
#   value and publishes only the fraction's distribution (README §Definitions, m).
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
{
  line = trim($0); if (line == "") next
  sp = index(line, " "); k = (sp == 0) ? line : substr(line, 1, sp - 1); v = (sp == 0) ? "" : trim(substr(line, sp + 1))
  if (k == "cascade_summaries") { flush_entry(); in_cs = 1; next }
  if (!in_cs) {
    if (k == "entry") { flush_entry(); in_e = 1; es = ""; ed = ""; eside = ""; iv = ""; next }
    if (!in_e) next
    if (k == "symbol" && es == "") es = v
    else if (k == "entry_date" && ed == "") ed = v
    else if (k == "side" && eside == "") eside = v
    else if (k == "initial_position_value" && iv == "") iv = v
    else if (k == "alternatives_considered") flush_entry()
    next
  }
  if (k == "date") { flush_cs(); d = v; delete F; next }
  if (k == "candidates_after_held" || k == "long_macro_admitted" || k == "long_breakout_admitted" || \
      k == "long_sector_admitted" || k == "long_grade_admitted" || k == "long_top_n_admitted" || k == "entered" || \
      k == "macro_trend") if (!(k in F)) F[k] = v
}
function flush_entry() {
  if (in_e && es != "" && iv != "") print es "\t" ed "\t" eside "\t" iv > TICKETS
  in_e = 0
}
function flush_cs() {
  if (d == "") return
  print d "\t" F["candidates_after_held"] "\t" F["long_macro_admitted"] "\t" F["long_breakout_admitted"] "\t" \
    F["long_sector_admitted"] "\t" F["long_grade_admitted"] "\t" F["long_top_n_admitted"] "\t" F["entered"] "\t" F["macro_trend"]
}
END { flush_entry(); flush_cs() }
