# count No_structural_stop skips (nested alternatives) by the parent record's entry_date month
/\(entry_date [0-9-]+\)/ { match($0, /\(entry_date [0-9-]+\)/); d=substr($0, RSTART+12, 7) }
/reason_skipped No_structural_stop/ { n[d]++ }
/reason_skipped Insufficient_cash/ { c[d]++ }
END { for (k in n) if (k ~ pat) printf "%s nostruct=%d cash=%d\n", k, n[k], c[k]+0 }
