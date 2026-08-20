#!/bin/sh
# E4 / #2407 phase 2 — split filled tickets into base-HELD and base-BROKEN and
# attribute realized P&L to each.
#
# THE QUESTION (#2407): a resting ticket's E was derived from a base. If that
# base broke while the ticket rested, the eventual fill is at a level nothing
# current justifies. How much of the record's return comes from such fills?
#
# ⚠ WHICH DATE IS THE FILL. `trade_audit.entry_decision.entry_date` is the
# PLACEMENT date, not the fill — it equals `ticket_lifecycle.placement_date` on
# all 1,466 records of the 26y record base, while the same records carry
# `ticket_age_weeks_at_fill` up to 865. The actual fill date is `trades.csv`'s
# `entry_date`. Verified: YUM-wein-2785 audit 2009-11-27 + 14wk ≈ trades entry
# 2010-03-09. Using the audit date for both ends makes the rest window empty and
# every ticket reads base-HELD — which is exactly what the first version of this
# script reported.
#
# THE DISCRIMINATOR, three ways (report all three — a cohort split believed off
# one cutoff is how feedback_perturb_before_believing_a_cohort_split happened):
#   broken_stop : a close between placement and fill fell below the ticket's own
#                 suggested_stop — the level the strategy itself would have
#                 exited at.
#   broken_4w   : ...below the base low, = min low over the 4 weeks ending at
#                 placement (the same window that defined local_range_top when
#                 entry_anchor_local_range_weeks = 4).
#   broken_8w   : ...below the 8-week base low. Width perturbation.
#
# NOT age. Age is what the clock cuts and what #2407 argues is the wrong
# variable; rest days are carried per row so the two can be cross-tabbed.
#
# JOIN KEY IS position_id, ALWAYS (feedback_position_id_is_the_only_join_key).
#
# Usage: measure.sh <scenario-out-dir> <snapshot-dir> <work-dir>
set -e
OUT=$1; SNAP=$2; WORK=${3:-/tmp/base-broken-work}
[ -n "$OUT" ] && [ -n "$SNAP" ] || { echo "usage: measure.sh <out-dir> <snap-dir> [work-dir]" >&2; exit 1; }
HERE=$(dirname "$0")
DUMP=${DUMP_SNAP:-./_build/default/trading/backtest/snapshot_warehouse/dump_snap/dump_snap.exe}
mkdir -p "$WORK"

# --- 1. tickets (placement-time state) -------------------------------------
sh "$HERE/extract_tickets.sh" "$OUT/trade_audit.sexp" > "$WORK/tickets.tsv"
n_tickets=$(wc -l < "$WORK/tickets.tsv")
n_expect=$(grep -c '(placement_date' "$OUT/trade_audit.sexp")
[ "$n_tickets" -eq "$n_expect" ] || { echo "ABORT: extracted $n_tickets rows, sexp has $n_expect placement_date" >&2; exit 1; }
echo "tickets (entry decisions): $n_tickets"

# --- 2. round trips, keyed on position_id ----------------------------------
awk -F, 'NR>1 && $20!="" { print $20 "\t" $9 "\t" $3 "\t" $13 }' "$OUT/trades.csv" \
  > "$WORK/pnl.tsv"   # position_id, pnl_dollars, FILL date, exit_trigger
n_pnl=$(wc -l < "$WORK/pnl.tsv"); n_trades=$(( $(wc -l < "$OUT/trades.csv") - 1 ))
echo "round trips: $n_pnl  (trades.csv lines: $n_trades)"
# A blank position_id is the pre-#2317 audit-join defect: the round trip exists
# but lost its link to the entry decision, so it can never be classified. On the
# 2026-08-12 ladder-v4 artifacts this silently dropped 563 of 1,136 rows — HALF
# the population — and every table below would still have printed.
if [ "$n_pnl" -lt "$n_trades" ]; then
  echo "!! WARNING: $(( n_trades - n_pnl )) of $n_trades trades have a BLANK position_id and are excluded."
  echo "!! Every cohort figure below is over the joinable subset only. On a post-#2317 run this should be 0."
fi

# --- 3. work list: placement state + fill date, one row per position_id -----
# ⚠ position_id is NOT unique in trades.csv. On this run `FARM-wein-914` carries
# two round trips (−1,586.38 and +2,164.52, same fill date). Keying P&L by id
# with last-wins therefore double-counted one and dropped the other — a +3,750.90
# overstatement that showed up as an unexplained 3,751 gap between two totals.
# So: SUM P&L per id, and take the earliest fill date. `position_id` remains the
# right join key (symbols repeat far more), but it is not a unique key, and a
# join that assumes it is will silently lose rows.
awk -F'\t' '
  FNR==NR { sym[$1]=$2; place[$1]=$3; e[$1]=$5; stop[$1]=$6; lrt[$1]=$7; kind[$1]=$8; next }
  {
    if (!($1 in place)) { unjoined++; next }
    pnl[$1] += $2
    if (!($1 in fill) || $3 < fill[$1]) fill[$1] = $3
    seen[$1]++
  }
  END {
    for (pid in pnl) {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%.2f\n", pid, sym[pid], place[pid], fill[pid], e[pid], stop[pid], lrt[pid], kind[pid], pnl[pid]
      if (seen[pid] > 1) printf "!! %s carries %d round trips; their P&L is summed\n", pid, seen[pid] > "/dev/stderr"
    }
    if (unjoined) printf "!! %d round trips had no entry decision\n", unjoined > "/dev/stderr"
  }
' "$WORK/tickets.tsv" "$WORK/pnl.tsv" | sort > "$WORK/work.tsv"
echo "joined (unique position_id): $(wc -l < "$WORK/work.tsv")"

# --- 4. per-ticket bar reduction over [placement, fill] --------------------
: > "$WORK/bars.tsv"
while IFS="$(printf '\t')" read -r pid sym place fill e stop lrt kind pnl; do
  # from = placement minus one calendar year, by string surgery (portable across
  # BSD `date -v` and GNU `date -d`). Bars older than the 8-week base window are
  # ignored by the tail-window reduction below.
  from="$(( $(echo "$place" | cut -c1-4) - 1 ))$(echo "$place" | cut -c5-10)"
  snapf="$SNAP/$sym.snap"
  [ -f "$snapf" ] || { printf '%s\t%s\tNOSNAP\n' "$pid" "$sym" >> "$WORK/bars.tsv"; continue; }
  "$DUMP" "$snapf" "$from" "$fill" 2>/dev/null | awk -F, -v pid="$pid" -v place="$place" -v fill="$fill" '
    NR==1 { next }
    {
      d=$1; hi=$3+0; lo=$4+0; cl=$5+0
      if (d <= place) { n4++; lows4[n4]=lo }
      if (d > place && d < fill) {
        if (mc=="" || cl<mc) mc=cl
        if (ml=="" || lo<ml) ml=lo
        if (mh=="" || hi>mh) mh=hi
        nrest++
      }
    }
    END {
      lo4=""; lo8=""
      for (i=n4; i>0 && i>n4-20; i--) if (lo4=="" || lows4[i]<lo4) lo4=lows4[i]
      for (i=n4; i>0 && i>n4-40; i--) if (lo8=="" || lows4[i]<lo8) lo8=lows4[i]
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", pid,
        (mc==""?"-":mc), (ml==""?"-":ml), (mh==""?"-":mh), (nrest+0),
        (lo4==""?"-":lo4), (lo8==""?"-":lo8)
    }' >> "$WORK/bars.tsv"
done < "$WORK/work.tsv"
echo "bar rows: $(wc -l < "$WORK/bars.tsv")"

# --- 5. classify -----------------------------------------------------------
awk -F'\t' '
  FNR==NR { w_place[$1]=$3; w_fill[$1]=$4; w_stop[$1]=$6; w_pnl[$1]=$9; next }
  {
    pid=$1; mc=$2; rest=$5+0; lo4=$6; lo8=$7
    if (!(pid in w_place)) next
    stop=w_stop[pid]+0
    bs = (mc!="-" && mc+0 < stop) ? 1 : 0
    b4 = (mc!="-" && lo4!="-" && mc+0 < lo4+0) ? 1 : 0
    b8 = (mc!="-" && lo8!="-" && mc+0 < lo8+0) ? 1 : 0
    printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%.2f\n", pid, w_place[pid], w_fill[pid], rest, bs, b4, b8, w_pnl[pid]
  }
' "$WORK/work.tsv" "$WORK/bars.tsv" > "$WORK/joined.tsv"
echo "classified rows: $(wc -l < "$WORK/joined.tsv")"

# --- 6. cohort tables ------------------------------------------------------
for col in 5 6 7; do
  case $col in 5) label=broken_stop;; 6) label=broken_4w;; 7) label=broken_8w;; esac
  echo ""
  echo "=== $label ==="
  awk -F'\t' -v c=$col '
    { n[$c]++; s[$c]+=$8; if ($8>mx[$c]) { mx[$c]=$8; mxid[$c]=$1 }; if ($8<mn[$c]) { mn[$c]=$8; mnid[$c]=$1 }; tot+=$8 }
    END {
      printf "%-8s %6s %14s %10s %8s %14s %14s\n", "cohort","n","pnl","per_trade","%oftot","max_trade","min_trade"
      for (k=0; k<=1; k++)
        printf "%-8s %6d %14.0f %10.0f %7.1f%% %14.0f %14.0f  max=%s\n",
          (k?"BROKEN":"held"), n[k], s[k], (n[k]?s[k]/n[k]:0), (tot?100*s[k]/tot:0), mx[k], mn[k], mxid[k]
    }' "$WORK/joined.tsv"
done

# --- 7. is "broken base" just age in disguise? -----------------------------
# The whole premise of #2407 is that these are DIFFERENT variables. If the
# cross-tab is diagonal, the mechanism is the clock wearing a new name.
# Emit the cross-tab for BOTH the 4w and the 8w flag. The first version printed
# only the 4w one while the writeup reported the 8w table, so re-running the
# committed script did not reproduce the committed result — a future session
# would have read that as a reproduction failure.
for xcol in 6 7; do
  case $xcol in 6) xlabel=broken_4w;; 7) xlabel=broken_8w;; esac
  echo ""
  echo "=== cross-tab: rest (trading bars) vs $xlabel ==="
  awk -F'\t' -v c=$xcol '
    { band = ($4<=5?"0-1wk":($4<=25?"1-5wk":($4<=65?"5-13wk":($4<=130?"13-26wk":">26wk"))))
      k = band "|" ($c?"BROKEN":"held"); n[k]++; s[k]+=$8 }
    END {
      printf "%-8s %-7s %6s %14s %12s\n", "rest","base","n","pnl","per_trade"
      split("0-1wk 1-5wk 5-13wk 13-26wk >26wk", ord, " ")
      for (i=1;i<=5;i++) for (j=1;j<=2;j++) {
        st = (j==1?"held":"BROKEN"); k = ord[i] "|" st
        if (k in n) printf "%-8s %-7s %6d %14.0f %12.0f\n", ord[i], st, n[k], s[k], s[k]/n[k]
      }
    }' "$WORK/joined.tsv"
done

# --- 8. concentration check ------------------------------------------------
# 85% of this strategy's return is ~10 trades; a cohort verdict that flips when
# one trade moves is not a verdict.
echo ""
echo "=== top 12 trades by pnl, with cohort flags ==="
sort -t"$(printf '\t')" -k8,8gr "$WORK/joined.tsv" | head -12 \
  | awk -F'\t' '{printf "%-22s place=%s fill=%s rest=%-4s stop=%s 4w=%s 8w=%s  pnl=%.0f\n", $1,$2,$3,$4,$5,$6,$7,$8}'
echo ""
echo "=== worst 6 trades by pnl ==="
sort -t"$(printf '\t')" -k8,8g "$WORK/joined.tsv" | head -6 \
  | awk -F'\t' '{printf "%-22s rest=%-4s stop=%s 4w=%s 8w=%s  pnl=%.0f\n", $1,$4,$5,$6,$7,$8}'

echo ""
echo "rows written to $WORK/joined.tsv (pid placement fill rest_bars broken_stop broken_4w broken_8w pnl)"
