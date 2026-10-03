# one line per skipped alternative: symbol parent_entry_date reason
/^ *\(\(symbol [^)]+\) \(entry_date [0-9-]+\)/ { match($0, /\(entry_date [0-9-]+\)/); d=substr($0, RSTART+12, RLENGTH-13); inalt=0 }
/alternatives_considered/ { inalt=1 }
inalt && /\(\(symbol [^)]+\) \(side/ { match($0, /\(symbol [^)]+\)/); s=substr($0, RSTART+8, RLENGTH-9) }
inalt && /reason_skipped/ { match($0, /reason_skipped [A-Za-z_]+/); r=substr($0, RSTART+15, RLENGTH-15); print s, d, r }
