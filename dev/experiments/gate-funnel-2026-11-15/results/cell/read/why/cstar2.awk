FILENAME==ARGV[1] { YR[$1]=$2; TR[$1]=$3; RG[$1]=$5; next }
FNR==1 { next }
{ if ($5!=1) next; d=$1; s=$2; t=days(d); if ((s in last) && t-last[s] < 182) next; last[s]=t
  if ($8!="F" && $8!="D") next
  r=$7+0; if (r>1.90) r=1.90; y=YR[d]
  k=RG[d] ((y=="2003")?" (2003)":(y=="2009")?" (2009)":" (other years)")
  n[k]++; sr[k]+=r; mo[k]+=$6+0 }
END { for (k in n) printf "%-24s n %4d mean %+6.2f%% monster %5.1f%%\n", k, n[k], 100*sr[k]/n[k], 100*mo[k]/n[k] }
