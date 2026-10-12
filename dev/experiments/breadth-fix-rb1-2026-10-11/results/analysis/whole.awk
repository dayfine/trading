# Whole-window TR, log return and CAGR per column of navspy.csv (date,Os0,Os1,Os2,Ns0,Ns1,Ns2,SPY).
# Strategy base = the $1M initial cash (2000-01-01); SPY base = the first row's close (2000-01-03, pack convention).
function jd(d,  Y,M,D,a,yy,mm){ Y=substr(d,1,4)+0; M=substr(d,6,2)+0; D=substr(d,9,2)+0; a=int((14-M)/12); yy=Y+4800-a; mm=M+12*a-3; return D+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045 }
BEGIN{FS=","; split("O-s0 O-s1 O-s2 N-s0 N-s1 N-s2 SPY",nm," ")}
NR==1{spy0=$8} {last=$0; d=$1}
END{ n=split(last,v,","); yrs=(jd(d)-jd("2000-01-01"))/365.25; for(i=2;i<=7;i++) b[i]=1000000; b[8]=spy0;
  for(i=2;i<=8;i++){ m=v[i]/b[i]; printf "%-5s TR %8.2f%%  log %.4f  CAGR %.3f%%\n", nm[i-1], (m-1)*100, log(m), (exp(log(m)/yrs)-1)*100 }
  printf "years %.4f (2000-01-01 -> %s)\n", yrs, d }
