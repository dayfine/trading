#!/bin/sh
# Sector-year signal-vs-outcome dataset from px.csv (symbol,datekey,close,bardate), members.csv (year,symbol),
# data/sectors.csv, graded.csv (record trades). Signal = trailing-26wk return vs GSPC (rs_start at Y-1 Dec 31,
# rs_mid at Y Jun 30); outcome = calendar-year return (ret_y) and H2 return (ret_h2). Stale last-bars
# (bardate > 45 days before the key) are dropped so delisted names do not carry a frozen price.
W=${W:-/tmp/yr-run}; cd "${REPO:-$(git rev-parse --show-toplevel)}"
awk -F, '
  function dnum(d,  a){ split(d,a,"-"); return a[1]*372+a[2]*31+a[3] }
  FILENAME==ARGV[1] { sec[$1]=$2; next }
  FILENAME==ARGV[2] { mem[$1","$2]=1; next }
  FILENAME==ARGV[3] { if (FNR>1) { y=substr($2,1,4); traded[y","$1]=1; tpnl[y","$1]+=$8 }; next }
  FILENAME==ARGV[4] { if (dnum($2)-dnum($4) <= 45) px[$1","$2]=$3; next }
  END {
    for (y=2000; y<=2026; y++) {
      ym1=y-1; k0=ym1"-06-30"; k1=ym1"-12-31"; k2=y"-06-30"; k3=(y==2026? "2026-08-31" : y"-12-31")
      g0=px["GSPC.INDX,"k0]; g1=px["GSPC.INDX,"k1]; g2=px["GSPC.INDX,"k2]; g3=px["GSPC.INDX,"k3]
      for (key in mem) { split(key,a,","); if (a[1]!=y) continue; s=a[2]
        p0=px[s","k0]; p1=px[s","k1]; p2=px[s","k2]; p3=px[s","k3]
        if (p0==""||p1==""||p2==""||p3==""||p0==0||p1==0||p2==0) continue
        rs0=(p1/p0)/(g1/g0)-1; rsm=(p2/p1)/(g2/g1)-1; ry=p3/p1-1; rh2=p3/p2-1
        sc=sec[s]; if(sc=="") sc="(untagged)"
        printf "%d,%s,%s,%.4f,%.4f,%.4f,%.4f,%d,%.0f\n", y, s, sc, rs0, rsm, ry, rh2, (traded[y","s]?1:0), tpnl[y","s]+0
      }
    }
  }' data/sectors.csv $W/members.csv $W/graded.csv $W/px.csv > $W/sy.csv
wc -l $W/sy.csv
