# NAV_d = recon cash_d + sum over positions held at close of d of (q / later applied split factors) x raw close_d
# files: 1 dates (one per line), 2 splits (no hdr), 3 trades (hdr), 4 open (hdr), 5 day.csv (date,V,cash,...), 6 bars (sym,date,close)
BEGIN{FS=","}
FNR==1{f++}
f==1{ want[$1]=1; nw++; wd[nw]=$1; next }
f==2{ ns[$1]++; sd[$1,ns[$1]]=$2; sf[$1,ns[$1]]=$3+0; next }
f==3{ if(FNR==1) next; np++; ps[np]=$1; pe[np]=$3; px[np]=$4; pq[np]=$8+0; next }
f==4{ if(FNR==1) next; np++; ps[np]=$1; pe[np]=$3; px[np]="9999-12-31"; pq[np]=$5+0; next }
f==5{ if($1 in want){ V[$1]=$2; C[$1]=$3 } next }
f==6{ cl[$1","$2]=$3+0; next }
END{ for(w=1;w<=nw;w++){ d=wd[w]; m=0; miss="";
    for(p=1;p<=np;p++){ if(pe[p]<=d && d<px[p]){ s=ps[p]; fac=1; for(k=1;k<=ns[s];k++){ if(sd[s,k]>d && sd[s,k]<=px[p]) fac*=sf[s,k] }
        k2=s","d; if(!(k2 in cl)){ miss=miss" "s; continue } m+=pq[p]/fac*cl[k2] } }
    printf "%s V=%.0f recon=%.0f diff=%.0f%s\n", d, V[d], C[d]+m, C[d]+m-V[d], (miss!=""?" MISSING:"miss:"") } }
