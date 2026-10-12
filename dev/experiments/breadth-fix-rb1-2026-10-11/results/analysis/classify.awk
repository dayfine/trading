# inputs: macro_ON.txt, aud_O_sX.txt, aud_N_sX.txt, O-trades.csv, N-trades.csv
# macro_ON: date Otrend Obstate date Ntrend Nbstate
function last_le(d,   lo,hi,mid){ lo=1; hi=nw; if(d<wd[1]) return 0; while(lo<hi){mid=int((lo+hi+1)/2); if(wd[mid]<=d) lo=mid; else hi=mid-1} return lo }
FILENAME ~ /macro_ON/ {nw++; wd[nw]=$1; ot[nw]=$2; nt[nw]=$5; next}
FILENAME ~ /aud_O/ {odec[$1]=$3; next}
FILENAME ~ /aud_N/ {ndec[$1]=$3; next}
FILENAME ~ /\/O-/ && FNR>1 {split($0,a,","); k=a[1]"|"a[3]; o[k]=$0; next}
FILENAME ~ /\/N-/ && FNR>1 {split($0,a,","); k=a[1]"|"a[3]; n[k]=$0; next}
END{
 for(k in n) if(!(k in o)){ split(n[k],a,","); pid=a[20]; dec=ndec[pid]; i=last_le(dec); j=last_le(a[3]);
   cls=(ot[i]=="Bearish")?"gate":"path"; G[cls]++; GP[cls]+=a[9];
   print "GAIN", a[1], "dec="dec, "fill="a[3], "O@dec="ot[i], "N@dec="nt[i], "O@fill="ot[j], "N@fill="nt[j], "pnl="a[9], cls }
 for(k in o) if(!(k in n)){ split(o[k],a,","); pid=a[20]; dec=odec[pid]; i=last_le(dec); j=last_le(a[3]);
   cls=(nt[i]=="Bearish")?"gate":"path"; L[cls]++; LP[cls]+=a[9];
   print "LOST", a[1], "dec="dec, "fill="a[3], "O@dec="ot[i], "N@dec="nt[i], "O@fill="ot[j], "N@fill="nt[j], "pnl="a[9], cls }
 printf "SUMMARY gained: gate %d (%.0f) path %d (%.0f) | lost: gate %d (%.0f) path %d (%.0f)\n", G["gate"], GP["gate"], G["path"], GP["path"], L["gate"], LP["gate"], L["path"], LP["path"] > "/dev/stderr"
}
