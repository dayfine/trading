# From a trade_audit.sexp: one line per entered record: symbol entry_date suggested_entry
# Top-level record header is "((symbol X) (entry_date D) (position_id ...)". Nested alternatives use "(((symbol X) (side".
/^ *\(\(symbol [^)]+\) \(entry_date [0-9-]+\)/ {
  match($0, /\(symbol [^)]+\)/); s=substr($0, RSTART+8, RLENGTH-9)
  match($0, /\(entry_date [0-9-]+\)/); d=substr($0, RSTART+12, RLENGTH-13)
  want=1; next }
/alternatives_considered/ { want=0 }
want && /\(suggested_entry [0-9.]+\)/ { match($0, /\(suggested_entry [0-9.]+\)/); v=substr($0, RSTART+17, RLENGTH-18); print s, d, v; want=0 }
