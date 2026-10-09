# Flatten trade_audit.sexp: one row per audit record (entry decision).
# out: pid sym decision_date placement macro_at_decision filled fill_price age_wk installed_stop floor_kind suggested close_dec exit_date
function emit(){ if(pid!="") printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", pid,sym,dd,pl,mt,(fp!=""?"Y":"N"),fp,age,ist,fk,sug,cd,xd,cage,crs }
function reset(){ pid=""; sym=""; dd=""; pl=""; mt=""; fp=""; age=""; ist=""; fk=""; sug=""; cd=""; xd=""; cage=""; crs=""; inalt=0 }
/^ *\(+entry$/ { emit(); reset(); want=1; next }
want==1 && /\(symbol [^)]+\) \(entry_date [0-9-]+\)/ {
  match($0,/\(symbol [^)]+\)/); sym=substr($0,RSTART+8,RLENGTH-9);
  match($0,/\(entry_date [0-9-]+\)/); dd=substr($0,RSTART+12,RLENGTH-13);
  if (match($0,/\(position_id [^)]+\)/)) { pid=substr($0,RSTART+13,RLENGTH-14); want=0 } else want=2; next }
want==2 && /\(position_id [^)]+\)/ { match($0,/\(position_id [^)]+\)/); pid=substr($0,RSTART+13,RLENGTH-14); want=0 }
pid!="" && /\(alternatives_considered/ { inalt=1 }
pid!="" && /^ *\(exit_$/ { inalt=0 }
pid!="" && /^ *\(execution$/ { inalt=0 }
pid!="" && /^ *\(stop_decisions$/ { inalt=0 }
pid!="" && !inalt && mt=="" && /\(macro_trend [A-Za-z]+\)/ { match($0,/\(macro_trend [A-Za-z]+\)/); mt=substr($0,RSTART+13,RLENGTH-14) }
pid!="" && !inalt && pl=="" && /\(placement_date [0-9-]+\)/ { match($0,/\(placement_date [0-9-]+\)/); pl=substr($0,RSTART+16,RLENGTH-17) }
pid!="" && !inalt && age=="" && /\(ticket_age_weeks_at_fill [0-9]+\)/ { match($0,/\(ticket_age_weeks_at_fill [0-9]+\)/); age=substr($0,RSTART+26,RLENGTH-27) }
pid!="" && !inalt && ist=="" && /\(installed_stop [-0-9.e]+\)/ { match($0,/\(installed_stop [-0-9.e]+\)/); ist=substr($0,RSTART+16,RLENGTH-17) }
pid!="" && !inalt && fk=="" && /\(stop_floor_kind [A-Za-z_]+\)/ { match($0,/\(stop_floor_kind [A-Za-z_]+\)/); fk=substr($0,RSTART+17,RLENGTH-18) }
pid!="" && !inalt && sug=="" && /\(suggested_entry [-0-9.e]+\)/ { match($0,/\(suggested_entry [-0-9.e]+\)/); sug=substr($0,RSTART+17,RLENGTH-18) }
pid!="" && !inalt && cd=="" && /\(close_at_decision [-0-9.e]+\)/ { match($0,/\(close_at_decision [-0-9.e]+\)/); cd=substr($0,RSTART+19,RLENGTH-20) }
pid!="" && !inalt && fp=="" && /\(fill_price [-0-9.e]+\)/ { match($0,/\(fill_price [-0-9.e]+\)/); fp=substr($0,RSTART+12,RLENGTH-13) }
pid!="" && !inalt && xd=="" && /\(exit_date [0-9-]+\)/ { match($0,/\(exit_date [0-9-]+\)/); xd=substr($0,RSTART+11,RLENGTH-12) }
/^ \(cascade_summaries/ { emit(); reset(); exit }
pid!="" && !inalt && cage=="" && /\(ticket_age_weeks_at_cancel [0-9]+\)/ { match($0,/\(ticket_age_weeks_at_cancel [0-9]+\)/); cage=substr($0,RSTART+28,RLENGTH-29) }
pid!="" && !inalt && crs=="" && /\(cancel_reason [A-Za-z_]+\)/ { match($0,/\(cancel_reason [A-Za-z_]+\)/); crs=substr($0,RSTART+15,RLENGTH-16) }
