# SPY regime per day (review-pack rule, #3255 with warm-up): weekly close vs its 30-week MA and the MA's
# 4-week slope; a week's regime is known at its last close and applies to the FOLLOWING week's days.
# Input: date,adj_close ascending (start >= 34 weeks before the window). Output: date,adj_close,regime.
function wkidx(d,  Y,M,D,a,yy,mm,jdn){ Y=substr(d,1,4)+0; M=substr(d,6,2)+0; D=substr(d,9,2)+0; a=int((14-M)/12); yy=Y+4800-a; mm=M+12*a-3; jdn=D+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045; return int((jdn-2447893)/7) }
function ma(n,  s,i){ s=0; for(i=n-29;i<=n;i++) s+=cl[i]; return s/30 }
BEGIN{FS=","; cur=""}
{ d=$1; v=$2+0; k=wkidx(d)
  if(k!=wk && last!=""){ n++; cl[n]=last; if(n>=34){ m=ma(n); m4=ma(n-4); c=cl[n]; cur=(c>m && m>m4)?"UP":((c<m && m<m4)?"DOWN":"MIXED") } }
  wk=k; last=v; print d","v","cur }
