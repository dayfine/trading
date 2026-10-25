#!/bin/sh
# floor-nearest-2026-10-25 results read: reproducible extracts behind README §Results.
# Usage: sh fn-analysis.sh <sn-results> <s-results> <sn-raw> <s-raw> <pack-root> <data-dir> <regime-awk> <out-dir>
#   sn-results   SN per-cell artifacts (trades.csv, actual.sexp, summary.sexp, open_positions.csv,
#                equity_curve.csv, audit_entries.csv): this experiment's results/ (collected from /tmp/fn-res2)
#   s-results    the null's committed results: ../path-stability-2026-10-23/results
#   sn-raw       SN trade_audit.sexp files (.sweep-output/floor-nearest)
#   s-raw        S trade_audit.sexp files (.sweep-output/path-stability)
#   pack-root    .sweep-output (review-ps-S-p0 and review-ps-SN-p0 site/data JSON)
#   data-dir     the CSV store (data/), for the 2024-12-30 close of positions open at the end
#   regime-awk   ../path-stability-2026-10-23/results/read/regime.awk (period list widened here by sed)
#   out-dir      where the extracts go
# POSIX sh + awk only. Classes join the two arms on the SAME decision (Friday date + symbol) from each
# audit's cascade_summaries; within an arm, decision -> audit entry (symbol + entry_date) -> position_id ->
# trades.csv / open_positions.csv. P&L = pnl_dollars + dividends_received (realised) or the 2024-12-30 mark.
set -eu
SN=$1; S=$2; SNRAW=$3; SRAW=$4; P=$5; D=$6; RAWK=$7; O=$8
KS="0 1 2 3 4 5"
mkdir -p "$O/decisions" "$O/tickets"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

res() { if [ "$1" = SN ]; then echo "$SN/ps-SN-p$2-s0"; else echo "$S/ps-S-p$2-s0"; fi; }
raw() { if [ "$1" = SN ]; then echo "$SNRAW/ps-SN-p$2-s0-trade_audit.sexp"; else echo "$SRAW/ps-S-p$2-s0-trade_audit.sexp"; fi; }

# 1. Top-N decisions per cell: date,symbol,outcome (cascade_summaries only, never alternatives_considered).
dec_awk='{
  i = index($0, "(cascade_summaries"); s = substr($0, i); n = split(s, wk, /\(\(date /)
  for (w = 2; w <= n; w++) { d = substr(wk[w], 1, 10); r = wk[w]
    while (match(r, /\(\(symbol [^)]*\) \(side [A-Za-z]+\) \(outcome (Placed|\(Skipped [A-Za-z_]+\))\)/)) {
      rec = substr(r, RSTART, RLENGTH); r = substr(r, RSTART + RLENGTH); split(rec, a, /[() ]+/)
      print d "," a[3] "," ((rec ~ /Placed/) ? "Placed" : a[8]) } } }'
for a in S SN; do for k in $KS; do
  tr -s '\n\t ' '   ' < "$(raw $a $k)" | awk "$dec_awk" > "$O/decisions/ps-$a-p$k-s0-decisions.csv"
done; done

# 2. Liveness counts (README step 1) and outcome mix, every cell.
{
  echo "cell No_structural_stop Placed Insufficient_cash Sized_to_zero Share_class_held total"
  for a in S SN; do for k in $KS; do
    awk -F, -v c="ps-$a-p$k" '{n[$3]++; t++} END{printf "%s %d %d %d %d %d %d\n", c, n["No_structural_stop"], n["Placed"], n["Insufficient_cash"], n["Sized_to_zero"], n["Share_class_held"], t}' "$O/decisions/ps-$a-p$k-s0-decisions.csv"
  done; done
  echo; echo "SN p0 vs the pre-registered S p0 counts (5078 / 190): bar No_structural_stop <= 3808 AND Placed > 190"
  awk -F, '{n[$3]++} END{printf "SN p0 No_structural_stop %d (%.3f x), Placed %d (%.3f x)\n", n["No_structural_stop"], n["No_structural_stop"]/5078, n["Placed"], n["Placed"]/190}' "$O/decisions/ps-SN-p0-s0-decisions.csv"
} > "$O/liveness.txt"

# 3. Same-decision transitions S -> SN, per pair.
{
  echo "pair | S NSS also decided in SN | ->Placed | ->Insufficient_cash | ->Sized_to_zero | ->other | stayed NSS | S Placed also decided in SN | ->Insufficient_cash (displaced) | S Insufficient_cash -> SN Placed"
  for k in $KS; do
    awk -F, -v lab="p$k" 'NR == FNR { o[$1 "," $2] = $3; next }
      { key = $1 "," $2; if (!(key in o)) next; x = o[key]
        if ($3 == "No_structural_stop") { ns++; if (x == "Placed") a++; else if (x == "Insufficient_cash") b++; else if (x == "Sized_to_zero") c++; else if (x == "No_structural_stop") e++; else d++ }
        if ($3 == "Placed") { pl++; if (x == "Insufficient_cash") dis++ }
        if ($3 == "Insufficient_cash" && x == "Placed") sw++ }
      END { printf "%s | %d | %d | %d | %d | %d | %d | %d | %d | %d\n", lab, ns, a, b, c, d, e, pl, dis, sw }' \
      "$O/decisions/ps-SN-p$k-s0-decisions.csv" "$O/decisions/ps-S-p$k-s0-decisions.csv"
  done
  echo; echo "displaced S tickets (S Placed, SN Insufficient_cash): did SN place an S-unplaced name EARLIER in the same week's list?"
  for k in $KS; do
    awk -F, -v lab="p$k" 'NR == FNR { oS[$1 "," $2] = $3; next }
      { if ($1 != cur) { cur = $1; conv = 0; extra = 0 } key = $1 "," $2; o = (key in oS) ? oS[key] : "absent"
        if ($3 == "Placed" && o != "Placed") extra++; if ($3 == "Placed" && o == "No_structural_stop") conv++
        if ($3 == "Insufficient_cash" && o == "Placed") { tot++; if (conv > 0) a++; else if (extra > 0) b++; else c++ } }
      END { printf "%s displaced %d: same week after a converted SN placement %d, after another SN-only placement %d, carry-over (no extra SN placement earlier that week) %d\n", lab, tot, a, b, c }' \
      "$O/decisions/ps-S-p$k-s0-decisions.csv" "$O/decisions/ps-SN-p$k-s0-decisions.csv"
  done
  echo; echo "first decisions that differ (S vs SN), p0 and p4:"
  for k in 0 4; do
    awk -F, -v lab="p$k" 'NR == FNR { o[$1 "," $2] = $3; next } { key = $1 "," $2; x = (key in o) ? o[key] : "absent"; if (x != $3 && n < 3) { print lab, $1, $2, "S:" x, "SN:" $3; n++ } }' \
      "$O/decisions/ps-S-p$k-s0-decisions.csv" "$O/decisions/ps-SN-p$k-s0-decisions.csv"
  done
} > "$O/transitions.txt"

# 4. Per placed ticket: decision date, symbol, position_id, status, fill date, P&L, return %, stop distance,
#    notional / NAV at fill, exit trigger, days held, and the OTHER arm's outcome on the same decision (class).
mark() { # open_positions.csv -> symbol entry_date entry_price qty close pnl  (close of 2024-12-30, the last NAV day)
  tail -n +2 "$1" | while IFS=, read -r sym _side ed ep q; do
    f=$D/$(printf %s "$sym" | cut -c1)/$(printf %s "$sym" | rev | cut -c1)/$sym/data.csv
    c=$(awk -F, '$1 <= "2024-12-30" { c = $5 } END { print c }' "$f")
    awk -v s="$sym" -v ed="$ed" -v ep="$ep" -v q="$q" -v c="$c" 'BEGIN { printf "%s %s %s %s %s %.2f\n", s, ed, ep, q, c, q * (c - ep) }'
  done
}
for a in S SN; do for k in $KS; do
  r=$(res $a $k); other=S; [ "$a" = S ] && other=SN
  mark "$r-open_positions.csv" > "$T/open"
  awk -v OPEN="$T/open" -v TR="$r-trades.csv" -v AE="$r-audit_entries.csv" -v EQ="$r-equity_curve.csv" -v ARM="$a" -v CELL="p$k" '
    BEGIN { FS = ","
      while ((getline l < AE) > 0) { split(l, x, ","); if (x[1] == "position_id") continue; pid[x[2] "|" x[3]] = x[1]; can[x[1]] = x[4] }
      while ((getline l < TR) > 0) { split(l, x, ","); if (x[1] == "symbol") continue; tp[x[20]] = x[9] + x[25]; tf[x[20]] = x[3]; tx[x[20]] = x[13]; tr_[x[20]] = x[10]; sd[x[20]] = x[16]; nt[x[20]] = x[6] * x[8]; dh[x[20]] = x[5] }
      while ((getline l < EQ) > 0) { split(l, x, ","); nav[x[1]] = x[2] }
      while ((getline l < OPEN) > 0) { split(l, x, " "); op[x[1]] = x[6]; of[x[1]] = x[2]; on[x[1]] = x[3] * x[4]; orr[x[1]] = 100 * x[6] / (x[3] * x[4]) } }
    FNR == NR { o[$1 "," $2] = $3; next }
    $3 == "Placed" { key = $1 "," $2; cls = (key in o) ? o[key] : "absent"; p = pid[$2 "|" $1]
      if (p == "") { print ARM, CELL, cls, $1, $2, "-", "noaudit", "-", 0, "NA", "NA", "NA", "NA", "NA"; next }
      if (p in tp) { printf "%s %s %s %s %s %s filled %s %.0f %s %s %.4f %s %s\n", ARM, CELL, cls, $1, $2, p, tf[p], tp[p], tr_[p], sd[p], (tf[p] in nav ? nt[p] / nav[tf[p]] : -1), tx[p], dh[p]; next }
      c = can[p]
      if (c == "" && ($2 in op)) { printf "%s %s %s %s %s %s open %s %.0f %.2f NA %.4f open NA\n", ARM, CELL, cls, $1, $2, p, of[$2], op[$2], orr[$2], (of[$2] in nav ? on[$2] / nav[of[$2]] : -1); next }
      print ARM, CELL, cls, $1, $2, p, (c == "" ? "resting_at_end" : c), "-", 0, "NA", "NA", "NA", "NA", "NA" }' \
    "$O/decisions/ps-$other-p$k-s0-decisions.csv" "$O/decisions/ps-$a-p$k-s0-decisions.csv" > "$O/tickets/ps-$a-p$k-tickets.txt"
  # the marks must reproduce the run's own unrealised P&L
  u=$(grep -oE 'unrealized_pnl [-0-9.e]+' "$r-actual.sexp" | awk '{print $2}')
  awk -v u="$u" -v c="ps-$a-p$k" '{ s += $6 } END { if (s - u > 100 || u - s > 100) printf "MARK CHECK FAIL %s: marks %.0f vs actual %.0f\n", c, s, u }' "$T/open" >&2
done; done
cat "$O"/tickets/ps-*-tickets.txt > "$T/all"

# 5. NAV gap decomposition per pair (SN - S): shared tickets, converted skips, cash swaps, displaced, rest, interest.
{
  echo "columns: arm cell class(other arm's outcome on the same decision) decision symbol position_id status fill pnl ret% stopdist notional/NAV exit days  (tickets/ps-*-tickets.txt)"
  echo
  echo "pair | dNAV | dTickets | shared: SN-S | converted (S skipped NSS) | S cash -> SN placed | other SN-only | displaced: S placed, SN cash (minus S P&L) | other S-only (minus) | dInterest | residual  (\$k)"
  for k in $KS; do
    fS=$(grep -o 'final_portfolio_value [0-9.]*' "$(res S $k)-summary.sexp" | awk '{print $2}'); fN=$(grep -o 'final_portfolio_value [0-9.]*' "$(res SN $k)-summary.sexp" | awk '{print $2}')
    iS=$(grep -o 'cashinteresttotal [0-9.]*' "$(res S $k)-summary.sexp" | awk '{print $2}'); iN=$(grep -o 'cashinteresttotal [0-9.]*' "$(res SN $k)-summary.sexp" | awk '{print $2}')
    awk -v k="p$k" -v fS="$fS" -v fN="$fN" -v iS="$iS" -v iN="$iN" '$2 == k {
        if ($1 == "S") { if ($3 == "Placed") bS += $9; else if ($3 == "Insufficient_cash") dS += $9; else xS += $9 }
        else { if ($3 == "Placed") bN += $9; else if ($3 == "No_structural_stop") cN += $9; else if ($3 == "Insufficient_cash") wN += $9; else xN += $9 } }
      END { dt = (bN + cN + wN + xN) - (bS + dS + xS); d = fN - fS; di = iN - iS
        printf "%s | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f\n", k, d/1000, dt/1000, (bN-bS)/1000, cN/1000, wN/1000, xN/1000, -dS/1000, -xS/1000, di/1000, (d-dt-di)/1000 }' "$T/all"
  done
  echo
  echo "shared decisions (placed in both arms): filled in both (SN P&L - S P&L) | filled in S only | filled in SN only  (\$k)"
  for k in $KS; do
    awk -v k="p$k" '$2 == k && $3 == "Placed" { key = $4 " " $5; f = ($7 == "filled" || $7 == "open")
        if ($1 == "S") { s[key] = $9; fs[key] = f; ss[key] = $5 "(" $7 "," int($9/1000) "k)" } else { n[key] = $9; fn[key] = f; sn[key] = $7 } }
      END { for (x in s) { if (!(x in n)) continue
          if (fs[x] && fn[x]) { a++; da += n[x] - s[x] } else if (fs[x]) { b++; db -= s[x]; if (s[x] > 100000) big = big " " ss[x] "->SN " sn[x] } else if (fn[x]) { c++; dc += n[x] } }
        printf "%s | %d %+.0f | %d %+.0f%s | %d %+.0f\n", k, a, da/1000, b, db/1000, big, c, dc/1000 }' "$T/all"
  done
} > "$O/decomposition.txt"

# 6. Cohorts pooled over the six pairs: distribution, perturbation (drop the top names), by decision year,
#    stop-distance bands and exit mix. Returns: realised pnl_percent; open positions: mark / notional.
dist='function srt(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } }
  function q(a, n, p) { return a[int(p * (n - 1)) + 1] }
  { m++; r[m] = $10; s += $10; P += $9; if ($10 > 50) t5++; if ($10 > 100) t1++; if ($10 > 0) w++ }
  END { if (!m) { print lab, "n=0"; exit } srt(r, m)
    printf "%-40s n=%3d mean %+6.2f%% p10 %+6.2f p25 %+6.2f median %+6.2f p75 %+6.2f p90 %+6.2f win %4.1f%% >+50%% %4.1f%% >+100%% %3.1f%% P&L %+.0fk\n", lab, m, s/m, q(r,m,.1), q(r,m,.25), q(r,m,.5), q(r,m,.75), q(r,m,.9), 100*w/m, 100*t5/m, 100*t1/m, P/1000 }'
coh() { awk -v ex="$3" 'BEGIN { n = split(ex, e, " "); for (i = 1; i <= n; i++) X[e[i]] = 1 } $1 == A && $3 == C && ($7 == "filled" || $7 == "open") && !($5 in X)' A="$1" C="$2" "$T/all" | awk -v lab="$4" "$dist"; }
{
  echo "filled or open tickets pooled over p0-p5 (the cells share most trades: see the overlap line)"
  coh SN No_structural_stop "" "converted skips (SN; S skipped NSS)"
  coh SN No_structural_stop "IONQ" "converted ex IONQ"
  coh SN No_structural_stop "IONQ NVDA" "converted ex IONQ, NVDA"
  coh S Insufficient_cash "" "displaced (S placed; SN Insufficient_cash)"
  coh S Insufficient_cash "MMYT" "displaced ex MMYT"
  coh S Insufficient_cash "MMYT APPS" "displaced ex MMYT, APPS"
  coh S Placed "" "shared, S side"
  coh SN Placed "" "shared, SN side"
  coh S Placed "ADMA APPS" "shared S side ex ADMA, APPS"
  coh SN Insufficient_cash "" "S cash -> SN placed (SN side)"
  echo
  awk '$1 == "SN" && $3 == "No_structural_stop" && ($7 == "filled" || $7 == "open") { k = $5 " " $4; n[k]++ } END { for (k in n) c[n[k]]++; printf "converted tickets by number of cells holding the same decision: "; for (i = 1; i <= 6; i++) printf "%d:%d ", i, c[i]; printf "(distinct %d)\n", length(n) }' "$T/all"
  echo; echo "by decision year, pooled P&L \$k: converted (SN) | displaced (S P&L, lost) | shared SN - S"
  awk '{ y = substr($4, 1, 4); Y[y] = 1; if ($1 == "SN" && $3 == "No_structural_stop") c[y] += $9; if ($1 == "S" && $3 == "Insufficient_cash") d[y] += $9; if ($3 == "Placed") { if ($1 == "SN") b[y] += $9; else b[y] -= $9 } }
    END { for (y in Y) printf "%s | %+.0f | %+.0f | %+.0f\n", y, c[y]/1000, d[y]/1000, b[y]/1000 }' "$T/all" | sort
  echo; echo "p0 only, by decision year, \$k: converted (SN) | S cash -> SN placed (SN) | displaced (S P&L) | shared SN | shared S"
  awk '$2 == "p0" { y = substr($4, 1, 4); Y[y] = 1
      if ($1 == "SN" && $3 == "No_structural_stop") c[y] += $9; if ($1 == "SN" && $3 == "Insufficient_cash") w[y] += $9
      if ($1 == "S" && $3 == "Insufficient_cash") d[y] += $9; if ($3 == "Placed") { if ($1 == "SN") bn[y] += $9; else bs[y] += $9 } }
    END { for (y in Y) printf "%s | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f\n", y, c[y]/1000, w[y]/1000, d[y]/1000, bn[y]/1000, bs[y]/1000 }' "$T/all" | sort
  echo; echo "initial stop distance bands and size at fill (filled or open)"
  for x in "SN No_structural_stop" "SN Placed" "S Insufficient_cash"; do
    echo "$x" | { read -r A C; awk -v A="$A" -v C="$C" '$1 == A && $3 == C && $11 != "NA" { n++; d = $11; if (d >= .14) h++; else if (d >= .10) m++; else if (d >= .05) l++; else t++; s += $12 }
      END { printf "%-3s %-20s n=%d stop>=14%%: %.0f%% | 10-14%%: %.0f%% | 5-10%%: %.0f%% | <5%%: %.0f%% | mean size %.1f%% of NAV\n", A, C, n, 100*h/n, 100*m/n, 100*l/n, 100*t/n, 100*s/n }' "$T/all"; }
  done
  echo; echo "exit mix of realised trades (SN side)"
  awk '$1 == "SN" && ($3 == "No_structural_stop" || $3 == "Placed") && $7 == "filled" { k = $3; n[k]++; ex[k " " $13]++; d[k] += $14; r[k " " $13] += $10 }
    END { for (k in n) { printf "%s: n=%d mean days %.0f |", k, n[k], d[k]/n[k]; for (x in ex) { split(x, z, " "); if (z[1] == k) printf " %s %.0f%% (mean %+.1f%%)", z[2], 100*ex[x]/n[k], r[x]/ex[x] } printf "\n" } }' "$T/all"
} > "$O/cohorts.txt"

# 7. V12-class trades (installed stop > 15 % under the fill, split-basis cases > 50 % listed apart), by class.
{
  for k in $KS; do
    awk -v k="p$k" 'FNR == NR { if ($1 == "SN" && $2 == k) c[$6] = $3; next } FNR > 1 && $21 > 0.14995 { if ($21 > 0.5) { sb = sb " " $1 " " $3 " (" $21 ")"; next } n++; m[(($20 in c) ? c[$20] : "?")]++ }
      END { printf "SN %s: %d edge cases;", k, n; for (x in m) printf " %s %d;", x, m[x]; printf " split-basis:%s\n", (sb == "" ? " none" : sb) }' FS=' ' "$T/all" FS=',' "$(res SN $k)-trades.csv"
  done
  for k in $KS; do awk -F, -v k="p$k" 'NR > 1 && $21 > 0.14995 { if ($21 > 0.5) s++; else n++ } END { printf "S  %s: %d edge cases, %d split-basis\n", k, n, s }' "$(res S $k)-trades.csv"; done
} > "$O/v12.txt"

# 8. Tail-name traces: every decision on the window's tail names, per cell.
{
  for sym in APPS GLNG ADMA MMYT MSTR IONQ; do echo "== $sym"
    for k in $KS; do for a in S SN; do
      printf "%-3s p%d: " "$a" "$k"; awk -F, -v s="$sym" '$2 == s { printf "%s:%s ", $1, $3 }' "$O/decisions/ps-$a-p$k-s0-decisions.csv"
      awk -v s="$sym" -v a="$a" -v k="p$k" '$1 == a && $2 == k && $5 == s && $7 != "-" { printf " | ticket %s %s %s %s P&L %+.0fk", $4, $6, $7, $8, $9/1000 }' "$T/all"; echo
    done; done
  done
  held() { awk -F, -v d="$2" 'NR > 1 && $3 <= d && $4 > d { printf "%s(%s,%.0fk) ", $1, $3, $6*$8/1000 }' "$1-trades.csv"; awk -F, -v d="$2" 'NR > 1 && $3 <= d { printf "%s(%s,%.0fk,open) ", $1, $3, $4*$5/1000 }' "$1-open_positions.csv"; }
  echo; echo "== books on the decision day (positions held; entry date, notional at entry)"
  for x in "3 2020-06-12" "5 2020-06-12" "0 2022-02-04" "1 2023-10-06" "4 2023-10-06" "5 2023-10-06"; do
    echo "$x" | { read -r k d; for a in S SN; do printf "%-3s p%s %s: " "$a" "$k" "$d"; held "$(res $a $k)" "$d"; echo; done; }
  done
} > "$O/tail-traces.txt"

# 9. Paired by seed (descriptive; the README reads the arms unpaired): ln(1+R) per pair, year-end NAV ratio
#    SN/S, first day the paired NAVs differ, and yearly returns per cell.
{
  echo "pair lnR_S lnR_SN diff first_NAV_difference SN/S NAV at year end 2019..2024"
  for k in $KS; do
    rs=$(grep -oE 'total_return_pct [-0-9.e]+' "$(res S $k)-actual.sexp" | awk '{print $2}'); rn=$(grep -oE 'total_return_pct [-0-9.e]+' "$(res SN $k)-actual.sexp" | awk '{print $2}')
    on=$(awk -F, 'NR == FNR { if (FNR > 1) v[$1] = $2; next } FNR > 1 && !done { if (!($1 in v) || v[$1] != $2) { print $1; done = 1 } } END { if (!done) print "never" }' "$(res S $k)-equity_curve.csv" "$(res SN $k)-equity_curve.csv")
    awk -F, -v k="p$k" -v rs="$rs" -v rn="$rn" -v on="$on" 'FNR == 1 { f++; next } f == 1 { s[$1] = $2; next } { n[$1] = $2; last[substr($1, 1, 4)] = $1 }
      END { a = log(1 + rs/100); b = log(1 + rn/100); printf "%s %.4f %.4f %+.4f %s", k, a, b, b - a, on; for (y = 2019; y <= 2024; y++) printf " %.3f", n[last[y]] / s[last[y]]; printf "\n" }' "$(res S $k)-equity_curve.csv" "$(res SN $k)-equity_curve.csv"
  done | tee "$T/pairs"
  awk '{ d = $4; s += d; ss += d * d; n++ } END { m = s / n; sd = sqrt((ss - n * m * m) / (n - 1)); printf "paired mean %+.4f sd %.4f se %.4f (n=%d, all signs: see column 4)\n", m, sd, sd / sqrt(n), n }' "$T/pairs"
  echo; echo "yearly return per cell 2019..2024"
  for k in $KS; do for a in S SN; do
    awk -F, -v c="ps-$a-p$k" 'NR == 2 { prev = $2 } NR > 1 { y = substr($1, 1, 4); if (y != cy && cy != "") { r[cy] = v / prev - 1; prev = v } cy = y; v = $2 } END { r[cy] = v / prev - 1; printf "%-9s", c; for (y = 2019; y <= 2024; y++) printf " %+6.1f%%", 100 * r[y]; printf "\n" }' "$(res $a $k)-equity_curve.csv"
  done; done
  echo; echo "tail per cell (README step 4): trades, trades with pnl_percent > 100, top trade by TR P&L (pnl_dollars + dividends), its share of realised TR P&L, end unrealised (actual.sexp)"
  for k in $KS; do for a in S SN; do
    un=$(grep -oE 'unrealized_pnl [-0-9.e]+' "$(res $a $k)-actual.sexp" | awk '{print $2}')
    awk -F, -v c="ps-$a-p$k" -v un="$un" 'NR > 1 { p = $9 + $25; t += p; n++; if ($10 > 100) b++; if (p > mx) { mx = p; ms = $1 " " $3 } }
      END { printf "%-9s trades %d | >+100%% %d | top %s %.0fk | top share %.0f%% of realised %.0fk | unrealised %.0fk\n", c, n, b, ms, mx/1000, 100*mx/t, t/1000, un/1000 }' "$(res $a $k)-trades.csv"
  done; done
  echo; echo "README cohort join (trades.csv, symbol|entry_date): both (S P&L, SN P&L) | S-only | SN-only"
  for k in $KS; do
    awk -F, -v k="p$k" 'FNR == 1 { f++; next } { key = $1 "|" $3; p = $9 + $25; if (f == 1) s[key] = p; else n[key] = p }
      END { for (x in s) { if (x in n) { nb++; bs += s[x]; bn += n[x] } else { no++; po += s[x] } } for (x in n) if (!(x in s)) { nn++; pn += n[x] }
        printf "%s both %d (S %.0fk, SN %.0fk) | S-only %d %+.0fk | SN-only %d %+.0fk\n", k, nb, bs/1000, bn/1000, no, po/1000, nn, pn/1000 }' "$(res S $k)-trades.csv" "$(res SN $k)-trades.csv"
  done
  echo; echo "initial stop on trades both arms took (trades.csv entry_stop, joined on symbol|entry_date; 0.005 tolerance)"
  for k in $KS; do
    awk -F, -v k="p$k" 'FNR == 1 { f++; next } f == 1 { s[$1 "|" $3] = $11; next } { key = $1 "|" $3; if (key in s) { n++; if ($11 > s[key] + 0.005) t++; else if ($11 < s[key] - 0.005) l++; else e++ } }
      END { printf "%s shared %d: same stop %d, SN tighter %d, SN looser %d\n", k, n, e, t, l }' "$(res S $k)-trades.csv" "$(res SN $k)-trades.csv"
  done
  echo; echo "p0, trades exited in 2022: realised TR P&L by class (the other arm's outcome on the same decision)"
  for a in S SN; do
    awk -v a="$a" 'FNR == NR { if (FNR > 1) { split($0, x, ","); ex[x[20]] = substr(x[4], 1, 4) } next }
      $1 == a && $2 == "p0" && $7 == "filled" && ex[$6] == "2022" { c[$3] += $9; n[$3]++ }
      END { for (y in c) printf "%s p0 2022 exits, class %s: n=%d P&L %+.0fk\n", a, y, n[y], c[y]/1000 }' "$(res $a 0)-trades.csv" "$T/all"
  done
  echo; echo "max drawdown peak -> trough per cell"
  for k in $KS; do for a in S SN; do
    awk -F, -v c="ps-$a-p$k" 'NR > 1 { v = $2; if (v > pk) { pk = v; pd = $1 } dd = 1 - v / pk; if (dd > mdd) { mdd = dd; tp = pd; td = $1 } } END { printf "%-9s %.1f%% %s -> %s\n", c, 100 * mdd, tp, td }' "$(res $a $k)-equity_curve.csv"
  done; done
} > "$O/paired.txt"

# 10. Exposure and return by SPY regime, per year and per period, S p0 vs SN p0 (the pack's regime rule;
#     regime.awk from the path-stability read with the period list widened).
j2l() { tr -d '[]"' < "$1" | tr '\n' ' ' | sed 's/ //g' | awk -v n="$2" -F, '{for(i=1;i<=NF;i+=n){s=$i; for(k=1;k<n;k++) s=s","$(i+k); print s}}'; }
j2l "$P/review-ps-SN-p0/site/data/spy_warmup.json" 3 > "$T/spy_warm.csv"
j2l "$P/review-ps-SN-p0/site/data/spy.json" 2 > "$T/spy.csv"
for a in S SN; do j2l "$P/review-ps-$a-p0/site/data/p0_nav.json" 4 > "$T/nav_$a.csv"; done
sed 's/np=split("2019-2021 2022-2024 2019-2024",PER," ");/np=split("2019-2019 2020-2020 2021-2021 2022-2022 2023-2023 2024-2024 2019-2021 2022-2024 2019-2024",PER," ");/' "$RAWK" > "$T/regime.awk"
grep -q '2019-2019 2020-2020' "$T/regime.awk" || { echo "regime.awk period list not found" >&2; exit 1; }
(cd "$T" && awk -f regime.awk spy_warm.csv spy.csv nav_S.csv nav_SN.csv) > "$O/regime-split.txt"

echo "wrote $O/{liveness,transitions,decomposition,cohorts,v12,tail-traces,paired,regime-split}.txt, decisions/, tickets/"
