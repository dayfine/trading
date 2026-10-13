# Append the ev2.awk diagnostics to the committed event table on (sym, date). Files: ev2.csv then ev.csv.
NR == FNR { k[$1 "," $2] = $0; next }
FNR == 1 { print $0 ",bclose,lvl,ma,below_sup,dd52,room26,room52,nbars_after,s05,s10,s15,s20,s30,s50,s100,sh26,sh52"; next }
{ key = $1 "," $2; if (!(key in k)) { miss++; next } n = split(k[key], a, ","); x = ""; for (i = 3; i <= n; i++) x = x "," a[i]; print $0 x }
END { if (miss) print "join: " miss " events missing from ev2" > "/dev/stderr" }
