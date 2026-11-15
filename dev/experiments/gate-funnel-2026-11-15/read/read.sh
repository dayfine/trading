#!/bin/sh
# gate-funnel-2026-11-15 read: README §Decision rule and §Descriptive reads on one S cell's candidates.sexp (with the
# #3625/#3626 top-N view) and trade_audit.sexp, self-check first. POSIX sh + awk (mawk-tested), no toolchain needed.
#
# Inputs (environment):
#   CANDS AUDIT TRADES OPENPOS EQUITY ACTUAL   the cell's candidates.sexp, trade_audit.sexp, trades.csv,
#                                              open_positions.csv, equity_curve.csv, actual.sexp
#   PARAMS    the cell's params.sexp (optional): its overrides say whether G3, reserve_cash_for_resting_tickets, is on
#   DATA      bar store root (<A>/<B>/<SYM>/data.csv), the run's own TRADING_DATA_DIR
#   PIT       pit-v12 composition dir (top-3000-YYYY.sexp), the run's universe schedule
#   OUT       mark-free aggregate tables (public repo)
#   PRIV      row-level derived tables, gzipped (private repo dayfine/trading-results; each kept only under 90 MB)
#   WORK      scratch (never committed anywhere: raw closes, names with returns)
#   SEED=0 CAP=20      tiebreak_seed and max_buy_candidates of the cell
#   STORE_END          the run's end date (2026-06-26): a name whose last bar is more than 14 days before it is read as
#                      delisted (fwd.awk). Required: defaulting it to the store's last bar mislabelled truncated rows
#                      as delisted in ../price-band-binding-2026-11-13 (§Defects found 1 there).
#   EVENTS=all|surfaced|none   screen events for the macro proxy: every PIT member, only symbols with a candidate row
#                      (smoke), or none
# Exit 3 when the self-check fails: OUT then holds only selfcheck.txt (README §Self-check).
# EODHD terms: nothing written to OUT carries a price, a bar, a name with its return, or a per-name return.
set -u
: "${CANDS:?}" "${AUDIT:?}" "${TRADES:?}" "${OPENPOS:?}" "${EQUITY:?}" "${ACTUAL:?}" "${DATA:?}" "${PIT:?}" "${OUT:?}" "${PRIV:?}" "${WORK:?}" "${STORE_END:?}"
SEED=${SEED:-0}; CAP=${CAP:-20}; EVENTS=${EVENTS:-all}
HERE=$(cd "$(dirname "$0")" && pwd); L=$HERE/lib
PL=$HERE/../../price-band-binding-2026-11-13/read/lib          # reused unchanged: audit.awk rank.awk dates.awk fwd.awk
SL=$HERE/../../price-band-tiebreak-2026-11-13/screen/lib       # reused unchanged: mscan.awk gspc_weekly.awk
TAB=$(printf '\t')
mkdir -p "$OUT" "$PRIV" "$WORK"; rm -rf "$WORK/req" "$WORK/win"; mkdir -p "$WORK/req" "$WORK/win"
rm -f "$OUT"/*.txt "$OUT"/*.tsv "$PRIV"/*.gz
say() { echo "[$(date -u '+%H:%M:%S')Z] read: $*" >&2; }
fail() { say "FAILED: $*"; exit 2; }
spath() { awk -v D="$DATA" '{ printf "%s\t%s/%s/%s/%s/data.csv\n", $1, D, toupper(substr($1, 1, 1)), toupper(substr($1, length($1), 1)), $1 }'; }
md5f() { (md5sum "$1" 2>/dev/null || md5 -r "$1") | cut -c1-32; }

say "1/8 parse candidates.sexp and trade_audit.sexp"
tr '()' '\n\n' < "$CANDS" | awk -v WEEKS="$WORK/weeks.tsv" -f "$L/cands.awk" > "$WORK/rows.tsv"
tr '()' '\n\n' < "$AUDIT" | awk -v ENTRIES="$WORK/pbb-entries.tsv" -f "$PL/audit.awk" > "$WORK/walk.tsv"
tr '()' '\n\n' < "$AUDIT" | awk -v TICKETS="$WORK/tickets.tsv" -f "$L/summ.awk" > "$WORK/cs.tsv"
[ -s "$WORK/weeks.tsv" ] || fail "no screened dates parsed from $CANDS"
awk -F'\t' '$3 == "Admitted" || $3 == "Dropped_at_top_n"' "$WORK/rows.tsv" > "$WORK/pool_all.tsv"

say "2/8 self-check (README §Self-check)"
{ echo "# gate-funnel self-check (read/read.sh step 2; README §Self-check). SEED=$SEED CAP=$CAP"
  awk -F'\t' -v SEED="$SEED" -v CAP="$CAP" -v OPEN="$WORK/open.tsv" -f "$PL/rank.awk" -f "$L/check.awk" \
    "$WORK/weeks.tsv" "$WORK/cs.tsv" "$WORK/walk.tsv" "$WORK/rows.tsv"; echo "exit $?"; } > "$WORK/sc.txt"
rc=$(tail -1 "$WORK/sc.txt" | sed 's/exit //'); sed '$d' "$WORK/sc.txt" > "$OUT/selfcheck.txt"
if [ "$rc" -ne 0 ]; then
  echo "SELF-CHECK FAILED (exit $rc): the read stops here; no other table is written." >> "$OUT/selfcheck.txt"
  say "SELF-CHECK FAILED"; cat "$OUT/selfcheck.txt" >&2; exit 3
fi
echo "SELF-CHECK PASSED" >> "$OUT/selfcheck.txt"
awk -F'\t' 'FNR == NR { if ($2 == 1) o[$1] = 1; next } $1 in o' "$WORK/open.tsv" "$WORK/pool_all.tsv" > "$WORK/pool.tsv"

say "3/8 m (ticket cost as a NAV fraction) and f (placed -> filled)"
awk -F, 'NR > 1 { print $1 "\t" $2 }' "$EQUITY" > "$WORK/nav.tsv"
LC_ALL=C sort -t "$TAB" -k2,2 "$WORK/tickets.tsv" | awk -F'\t' -v OUTF="$WORK/mfrac.txt" '
  FNR == NR { nn++; ND[nn] = $1; NV[nn] = $2; next }
  $3 == "Long" { nt++; while (i < nn && ND[i + 1] <= $2) i++
    if (i == 0 || NV[i] + 0 <= 0) { nonav++; next } nf++; F[nf] = $4 / NV[i] }
  END { for (a = 2; a <= nf; a++) { t = F[a]; b = a - 1; while (b >= 1 && F[b] > t) { F[b + 1] = F[b]; b-- } F[b + 1] = t }
        printf "%.6f %d %d %d", (nf ? (nf % 2 ? F[(nf + 1) / 2] : (F[nf / 2] + F[nf / 2 + 1]) / 2) : 0), nt, nf, nonav > OUTF
        printf "\t%.4f %.4f %.4f %.4f\n", F[int(nf * .1 + .999)], F[int(nf * .25 + .999)], F[int(nf * .75 + .999)], F[int(nf * .9 + .999)] > OUTF }' \
  "$WORK/nav.tsv" -
read -r M NT NF NONAV Q10 Q25 Q75 Q90 < "$WORK/mfrac.txt" || fail "no placed long ticket"
n_entries=$(( $(awk 'END { print NR - 1 }' "$TRADES") + $(awk 'END { print NR - 1 }' "$OPENPOS") ))
FILL=$(awk -v e="$n_entries" -v t="$NT" 'BEGIN { printf "%.6f", (t > 0) ? e / t : 0 }')
YARD=$(grep -oE 'total_return_pct [-0-9.eE+]+|total_trades [0-9]+' "$ACTUAL" | awk '{ v[$1] = $2 } END { l = log(1 + v["total_return_pct"] / 100); t = v["total_trades"] + 0; printf "%.6f %.4f %d", (t > 0 ? l / t : 0), l, t }')
HOLD=$(grep -oE 'avg_holding_days [0-9.eE+]+' "$ACTUAL" | awk '{ printf "%d", $2 + 0.5 }')
G3=0; [ -n "${PARAMS:-}" ] && grep -q '(reserve_cash_for_resting_tickets true)' "$PARAMS" && G3=1

say "4/8 gate before cap (README §Decision rule)"
{ printf "ticket cost as a NAV fraction (initial_position_value / equity_curve on the decision date): %d placed long tickets, %d with a NAV, %d without; p10 / p25 / p50 / p75 / p90 = %s / %s / %s / %s / %s; m = the median\n" \
    "$NT" "$NF" "$NONAV" "$Q10" "$Q25" "$M" "$Q75" "$Q90"
  printf "fill f = entries %d (trades.csv + open_positions.csv) / placed long tickets %d = %s\n" "$n_entries" "$NT" "$FILL"
  echo "$YARD" | awk '{ printf "yardstick: ln(1 + R) %.4f over %d trades = %.6f log per trade (actual.sexp)\n", $2, $3, $1 }'
  awk -F'\t' -v M="$M" -v FILL="$FILL" -v HOLD="${HOLD:-0}" -v G3="$G3" -v CAP="$CAP" -v FRIDAYS="$WORK/fridays.tsv" -v CROWD="$WORK/crowd.tsv" \
    -v GATES="$WORK/gbcgates.txt" -f "$PL/dates.awk" -f "$L/gbc.awk" "$WORK/open.tsv" "$WORK/weeks.tsv" "$WORK/pool.tsv" || fail "gbc.awk"
} > "$OUT/gate_before_cap.txt"
{ printf 'date\tadmitted\tfunded\tnot_reached\tw_no_structural_stop\tw_stop_too_wide\tw_cash\tw_held\tw_other\tcut\tcut_buyable\tcut_no_structural_stop\tcut_stop_too_wide\tcut_held\tlong_cash_left_pct\tlong_resting_reserved_pct\tfree_net\tslots_gross\tslots_net\tx_gross\tx_net\tcrowded_gross\tcrowded_net\tx_ref\n'
  cat "$WORK/fridays.tsv"; } > "$OUT/fridays.tsv"

say "5/8 the funnel by year (descriptive read 1)"
awk -F'\t' -v TSV="$OUT/funnel_year.tsv" -f "$L/fy.awk" "$WORK/open.tsv" "$WORK/cs.tsv" "$WORK/rows.tsv" > "$OUT/funnel.txt" || fail "fy.awk"

say "6/8 screen events for the macro proxy (EVENTS=$EVENTS)"
: > "$WORK/events.tsv"
if [ "$EVENTS" != none ]; then
  for f in "$PIT"/top-3000-[0-9][0-9][0-9][0-9].sexp; do
    y=$(basename "$f" .sexp | sed 's/top-3000-//')
    grep -o '(symbol [^)]*)' "$f" | sed 's/(symbol //; s/)//' | awk -v y="$y" '{ print $1 "\t" y "-05-31\t" (y + 1) "-05-30" }'
  done > "$WORK/windows.tsv"
  if [ "$EVENTS" = surfaced ]; then
    cut -f2 "$WORK/rows.tsv" | LC_ALL=C sort -u > "$WORK/surfaced.txt"
    awk -F'\t' 'FNR == NR { s[$1] = 1; next } $1 in s' "$WORK/surfaced.txt" "$WORK/windows.tsv" > "$WORK/windows.tmp" && mv "$WORK/windows.tmp" "$WORK/windows.tsv"
  fi
  LC_ALL=C sort -t "$TAB" -k1,1 "$WORK/windows.tsv" |
    awk -F'\t' -v W="$WORK/win" '{ f = W "/" $1; if (f != last) { if (last != "") close(last); last = f } print > f }'
  g="$DATA/G/X/GSPC.INDX/data.csv"; if [ -f "$g" ]; then awk -F, -f "$SL/gspc_weekly.awk" "$g" > "$WORK/gspc_weekly.tsv"; else : > "$WORK/gspc_weekly.tsv"; fi
  ls "$WORK/win" | spath | while IFS="$TAB" read -r sym f; do
    [ -f "$f" ] && awk -F'\t' -v SYM="$sym" -f "$SL/mscan.awk" "$WORK/gspc_weekly.tsv" "$WORK/win/$sym" "$f"
  done > "$WORK/events.tsv"
fi
# An event in the week of a screened Friday that was not open is a breakout the macro gate (or a live block) removed
# before the trace could name it; it is read from that Friday's close, like every other population.
awk -F'\t' -f "$PL/dates.awk" -f "$L/mweek.awk" "$WORK/open.tsv" "$WORK/events.tsv" > "$WORK/macro_events.tsv"
LC_ALL=C sort -t "$TAB" -k1,1 -k2,2 -o "$WORK/macro_events.tsv" "$WORK/macro_events.tsv"

say "7/8 populations and their forward outcomes (descriptive reads 2-3, the ride clause)"
awk -F'\t' -v NALL="$WORK/nall.tsv" -f "$PL/dates.awk" -f "$L/classes.awk" \
  "$WORK/open.tsv" "$WORK/crowd.tsv" "$WORK/macro_events.tsv" "$WORK/rows.tsv" > "$WORK/classes.tsv" || fail "classes.awk"
awk -F'\t' -v OFS='\t' '{ print $3, $2 }' "$WORK/classes.tsv" | LC_ALL=C sort -u -t "$TAB" -k1,1 -k2,2 |
  awk -F'\t' -v R="$WORK/req" '{ f = R "/" $1; if (f != last) { if (last != "") close(last); last = f } print $2 > f }'
say "   STORE_END $STORE_END; $(ls "$WORK/req" | wc -l | tr -d ' ') symbols"
ls "$WORK/req" | spath | while IFS="$TAB" read -r sym f; do
  if [ -f "$f" ]; then awk -F, -v SYM="$sym" -v STORE_END="$STORE_END" -f "$PL/dates.awk" -f "$PL/fwd.awk" "$WORK/req/$sym" "$f"
  else awk -v S="$sym" '{ print S "\t" $1 "\tNA\tNA\tNA\tNA\tNA\tX" }' "$WORK/req/$sym"; fi
done > "$WORK/fwd.tsv"
awk -F'\t' -v CAPR=1.90 -v GATES="$WORK/cfgates.txt" -v ONLY='^(macro|all|brk|sector|grade|cut|crowd|walk|other)' \
  -v TITLE="Descriptive read 2: what each gate's removed names did next, against the funded names (README §Descriptive reads; screen definitions, one row per symbol per 26 weeks)" \
  -f "$L/cf.awk" "$WORK/fwd.tsv" "$WORK/nall.tsv" "$WORK/classes.tsv" > "$OUT/counterfactual.txt" || fail "cf.awk"
awk -F'\t' -v CAPR=1.90 -v GATES=/dev/null -v ONLY='^(tier|score|walk:Funded)' \
  -v TITLE="Descriptive read 3: score against outcome over the post-cascade pool, Admitted + Dropped_at_top_n (tier: one row per symbol per tier per 26 weeks; tierw: every row; score: one per symbol per score per 26 weeks)" \
  -f "$L/cf.awk" "$WORK/fwd.tsv" "$WORK/nall.tsv" "$WORK/classes.tsv" > "$OUT/score.txt" || fail "cf.awk (score)"
# Row-level derived tables (names with returns): private repo only, gzipped, and only under 90 MB.
awk -F'\t' -v OFS='\t' 'FNR == NR { k[$1, $2] = $5 OFS $7 OFS $8; next }
  { o = (($2, $1) in k) ? k[$2, $1] : "NA" OFS "NA" OFS "X"; print $0, o }' "$WORK/fwd.tsv" "$WORK/pool.tsv" |
  { printf 'date\tsymbol\toutcome\tgate\tscore\trank\twalk\twalk_dist\tshadow\tshadow_dist\tgrade\tmonster\tride\tcov\n'; cat; } | gzip -9 > "$WORK/pool_outcomes.tsv.gz"
awk -F'\t' -v OFS='\t' 'FNR == NR { k[$1, $2] = $5 OFS $7 OFS $8; next }
  { o = (($2, $1) in k) ? k[$2, $1] : "NA" OFS "NA" OFS "X"; print $0, o }' "$WORK/fwd.tsv" "$WORK/crowd.tsv" |
  { printf 'date\tsymbol\trank\tin_cstar_gross\tin_cstar_net\tmonster\tride\tcov\n'; cat; } | gzip -9 > "$WORK/crowd_outcomes.tsv.gz"
rm -f "$WORK/priv.txt"
for f in pool_outcomes.tsv.gz crowd_outcomes.tsv.gz; do
  sz=$(wc -c < "$WORK/$f" | tr -d ' ')
  if [ "$sz" -lt 94371840 ]; then cp "$WORK/$f" "$PRIV/$f"; echo "$f $sz bytes: private" >> "$WORK/priv.txt"; else echo "$f $sz bytes: over 90 MB, kept nowhere" >> "$WORK/priv.txt"; fi
done

say "8/8 the pre-registered rules, applied mechanically (README §Decision rule)"
cat "$WORK/gbcgates.txt" "$WORK/cfgates.txt" | awk -v YARD="$YARD" -f "$L/rules.awk" > "$OUT/rules.txt"
{ echo "# inputs of this read"
  echo "SEED=$SEED CAP=$CAP EVENTS=$EVENTS STORE_END=$STORE_END G3=$G3 (reserve_cash_for_resting_tickets; net free cash = gross when 1)"
  echo "candidates.sexp md5 $(md5f "$CANDS") bytes $(wc -c < "$CANDS" | tr -d ' ')"
  echo "trade_audit.sexp md5 $(md5f "$AUDIT")"
  echo "trades.csv md5 $(md5f "$TRADES")"
  echo "screened dates $(wc -l < "$WORK/weeks.tsv" | tr -d ' '), Long rows $(wc -l < "$WORK/rows.tsv" | tr -d ' '), pool rows on open Fridays $(wc -l < "$WORK/pool.tsv" | tr -d ' '), walk rows $(wc -l < "$WORK/walk.tsv" | tr -d ' '), placed long tickets $NT, entries $n_entries, screen events $(wc -l < "$WORK/events.tsv" | tr -d ' '), macro-proxy events $(wc -l < "$WORK/macro_events.tsv" | tr -d ' '), forward-outcome requests $(wc -l < "$WORK/fwd.tsv" | tr -d ' ')"
  cat "$WORK/priv.txt"
} > "$OUT/inputs.txt"
say "done: $OUT (private: $PRIV)"
