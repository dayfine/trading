#!/bin/sh
# breadth_rule.sh T_ABOVE T_NL [trades.csv ...] — state at entry = crash if pct_above<T_ABOVE or nl_pct>T_NL;
# prints per-trades-file: entries/P&L/A-grade by state, and per-year first-crash date vs macro gate's first non-Bullish date.
W=/tmp/yr-run; TA=$1; TN=$2; shift 2
for f in "$@"; do awk -F, -v TA=$TA -v TN=$TN -v name="$(basename $f | cut -c1-16)" '
  FILENAME==ARGV[1] { sd[++ns]=$1; st[ns]=($2<TA || $3>TN)?"crash":($2<50)?"weak":"ok"; next }
  FILENAME==ARGV[2] { md[++nm]=$1; mt[nm]=$2; next }
  FNR>1 { e=$3; s="?"; for(i=ns;i>=1;i--){ if(sd[i]<=e){ s=st[i]; break } }; m="?"; for(i=nm;i>=1;i--){ if(md[i]<=e){ m=mt[i]; break } }
    c[s]++; p[s]+=$9; if($9<0) l[s]+=$9; if($10>=20) a[s]++
    k=s"|"m; ck[k]++; pk[k]+=$9 }
  END { printf "%-16s", name; for(s in c) printf " | %-5s n=%3d pnl %+9.0f loss %+9.0f A=%2d", s, c[s], p[s], l[s], a[s]; print ""
        printf "%-16s  crash x macro:", name; for(k in ck) printf " %s n=%d %+.0f;", k, ck[k], pk[k]; print "" }' $W/state_daily.csv $W/macro.txt FS=, "$f"; done
