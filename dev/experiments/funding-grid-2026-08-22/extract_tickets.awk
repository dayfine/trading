function ext(re,   s) { if (match($0, re)) { s = substr($0, RSTART, RLENGTH); sub(/^[^ ]+ /, "", s); sub(/\)$/, "", s); return s } return "" }
/\(symbol [A-Za-z0-9_.]+\) \(entry_date [0-9-]+\) \(position_id / {
  if (sym != "") print sym "\t" ed "\t" pid "\t" pd "\t" (canc ? "cancelled" : "filled")
  sym = ext("\\(symbol [A-Za-z0-9_.]+\\)")
  ed  = ext("\\(entry_date [0-9-]+\\)")
  pid = ext("\\(position_id [^)]+\\)")
  pd = ""; canc = 0; next
}
/\(placement_date [0-9-]+\)/ { pd = ext("\\(placement_date [0-9-]+\\)") }
/cancel_reason entry_fill_rejected_by_portfolio/ { canc = 1 }
END { if (sym != "") print sym "\t" ed "\t" pid "\t" pd "\t" (canc ? "cancelled" : "filled") }
