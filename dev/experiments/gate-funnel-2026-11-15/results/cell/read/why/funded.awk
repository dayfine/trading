FILENAME==ARGV[1] { YR[$1]=$2; TR[$1]=$3; RG[$1]=$5; HELD[$1]=$7; next }
FNR==1 { next }
($7==W_) { d=$1; s=$2; if (!(d in YR)) next; t=days(d); if ((s in last) && t-last[s] < 182) next; last[s]=t
  if ($14!="F" && $14!="D") next
  r=$13+0; if (r>1.90) r=1.90; m=$12+0; y=YR[d]
  if (G=="year") k=y
  else if (G=="period") k=(y=="2000"||y=="2001"||y=="2002"||y=="2008") ? "a:bear 00-02,08" : (y=="2003"||y=="2009") ? "b:recovery 03,09" : (y=="2016"||y=="2022"||y=="2023") ? "c:16,22,23" : "d:other"
  else if (G=="regime") k=RG[d]
  else if (G=="trend") k=TR[d]
  else k="all"
  n[k]++; sr[k]+=r; mo[k]+=m; w[k]+=(r>0); N++; SR+=r }
END { printf "%-18s %5s %8s %8s %7s\n", G, "n", "mean%", "monst%", "win%"; for (k in n) printf "%-18s %5d %+8.2f %8.1f %7.1f\n", k, n[k], 100*sr[k]/n[k], 100*mo[k]/n[k], 100*w[k]/n[k]; printf "TOTAL %d %+.2f\n", N, 100*SR/N }
