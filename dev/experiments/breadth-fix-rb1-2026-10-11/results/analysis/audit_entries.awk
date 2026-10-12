# Emit one line per audit entry record:
# position_id symbol decision_date macro_trend macro_conf ad_line momentum placement_date age_weeks_at_fill
function flush(){ if(inrec) print pid, sym, dd, mt, mc, ad, mo, pl, age, cr; inrec=0 }
/^ \(cascade_summaries/ {flush(); exit}
match($0, /\(\(symbol [^)]+\) \(entry_date [0-9-]+\)/) {
  flush(); s=substr($0,RSTART,RLENGTH); split(s,a,/[() ]+/);
  sym=a[3]; dd=a[5]; inrec=1; pid="?"; mt="?"; mc="?"; ad="?"; mo="?"; pl="?"; age="?"; cr="filled"; want="" }
inrec && pid=="?" && match($0,/\(position_id [^)]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); pid=b[2] }
inrec && mt=="?" && match($0,/\(macro_trend [A-Za-z]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); mt=b[2] }
inrec && mc=="?" && match($0,/\(macro_confidence [0-9.eE+-]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); mc=b[2] }
inrec && /\(name "A-D Line"\)/ {want="ad"}
inrec && /\(name "Momentum Index"\)/ {want="mo"}
inrec && want!="" && match($0,/\(signal [A-Za-z]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); if(want=="ad"&&ad=="?") ad=b[2]; if(want=="mo"&&mo=="?") mo=b[2]; want="" }
inrec && pl=="?" && match($0,/\(placement_date [0-9-]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); pl=b[2] }
inrec && age=="?" && match($0,/\(ticket_age_weeks_at_fill [0-9]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); age=b[2] }
END{flush()}
inrec && age=="?" && match($0,/\(ticket_age_weeks_at_cancel [0-9]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); age="c"b[2] }
inrec && match($0,/\(cancel_reason [a-z_]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); cr=b[2] }
