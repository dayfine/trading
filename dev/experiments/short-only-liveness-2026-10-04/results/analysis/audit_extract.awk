# Extract one row per audit record from a trade_audit.sexp (pretty-printed).
# Output TSV: position_id symbol decision_date macro_trend suggested_entry close_at_decision
#             installed_stop stop_floor_kind placement_date ticket_age_weeks fill_price designed_trigger
#             exit_kind exit_label exit_date
function grab(line, key,    re, m) {
  re = "\\(" key " [^()]*\\)"
  if (match(line, re)) {
    m = substr(line, RSTART + length(key) + 2, RLENGTH - length(key) - 3)
    return m
  }
  return ""
}
function flush() {
  if (pid != "")
    print pid "\t" sym "\t" ddate "\t" mt "\t" sugg "\t" cad "\t" inst "\t" sfk "\t" plc "\t" age "\t" fillp "\t" dtrig "\t" exk "\t" exl "\t" exd
  pid = ""; sym = ""; ddate = ""; mt = ""; sugg = ""; cad = ""; inst = ""; sfk = ""; plc = "";
  age = ""; fillp = ""; dtrig = ""; exk = ""; exl = ""; exd = ""; in_alt = 0; in_exit = 0
}
BEGIN { OFS = "\t"; pid = "" }
/\(cascade_summaries/ { flush(); exit }
/\(\(entry *$/ { flush(); in_entry = 1; in_alt = 0; in_exit = 0; next }
{
  line = $0
  if (line ~ /\(alternatives_considered/) in_alt = 1
  if (line ~ /\(exit_ *$/ || line ~ /\(exit_ \(\(\(/ || line ~ /\(external_exit/) { in_alt = 0; in_exit = 1 }
  if (line ~ /\(execution/) { in_alt = 0; in_exit = 2 }
  if (!in_alt && in_exit == 0) {
    if (sym == "" && (v = grab(line, "symbol")) != "") sym = v
    if (ddate == "" && (v = grab(line, "entry_date")) != "") ddate = v
    if (pid == "" && (v = grab(line, "position_id")) != "") pid = v
    if (mt == "" && (v = grab(line, "macro_trend")) != "") mt = v
    if (sugg == "" && (v = grab(line, "suggested_entry")) != "") sugg = v
    if (cad == "" && (v = grab(line, "close_at_decision")) != "") cad = v
    if (inst == "" && (v = grab(line, "installed_stop")) != "") inst = v
    if (sfk == "" && (v = grab(line, "stop_floor_kind")) != "") sfk = v
    if (plc == "" && (v = grab(line, "placement_date")) != "") plc = v
    if (age == "" && (v = grab(line, "ticket_age_weeks_at_fill")) != "") age = v
  }
  if (in_exit == 1) {
    if (exd == "" && (v = grab(line, "exit_date")) != "") exd = v
    if (exk == "" && line ~ /Stop_loss/) exk = "Stop_loss"
    if (exk == "" && line ~ /Strategy_signal/) exk = "Strategy_signal"
    if (exk == "" && match(line, /\(exit_trigger \(([A-Za-z_]+)/)) { exk = substr(line, RSTART + 15, RLENGTH - 15) }
    if (exl == "" && (v = grab(line, "label")) != "") exl = v
  }
  if (in_exit == 2) {
    if (fillp == "" && (v = grab(line, "fill_price")) != "") fillp = v
    if (dtrig == "" && (v = grab(line, "designed_trigger")) != "") dtrig = v
  }
  if (line ~ /\(stop_decisions/) in_exit = 3
}
END { flush() }
