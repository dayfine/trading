#!/bin/sh
# Results-analyst re-derivation for short-wide-top-2026-10-13. Host only, no container, ~10 min. Run from the repo root.
# Writes $A/analysis.txt (every table the Reading quotes) and $A/traces.txt. Scratch goes to $W.
set -e
E=dev/experiments/short-wide-top-2026-10-13
export A=${A:-$E/results/analysis}
W=${W:-.sweep-output/short-wide-top/analysis}
M=dev/experiments/short-setup-map-2026-10-12/results/membership.txt
SM=dev/experiments/short-setup-map-2026-10-12/results/events
D=${DATA:-data}
rm -rf $W; mkdir -p $W/sym $W/span
cut -d' ' -f1 $M | xargs -P 4 -n 1 sh $A/ra_one.sh $W/sym
find $W/sym -name '*.out' -exec cat {} + > $W/all.txt
grep ^EV $W/all.txt | cut -d, -f2- > $W/ra_ev.csv
grep ^NU $W/all.txt | cut -d, -f2- > $W/ra_null.csv
cat $E/results/events/*.csv | awk 'NR==1 || !/^sym,/' > $W/ev.csv
cat $SM/*.csv | awk 'NR==1 || !/^sym,/' > $W/sm_ev.csv
awk -F, 'NR>1{ printf "%s,%s,%s,x,x,%s,x,x,x,x,%s,%s,x,%s,x,x,x,x,x,x,x,x,x,%s\n", $1, $2, $3, $9, $16, $17, $19, $2 }' $W/sm_ev.csv > $W/sm_like.csv
awk -F, 'NR>1{print $1","$8","$15}' $W/ev.csv | sort -t, -k1,1 > $W/ev_entries.csv
cut -d, -f1 $W/ev_entries.csv | uniq | xargs -P 4 -n 1 sh $A/span_one.sh $W > $W/spans.csv
{
echo "# short-wide-top-2026-10-13: results-analyst re-derivation (run_all.sh)"
echo
echo "## 1. Independent re-derivation vs the committed table (first 17 columns)"
awk -F, 'NR>1' $W/ev.csv | sort > $W/c17.txt; cut -d, -f1-17 $W/ra_ev.csv | sort > $W/r17.txt
printf "committed %s, re-derived %s, identical rows %s\n" $(wc -l < $W/c17.txt) $(wc -l < $W/r17.txt) $(comm -12 $W/c17.txt $W/r17.txt | wc -l)
echo "only committed:"; comm -23 $W/c17.txt $W/r17.txt | cut -d, -f1-6
echo "only re-derived:"; comm -13 $W/c17.txt $W/r17.txt | cut -d, -f1-6
echo "the two differences are exact 30-week-MA ties (sum30(i) = sum30(i-4) in integer units):"
for x in "MOD M D 2018-05-04" "WGRD W D 2004-07-23"; do set -- $x; awk -F, -v T=$4 -f $A/dbg2.awk $D/$2/$3/$1/data.csv | head -1 | sed "s/^/  $1 /"; done
echo
echo "## 2. Headline distributions recomputed from the committed events (\$5 floor)"
awk -F, 'NR>1 && $3+0>=5 { y=substr($2,1,4)+0; h=(y<=2012)?"h1":"h2"; print "O1+20\t"$10; print "O1+60\t"$11; print "O1+120\t"$12; print "O2\t"$14; print "O2|"h"\t"$14; print "O1+60|"h"\t"$11; x=$14+0; if(x<-1)x=-1; if(x>1)x=1; print "O2 clipped\t"x; print "O2 abs short ret\t"$13 }' $W/ev.csv > $W/kv.txt; sh $A/stat.sh $W/kv.txt
awk -F, 'NR>1 { d=$14-$12; if($16==0){ n0++; if(d>1e-4||d<-1e-4) mm++ } else n1++; a=($12+0>0); b=($14+0>0); if(a&&!b) lost++; if(!a&&b) won++ } END { printf "unstopped %d (|O2 - O1+120| > 1e-4: %d), stopped %d; the stop flips a beat to a loss on %d events and a loss to a beat on %d\n", n0, mm+0, n1, lost, won }' $W/ev.csv
echo "room:"; awk -F, 'NR>1{print "room\t"$17}' $W/ev.csv > $W/kv.txt; sh $A/stat.sh $W/kv.txt
echo "the ten most negative O2 excesses and their share of the mean:"
awk -F, 'NR>1{print $14","$1","$2","$17}' $W/ev.csv | sort -t, -k1,1g | head -10 | awk -F, -v N=$(awk 'END{print NR-1}' $W/ev.csv) '{c+=$1; printf "  %-9s %s exc %+10.2f%% room %+8.1f%% contrib %+.3f pp cum %+.3f pp\n", $2, $3, 100*$1, 100*$4, 100*$1/N, 100*c/N}'
awk -F, 'NR>1{ if($14+0<-1) lo++; if($14+0>1) hi++ } END{ print "O2 excess < -100 %: " lo ", > +100 %: " hi }' $W/ev.csv
echo "clipped / trimmed halves:"
awk -F, 'NR>1 { y=substr($2,1,4)+0; h=(y<=2012)?"h1":"h2"; x=$14+0; c=x; if(c<-1)c=-1; if(c>1)c=1; print "clip O2|"h"\t"c; if($17+0<=1 && x>=-1 && x<=1) { print "trim O2|"h"\t"x; print "trim O1+60|"h"\t"$11 } }' $W/ev.csv > $W/kv.txt; sh $A/stat.sh $W/kv.txt
echo
echo "## 3. By breakdown year (c2 O2 excess, c3 O1+60, c4 absolute short return, c5 SPY return over the O2 hold)"
awk -F, 'NR>1{ print substr($2,1,4)","$14","$11","$13","($14-$13) }' $W/ev.csv | awk -F, -f $A/med.awk | sort
echo
echo "## 4. Random-member null, every 4th Friday (c2 O1+60, c3 O1+120)"
awk -F, '{ y=substr($2,1,4)+0; h=(y<=2012)?"h1":"h2"; print "ALL,"$4","$5; print h","$4","$5 }' $W/ra_null.csv | awk -F, -f $A/med.awk | sort
echo
echo "## 5. Events vs the calendar-matched null (nearest 4-week sample date)"
awk -F, -f $A/match.awk $W/ra_null.csv $W/ra_ev.csv | sort
echo
echo "## 6. By year: events vs the calendar-matched null"
awk -F, -f $A/match_year.awk $W/ra_null.csv $W/ra_ev.csv
echo
echo "## 7. Halves cutoff sweep vs the matched null"
awk -F, -f $A/sweep.awk $W/ra_null.csv $W/ra_ev.csv
echo
echo "## 8. Setup-map breakdowns (45,599, close entry) vs the same null"
awk -F, -f $A/match.awk $W/ra_null.csv $W/sm_like.csv | sort
echo
echo "## 9. Overlap with the setup map"
awk -F, -f $A/overlap.awk $W/sm_ev.csv $W/ev.csv
awk -F, -f $A/lag.awk $W/sm_ev.csv $W/ev.csv | sort | uniq -c | sort -k2,2n | awk '{ if ($2=="none") none=$1; else { t+=$1; c[$2]=$1 } } END { tot=t+none; printf "no setup-map event in the 52 weeks before: %d (%.1f%%)\n", none, 100*none/tot; cum=0; for (w=0; w<=52; w++) { cum+=c[w]; if (w==0||w==4||w==8||w==13||w==26||w==52) printf "setup-map event 0..%d weeks before: cum %.1f%%\n", w, 100*cum/tot } }'
echo
echo "## 10. Entry convention and entry-bar stop check (re-derived events)"
awk -F, '{ print "O1+60 open\t"$11; print "O1+60 close entry\t"$20; print "O1+120 close entry\t"$21; print "O2 close entry\t"$22; print "O1+60 open - close\t"($11-$20) }' $W/ra_ev.csv > $W/kv.txt; sh $A/stat.sh $W/kv.txt
awk -F, '{ if ($23 != $14) ch++ } END { print "entry-bar stop check changes O2 on " ch+0 " events" }' $W/ra_ev.csv
echo
echo "## 11. Entry vs the top week's high, and weeks H -> breakdown (c2 O1+60, c3 O1+120, c4 O2)"
awk -F, '{d=$19+0; g=(d>-0.2)?"a >-20%":(d>-0.3?"b -20..-30%":(d>-0.4?"c -30..-40%":(d>-0.5?"d -40..-50%":"e <-50%"))); print g","$11","$12","$14}' $W/ra_ev.csv | awk -F, -f $A/med.awk | sort
awk -F, '{w=$5+0; g=(w<=12)?"wk 8-12":(w<=20?"wk 13-20":(w<=30?"wk 21-30":(w<=40?"wk 31-40":"wk 41-52"))); print g","$11","$12","$14}' $W/ra_ev.csv | awk -F, -f $A/med.awk | sort
echo "null by distance from the trailing 52-week high (c2 O1+60, c3 O1+120):"
awk -F, '$6!=""{d=$6+0; g=(d>-0.2)?"a >-20%":(d>-0.3?"b -20..-30%":(d>-0.4?"c -30..-40%":(d>-0.5?"d -40..-50%":"e <-50%"))); print "null "g","$4","$5}' $W/ra_null.csv | awk -F, -f $A/med.awk | sort
echo "events vs the date x distance matched null:"; awk -F, -v MODE=all -f $A/match2.awk $W/ra_null.csv $W/ra_ev.csv | sort
echo "same, null restricted to members below a falling 30-week MA:"; awk -F, -v MODE=fall -f $A/match2.awk $W/ra_null.csv $W/ra_ev.csv | sort
echo "room buckets vs the calendar-matched null:"
awk -F, '{ r=$17+0; $6=(r<=0.15)?"room <=15%":(r<=0.30?"room 15-30%":(r<=0.60?"room 30-60%":(r<=1.0?"room 60-100%":"room >100%"))); OFS=","; print }' $W/ra_ev.csv > $W/x.csv; awk -F, -f $A/match.awk $W/ra_null.csv $W/x.csv | grep phase | sort
echo "room buckets vs the date x distance matched null:"; awk -F, -v MODE=all -f $A/match2room.awk $W/ra_null.csv $W/ra_ev.csv | sort | grep room
echo
echo "## 12. Where the stop sits: shoulder high vs the top week's high"
awk -F, '{ sh=$7/1.01; n++; if (sh > $18) a++ } END { printf "shoulder high above the H week high (stop above the head): %d of %d (%.1f%%)\n", a, n, 100*a/n }' $W/ra_ev.csv
awk -F, '{ sh=$7/1.01; $6 = (sh <= $18) ? "lower-right-shoulder" : "head-in-shoulder"; OFS=","; print }' $W/ra_ev.csv > $W/x.csv; awk -F, -f $A/match.awk $W/ra_null.csv $W/x.csv | grep phase | sort
awk -F, '{ r=($7/1.01)/$18; $6=(r>1.25)?"ratio >1.25":(r>1.10?"ratio 1.10-1.25":(r>1.0?"ratio 1.00-1.10":(r>0.95?"ratio 0.95-1.00":(r>0.90?"ratio 0.90-0.95":"ratio <=0.90")))); OFS=","; print }' $W/ra_ev.csv > $W/x.csv; awk -F, -f $A/match.awk $W/ra_null.csv $W/x.csv | grep phase | sort
echo
echo "## 13. Week- and month-clustered bootstrap (B = 1,000)"
awk -F, 'NR>1{print $2","($11+0>0)}' $W/ev.csv | awk -F, -v B=1000 -v SEED=7 -v LBL="O1+60 beat, week clusters" -f $A/boot.awk
awk -F, 'NR>1{print substr($2,1,7)","($11+0>0)}' $W/ev.csv | awk -F, -v B=1000 -v SEED=7 -v LBL="O1+60 beat, month clusters" -f $A/boot.awk
awk -F, 'NR>1 && substr($2,1,4)+0>=2013 {print $2","($14+0>0)}' $W/ev.csv | awk -F, -v B=1000 -v SEED=7 -v LBL="O2 beat 2013-25, week clusters" -f $A/boot.awk
awk -F, '{ sh=$7/1.01; if (sh <= $18) print $2","($11+0>0) }' $W/ra_ev.csv | awk -F, -v B=1000 -v SEED=11 -v LBL="lower-right-shoulder O1+60 beat, week clusters" -f $A/boot.awk
awk -F, -f $A/flags.awk $W/ra_null.csv $W/ra_ev.csv > $W/flags60.csv
for ph in s4_early s4_late s3 s12; do grep "^$ph," $W/flags60.csv | cut -d, -f2,3 | awk -F, -v B=1000 -v SEED=5 -v LBL="$ph: share above the date's null median at +60, week clusters" -f $A/boot.awk; done
cut -d, -f2,3 $W/flags60.csv | awk -F, -v B=1000 -v SEED=5 -v LBL="ALL: share above the date's null median at +60, week clusters" -f $A/boot.awk
echo
echo "## 14. Economic scale (sum of excess over the sum of bars held, x 252)"
awk -F, 'NR>1 { x=$14+0; b=$15+0; if (b < 1) b = 1; sx+=x; sb+=b; c=x; if(c<-1)c=-1; if(c>1)c=1; sc+=c; r=$13+0; cr=r; if(cr<-1)cr=-1; if(cr>1)cr=1; scr+=cr; if ($17+0<=1 && x>=-1 && x<=1) { tx+=x; tb+=b }; n++; hb+=$15 } END { printf "O2: mean hold %.1f bars; excess per year: raw %+.1f%%, clipped %+.1f%%, trimmed %+.1f%%; absolute short return per year, clipped %+.1f%%\n", hb/n, 100*sx/sb*252, 100*sc/sb*252, 100*tx/tb*252, 100*scr/sb*252 }' $W/ev.csv
awk -F, '{ x=$5+0; c=x; if(c<-1)c=-1; if(c>1)c=1; s+=c; n++; y=substr($2,1,4)+0; if (y<=2012) {s1+=c; n1++} else {s2+=c; n2++} } END { printf "null O1+120, clipped: %+.1f%%/yr; 2000-12 %+.1f%%/yr, 2013-25 %+.1f%%/yr\n", 100*s/n*252/120, 100*s1/n1*252/120, 100*s2/n2*252/120 }' $W/ra_null.csv
awk -F, 'NR>1 { x=$12+0; c=x; if(c<-1)c=-1; if(c>1)c=1; s+=c; n++; y=substr($2,1,4)+0; if (y<=2012) {s1+=c; n1++} else {s2+=c; n2++} } END { printf "events O1+120, clipped: %+.1f%%/yr; 2000-12 %+.1f%%/yr, 2013-25 %+.1f%%/yr\n", 100*s/n*252/120, 100*s1/n1*252/120, 100*s2/n2*252/120 }' $W/ev.csv
echo
echo "## 15a. Additions quoted by the Reading"
echo "entry vs the top week's weekly high, and stop room:"
awk -F, '{print "entry vs H weekly high\t"$19}' $W/ra_ev.csv > $W/kv.txt; sh $A/stat.sh $W/kv.txt
echo "share stopped by room bucket (committed events):"
awk -F, 'NR>1 { r=$17+0; g=(r<=0.15)?"room <=15%":(r<=0.30?"room 15-30%":"room >30%"); n[g]++; s[g]+=($16==1) } END { for (g in n) printf "  %-12s n=%5d stopped %5.1f%%\n", g, n[g], 100*s[g]/n[g] }' $W/ev.csv | sort
echo "year-level event minus matched null (O1+120 beat):"
awk -F, -f $A/match_year.awk $W/ra_null.csv $W/ra_ev.csv | awk 'NR>1 { gsub(/pp/,"",$6); x=$6+0; n++; s+=x; ss+=x*x; if ($1!=2009) { m++; t+=x; tt+=x*x }; if (x>0) pos++ } END { printf "  mean %+.1f pp, SD %.1f pp; without 2009 mean %+.1f, SD %.1f; positive in %d of %d years\n", s/n, sqrt(ss/n-(s/n)^2), t/m, sqrt(tt/m-(t/m)^2), pos, n }'
echo "top width (weeks H -> breakdown) vs the calendar-matched null:"
awk -F, '{ w=$5+0; $6=(w<=12)?"wk 8-12":(w<=20?"wk 13-20":(w<=30?"wk 21-30":(w<=40?"wk 31-40":"wk 41-52"))); OFS=","; print }' $W/ra_ev.csv > $W/x.csv; awk -F, -f $A/match.awk $W/ra_null.csv $W/x.csv | grep phase | sort
echo "spike check, shoulder/head ratio <= 0.90 specimens: the H week's max intraday high over its max close"
for x in "VMC V C 2008-09-19" "HOPE H E 2008-09-19" "PB P B 2008-09-19" "HTBX H X 2015-03-13" "IMNN I N 2020-06-19"; do set -- $x
  awk -F, -v hd=$4 -v s=$1 'NR>1 && $5+0>0 { r=$6/$5; d[NR]=$1; h[NR]=$3*r; c[NR]=$6; if ($1==hd) k=NR } END { mh=0; mc=0; for (j=k-4; j<=k; j++) { if (h[j]>mh) mh=h[j]; if (c[j]>mc) mc=c[j] } printf "  %-5s H %s: high %.3f, close %.3f, high/close %.2f\n", s, hd, mh, mc, mh/mc }' $D/$2/$3/$1/data.csv; done
echo "BOUBYAN trading weekdays (0=Sun .. 6=Sat):"
awk -F, 'function jdn(s,  y,m,d,a,y2,m2){y=substr(s,1,4)+0;m=substr(s,6,2)+0;d=substr(s,9,2)+0;a=int((14-m)/12);y2=y+4800-a;m2=m+12*a-3;return d+int((153*m2+2)/5)+365*y2+int(y2/4)-int(y2/100)+int(y2/400)-32045} NR>1 { w=(jdn($1)+1)%7; c[w]++ } END { for (w=0; w<7; w++) printf "  %d:%d", w, c[w]; print "" }' $D/B/N/BOUBYAN/data.csv
echo
echo "## 15. Data checks"
awk -F, '{ if ($3>250) a++; if ($5>365) g++ } END { print "+120-bar windows longer than 250 calendar days: " a+0 "; with a bar gap > 365 days: " g+0 }' $W/spans.csv
echo "  sym,entry,days to +120,days to O2 exit,largest gap (days),gap starts after"; sort -t, -k5,5nr $W/spans.csv | head -10 | sed "s/^/  /"
awk -F, 'NR>1 { s=$1; c=""; if (s ~ /-WS(-|$)/) c="warrant"; else if (s ~ /-UN(-|$)/) c="unit"; else if (s ~ /^(HSBA|SBER|CELSIA|CTRA_old|NVTK|PLZL|BOUBYAN|ROSG)$/) c="non-USD"; if (c!="") n[c]++ } END { for (k in n) print "events on " k ": " n[k] }' $W/ev.csv
awk -F, '{ if ($6 != $25) d++ } END { print "phase label differs between the last-bar date and the week Friday: " d+0 }' $W/ra_ev.csv
} > $A/analysis.txt
{
for x in "BDY B Y 2007-07-27 2006-12-08" "EXPR E R 2012-07-27 2011-07-29" "EXR E R 2008-10-17 2008-05-02" "COKE C E 2009-10-30 2009-06-05" "CSCO C O 2000-10-27 2000-02-25"; do
  set -- $x; echo "=== $1 $4"; awk -F, -v BD=$4 -v HD=$5 -f $A/trace.awk $D/S/Y/SPY/data.csv $D/$2/$3/$1/data.csv
done
} > $A/traces.txt
echo "wrote $A/analysis.txt and $A/traces.txt"
