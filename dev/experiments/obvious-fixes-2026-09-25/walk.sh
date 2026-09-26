#!/bin/sh
# walk.sh -- the decision walkthrough tables behind salt0-analysis.md, rebuilt from one run's artifacts.
#
# usage: sh walk.sh PREFIX PACKDATA OUT [YEAR ...]
#   PREFIX    run artifact prefix, e.g. .sweep-output/obvious-fixes/f2-fills-faithful-s0-v11-
#             (reads PREFIXtrade_audit.sexp and PREFIXtrades.csv)
#   PACKDATA  that run's review-pack data dir (review_pack.sh --out DIR ... -> DIR/site/data) and run label,
#             as DIR/site/data:LABEL (reads LABEL_trades.json, LABEL_nav.json, spy.json)
#   OUT       output dir (tsv intermediates + tables.txt + walk-YEAR.txt)
#   YEAR      optional years to print week by week
# Needs the CSV bar store at ./data (repo root). POSIX sh + awk + jq; host only, no container.
set -eu
PREFIX=$1; PD=${2%%:*}; LB=${2#*:}; OUT=$3; shift 3
mkdir -p "$OUT"
AUD=${PREFIX}trade_audit.sexp; TRC=${PREFIX}trades.csv

# 1. one line per audit record, and the per-week cascade summaries
tr '\n' ' ' < "$AUD" | tr -s ' ' | sed 's/ (cascade_summaries/\
CASCADE/' | head -1 | sed 's/((entry /\
ENTRY /g' | grep '^ENTRY' > "$OUT/records.txt"
awk 'function f(k){ if (match($0,"\\(" k " [^()]*\\)")) return substr($0,RSTART+length(k)+2,RLENGTH-length(k)-3); return "" }
{ alts=$0; na=gsub(/reason_skipped /,"&",alts); cash=gsub(/Insufficient_cash/,"&",alts); fill=index($0,"(fill_price")>0
  trig=""; if (match($0,/exit_trigger \([A-Za-z_]+/)) trig=substr($0,RSTART+14,RLENGTH-14)
  print f("symbol") "\t" f("entry_date") "\t" f("position_id") "\t" f("macro_trend") "\t" f("cascade_score") "\t" f("cascade_grade") "\t" f("ticket_age_weeks_at_fill") "\t" f("exit_date") "\t" trig "\t" fill "\t" na "\t" cash "\t" f("stop_floor_kind") "\t" f("risk_pct") "\t" f("initial_position_value") "\t" f("fill_vs_trigger_pct") }' \
  "$OUT/records.txt" > "$OUT/entries.tsv"   # sym placed pid macro score grade age exit trig filled n_alt n_cash floor risk value fvt
tr '\n' ' ' < "$AUD" | tr -s ' ' | sed 's/.*(cascade_summaries//' | sed 's/((date /\
/g' | awk 'NR>1{d=$1; sub(/\)$/,"",d); out=d; n=split("macro_trend breadth_state candidates_after_held long_breakout_admitted long_grade_admitted long_top_n_admitted short_top_n_admitted entered",k," ")
  for(i=1;i<=n;i++){ if(match($0,"\\(" k[i] " [^()]*\\)")) out=out "\t" substr($0,RSTART+length(k[i])+2,RLENGTH-length(k[i])-3); else out=out "\t" } print out}' > "$OUT/weeks.tsv"

# 2. weekly timeline: screen row + next-week SPY and NAV return, exposure, positions
jq -r '.[]|@tsv' "$PD/spy.json" > "$OUT/spy.tsv"; jq -r '.[]|@tsv' "$PD/${LB}_nav.json" > "$OUT/nav.tsv"
awk -F'\t' 'FILENAME~/spy.tsv$/{s[++ns]=$1; sv[ns]=$2; next} FILENAME~/nav.tsv$/{n[++nn]=$1; nv[nn]=$2; ex[nn]=$3; np[nn]=$4; next}
 { d[++nw]=$1; row[nw]=$0 }
 END{ i=1; j=1; for(w=1;w<=nw;w++){ while(i<ns && s[i+1]<=d[w]) i++; while(j<nn && n[j+1]<=d[w]) j++; S[w]=sv[i]; N[w]=nv[j]; E[w]=ex[j]; P[w]=np[j] }
   for(w=1;w<nw;w++) printf "%s\t%.5f\t%.5f\t%s\t%s\n", row[w], S[w+1]/S[w]-1, N[w+1]/N[w]-1, E[w], P[w] }' \
  "$OUT/spy.tsv" "$OUT/nav.tsv" "$OUT/weeks.tsv" > "$OUT/timeline.tsv"
jq -r '.[]|[.id,.sym,.ed,.xd,.pct,.pnl,.trig,.p13,.mfe,.days,.sfd]|@tsv' "$PD/${LB}_trades.json" > "$OUT/tr_full.tsv"

# 3. forward returns (13w/26w, adjusted) for every funded and cash-rejected candidate at its screen
awk '{ d=""; if(match($0,/\(entry_date [^()]*\)/)) d=substr($0,RSTART+12,RLENGTH-13)
  s=""; if(match($0,/\(symbol [^()]*\)/)) s=substr($0,RSTART+8,RLENGTH-9); print d "\t" s "\tfunded"
  rest=substr($0,index($0,"(alternatives_considered"))
  while (match(rest,/\(\(symbol [^()]*\) \(side [A-Za-z]*\) \(score [^()]*\) \(grade [^()]*\) \(reason_skipped [^()]*\)/)) {
    a=substr(rest,RSTART,RLENGTH); rest=substr(rest,RSTART+RLENGTH)
    sym=a; sub(/^\(\(symbol /,"",sym); sub(/\).*/,"",sym); rs=a; sub(/.*\(reason_skipped /,"",rs); sub(/\).*/,"",rs)
    print d "\t" sym "\talt:" rs } }' "$OUT/records.txt" > "$OUT/queries.tsv"
cut -f1,2 "$OUT/queries.tsv" | sort -u -k2,2 -k1,1 > "$OUT/uq.tsv"
awk -F'\t' 'function load(sym,  f,line,a){ delete D; delete A; nb=0; f="data/" substr(sym,1,1) "/" substr(sym,length(sym),1) "/" sym "/data.csv"
  while ((getline line < f) > 0) { if (line ~ /^date/) continue; split(line,a,","); if (a[6]+0<=0) continue; nb++; D[nb]=a[1]; A[nb]=a[6] } close(f) }
{ if ($2!=cur) { cur=$2; load(cur) } if (nb==0) { print $1 "\t" $2 "\tNA\tNA"; next }
  lo=1; hi=nb; i=0; while(lo<=hi){m=int((lo+hi)/2); if(D[m]<=$1){i=m; lo=m+1} else hi=m-1}
  if (i==0) { print $1 "\t" $2 "\tNA\tNA"; next }
  r13=(i+65<=nb)? A[i+65]/A[i]-1 : A[nb]/A[i]-1; r26=(i+130<=nb)? A[i+130]/A[i]-1 : A[nb]/A[i]-1
  printf "%s\t%s\t%.4f\t%.4f\n", $1,$2,r13,r26 }' "$OUT/uq.tsv" > "$OUT/fwd.tsv"

# 4. 20-day ATR (% of close) before each fill
sort -t"$(printf '\t')" -k2,2 "$OUT/tr_full.tsv" | awk -F'\t' '
function load(sym, f,line,a){ delete H; delete L; delete C; delete Dt; nb=0; f="data/" substr(sym,1,1) "/" substr(sym,length(sym),1) "/" sym "/data.csv"
 while((getline line < f)>0){ if(line~/^date/)continue; split(line,a,","); if(a[5]+0<=0)continue; nb++; Dt[nb]=a[1]; H[nb]=a[3]; L[nb]=a[4]; C[nb]=a[5]} close(f)}
{ if($2!=cur){cur=$2; load(cur)} i=0; for(k=nb;k>=1;k--) if(Dt[k]<$3){i=k;break}
  if(i<21) next; s=0; for(k=i-19;k<=i;k++){tr=H[k]-L[k]; if(H[k]-C[k-1]>tr)tr=H[k]-C[k-1]; if(C[k-1]-L[k]>tr)tr=C[k-1]-L[k]; s+=tr/C[k-1]}
  print $1 "\t" $3 "\t" $7 "\t" $10 "\t" $9 "\t" $6 "\t" $11 "\t" s/20 }' > "$OUT/atr.tsv"   # pid ed trig days mfe pnl stopdist atr

# 5. tables
{
echo "== returns by macro state (screen week -> next week), by era"
awk -F'\t' '{y=substr($1,1,4); e=(y<2009?"2000-08":(y<2020?"2009-19":"2020-26")); k=e" | "$2; n[k]++; s[k]+=log(1+$10); v[k]+=log(1+$11); x[k]+=$12}
 END{for(k in n) printf "%s | %d wk | SPY %+.0f%% | NAV %+.0f%% | expo %.0f%%\n",k,n[k],100*(exp(s[k])-1),100*(exp(v[k])-1),x[k]/n[k]}' "$OUT/timeline.tsv" | sort
echo; echo "== funded vs cash-rejected, 26w forward return from the screen, paired per screen week"
awk -F'\t' 'NR==FNR{r26[$1"|"$2]=$4; next} { k=$1"|"$2; role=($3=="funded")?"F":"A"; if(seen[role k]++) next; if(r26[k]=="NA") next
  y=substr($1,1,4); e=(y<2009?"2000-08":(y<2020?"2009-19":"2020-26")); W[$1 role]+=r26[k]; WN[$1 role]++; WE[$1]=e }
 END{ for(w in WE) if(WN[w "F"]>0 && WN[w "A"]>0){ d=W[w "F"]/WN[w "F"]-W[w "A"]/WN[w "A"]; pw[WE[w]]++; if(d>0) pb[WE[w]]++ }
   for(e in pw) printf "%s: screen weeks %d, funded mean beat alternatives %.0f%%\n", e, pw[e], 100*pb[e]/pw[e] }' "$OUT/fwd.tsv" "$OUT/queries.tsv" | sort
echo; echo "== outcome by initial stop kind"
awk -F'\t' 'NR==FNR{fk[$3]=$13; next} {k=fk[$1]; n[k]++; p[k]+=$6; c[k]+=$5; sd[k]+=$11; if($7=="stop_loss")s[k]++; if($7=="stop_loss"&&$10<=20&&$9<3)q[k]++}
 END{for(k in n) printf "%s | %d trades | %.0fk | mean %+.2f%% | stopped %.0f%% | quick-fail %.0f%% | init stop %.1f%%\n",k,n[k],p[k]/1000,c[k]/n[k],100*s[k]/n[k],100*q[k]/n[k],100*sd[k]/n[k]}' "$OUT/entries.tsv" "$OUT/tr_full.tsv"
echo; echo "== quick-fail rate (stop <=20d, MFE <3%) by stop distance / ATR20"
awk -F'\t' '{r=$7/$8; b=(r<1?"a) <1 ATR":(r<2?"b) 1-2":(r<3?"c) 2-3":"d) 3+ ATR"))); n[b]++; if($3=="stop_loss"&&$4<=20&&$5<3)q[b]++; p[b]+=$6}
 END{for(b in n) printf "%s | %d | %.0f%% | %.0fk\n",b,n[b],100*q[b]/n[b],p[b]/1000}' "$OUT/atr.tsv" | sort
echo; echo "== fills by ticket age"
awk -F'\t' 'NR==FNR{if($10==1)age[$3]=$7; next} {a=age[$1]; b=(a<=4?"a) 0-4w":(a<=25?"b) 5-25w":(a<=103?"c) 26-103w":(a<=259?"d) 2-5y":"e) 5y+")))); n[b]++; p[b]+=$6}
 END{for(b in n) printf "%s | %d | %.0fk\n",b,n[b],p[b]/1000}' "$OUT/entries.tsv" "$OUT/tr_full.tsv" | sort
echo; echo "== macro state in force at fill"
awk -F'\t' 'FILENAME~/timeline/{wd[++n]=$1; st[n]=$2; next} FILENAME~/entries/{if($10==1)age[$3]=$7; next}
 { i=0; for(k=n;k>=1;k--) if(wd[k]<$3){i=k;break}; b=(i?st[i]:"?") (age[$1]>=4?" stale(>=4w)":" fresh"); c[b]++; p[b]+=$6 }
 END{for(b in c) printf "%s | %d | %.0fk\n",b,c[b],p[b]/1000}' "$OUT/timeline.tsv" "$OUT/entries.tsv" "$OUT/tr_full.tsv" | sort
echo; echo "== stop raises (trades.csv n_stop_raises)"
awk -F, 'NR>1{k=($23+0==0?"0":($23+0<=2?"1-2":"3+")); n[k]++; p[k]+=$9; d[k]+=$5} END{for(k in n) printf "%s raises | %d | %.0fk | %.0f days\n",k,n[k],p[k]/1000,d[k]/n[k]}' "$TRC" | sort
} > "$OUT/tables.txt"

# 6. week-by-week walks
for Y in "$@"; do
awk -F'\t' -v Y="$Y" '
FILENAME~/entries/{ if($10==1){age[$3]=$7; fk[$3]=($13=="Buffer_fallback"?"fb":"sf")} pl[$2]=pl[$2] $1 (($10==1)?"":"·") " "; next}
FILENAME~/tr_full/{ fills[$3]=fills[$3] $2 "(" age[$1] "w," fk[$1] ") "; ex[$4]=ex[$4] $2 ":" substr($7,1,4) sprintf("%+.0f%%/%+.0fk", $5, $6/1000) "→" sprintf("%+.0f", $8) " "; next}
FILENAME~/timeline/{ if(substr($1,1,4)!=Y) next; nw++; wd[nw]=$1; row[nw]=sprintf("%s %-7s cand=%s→%s ent=%s | spy%+.1f nav%+.1f expo%s pos%s", $1, $2, $5, $6, $9, 100*$10, 100*$11, $12, $13) }
END{ prev=(Y-1) "-12-31"; for(w=1;w<=nw;w++){ F=""; X=""; for(d in fills) if(d>prev && d<=wd[w]) F=F fills[d]; for(d in ex) if(d>prev && d<=wd[w]) X=X ex[d]
  print row[w]; if(pl[wd[w]]!="") print "   placed: " pl[wd[w]]; if(F!="") print "   FILLED: " F; if(X!="") print "   EXITED: " X; prev=wd[w] } }' \
  "$OUT/entries.tsv" "$OUT/tr_full.tsv" "$OUT/timeline.tsv" > "$OUT/walk-$Y.txt"
done
echo "done: $OUT/tables.txt"
