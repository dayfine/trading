# count longs whose fill date's latest weekly macro reading (<= fill date) is Bearish; col = 2 (O) or 5 (N) in macro_ON.txt
function last_le(d,   lo,hi,mid){ lo=1; hi=nw; if(d<wd[1]) return 0; while(lo<hi){mid=int((lo+hi+1)/2); if(wd[mid]<=d) lo=mid; else hi=mid-1} return lo }
FILENAME ~ /macro_ON/ {nw++; wd[nw]=$1; tr[nw]=$col; next}
FNR==1{next}
{ split($0,a,","); i=last_le(a[3]); if(tr[i]=="Bearish"){c++; p+=a[9]; if(list) print "  ", a[1], "fill="a[3], "wk="wd[i], "pnl="a[9], a[20]} }
END{printf "against-macro fills: %d  net %.0f\n", c, p}
