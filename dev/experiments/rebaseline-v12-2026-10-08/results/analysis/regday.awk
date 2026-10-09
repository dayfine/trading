function jdn(s,   y,m,d,a,yy,mm){ y=substr(s,1,4)+0; m=substr(s,6,2)+0; d=substr(s,9,2)+0;
  a=int((14-m)/12); yy=y+4800-a; mm=m+12*a-3;
  return d+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045 }
function wk(s){ return int((jdn(s)+1)/7) }
BEGIN{FS=","}
FILENAME==ARGV[1]{ w=wk($1); if(w!=cw && cw!=""){ nc++; cl[nc]=last; if(nc>=34){ s=0; for(i=nc-29;i<=nc;i++) s+=cl[i]; m=s/30; s=0; for(i=nc-33;i<=nc-4;i++) s+=cl[i]; m4=s/30; c=cl[nc]; reg = (c>m && m>m4) ? "UP" : (c<m && m<m4) ? "DOWN" : "MIXED" } } cw=w; last=$2+0; print $1","reg; next }
