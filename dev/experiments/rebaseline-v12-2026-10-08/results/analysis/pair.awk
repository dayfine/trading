# files: rb0 trades, rb1 trades. join on symbol|entry_date.
BEGIN{FS=","}
FILENAME==ARGV[1]{ if(FNR==1) next; k=$1"|"$3; A[k]=$0; ap[k]=$9; aq[k]=$8; ae[k]=$6; ax[k]=$7; axd[k]=$4; na++; ta+=$9; if($9>0) wa++; next }
FILENAME==ARGV[2]{ if(FNR==1) next; k=$1"|"$3; B[k]=$0; bp[k]=$9; bq[k]=$8; be[k]=$6; bx[k]=$7; bxd[k]=$4; nb++; tb+=$9; if($9>0) wb++; next }
END{ for(k in B) if(k in A){ nm++; if(ae[k]!=be[k]||ax[k]!=bx[k]||axd[k]!=bxd[k]) nd++; ms+=bp[k]-ap[k]; r=(aq[k]>0? bq[k]/aq[k] : 0); nr++; rr[nr]=r } else { bo++; bos+=bp[k] }
  for(k in A) if(!(k in B)){ ao++; aos+=ap[k] }
  # sort ratios
  for(i=1;i<=nr;i++) for(j=i+1;j<=nr;j++) if(rr[j]<rr[i]){t=rr[i]; rr[i]=rr[j]; rr[j]=t}
  printf "trades rb0=%d rb1=%d | win%% rb0=%.2f rb1=%.2f | realised rb0=%.0f rb1=%.0f delta=%.0f = matched %.0f + rb1-only %.0f (n=%d) - rb0-only %.0f (n=%d) | matched=%d (date/price differs: %d) qty ratio p10/p50/p90=%.3f/%.3f/%.3f\n", na, nb, 100*wa/na, 100*wb/nb, ta, tb, tb-ta, ms, bos, bo, aos, ao, nm, nd+0, rr[int(nr*0.1)+1], rr[int(nr*0.5)+1], rr[int(nr*0.9)+1]
  # largest divergences: |delta| where matched: bp-ap ; unmatched: own pnl
  for(k in B){ d=(k in A)? bp[k]-ap[k] : bp[k]; tag=(k in A)?"matched":"rb1-only"; printf "%s,%s,%.0f,%s\n", (d<0?-d:d), k, d, tag > OUT }
  for(k in A) if(!(k in B)){ d=-ap[k]; printf "%s,%s,%.0f,rb0-only(pnl %.0f)\n", (d<0?-d:d), k, d, ap[k] > OUT } }
