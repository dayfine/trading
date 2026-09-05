#!/bin/sh
W=/tmp/yr-run; F=dev/experiments/record-rebase-2026-09-03/results/rec26y-new-s0-trades.csv
echo "symbol,entry,exit,days,ep,xp,pct,pnl,trigger,sector,max13e,min13e,p13x,max13x,min13x,barsx,grade" > $W/graded.csv
awk -F, 'NR>1' $F | while IFS=, read sym side ed xd days ep xp qty pnl pct rest; do
  trig=$(echo "$rest" | cut -d, -f3); sec=$(awk -F, -v s="$sym" '$1==s{print $2; exit}' data/sectors.csv); [ -z "$sec" ] && sec="(untagged)"
  f=data/$(echo $sym | cut -c1)/$(echo $sym | rev | cut -c1)/$sym/data.csv
  if [ ! -f "$f" ]; then echo "$sym,$ed,$xd,$days,$ep,$xp,$pct,$pnl,$trig,$sec,,,,,,,NODATA" >> $W/graded.csv; continue; fi
  awk -F, -v ed="$ed" -v xd="$xd" -v ep="$ep" -v xp="$xp" -v sym="$sym" -v pct="$pct" -v days="$days" -v pnl="$pnl" -v trig="$trig" -v sec="$sec" '
    NR==1 { for(i=1;i<=NF;i++){ if($i=="adjusted_close") ac=i; if($i=="date") d=i }; next }
    { dt=$d; p=$ac
      if (dt>=ed && pe==0) pe=p
      if (dt>=xd && px==0) px=p
      if (pe>0 && dt>=ed) { j++; if(j<=65){ if(p>mxe) mxe=p; if(mne==0||p<mne) mne=p } }
      if (px>0 && dt>=xd) { k++; if(k<=65){ if(p>mxa) mxa=p; if(mna==0||p<mna) mna=p; p13=p } } }
    END { if(pe==0||px==0){ printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,,,,,,,NODATA\n", sym,ed,xd,days,ep,xp,pct,pnl,trig,sec; exit }
      me=(mxe/pe-1)*100; mi=(mne/pe-1)*100; a13=(p13/px-1)*100; ma=(mxa/px-1)*100; mn=(mna/px-1)*100
      g="C"
      if (pct+0 >= 20 || (pct+0 > 0 && ma <= 10)) g="A"
      else if (pct+0 > 0 && pct+0 < 20) g="B"
      if (pct+0 <= 0) { if (ma >= 50) g="F"; else if (ma >= 15) g="D"; else if (a13 <= -5) g="B"; else g="C" }
      if (xp+0 < ep*0.05) g="X"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%.1f,%.1f,%.1f,%.1f,%.1f,%d,%s\n", sym,ed,xd,days,ep,xp,pct,pnl,trig,sec,me,mi,a13,ma,mn,k,g }' "$f" >> $W/graded.csv
done
echo "GRADE DONE $(wc -l < $W/graded.csv)" >> $W/graded.done
