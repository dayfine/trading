#!/bin/sh
# walk-rk.sh -- the 09-26 decision walkthrough (dev/experiments/obvious-fixes-2026-09-25/walk.sh), re-run on the
# record (record-kseed k0) and extended with the weekly stop decisions (#2977/#2986).
#
# usage: sh walk-rk.sh PREFIX PACKDATA:LABEL OUT [YEAR ...]
#   PREFIX    run artifact prefix (reads PREFIXtrade_audit.sexp, PREFIXtrades.csv, PREFIXequity_curve.csv,
#             PREFIXopen_positions.csv), e.g. .sweep-output/record-kseed/rk-k0-s0-
#   PACKDATA  that run's review-pack data dir and run label, DIR/site/data:LABEL (LABEL_trades.json, LABEL_nav.json,
#             spy.json). Build it host-only with
#               sh dev/scripts/review_pack.sh --out DIR --no-container LABEL=PREFIX
#   OUT       output dir (tsv intermediates, tables.txt, stops.txt, walk-YEAR.txt)
#   YEAR      optional years to print week by week
# Needs the CSV bar store at ./data (repo root; run from the repo root). POSIX sh + awk + jq; host only.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd); L=$HERE/lib
PREFIX=$1; PD=${2%%:*}; LB=${2#*:}; OUT=$3; shift 3
mkdir -p "$OUT"
AUD=${PREFIX}trade_audit.sexp; TRC=${PREFIX}trades.csv

# ---- 1. audit records, weekly cascade summaries + top-N decisions, stop decisions -------------------------------
tr '\n' ' ' < "$AUD" | tr -s ' ' | sed 's/ (cascade_summaries/\
CASCADE/' | head -1 | sed 's/((entry /\
ENTRY /g' | grep '^ENTRY' > "$OUT/records.txt"
awk -f "$L/entries.awk" "$OUT/records.txt" > "$OUT/entries.tsv"
awk -f "$L/stopdec.awk" "$OUT/records.txt" > "$OUT/stopdec.tsv"
tr '\n' ' ' < "$AUD" | tr -s ' ' | sed 's/.*(cascade_summaries//' | sed 's/((date /\
/g' | awk 'NR>1' | awk -v DEC="$OUT/decisions.tsv" -f "$L/weeks.awk" > "$OUT/weeks.tsv"

# ---- 2. weekly timeline: screen row + next-week SPY (total return) and NAV return, exposure %, positions -------
jq -r '.[]|@tsv' "$PD/spy.json" > "$OUT/spy.tsv"; jq -r '.[]|@tsv' "$PD/${LB}_nav.json" > "$OUT/nav.tsv"
awk -F'\t' 'FILENAME~/spy.tsv$/{s[++ns]=$1; sv[ns]=$2; next} FILENAME~/nav.tsv$/{n[++nn]=$1; nv[nn]=$2; ex[nn]=$3; np[nn]=$4; next}
 { d[++nw]=$1; row[nw]=$0 }
 END{ i=1; j=1; for(w=1;w<=nw;w++){ while(i<ns && s[i+1]<=d[w]) i++; while(j<nn && n[j+1]<=d[w]) j++; S[w]=sv[i]; N[w]=nv[j]; E[w]=ex[j]; P[w]=np[j] }
   for(w=1;w<nw;w++) printf "%s\t%.5f\t%.5f\t%s\t%s\n", row[w], S[w+1]/S[w]-1, N[w+1]/N[w]-1, E[w], P[w] }' \
  "$OUT/spy.tsv" "$OUT/nav.tsv" "$OUT/weeks.tsv" > "$OUT/timeline.tsv"
# timeline cols: 1 date 2 macro 3 breadth 4 cand_after_held 5 breakout 6 grade 7 topN 8 entered 9 placed 10 nss 11 cash
#                12 sized0 13 other 14 spy_next_wk 15 nav_next_wk 16 expo% 17 npos
jq -r '.[]|[.id,.sym,.ed,.xd,.pct,.pnl,.trig,.p13,.mfe,.days,.sfd,.nraise,.maxs,.es,.xs,.ep,.xp,.pmax,.mae,.div,.fe,.fx]|@tsv' "$PD/${LB}_trades.json" > "$OUT/tr_full.tsv"
# tr_full cols: 1 pid 2 sym 3 fill_date 4 exit_date 5 pct 6 pnl 7 trig 8 p13 9 mfe 10 days 11 sfd 12 nraise 13 maxs
#               14 entry_stop 15 exit_stop 16 ep 17 xp 18 post_max 19 mae 20 div 21 fe 22 fx

# ---- 3. forward returns (13/26/52 w, adjusted) from the screen date for every top-N decision ---------------------
cut -f1,2 "$OUT/decisions.tsv" | sort -u -k2,2 -k1,1 > "$OUT/uq.tsv"
awk -F'\t' -f "$L/fwd.awk" "$OUT/uq.tsv" > "$OUT/fwd.tsv"   # date sym r13 r26 r52

# ---- 4. 20-day ATR (% of close) before each fill; peak close during the hold ------------------------------------
sort -t"$(printf '\t')" -k2,2 "$OUT/tr_full.tsv" | awk -F'\t' -f "$L/atr.awk" > "$OUT/atr.tsv"
# atr cols: 1 pid 2 fill_date 3 trig 4 days 5 mfe 6 pnl 7 stopdist(sfd) 8 atr20

# ---- 5. tables -------------------------------------------------------------------------------------------------
sh "$L/tables.sh" "$OUT" "$TRC" > "$OUT/tables.txt"
sh "$L/stops.sh" "$OUT" "$TRC" > "$OUT/stops.txt"
sh "$L/extras.sh" "$OUT" "$TRC" "$PREFIX" > "$OUT/extras.txt"

# ---- 6. week-by-week walks ---------------------------------------------------------------------------------------
for Y in "$@"; do
awk -F'\t' -v Y="$Y" '
FILENAME~/entries/{ if($10==1){age[$3]=$7} pl[$2]=pl[$2] $1 (($10==1)?"":"·") " "; next}
FILENAME~/tr_full/{ fills[$3]=fills[$3] $2 "(" age[$1] "w) "; ex[$4]=ex[$4] $2 ":" substr($7,1,4) sprintf("%+.0f%%/%+.0fk", $5, $6/1000) "→" sprintf("%+.0f", $8) " "; next}
FILENAME~/timeline/{ if(substr($1,1,4)!=Y) next; nw++; wd[nw]=$1; row[nw]=sprintf("%s %-7s grade=%s top=%s placed=%s nss=%s cash=%s | spy%+.1f nav%+.1f expo%s pos%s", $1, $2, $6, $7, $9, $10, $11, 100*$14, 100*$15, $16, $17) }
END{ prev=(Y-1) "-12-31"; for(w=1;w<=nw;w++){ F=""; X=""; for(d in fills) if(d>prev && d<=wd[w]) F=F fills[d]; for(d in ex) if(d>prev && d<=wd[w]) X=X ex[d]
  print row[w]; if(pl[wd[w]]!="") print "   placed: " pl[wd[w]]; if(F!="") print "   FILLED: " F; if(X!="") print "   EXITED: " X; prev=wd[w] } }' \
  "$OUT/entries.tsv" "$OUT/tr_full.tsv" "$OUT/timeline.tsv" > "$OUT/walk-$Y.txt"
done
echo "done: $OUT/tables.txt $OUT/stops.txt"
