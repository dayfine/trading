# FILE1 = macro_trend.sexp ; FILE2 = trades.csv. Prints entries filled in a Bearish-screen week.
FNR==NR { if (match($0,/date [0-9-]+/)) { d=substr($0,RSTART+5,10); match($0,/trend [A-Za-z]+/); t=substr($0,RSTART+6,RLENGTH-6); n++; D[n]=d; T[n]=t }; next }
FNR==1 { next }
{ split($0,f,","); e=f[3]; tr=""; for(i=1;i<=n;i++){ if (D[i]<=e) tr=T[i]; else break }
  if (tr=="Bearish") { c++; print "  BEAR " f[1] " " e " pnl=" f[9] } }
END { print "  bearish_fills=" c+0 }
