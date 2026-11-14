#!/bin/sh
# t3.sh -- applies README §"Pre-registered reads" #3136 T3 (attribution, read in decision order) to the committed
# W0 / Wtd artifacts, as written. Prints every quantity the read uses:
#   rows      every arm-only, base-only and changed-* row of firstdiff.txt (id-shift rows excluded), with its id (the
#             arm's for arm-only / changed-arm, the base's for base-only / changed-base) and its decision date (the
#             <tag>-entries.tsv placed row with that id); a changed pair is printed once with both ids and the
#             columns that differ (position_id excepted)
#   divisor   F at the row's entry date, as td-full's True_dollar_divisor reads it (read/divisor.awk): data.csv from
#             the checkout's trading/test_data where it has one (README §Data step 2: committed files win), else from
#             the bar store; splits.csv from SPLITS_ROOT. Also F on the bar store's full-history data.csv, and F on
#             close-confirmed splits only (the README's wording, without the code's volume check)
#   gate      the $1M entry gate (20-bar Mean, the record's Liquidity_config) at the decision date, from the bar
#             store's data.csv, as three flags: stored passes, true passes, true pass rests on one bar (#3136 O2)
#   class     blocked->admitted (arm-only row, F < 1, stored fails and true passes at the decision date)
#             admitted->blocked (base-only row, F > 1, stored passes and true fails)
#             hold-exit-changed (changed pair whose exit_trigger differs with liquidity_exit on one side)
#             displacement      (every other differing row: sizing, a freed or consumed slot, cash, a moved week)
#   F         the smallest id among rows on a symbol with F != 1 at its entry date (computed on both F definitions);
#             T3 passes if F exists and no differing row has an id below F. Rows below F are listed for the
#             trace-before-FAIL step.
#   hold      for each hold-exit-changed pair, the first Friday from entry on which the hold floor
#             (min_hold_dollar_adv in the arm's params.sexp) reads pass on the stored basis and fail on the true one
#   clock     the first placed id of each extract (the warmup year draws ids too) and the first placed decision
#             (symbol|date) that is in one extract only
# Prints derived divisors and pass/fail flags only, never a bar, price, volume or split row (EODHD terms).
#
# usage: sh t3.sh RESULTS_DIR DATA_DIR TEST_DATA_DIR [SPLITS_ROOT]
#   RESULTS_DIR    dev/experiments/chain-w-2026-11-10/results
#   DATA_DIR       a bar store laid out <L1>/<L2>/<SYM>/{data,splits}.csv (stands in for bars/data-20261102)
#   TEST_DATA_DIR  the run tree's trading/test_data (unchanged from b54e44ea9 to the reading's checkout)
#   SPLITS_ROOT    an unpacked corpact-2026-10-27 (default DATA_DIR; the script reports any splits.csv that differs)
set -u
R=${1:?usage: sh t3.sh RESULTS_DIR DATA_DIR TEST_DATA_DIR [SPLITS_ROOT]}; D=${2:?}; T=${3:?}; SP=${4:-$2}
HERE=$(cd "$(dirname "$0")" && pwd); AWK_DIV=$HERE/divisor.awk
W=${TMPDIR:-/tmp}/t3.$$; mkdir -p "$W"; trap 'rm -rf "$W"' EXIT
GATE=$(tr -s '() \n' '    ' < "$R/cw-Wtd-s0-params.sexp" | awk '{ for (i = 1; i < NF; i++) if ($i == "min_entry_dollar_adv") print $(i + 1) + 0 }')
HOLD=$(tr -s '() \n' '    ' < "$R/cw-Wtd-s0-params.sexp" | awk '{ for (i = 1; i < NF; i++) if ($i == "min_hold_dollar_adv") print $(i + 1) + 0 }')

shard() { printf %s "$1" | awk '{ print toupper(substr($0, 1, 1)) "/" toupper(substr($0, length($0), 1)) "/" $0 }'; }
splits_of() { s=$SP/$(shard "$1")/splits.csv; [ -f "$s" ] && { echo "$s"; return; }; echo "date,factor" > "$W/nosplits"; echo "$W/nosplits"; }
asrun_of() { p=$(shard "$1"); if [ -f "$T/$p/data.csv" ]; then echo "$T/$p/data.csv"; else echo "$D/$p/data.csv"; fi; }

# --- 0. the decision clock
for a in W0 Wtd; do
  awk -F'\t' '$4 == "placed" { id = $1; sub(/.*-wein-/, "", id); print id "\t" $3 "\t" $2 }' "$R/cw-$a-s0-entries.tsv" |
    sort -n -k1,1 > "$W/dec-$a"
done
echo "clock: first placed id W0 $(head -1 "$W/dec-W0" | cut -f1,3 | tr '\t' ' '), Wtd $(head -1 "$W/dec-Wtd" | cut -f1,3 | tr '\t' ' ')"
awk -F'\t' 'FILENAME == ARGV[1] { a[$3 "|" $2] = $1; next } { b[$3 "|" $2] = $1; if (!($3 "|" $2 in a)) { print "W0 lacks\t" $2 "\t" $3 "\tWtd id " $1 } }
  END { for (k in a) if (!(k in b)) { split(k, p, "|"); print "Wtd lacks\t" p[2] "\t" p[1] "\tW0 id " a[k] } }' "$W/dec-W0" "$W/dec-Wtd" |
  LC_ALL=C sort -t "$(printf '\t')" -k2,2 | head -1 | awk -F'\t' '{ print "clock: first placed decision in one extract only: " $3 " " $2 " (" $1 ", " $4 ")" }'

# --- 1. differing rows: id, kind, symbol, entry_date, exit_date, exit_trigger, full row
awk -F'\t' '$3 == "arm-only" || $3 == "base-only" || $3 == "changed-base" || $3 == "changed-arm" {
    n = split($4, f, ","); id = f[20]; sub(/.*-wein-/, "", id)
    print id "\t" $3 "\t" $2 "\t" $1 "\t" f[4] "\t" f[13] "\t" $4 }' "$R/firstdiff.txt" > "$W/rows"

# --- 2. divisor and gate flags per symbol (query dates: entry dates for F, decision dates for the gate)
awk -F'\t' 'FILENAME == ARGV[1] { dW0[$1] = $2; next } FILENAME == ARGV[2] { dWtd[$1] = $2; next }
  { dd = ($2 ~ /arm/) ? dWtd[$1] : dW0[$1]; print $3 "\t" $4 "\t" (dd == "" ? "-" : dd) }' \
  "$W/dec-W0" "$W/dec-Wtd" "$W/rows" > "$W/q"
: > "$W/div"; : > "$W/gate"; nsp=0; ntd=0
for s in $(cut -f1 "$W/q" | LC_ALL=C sort -u); do
  p=$(shard "$s"); full=$D/$p/data.csv; asrun=$(asrun_of "$s"); spl=$(splits_of "$s")
  [ "$asrun" != "$full" ] && ntd=$((ntd + 1))
  [ "$SP" != "$D" ] && [ -f "$D/$p/splits.csv" ] && ! cmp -s "$spl" "$D/$p/splits.csv" && { nsp=$((nsp + 1)); echo "splits differ from DATA_DIR: $s" >&2; }
  if [ ! -f "$full" ]; then echo "$s: no data.csv in DATA_DIR" >&2; continue; fi
  awk -F'\t' -v s="$s" '$1 == s { print $2 }' "$W/q" | LC_ALL=C sort -u > "$W/qd"
  awk -v sym="$s" -f "$AWK_DIV" "$spl" "$asrun" "$asrun" "$W/qd" | awk '{ print $0 "\tasrun" }' >> "$W/div"
  awk -v sym="$s" -f "$AWK_DIV" "$spl" "$full" "$full" "$W/qd" | awk '{ print $0 "\tfull" }' >> "$W/div"
  awk -F'\t' -v s="$s" -v g="$GATE" '$1 == s && $3 != "-" { print $3 "\t" g }' "$W/q" | LC_ALL=C sort -u > "$W/qg"
  [ -s "$W/qg" ] && awk -v sym="$s" -v mode=adv -f "$AWK_DIV" "$spl" "$asrun" "$full" "$W/qg" >> "$W/gate"
done
echo "symbols: $(cut -f1 "$W/q" | LC_ALL=C sort -u | wc -l | tr -d ' ') differing; $ntd read data.csv from TEST_DATA_DIR (td-full step 2); splits.csv differing from DATA_DIR: $nsp; entry gate $GATE, hold floor $HOLD"

# --- 3. the table, F and the verdict
awk -F'\t' '
  FILENAME == ARGV[1] { if ($NF == "asrun") { Fa[$1 "|" $2] = $3; Fc[$1 "|" $2] = $4 } else Ff[$1 "|" $2] = $3; next }
  FILENAME == ARGV[2] { g3[$1 "|" $2] = $4 "" $5 "" $7; next }
  FILENAME == ARGV[3] { dec[$1] = $2; next }
  FILENAME == ARGV[4] { decA[$1] = $2; next }
  {
    id = $1; kind = $2; sym = $3; ed = $4; key = sym "|" ed
    d = (kind ~ /arm/) ? decA[id] : dec[id]; if (d == "") d = "-"
    fa = Fa[key]; ff = Ff[key]; fc = Fc[key]
    if (kind == "changed-base") { cb[key] = $0; cbid[key] = id; cbd[key] = d; next }
    if (kind == "changed-arm") {
      split(cb[key], x, "\t"); split(x[7], xb, ","); split($7, ya, ",")
      ch = ""; for (i = 1; i <= 25; i++) if (i != 20 && xb[i] != ya[i]) ch = ch (ch == "" ? "" : "+") H[i]
      cls = "displacement"
      if (xb[13] != ya[13] && (xb[13] == "liquidity_exit" || ya[13] == "liquidity_exit")) {
        cls = "hold-exit-changed"; print sym "\t" ed "\t" (xb[4] < ya[4] ? xb[4] : ya[4]) > "/dev/stderr" }
      emit(cbid[key] "/" id, "changed", sym, ed, cbd[key] "/" d, fa, ff, fc, "-", ch, cls)
      add(cbid[key], fa, fc, "changed " sym " " ed " (base id)"); add(id, fa, fc, "changed " sym " " ed " (arm id)")
      next
    }
    g = g3[sym "|" d]; if (g == "") g = "---"
    cls = "displacement"
    if (kind == "arm-only" && fa + 0 < 1 && substr(g, 1, 2) == "01") cls = "blocked->admitted"
    if (kind == "base-only" && fa + 0 > 1 && substr(g, 1, 2) == "10") cls = "admitted->blocked"
    emit(id, kind, sym, ed, d, fa, ff, fc, g, "-", cls)
    add(id, fa, fc, kind " " sym " " ed)
  }
  function add(id, fa, fc, why) { ids[++nid] = id; idf[nid] = fa; idc[nid] = fc; idr[nid] = why }
  function emit(id, kind, sym, ed, d, fa, ff, fc, g, ch, cls) {
    nrow++; out[nrow] = id "\t" kind "\t" sym "\t" ed "\t" d "\t" fa "\t" ff "\t" fc "\t" g "\t" ch "\t" cls
    n_cls[cls]++; if (fa + 0 != 1) n_div[cls]++
  }
  function fmin(arr,    i, m) { m = -1; for (i = 1; i <= nid; i++) if (arr[i] != "" && arr[i] + 0 != 1 && (m < 0 || ids[i] + 0 < m)) { m = ids[i] + 0; mwhy = idr[i] }; return m }
  BEGIN { split("symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger,entry_stage,entry_volume_ratio,stop_initial_distance_pct,stop_trigger_kind,days_to_first_stop_trigger,screener_score_at_entry,position_id,stop_fill_distance_pct,max_stop,n_stop_raises,entry_anchor,dividends_received", H, ",") }
  END {
    print "id(s)\tkind\tsymbol\tentry_date\tdecision_date\tF_asrun\tF_full\tF_closeonly\tgate_s|t|onebar\tchanged_columns\tclass"
    for (i = 1; i <= nrow; i++) print out[i]
    print ""
    for (c in n_cls) printf "class %s: %d rows (%d on a symbol with F != 1)\n", c, n_cls[c], n_div[c] + 0
    nmiss = 0; for (i = 1; i <= nid; i++) if (idf[i] == "") nmiss++
    if (nmiss) printf "WARNING: %d ids have no divisor (no data.csv)\n", nmiss
    Fc_id = fmin(idc); Fc_why = mwhy; Fid = fmin(idf)
    if (Fid < 0) { print "F: none (no differing row sits on a symbol with F != 1): T3 has no F, no decision is recorded"; exit }
    printf "F = %d (%s); on close-confirmed splits only F = %d (%s)\n", Fid, mwhy, Fc_id, Fc_why
    nb = 0; for (i = 1; i <= nid; i++) if (ids[i] + 0 < Fid) { nb++; printf "below F: id %d %s\n", ids[i], idr[i] }
    printf "rows with an id below F: %d -> T3 %s\n", nb, (nb == 0 ? "PASS" : "needs the trace-before-FAIL step (README T3)")
  }' "$W/div" "$W/gate" "$W/dec-W0" "$W/dec-Wtd" "$W/rows" 2> "$W/hold"

# --- 4. hold-exit pairs: the first Friday from entry on which the hold floor flips (stored passes, true fails)
while IFS="$(printf '\t')" read -r s ed xd; do
  full=$D/$(shard "$s")/data.csv
  awk -F, -v a="$ed" -v b="$xd" -v h="$HOLD" 'NR > 1 && $1 >= a && $1 <= b {
      split($1, t, "-"); y = t[1] + 0; m = t[2] + 0; d = t[3] + 0; if (m < 3) { m += 12; y-- }
      if ((d + int(13 * (m + 1) / 5) + y + int(y / 4) - int(y / 100) + int(y / 400)) % 7 == 6) print $1 "\t" h }' "$full" > "$W/qh"
  awk -v sym="$s" -v mode=adv -f "$AWK_DIV" "$(splits_of "$s")" "$(asrun_of "$s")" "$full" "$W/qh" |
    awk -F'\t' -v s="$s" -v ed="$ed" '{ n++ } $4 == 1 && $5 == 0 && !f { f = $2 } $4 == 0 { sf++ }
      END { printf "hold %s (entry %s): %d Fridays to the earlier exit; first Friday stored passes and true fails: %s; Fridays stored fails: %d\n", s, ed, n, (f ? f : "none"), sf }'
done < "$W/hold"

# --- 5. decision level (the README's known limitation: F sees only decisions that leave a trades.csv row): every
# placed decision (symbol|decision date) in one extract only, filled or not, with F and the gate flags at that date
for a in W0 Wtd; do awk -F'\t' '{ print $3 "|" $2 "\t" $1 }' "$W/dec-$a" | LC_ALL=C sort > "$W/pk-$a"; done
{ LC_ALL=C join -t "$(printf '\t')" -v1 "$W/pk-W0" "$W/pk-Wtd" | awk -F'\t' '{ print $0 "\tW0 only" }'
  LC_ALL=C join -t "$(printf '\t')" -v2 "$W/pk-W0" "$W/pk-Wtd" | awk -F'\t' '{ print $0 "\tWtd only" }'; } > "$W/pk-diff"
echo "decision level: $(wc -l < "$W/pk-diff" | tr -d ' ') placed decisions in one extract only (symbol, decision date, id, arm, F as run, gate s|t|onebar, trades.csv row):"
while IFS="$(printf '\t')" read -r k id side; do
  s=${k%%|*}; d=${k#*|}; full=$D/$(shard "$s")/data.csv; asrun=$(asrun_of "$s"); spl=$(splits_of "$s")
  echo "$d" > "$W/q1"; printf '%s\t%s\n' "$d" "$GATE" > "$W/q1g"
  f=$(awk -v sym="$s" -f "$AWK_DIV" "$spl" "$asrun" "$asrun" "$W/q1" | cut -f3)
  g=$(awk -v sym="$s" -v mode=adv -f "$AWK_DIV" "$spl" "$asrun" "$full" "$W/q1g" | awk -F'\t' '{ print $4 $5 $7 }')
  tag=$( [ "$side" = "W0 only" ] && echo W0 || echo Wtd )
  row=$(awk -F, -v id="$id" '{ n = $20; sub(/.*-wein-/, "", n) } n == id { print "row " $3 }' "$R/cw-$tag-s0-trades.csv")
  printf '  %s\t%s\t%s\t%s\tF %s\tgate %s\t%s\n' "$s" "$d" "$id" "$side" "$f" "$g" "${row:-no row}"
done < "$W/pk-diff" | LC_ALL=C sort -t "$(printf '\t')" -k2,2 -k1,1
