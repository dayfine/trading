# usage: awk -f episodes.awk reopen.txt trades.csv equity_curve.csv spy.csv
function jd(d,  y,m,dd,a,yy,mm){ y=substr(d,1,4)+0; m=substr(d,6,2)+0; dd=substr(d,9,2)+0; a=int((14-m)/12); yy=y+4800-a; mm=m+12*a-3; return dd+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045 }
FNR==1 { fi++ }
fi==1 { R[++n]=$1 }
fi==2 && FNR>1 { split($0,a,","); dd=jd(a[3]); for(i=1;i<=n;i++){ x=dd-jd(R[i]); if(x>=0&&x<91) e13[i]++; if(x>=0&&x<182){ e26[i]++; p26[i]+=a[9] } } }
fi==3 && FNR>1 { split($0,a,","); nn++; navd[nn]=jd(a[1]); nav[nn]=a[2] }
fi==4 && FNR>1 { split($0,a,","); ns++; spyd[ns]=jd(a[1]); spy[ns]=a[6] }
function at(arr,dates,cnt,j,  i,best){ best=0; for(i=1;i<=cnt;i++){ if(dates[i]<=j) best=i; else break } return (best==0?"":arr[best]) }
END{
  printf "%-10s %5s %5s %9s %8s %8s\n","reopen","e13","e26","pnl26k","strat26","spy26"
  for(i=1;i<=n;i++){
    j=jd(R[i]); n0=at(nav,navd,nn,j); n1=at(nav,navd,nn,j+182); s0=at(spy,spyd,ns,j); s1=at(spy,spyd,ns,j+182)
    if(n0==""||n1==""||s0==""||s1=="") continue
    printf "%-10s %5d %5d %9.0f %7.1f%% %7.1f%%\n", R[i], e13[i], e26[i], p26[i]/1000, (n1/n0-1)*100, (s1/s0-1)*100
  }
}
