#!/bin/bash
# P0 harvest-rotate thesis validation. Usage: p0_analyze.sh <scenario_dir>
# Uses adjusted_close; reports MEDIAN (robust) + mean; winsor-drops |fwd|>5 glitches.
set -u
SD="$1"; AUD="$SD/trade_audit.sexp"; TR="$SD/trades.csv"
OUT=/tmp/p0_out; mkdir -p $OUT
echo "### inputs: trades=$(($(wc -l < "$TR")-1)) skip-records=$(grep -c reason_skipped "$AUD")"
awk '
/\(symbol [A-Za-z0-9_]+\) \(entry_date [0-9-]+\) \(position_id/ {
  if(sym!="") print sym","ed","kind
  sym=$0; sub(/.*\(\(symbol /,"",sym); sub(/\).*/,"",sym)
  ed=$0; sub(/.*\(entry_date /,"",ed); sub(/\).*/,"",ed); kind="other" }
/Early Stage2/ && sym!="" { kind="early" }
/Stage2 breakout|stage2_breakout|Breakout/ && sym!="" && kind=="other" { kind="breakout" }
END{ if(sym!="") print sym","ed","kind }' "$AUD" > $OUT/stage_kind.csv
echo "### entry stage_kind:"; awk -F, '{print $3}' $OUT/stage_kind.csv | sort | uniq -c | tr '\n' ' '; echo
awk -F, 'function nd(x){gsub(/-/,"",x);return x+0}
  NR==FNR{ s=$1; n[s]++; kd[s,n[s]]=nd($2); kk[s,n[s]]=$3; next }
  FNR>1{ s=$1; td=nd($3); best=""; bd=9999;
    for(i=1;i<=n[s];i++){ diff=kd[s,i]-td; if(diff<0)diff=-diff; if(diff<bd){bd=diff;best=kk[s,i]} }
    print $1","$3","$4","((best!=""&&bd<=5)?best:"other") }' $OUT/stage_kind.csv "$TR" > $OUT/held.csv

bash /tmp/fwd_a.sh < $OUT/held.csv > $OUT/fwd_a.csv

# median aggregator: stdin "bucket|value" -> sorted median+mean+n per bucket
med() { sort -t'|' -k1,1 -k2,2g | awk -F'|' '
  {b=$1; v[b,++c[b]]=$2+0; s[b]+=$2; n[b]++}
  END{ for(b in n){ m=n[b]; med=(m%2)?v[b,(m+1)/2]:(v[b,m/2]+v[b,m/2+1])/2;
    printf "%-14s n=%-5d median=%+8.4f mean=%+8.4f\n",b,n[b],med,s[b]/n[b]} }' | sort; }

echo; echo "===== (A) fwd-4w return by EXTENSION above 150dMA (held-weeks, adj-close) ====="
awk -F, 'NR>1 && $5!="NA"{v=$5+0; if(v>5||v<-0.95)next; e=$4+0;
  b=(e<0)?"1:ext<0":(e<.1)?"2:ext0-10":(e<.2)?"3:ext10-20":(e<.3)?"4:ext20-30":(e<.5)?"5:ext30-50":"6:ext>50"; print b"|"v}' $OUT/fwd_a.csv | med
echo; echo "===== (A) fwd-4w return by WEEKS-SINCE-ENTRY ====="
awk -F, 'NR>1 && $5!="NA"{v=$5+0; if(v>5||v<-0.95)next; w=$3+0;
  b=(w<=4)?"1:wk0-4":(w<=12)?"2:wk5-12":(w<=26)?"3:wk13-26":(w<=52)?"4:wk27-52":"5:wk53+"; print b"|"v}' $OUT/fwd_a.csv | med
echo; echo "===== (A) fresh early-S2(wk0-4,early) vs mature-extended(wk27+,ext>20%) ====="
awk -F, 'NR>1 && $5!="NA"{v=$5+0; if(v>5||v<-0.95)next; w=$3+0;e=$4+0;k=$7;
  if(w<=4&&k=="early")print "fresh-early|"v; if(w>=27&&e>0.2)print "mature-ext|"v}' $OUT/fwd_a.csv | med

# ===== PART B =====
echo; echo "===== (B) OPPORTUNITY COST ====="
awk '
/\(entry_date [0-9-]+\)/ { ed=$0; sub(/.*\(entry_date /,"",ed); sub(/\).*/,"",ed) }
/\(symbol [A-Za-z0-9_]+\) \(side / { alt=$0; sub(/.*\(symbol /,"",alt); sub(/\).*/,"",alt); sc=$0; sub(/.*\(score /,"",sc); sub(/\).*/,"",sc) }
/reason_skipped Insufficient_cash/ { print ed","alt","sc }' "$AUD" > $OUT/skips_all.csv
sort -t, -k1,1 -k3,3nr $OUT/skips_all.csv | awk -F, '!seen[$1]++' > $OUT/skips_top.csv
echo "distinct insufficient-cash dates: $(wc -l < $OUT/skips_top.csv)"
awk -F, '{print $2","$1",skip"}' $OUT/skips_top.csv | bash /tmp/fwd_batch.sh > $OUT/skip_fwd.csv
awk -F, 'NR==FNR{n++;hs[n]=$1;he[n]=$2;hx[n]=$3;next}
  {sd=$1;gsub(/-/,"",sd); for(i=1;i<=n;i++){e=he[i];gsub(/-/,"",e);x=hx[i];gsub(/-/,"",x); if(e+0<=sd+0&&sd+0<=x+0) print hs[i]","$1",held"}}' \
  $OUT/held.csv $OUT/skips_top.csv | sort -u > $OUT/held_lk.csv
bash /tmp/fwd_batch.sh < $OUT/held_lk.csv > $OUT/held_fwd.csv
echo "skip-lookups=$(($(wc -l<$OUT/skip_fwd.csv)-1)) held-lookups=$(($(wc -l<$OUT/held_fwd.csv)-1))"
echo "--- (B1) skipped-best vs AVG held capital (winsor mean + win%) ---"
awk -F, '
FILENAME~/skip_fwd/&&FNR>1&&$4!="NA"{ v=$4+0; if(v<=5&&v>=-0.95)sf[$2]=v }
FILENAME~/held_fwd/&&FNR>1&&$4!="NA"{ v=$4+0; if(v<=5&&v>=-0.95){hsum[$2]+=v; hn[$2]++} }
FILENAME~/skips_top/{ d=$1; if(d in sf && d in hn){ sk=sf[d]; hv=hsum[d]/hn[d]; ev++; ds+=sk; hh+=hv; if(sk>hv)win++ } }
END{ printf "matched=%d  mean skipped=%+.4f  mean avg-held=%+.4f  %%skip>held=%.1f%%\n",ev,(ev?ds/ev:0),(ev?hh/ev:0),(ev?100*win/ev:0) }
' $OUT/skip_fwd.csv $OUT/held_fwd.csv $OUT/skips_top.csv
echo "--- (B2) skipped-best vs MOST-EXTENDED held (harvest target) ---"
awk -F, '
FILENAME~/skip_fwd/&&FNR>1&&$4!="NA"{ v=$4+0; if(v<=5&&v>=-0.95)sf[$2]=v }
FILENAME~/held_fwd/&&FNR>1&&$4!="NA"&&$6!="NA"{ v=$4+0; if(v<=5&&v>=-0.95){d=$2; if(!(d in mx)||$6+0>mx[d]){mx[d]=$6+0; hx[d]=v}} }
FILENAME~/skips_top/{ d=$1; if(d in sf && d in hx){ sk=sf[d]; hv=hx[d]; ev++; ds+=sk; hh+=hv; if(sk>hv)win++ } }
END{ printf "matched=%d  mean skipped=%+.4f  mean most-ext-held=%+.4f  %%skip>ext-held=%.1f%%\n",ev,(ev?ds/ev:0),(ev?hh/ev:0),(ev?100*win/ev:0) }
' $OUT/skip_fwd.csv $OUT/held_fwd.csv $OUT/skips_top.csv
echo "### done"
