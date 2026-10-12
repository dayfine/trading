# From trade_audit.sexp cascade_summaries emit:
#   W date macro breadth long_macro_admitted long_top_n_admitted entered
#   D date symbol side outcome
/^ \(cascade_summaries/ {on=1}
!on {next}
match($0,/\(\(date [0-9-]+\) \(total_stocks/){ t=substr($0,RSTART,RLENGTH); split(t,a,/[() ]+/); wd=a[3]; mt=""; bs=""; lma=""; ltn=""; en="" }
on && match($0,/\(macro_trend [A-Za-z]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); mt=b[2] }
on && match($0,/\(breadth_state [A-Za-z_]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); bs=b[2] }
on && match($0,/\(long_macro_admitted [0-9]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); lma=b[2] }
on && match($0,/\(long_top_n_admitted [0-9]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); ltn=b[2] }
on && match($0,/\(entered [0-9]+\)/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/,"",t); split(t,b," "); en=b[2]; print "W", wd, mt, bs, lma, ltn, en }
on && match($0,/\(\(symbol [^)]+\) \(side [A-Za-z]+\) \(outcome [^)]*\)+/){ t=substr($0,RSTART,RLENGTH); gsub(/[()]/," ",t); n=split(t,c," "); o=""; for(i=6;i<=n;i++) o=o (o==""?"":"_") c[i]; print "D", wd, c[2], c[4], o }
