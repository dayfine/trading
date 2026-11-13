#!/bin/sh
# run.sh -- entry-timing screen: per-trade replays of three entry rules (and one narrow variant) over every closed
# trade of the record run's five tie-order seeds. Host only: POSIX sh + awk, no dune, no container.
#
# usage (from the repo root): sh dev/experiments/entry-timing-screen-2026-11-12/run.sh RUNDIR WORK
#   RUNDIR  holds rk-k{0..4}-s0-{trade_audit.sexp,trades.csv,equity_curve.csv} of record-kseed-2026-10-27
#           (the audit is not committed; locally it is .sweep-output/record-kseed/)
#   WORK    scratch directory for intermediates
# Needs the CSV bar store at ./data. Rewrites results/ next to this script. About 14 minutes in all.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd); L=$HERE/lib; RES=$HERE/results
WALK=$HERE/../decision-walk-rk-2026-11-06/lib
RUN=$1; W=$2; mkdir -p "$W" "$RES"
store() { printf '%s\n' "$1" | awk '{ printf "data/%s/%s/%s/data.csv", toupper(substr($0, 1, 1)), toupper(substr($0, length($0), 1)), $0 }'; }

# 1. audit entries (the decision walkthrough's parser), joined to trades + NAV at the screen
: > "$W/specs.tsv"; : > "$W/pct.tsv"; : > "$W/unfilled_specs.tsv"
for k in 0 1 2 3 4; do
  P=$RUN/rk-k$k-s0-
  tr '\n' ' ' < "${P}trade_audit.sexp" | tr -s ' ' | sed 's/ (cascade_summaries/\
CASCADE/' | head -1 | sed 's/((entry /\
ENTRY /g' | grep '^ENTRY' > "$W/records-k$k.txt"
  awk -f "$WALK/entries.awk" "$W/records-k$k.txt" > "$W/entries-k$k.tsv"
  awk -F'\t' -v k=$k -f "$L/specs.awk" "${P}equity_curve.csv" "$W/entries-k$k.tsv" "${P}trades.csv" >> "$W/specs.tsv"
  awk -F, -v k=$k 'NR > 1 { print k "\t" $20 "\t" $10 }' "${P}trades.csv" >> "$W/pct.tsv"
  awk -F'\t' -v k=$k -f "$L/unfilled_specs.awk" "${P}equity_curve.csv" "$W/entries-k$k.tsv" >> "$W/unfilled_specs.tsv"
done
awk -F, -f "$L/gspc_weekly.awk" data/G/X/GSPC.INDX/data.csv > "$W/gspc_weekly.tsv"

# 2. per-symbol replays (closed trades; then the never-filled tickets under the stale-E cap)
: > "$W/replay.tsv"; : > "$W/chart.tsv"; : > "$W/unfilled.tsv"
for sym in $(cut -f3 "$W/specs.tsv" | sort -u); do
  f=$(store "$sym"); [ -f "$f" ] || { echo "no store file: $sym" >&2; continue; }
  awk -F'\t' -v s="$sym" '$3 == s' "$W/specs.tsv" > "$W/one.tsv"
  awk -F'\t' -v CHART="$W/chart.tsv" -f "$L/replay.awk" "$W/gspc_weekly.tsv" "$W/one.tsv" "$f" >> "$W/replay.tsv"
done
for sym in $(cut -f3 "$W/unfilled_specs.tsv" | sort -u); do
  f=$(store "$sym"); [ -f "$f" ] || continue
  awk -F'\t' -v s="$sym" '$3 == s' "$W/unfilled_specs.tsv" > "$W/one.tsv"
  awk -F'\t' -v OFS='\t' -f "$L/unfilled.awk" "$W/one.tsv" "$f" >> "$W/unfilled.tsv"
done

# 3. results
H="seed,pid,sym,screen,fill_date,exit_date,exit_trigger,pnl,nav_at_screen,basis_ok,ext_screen_audit,ext_screen_replay,ext_fill,E_over_fill,rt4_over_fill,R_actual,pnl_model_actual,value_over_nav,null_fill_date,null_fill_over_fill,null_R,null_pnl"
for n in 2 4 8 13; do H="$H,h2n${n}_status,h2n${n}_fill_date,h2n${n}_fill_over_fill,h2n${n}_R,h2n${n}_pnl"; done
H="$H,ctl_R,ctl_pnl,ctl_stop_over_15pct"
for m in 3 8; do H="$H,h3m${m}_status,h3m${m}_fill_date,h3m${m}_fill_over_fill,h3m${m}_R,h3m${m}_pnl,h3m${m}_stop_dist"; done
for k in 0 1 2 3 4; do   # one file per seed (jj snapshots skip new files over 1 MiB)
  { echo "$H"; awk -F'\t' -v k=$k '$1 == k' "$W/replay.tsv" | sort -t"$(printf '\t')" -k5,5 -k2,2 | awk -F'\t' -v OFS=, '{ $1 = $1; print }'; } > "$RES/replay-k$k.csv"
done
{ echo "seed,pid,sym,placement,stale,filled_under_cap,fill_date,R,pnl_nav_pct"; sort -k1,1n -k2,2 "$W/unfilled.tsv" | awk -F'\t' -v OFS=, '{ $1 = $1; print }'; } > "$RES/unfilled.csv"
awk -F'\t' -f "$L/validate.awk" "$W/replay.tsv" > "$RES/validation.txt"
awk -F'\t' -f "$L/summarize.awk" "$W/pct.tsv" "$W/replay.tsv" > "$RES/summary.txt"
awk -F'\t' -f "$L/why.awk" "$W/pct.tsv" "$W/replay.tsv" > "$RES/why.txt"
awk -F'\t' -f "$L/extra.awk" "$W/pct.tsv" "$W/replay.tsv" > "$RES/extra.txt"
awk -F'\t' '{ k = $1; n[k]++; st[k] += $5; f[k] += $6; s[k] += $9; if ($6 && $8 <= -0.9) so[k]++ }
  END { print "== never-filled tickets under the stale-E cap (proxy: installed stop, 26-week hold)"
        for (k = 0; k <= 4; k++) printf "k%d unfilled tickets %d, stale E %d, would fill under the cap %d, proxy NAV-%% %+6.1f, stopped out %d\n", k, n[k], st[k], f[k], s[k], so[k] }' \
  "$W/unfilled.tsv" > "$RES/unfilled.txt"
echo "wrote the main screen to $RES"

# 4. follow-up screens (same day): book-literal pre-breakout floor (F1), k0 skip conversions under it, an entry-feature
#    scan, and post-stop re-entry (R1). Same inputs; adds ~4 minutes.
: > "$W/stops.tsv"
for k in 0 1 2 3 4; do awk -F, -v k=$k 'NR > 1 { print k "\t" $20 "\t" $11 "\t" $12 "\t" $23 }' "$RUN/rk-k$k-s0-trades.csv" >> "$W/stops.tsv"; done
awk -F'\t' 'FNR == NR { X[$1, $2] = $3 "\t" $4 "\t" $5; next } { print $0 "\t" X[$1, $2] }' "$W/stops.tsv" "$W/specs.tsv" > "$W/specs_x.tsv"
: > "$W/floor.tsv"; : > "$W/reentry.tsv"; : > "$W/reentry-nogate.tsv"
for sym in $(cut -f3 "$W/specs_x.tsv" | sort -u); do
  f=$(store "$sym"); [ -f "$f" ] || continue
  awk -F'\t' -v s="$sym" '$3 == s' "$W/specs_x.tsv" > "$W/one.tsv"
  awk -F'\t' -f "$L/floor.awk" "$W/one.tsv" "$f" >> "$W/floor.tsv"
  awk -F'\t' -v GATE=0.15 -f "$L/reentry.awk" "$W/one.tsv" "$f" >> "$W/reentry.tsv"
  awk -F'\t' -v GATE=0 -f "$L/reentry.awk" "$W/one.tsv" "$f" >> "$W/reentry-nogate.tsv"
done
# k0 top-N decisions (the decision walk's parser), then conversion events + the run's own entries as calibration rows
tr '\n' ' ' < "$RUN/rk-k0-s0-trade_audit.sexp" | tr -s ' ' | sed 's/.*(cascade_summaries//' | sed 's/((date /\
/g' | awk 'NR > 1' | awk -v DEC="$W/decisions.tsv" -f "$WALK/weeks.awk" > /dev/null
awk -F'\t' '$3 == "No_structural_stop" { print $2 "\t" $1 }' "$W/decisions.tsv" | sort -k1,1 -k2,2 | awk -F'\t' -f "$L/conv_events.awk" > "$W/events.tsv"
awk -F'\t' '$1 == 0 { print "0\t" $4 "\t" $3 "\t0\tnull\t" $5 "\t" $7 "\t" $13 }' "$W/specs.tsv" >> "$W/events.tsv"
: > "$W/conv.tsv"
for sym in $(cut -f3 "$W/events.tsv" | sort -u); do
  f=$(store "$sym"); [ -f "$f" ] || continue
  awk -F'\t' -v s="$sym" '$3 == s' "$W/events.tsv" > "$W/one.tsv"
  awk -F'\t' -f "$L/conv.awk" "$W/one.tsv" "$f" >> "$W/conv.tsv"
done
awk -F'\t' '$3 == "Insufficient_cash" { print $1 }' "$W/decisions.tsv" | sort -u > "$W/cashweeks.txt"
awk -F'\t' -f "$L/features.awk" "$W/pct.tsv" "$W/entries-k0.tsv" "$W/entries-k1.tsv" "$W/entries-k2.tsv" "$W/entries-k3.tsv" "$W/entries-k4.tsv" \
  "$W/specs.tsv" "$W/floor.tsv" "$W/replay.tsv" > "$W/features.tsv"

FH="seed,pid,sym,screen,exit_trigger,nav_at_screen,base_pnl"
for n in 8 13 26; do for m in 2 4 8; do FH="$FH,n${n}m${m}_status,n${n}m${m}_stop_dist,n${n}m${m}_pnl_gate,n${n}m${m}_pnl_nogate"; done; done
{ echo "$FH"; sort -t"$(printf '\t')" -k1,1n -k4,4 -k2,2 "$W/floor.tsv" | awk -F'\t' -v OFS=, '{ $1 = $1; print }'; } > "$RES/floor.csv"
RH="seed,pid,sym,exit_date,initial_stop_exit"
for w in 8 13 26; do RH="$RH,w${w}_status,w${w}_fill_date,w${w}_trade_pct,w${w}_nav_pct,w${w}_stop_dist,w${w}_rebought_by_run"; done
for v in reentry reentry-nogate; do
  { echo "$RH"; sort -t"$(printf '\t')" -k1,1n -k4,4 -k2,2 "$W/$v.tsv" | awk -F'\t' -v OFS=, '{ $1 = $1; print }'; } > "$RES/$v.csv"; done
{ echo "seed,date,sym,kind,status,nav_pct,stop_dist"; sort -t"$(printf '\t')" -k2,2 -k3,3 "$W/conv.tsv" | awk -F'\t' -v OFS=, '{ $1 = $1; print }'; } > "$RES/floor-conversions.csv"
{ echo "pid,fill_date,trade_pct,nav_pct,ext_screen,ext_fill,E_over_fill,rt4_over_fill,code_stop_dist,book_floor_dist,vol_ratio,rs,weeks_adv,score,ma_slope,ticket_age,macro"
  sort -t"$(printf '\t')" -k2,2 -k1,1 "$W/features.tsv" | awk -F'\t' -v OFS=, '{ $1 = $1; print }'; } > "$RES/features.csv"
awk -F'\t' -f "$L/fsum.awk" "$W/pct.tsv" "$W/floor.tsv" > "$RES/floor-cells.txt"
awk -F'\t' -f "$L/fsame.awk" "$W/pct.tsv" "$W/replay.tsv" "$W/floor.tsv" > "$RES/floor-samesize.txt"
awk -F'\t' -f "$L/csum.awk" "$W/conv.tsv" > "$RES/floor-conversions.txt"
awk -F'\t' -f "$L/quint.awk" "$W/features.tsv" > "$RES/features.txt"
awk -F'\t' -f "$L/rsum.awk" "$W/cashweeks.txt" "$W/reentry.tsv" > "$RES/reentry.txt"
awk -F'\t' -f "$L/rsum.awk" "$W/cashweeks.txt" "$W/reentry-nogate.tsv" > "$RES/reentry-nogate.txt"
awk -F'\t' -f "$L/rrobust.awk" "$W/reentry-nogate.tsv" > "$RES/reentry-robustness.txt"
echo "wrote follow-ups to $RES"

# 5. sizing reads over the result CSVs (QC rework 1 of #3594; no bars): H2' split into its price and size channels,
#    and F1's NAV at risk per trade at the run's position size.
awk -F, -f "$L/sizing.awk" "$RES/replay-k0.csv" "$RES/replay-k1.csv" "$RES/replay-k2.csv" "$RES/replay-k3.csv" \
  "$RES/replay-k4.csv" "$RES/floor.csv" > "$RES/sizing.txt"
echo "wrote sizing.txt to $RES"
