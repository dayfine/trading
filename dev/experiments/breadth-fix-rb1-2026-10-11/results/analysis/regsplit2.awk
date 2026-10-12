# usage: awk -F, -v d0=YYYY-MM-DD -v d1=YYYY-MM-DD -v tag=X -f regsplit2.awk spy_regime.csv expo.csv
# per regime and ALL: days, avg invested, cumulative strategy and SPY return (daily log sums over days d in [d0,d1])
FILENAME ~ /spy_regime/ {spy[$1]=$2; reg[$1]=$3; next}
{ d=$1; if(pd!="" && d>=d0 && d<=d1 && reg[d]!=""){ r=reg[d]; n[r]++; ex[r]+=$3; ls[r]+=log($2/pnav); lm[r]+=log(spy[d]/spy[pd]); n["ALL"]++; ex["ALL"]+=$3; ls["ALL"]+=log($2/pnav); lm["ALL"]+=log(spy[d]/spy[pd]) } pd=d; pnav=$2 }
END{ printf "%-6s", tag; for(k=1;k<=4;k++){ r=(k==1?"ALL":(k==2?"UP":(k==3?"MIXED":"DOWN"))); if(n[r]) printf " | %s %4d d %+6.1f%%/%+6.1f%% @%3.0f%%", r, n[r], 100*(exp(ls[r])-1), 100*(exp(lm[r])-1), ex[r]/n[r]; else printf " | %s -", r } printf "\n" }
