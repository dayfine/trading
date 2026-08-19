#!/bin/sh
# Extract one row per entry decision from a trade_audit.sexp.
#
# Emits TSV: position_id symbol placement_date entry_date E suggested_stop
#            local_range_top stop_floor_kind age_weeks_at_fill
#
# ONE RECORD = one `((entry` line. Every field is taken as the FIRST occurrence
# after that line, which is what makes the `alternatives_considered` block
# (which repeats `(symbol ...)` per rejected candidate) harmless: the entry's
# own symbol is already captured by then. Optional sexp fields render as
# `(field (value))` and are emitted as `-` when absent.
#
# Validation the caller MUST run (feedback_always_dissect_before_reporting):
#   rows emitted == `grep -c '(placement_date' <file>`
#   and spot-check 3 rows against the sexp by hand.
set -e
[ -n "$1" ] || { echo "usage: extract_tickets.sh <trade_audit.sexp>" >&2; exit 1; }

awk '
function grab(line, key,   re, s) {
  re = "\\(" key " [^()]*\\)"
  if (match(line, re)) { s = substr(line, RSTART, RLENGTH); sub("^\\(" key " ", "", s); sub("\\)$", "", s); return s }
  return ""
}
function grab_opt(line, key,   re, s) {
  re = "\\(" key " \\([^()]*\\)\\)"
  if (match(line, re)) { s = substr(line, RSTART, RLENGTH); sub("^\\(" key " \\(", "", s); sub("\\)\\)$", "", s); return s }
  return ""
}
function flush() {
  if (pid != "") printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", pid, sym, place, edate, e, stop, lrt, kind, age
}
/\(\(entry$/ { flush(); pid=""; sym=""; place=""; edate=""; e=""; stop=""; lrt="-"; kind="-"; age="-"; next }
{
  if (sym   == "") { v=grab($0,"symbol");           if (v!="") sym=v }
  if (edate == "") { v=grab($0,"entry_date");       if (v!="") edate=v }
  if (pid   == "") { v=grab($0,"position_id");      if (v!="") pid=v }
  if (e     == "") { v=grab($0,"suggested_entry");  if (v!="") e=v }
  if (stop  == "") { v=grab($0,"suggested_stop");   if (v!="") stop=v }
  if (kind  == "-"){ v=grab($0,"stop_floor_kind");  if (v!="") kind=v }
  if (place == "") { v=grab($0,"placement_date");   if (v!="") place=v }
  # [@sexp.option] renders Some v as `(field v)` and omits the field entirely
  # when None -- NOT as `(field (v))`, which is how a plain `t option` (e.g.
  # rs_value) renders. Using the wrong reader here silently produced `-` for
  # every row on the first pass.
  if (lrt   == "-"){ v=grab($0,"local_range_top"); if (v!="") lrt=v }
  if (age   == "-"){ v=grab($0,"ticket_age_weeks_at_fill"); if (v!="") age=v }
}
END { flush() }
' "$1"
