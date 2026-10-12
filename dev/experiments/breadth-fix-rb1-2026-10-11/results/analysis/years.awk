# Year table from navspy.csv: strategy vs SPY TR per calendar year, and N-O in pp. Bases as in whole.awk.
BEGIN{FS=","}
NR==1{ for(i=2;i<=7;i++) b[i]=1000000; b[8]=$8 }
{ y=substr($1,1,4); if(py!="" && y!=py) emit(py); for(i=2;i<=8;i++) last[i]=$i; py=y }
END{ emit(py) }
function emit(yy,  i, r){ for(i=2;i<=8;i++) r[i]=100*(last[i]/b[i]-1);
  printf "%s | O %+6.1f %+6.1f %+6.1f | N %+6.1f %+6.1f %+6.1f | SPY %+6.1f | N-O %+5.1f %+5.1f %+5.1f\n", yy, r[2],r[3],r[4],r[5],r[6],r[7],r[8], r[5]-r[2], r[6]-r[3], r[7]-r[4];
  for(i=2;i<=8;i++) b[i]=last[i] }
