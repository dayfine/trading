# C* net (or gross) rows, deduped per symbol per 182 days (classes.awk convention), FD coverage, ride capped 1.90.
# Joins the Friday context from fj.tsv. Groups by G (year|ctx). Prints n, mean ride, monster rate, win rate, sum ride.
FILENAME==ARGV[1] { YR[$1]=$2; TR[$1]=$3; RG[$1]=$5; AGE[$1]=$6; HELD[$1]=$7; FREE[$1]=$24; next }
FNR==1 { next }
{ if ((COL==5 && $5!=1) || (COL==4 && $4!=1)) next
  d=$1; s=$2; t=days(d); if ((s in last) && t-last[s] < 182) next; last[s]=t
  if ($8!="F" && $8!="D") { nx++; next }
  r=$7+0; if (r>1.90) r=1.90; m=$6+0
  y=YR[d]; h=HELD[d]
  if (G=="year") k=y
  else if (G=="period") k=(y=="2000"||y=="2001"||y=="2002"||y=="2008") ? "a:bear 00-02,08" : (y=="2003"||y=="2009") ? "b:recovery 03,09" : (y=="2016"||y=="2022"||y=="2023") ? "c:16,22,23" : "d:other"
  else if (G=="regime") k=RG[d]
  else if (G=="trend") k=TR[d]
  else if (G=="held") k=(h==0)?"0":(h<=2)?"1-2":(h<=5)?"3-5":"6+"
  else if (G=="rank") k=($3<=40)?"a:21-40":($3<=100)?"b:41-100":"c:101+"
  else k="all"
  n[k]++; sr[k]+=r; mo[k]+=m; w[k]+=(r>0); N++; SR+=r
}
END { printf "%-18s %5s %8s %8s %7s %9s\n", G, "n", "mean%", "monst%", "win%", "share_of_sum"
  for (k in n) printf "%-18s %5d %+8.2f %8.1f %7.1f %9.3f\n", k, n[k], 100*sr[k]/n[k], 100*mo[k]/n[k], 100*w[k]/n[k], sr[k]/SR
  printf "%-18s %5d %+8.2f\n", "TOTAL", N, 100*SR/N }
