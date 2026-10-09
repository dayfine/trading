# files: 1 spy_adj_full (date,adj; no hdr) for weekly regime; 2 spy series for returns (hdr: date,value); 3 day.csv (date,V,cash,...; no hdr)
# regime of a week (ISO week via jdn: weeks start Monday) known at its last close, applied to the FOLLOWING week's days.
function jdn(s,   y,m,d,a,yy,mm){ y=substr(s,1,4)+0; m=substr(s,6,2)+0; d=substr(s,9,2)+0;
  a=int((14-m)/12); yy=y+4800-a; mm=m+12*a-3;
  return d+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045 }
function wk(s){ return int((jdn(s)+1)/7) }   # jdn+1: Monday-based week index
function per(d,  y){ y=substr(d,1,4)+0; if(y<=2002) return "2000-02"; if(y<=2007) return "2003-07"; if(y==2008) return "2008"; if(y==2009) return "2009"; if(y<=2015) return "2010-15"; if(y<=2021) return "2016-21"; if(y==2022) return "2022"; if(y==2023) return "2023"; if(y==2024) return "2024"; return "2025-26" }
BEGIN{FS=","}
FILENAME==ARGV[1]{ w=wk($1); if(w!=cw && cw!=""){ nc++; cl[nc]=last; ma="" ; if(nc>=34){ s=0; for(i=nc-29;i<=nc;i++) s+=cl[i]; m=s/30; s=0; for(i=nc-33;i<=nc-4;i++) s+=cl[i]; m4=s/30; c=cl[nc]; reg = (c>m && m>m4) ? "UP" : (c<m && m<m4) ? "DOWN" : "MIXED" } } cw=w; last=$2+0; curreg[$1]=reg; next }
FILENAME==ARGV[2]{ if(FNR==1) next; sp[$1]=$2+0; next }
FILENAME==ARGV[3]{ d=$1; V=$2+0; C=$3+0; r=curreg[d]; if(r=="") r="NA"; p=per(d);
   if(pv=="") { pv=1000000; ps=sp[d] }   # first row: start NAV 1M; SPY bought at first close (first-day SPY return 0)
   lr=log(V/pv); ls=(ps>0 && (d in sp))? log(sp[d]/ps) : 0; inv=(V-C)/V;
   k=p SUBSEP r; L[k]+=lr; LS[k]+=ls; N[k]++; I[k]+=inv; k2="ALL" SUBSEP r; L[k2]+=lr; LS[k2]+=ls; N[k2]++; I[k2]+=inv;
   k3=p SUBSEP "ANY"; L[k3]+=lr; LS[k3]+=ls; N[k3]++; I[k3]+=inv; k4="ALL" SUBSEP "ANY"; L[k4]+=lr; LS[k4]+=ls; N[k4]++; I[k4]+=inv;
   pv=V; if(d in sp) ps=sp[d]; next }
END{ np=split("2000-02,2003-07,2008,2009,2010-15,2016-21,2022,2023,2024,2025-26,ALL",P,",");
  printf "period | UP | MIXED | DOWN | all days\n";
  for(i=1;i<=np;i++){ printf "%s", P[i]; split("UP,MIXED,DOWN,ANY",R,",");
    for(j=1;j<=4;j++){ k=P[i] SUBSEP R[j]; if(N[k]>0) printf " | %+.1f / %+.1f @ %.0f%% (%dd)", 100*(exp(L[k])-1), 100*(exp(LS[k])-1), 100*I[k]/N[k], N[k]; else printf " | n/a" }
    print "" }
  k="ALL" SUBSEP "NA"; if(N[k]>0) printf "unclassified days: %d\n", N[k] }
