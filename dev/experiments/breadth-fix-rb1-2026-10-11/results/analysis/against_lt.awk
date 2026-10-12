# like against.awk but with the latest weekly reading STRICTLY before the fill date (V23's rule)
function last_lt(d,   lo,hi,mid){ if(d<=wd[1]) return 0; lo=1; hi=nw; while(lo<hi){mid=int((lo+hi+1)/2); if(wd[mid]<d) lo=mid; else hi=mid-1} return lo }
FILENAME ~ /macro_ON/ {nw++; wd[nw]=$1; tr[nw]=$col; next}
FNR==1{next}
{ split($0,a,","); i=last_lt(a[3]); if(i>0 && tr[i]=="Bearish"){c++; p+=a[9]; if(list) print "  ", a[1], "fill="a[3], "wk="wd[i], "pnl="a[9]} }
END{printf "fills after a Bearish screen (strictly before): %d  net %.0f\n", c, p}
