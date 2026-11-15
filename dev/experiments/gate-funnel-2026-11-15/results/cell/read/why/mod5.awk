NR==1{next}
{ s=$5+0; g=(s%5==0)?"mult5":"off5"; if (H!="" ) { y=substr($1,1,4)+0; g=g ((y<=2012)?" 2000-12":" 2013-26") }
  k=g SUBSEP $2; t=days($1); if ((k in last) && t-last[k]<182) next; last[k]=t
  if ($14!="F" && $14!="D") next
  r=$13+0; if (r>1.9) r=1.9; n[g]++; S[g]+=r; M[g]+=$12; b=int((r+1)*1000+0.5); Hh[g,b]++ }
END { for (g in n) { c=0; p90=""; for (b=0;b<=2900;b++){ c+=Hh[g,b]; if (p90=="" && c>=0.9*n[g]) p90=b/1000-1 }
  printf "%-16s n %6d monster %5.2f%% mean %+6.2f%% p90 %+.3f\n", g, n[g], 100*M[g]/n[g], 100*S[g]/n[g], p90 } }
