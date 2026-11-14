#!/bin/sh
# price-band-binding-2026-11-13 read: the four measurements of README.md §Measurements on one S cell's
# candidates.sexp + trade_audit.sexp, self-check first. POSIX sh + awk (mawk-tested), no container toolchain needed.
#
# Inputs (environment):
#   CANDS AUDIT TRADES OPENPOS   the cell's candidates.sexp, trade_audit.sexp, trades.csv, open_positions.csv
#   DATA      bar store root (<A>/<B>/<SYM>/data.csv), the run's own TRADING_DATA_DIR
#   PIT       pit-v12 composition dir (top-3000-YYYY.sexp), the run's universe schedule
#   OUT       where the aggregate tables go (committed)      WORK  scratch (never committed: it holds raw closes)
#   SEED=0 CAP=20                tiebreak_seed and max_buy_candidates of the cell
#   EVENTS=all|surfaced          screen events of every PIT member, or (smoke) only symbols with a candidate row
#   STORE_END                    last bar date of the store (default: the latest last bar among the pool's names;
#                                the committed test_data overlay can carry older index files, so not GSPC)
# Exit 3 when the self-check fails: OUT then holds only selfcheck.txt, which says why (README §Self-check).
# EODHD terms: nothing written to OUT carries a price, a bar or a per-name return; WORK does and stays local.
set -u
: "${CANDS:?}" "${AUDIT:?}" "${TRADES:?}" "${OPENPOS:?}" "${DATA:?}" "${PIT:?}" "${OUT:?}" "${WORK:?}"
SEED=${SEED:-0}; CAP=${CAP:-20}; EVENTS=${EVENTS:-all}
HERE=$(cd "$(dirname "$0")" && pwd); L=$HERE/lib; SL=$HERE/../../price-band-tiebreak-2026-11-13/screen/lib
TAB=$(printf '\t')
# r(b): S's >= +100 % trades per entry by entry-price band, pooled over #3595's five S cells (README §Measurement 2).
R0=0.080357; R1=0.046083; R2=0.009662; R3=0.008902
mkdir -p "$OUT" "$WORK"; rm -rf "$WORK/req" "$WORK/win"; mkdir -p "$WORK/req" "$WORK/win"
say() { echo "[$(date -u '+%H:%M:%S')Z] read: $*" >&2; }
fail() { say "FAILED: $*"; exit 2; }
spath() { awk -v D="$DATA" '{ printf "%s\t%s/%s/%s/%s/data.csv\n", $1, D, toupper(substr($1, 1, 1)), toupper(substr($1, length($1), 1)), $1 }'; }

say "1/7 parse candidates.sexp and trade_audit.sexp"
tr '()' '\n\n' < "$CANDS" | awk -v WEEKS="$WORK/weeks.tsv" -f "$L/cands.awk" > "$WORK/rows.tsv"
tr '()' '\n\n' < "$AUDIT" | awk -v ENTRIES="$WORK/entries.tsv" -f "$L/audit.awk" > "$WORK/walk.tsv"
[ -s "$WORK/weeks.tsv" ] || { echo "no screened dates parsed from $CANDS" >&2; exit 2; }
awk -F'\t' '$3 == "Admitted" || $3 == "Dropped_at_top_n"' "$WORK/rows.tsv" > "$WORK/pool0.tsv"

say "2/7 decision-date raw close and ex-post outcomes per symbol"
{ awk -F'\t' -v OFS='\t' '{ print $2, $1 }' "$WORK/pool0.tsv"
  awk -F'\t' -v OFS='\t' '$3 == "Long" { print $1, $2 }' "$WORK/entries.tsv"; } |
  LC_ALL=C sort -u -t "$TAB" -k1,1 -k2,2 |
  awk -F'\t' -v R="$WORK/req" '{ f = R "/" $1; if (f != last) { if (last != "") close(last); last = f } print $2 > f }'
if [ -z "${STORE_END:-}" ]; then
  STORE_END=$(ls "$WORK/req" | spath | while IFS="$TAB" read -r sym f; do [ -f "$f" ] && tail -1 "$f" | cut -d, -f1; done | LC_ALL=C sort | tail -1)
fi
: "${STORE_END:?no bar file for any pool name under DATA}"
say "   STORE_END $STORE_END"
ls "$WORK/req" | spath | while IFS="$TAB" read -r sym f; do
  if [ -f "$f" ]; then awk -F, -v SYM="$sym" -v STORE_END="$STORE_END" -f "$L/dates.awk" -f "$L/fwd.awk" "$WORK/req/$sym" "$f"
  else awk -v S="$sym" '{ print S "\t" $1 "\tNA\tNA\tNA\tNA\tNA\tX" }' "$WORK/req/$sym"; fi
done > "$WORK/fwd.tsv"
awk -F'\t' -v OFS='\t' 'FNR == NR { B[$1, $2] = $4; next } { b = (($2, $1) in B) ? B[$2, $1] : "NA"; print $1, $2, $3, $5, b }' \
  "$WORK/fwd.tsv" "$WORK/pool0.tsv" | LC_ALL=C sort -s -t "$TAB" -k1,1 > "$WORK/pool.tsv"

say "3/7 self-check (README §Self-check)"
n_entries=$(( $(awk 'END { print NR - 1 }' "$TRADES") + $(awk 'END { print NR - 1 }' "$OPENPOS") ))
{ echo "# price-band-binding self-check (read/read.sh step 3; README §Self-check). SEED=$SEED CAP=$CAP"
  awk -F'\t' -v AG="$WORK/agates.txt" 'FNR == NR { B[$1, $2] = $4; C[$1, $2] = $3; next }
    $3 == "Long" { b = B[$1, $2]; if (b == "" || b == "NA") { na++; next }
      n++; s = ($4 >= 8) + ($4 >= 14) + ($4 >= 33); agree += (s == b)
      if ($5 != "NA") { m++; c = ($5 >= 8) + ($5 >= 14) + ($5 >= 33); cagree += (c == b) } }
    END { printf "band proxy (decision-date raw close from the bar store) vs the ticket band (suggested_entry): %d of %d placed tickets (trade_audit entry records) agree (%.1f %%); %d without a bar\n", agree, n, (n ? 100 * agree / n : 0), na
          printf "bar lookup vs trade_audit close_at_decision band: %d of %d agree (%.1f %%)\n", cagree, m, (m ? 100 * cagree / m : 0)
          printf "AG %.4f\n", (n ? agree / n : 0) > AG }' \
    "$WORK/fwd.tsv" "$WORK/entries.tsv"; } > "$OUT/selfcheck.txt"
awk -F'\t' -v SEED="$SEED" -v CAP="$CAP" -v MODE=check -v FRIDAYS=/dev/null -v SWAPS=/dev/null -v SELF="$WORK/sc.txt" \
  -v GATES=/dev/null -v N_ENTRIES="$n_entries" -f "$L/rank.awk" -f "$L/bind.awk" "$WORK/weeks.tsv" "$WORK/walk.tsv" "$WORK/pool.tsv"
rc=$?; cat "$WORK/sc.txt" >> "$OUT/selfcheck.txt"
if [ "$rc" -ne 0 ]; then
  echo "SELF-CHECK FAILED (exit $rc): the read stops here; no binding, tail or funnel table is written." >> "$OUT/selfcheck.txt"
  say "SELF-CHECK FAILED"; cat "$OUT/selfcheck.txt" >&2; exit 3
fi
echo "SELF-CHECK PASSED" >> "$OUT/selfcheck.txt"

say "4/7 binding and E_net (Measurements 1-2)"
awk -F'\t' -v SEED="$SEED" -v CAP="$CAP" -v FRIDAYS="$WORK/fridays.tsv" -v SWAPS="$WORK/swaps.tsv" -v SELF=/dev/null \
  -v GATES="$WORK/bgates.txt" -v N_ENTRIES="$n_entries" -v R0=$R0 -v R1=$R1 -v R2=$R2 -v R3=$R3 \
  -f "$L/rank.awk" -f "$L/bind.awk" "$WORK/weeks.tsv" "$WORK/walk.tsv" "$WORK/pool.tsv" > "$OUT/binding.txt" || fail "bind.awk"
{ printf 'date\tn_long\tn_pool\tn_admitted\tbinding\ttie_at_cut\tmultiband_tie\tchanged\tswaps\torder_changed\tsc1\tsc2\talpha\tn_walk\tn_placed\n'
  cat "$WORK/fridays.tsv"; } > "$OUT/fridays.tsv"
{ printf 'date\tdir\tsymbol\tband\tscore\trank_S\trank_P\n'; cat "$WORK/swaps.tsv"; } > "$OUT/swaps.tsv"

say "5/7 swap tail (Measurement 3)"
LC_ALL=C sort -s -t "$TAB" -k1,1 "$WORK/swaps.tsv" |
  awk -F'\t' -v CAPR=1.90 -v GATES="$WORK/tgates.txt" -f "$L/dates.awk" -f "$L/tail.awk" "$WORK/fwd.tsv" - > "$OUT/swap_tail.txt" || fail "tail.awk"

say "6/7 screen events and the funnel (Measurement 4; EVENTS=$EVENTS)"
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
awk -F'\t' -v GATES="$WORK/fgates.txt" -f "$L/dates.awk" -f "$L/rank.awk" -f "$L/funnel.awk" \
  "$WORK/weeks.tsv" "$WORK/events.tsv" "$WORK/rows.tsv" > "$OUT/funnel.txt" || fail "funnel.awk"

say "7/7 the pre-registered rules, applied mechanically (README §Decision rules)"
cat "$WORK/agates.txt" "$WORK/bgates.txt" "$WORK/tgates.txt" "$WORK/fgates.txt" | tr '\n' ' ' | awk '{
  for (i = 1; i < NF; i += 2) v[$i] = ($(i + 1) ~ /^[-+0-9.]+$/) ? $(i + 1) + 0 : $(i + 1)
  L1 = v["L1"]; L2 = v["L2"]; tr = v["T_ratio"]; tm = v["T_monsters"]; td = v["T_ride_diff"]
  # Rule 1, in README order; each branch prints its own reason.
  bpass = (L1 >= 0.25 && L2 >= 1.5)
  tfail = (tm >= 20 && (tr < 1.0 || td <= 0)); tpass = (tm >= 20 && tr >= 1.5 && v["T_h1_in_gt_out"] && v["T_h2_in_gt_out"] && td > 0)
  printf "Rule 1 inputs: L1 %.4f (bar 0.25) | L2 E_net %.3f (bars 0.75 / 1.5) | T ratio %.3f (bars 1.0 / 1.5), in>out 2000-12 %d, 2013-26 %d, monsters %d (min 20), ride diff %+.4f\n", L1, L2, tr, v["T_h1_in_gt_out"], v["T_h2_in_gt_out"], tm, td
  if (L2 < 0.75) r1 = "CLOSE-AXIS (L2 < 0.75: the expected direct tail effect is under about 0.1 log, half the about-0.2-log 26-year noise floor; keep as a default-off axis)"
  else if (L1 < 0.25) r1 = "PARK (L1 < 0.25: the order rarely changes the top 20 on binding dates, so the #3595 binds-often correction does not hold; but L2 >= 0.75, its cash-order re-draws still carry an expected tail at or above the bar, so no grounds to close)"
  else if (tfail) r1 = "CLOSE-AXIS (T: the order binds, but among tied names it swaps in no fatter tail; keep as a default-off axis)"
  else if (bpass && tpass) r1 = "FRESH-PREREGISTRATION (L1 >= 0.25, L2 >= 1.5 and T passes)"
  else r1 = "PARK (binding and tail are not decisive: L2 between 0.75 and 1.5, or T short of its bars)"
  if (v["AG"] < 0.90) r1 = sprintf("NOT APPLIED (the band proxy agrees with the ticket band on %.1f %% of placed tickets, below 90 %%)", 100 * v["AG"])
  printf "Rule 1 (tiebreak), mechanical: %s\n", r1
  # Rule 2, in README order: UNDERPOWERED, DIAL-STUDY (both views), one view only, lift below the share bar, NOTHING.
  ne = split(v["F_exact"], a, ","); nw = split(v["F_window"], b, ","); hit = ""; one = ""
  for (i = 1; i <= ne; i++) if (a[i] != "none") { if (index("," v["F_window"] ",", "," a[i] ",")) hit = hit " " a[i]; else one = one " " a[i] }
  for (i = 1; i <= nw; i++) if (b[i] != "none" && !index("," v["F_exact"] ",", "," b[i] ",")) one = one " " b[i]
  lift = ""; if (v["F_lift_exact"] != "none") lift = lift " exact:" v["F_lift_exact"]; if (v["F_lift_window"] != "none") lift = lift " window:" v["F_lift_window"]
  printf "Rule 2 inputs: hits (all three bars) exact %s, window %s | lift >= 1.25 at any share: exact %s, window %s | cheap monsters with a cascade row: exact %d, window %d (min 30 each)\n", v["F_exact"], v["F_window"], v["F_lift_exact"], v["F_lift_window"], v["F_cheap_monsters_exact"], v["F_cheap_monsters_window"]
  if (v["F_cheap_monsters_exact"] < 30 || v["F_cheap_monsters_window"] < 30) r2 = "UNDERPOWERED (fewer than 30 cheap monsters with a cascade row in a view): no conclusion"
  else if (hit != "") r2 = "DIAL-STUDY on" hit
  else if (one != "") r2 = "NO CONCLUSION (passes in one view only:" one ")"
  else if (lift != "") r2 = "NO CONCLUSION (lift >= 1.25 but under the 20 % share:" lift ")"
  else r2 = "NOTHING (breadth: no sub-gate is first to drop cheap monsters 1.25x as often as cheap breakouts, in either view)"
  printf "Rule 2 (sub-gate), mechanical: %s\n", r2
}' > "$OUT/rules.txt"
{ echo "# inputs of this read"
  echo "SEED=$SEED CAP=$CAP EVENTS=$EVENTS STORE_END=$STORE_END"
  echo "candidates.sexp md5 $( (md5sum "$CANDS" 2>/dev/null || md5 -r "$CANDS") | cut -c1-32) bytes $(wc -c < "$CANDS" | tr -d ' ')"
  echo "trade_audit.sexp md5 $( (md5sum "$AUDIT" 2>/dev/null || md5 -r "$AUDIT") | cut -c1-32)"
  echo "trades.csv md5 $( (md5sum "$TRADES" 2>/dev/null || md5 -r "$TRADES") | cut -c1-32)"
  echo "screened dates $(wc -l < "$WORK/weeks.tsv" | tr -d ' '), Long rows $(wc -l < "$WORK/rows.tsv" | tr -d ' '), pool rows $(wc -l < "$WORK/pool.tsv" | tr -d ' '), walk rows $(wc -l < "$WORK/walk.tsv" | tr -d ' '), entries $n_entries, screen events $(wc -l < "$WORK/events.tsv" | tr -d ' ')"
} > "$OUT/inputs.txt"
say "done: $OUT"
