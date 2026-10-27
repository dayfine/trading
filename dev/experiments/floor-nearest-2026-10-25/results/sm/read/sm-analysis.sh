#!/bin/sh
# floor-nearest-2026-10-25 arm SM results read: reproducible extracts behind README §"Results, arm SM".
# Usage: sh sm-analysis.sh <sm-results> <s-results> <s-decisions> <yearly-dir> <monthly-dir> <data-dir> \
#                          <sm-pack-data> <s-pack-data> <regime-awk> <out-dir>
#   sm-results   results/sm (the SM cells, collected by chain-sm.sh)
#   s-results    ../path-stability-2026-10-23/results (the S cells)
#   s-decisions  results/read/decisions (S top-N decisions, the SN read's reduction of the S audits)
#   yearly-dir   trading/test_data/backtest_scenarios/pit-v12/composition (committed yearly lists)
#   monthly-dir  the 320 staged monthly lists (not committed; md5 = pit-v12-monthly/composition.md5)
#   data-dir     the CSV store (data/): 2024-12-30 marks, month-end closes, holiday rows
#   sm-pack-data review-ps-SM-p0/site/data (the #3445 re-render), s-pack-data review-ps-S-p0/site/data
#   regime-awk   ../path-stability-2026-10-23/results/read/regime.awk
# POSIX sh + awk. Classes join S pk and SM pk on the SAME decision (Friday + symbol). A decision absent from the
# other arm's top-N is split by list membership: entrant (SM decision, symbol outside the yearly list in force),
# leaver (S decision, symbol outside the monthly list in force), held (the other arm held the symbol that day),
# cut (in the other arm's list, not in its top-N). P&L = pnl_dollars + dividends_received, or the 2024-12-30 mark.
set -eu
SMR=$1; SR=$2; SDEC=$3; YL=$4; ML=$5; D=$6; PSM=$7; PS=$8; RAWK=$9; shift 9; O=$1
KS="0 1 2 3 4 5"
mkdir -p "$O"; T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
syms_of() { grep -o '(symbol [^)]*)' "$1" | sed 's/(symbol //; s/)$//'; }
csv_of() { printf '%s/%s/%s/%s/data.csv' "$D" "$(printf %s "$1" | cut -c1)" "$(printf %s "$1" | rev | cut -c1)" "$1"; }
res() { if [ "$1" = SM ]; then echo "$SMR/ps-SM-p$2-s0"; else echo "$SR/ps-S-p$2-s0"; fi; }
dec() { if [ "$1" = SM ]; then echo "$SMR/ps-SM-p$2-s0-decisions.csv"; else echo "$SDEC/ps-S-p$2-s0-decisions.csv"; fi; }
other() { if [ "$1" = SM ]; then echo S; else echo SM; fi; }

# 1. Membership: yearly "Y SYM" (2017-2024), monthly "DATE SYM" (lists dated 2018-05-31 .. 2024-12-31).
: > "$T/yearly"; for y in 2017 2018 2019 2020 2021 2022 2023 2024; do syms_of "$YL/top-3000-$y.sexp" | sed "s/^/$y /" >> "$T/yearly"; done
: > "$T/monthly"; : > "$T/mdates"
for f in "$ML"/top-3000-*.sexp; do d=$(basename "$f" .sexp); d=${d#top-3000-}
  case "$d" in 2018-0[5-9]* | 2018-1* | 2019* | 202[0-4]*) syms_of "$f" | sed "s/^/$d /" >> "$T/monthly"; echo "$d" >> "$T/mdates" ;; esac
done

# 2. Annotated decisions: pair arm date symbol outcome other_outcome in_yearly in_monthly other_held
for k in $KS; do for a in S SM; do
  o=$(other $a); r=$(res $o $k)
  awk -F, -v K=p$k -v A=$a -v Y="$T/yearly" -v MO="$T/monthly" -v MD="$T/mdates" -v OT="$(dec $o $k)" -v OTT="$r-trades.csv" -v OTO="$r-open_positions.csv" '
    function yr(d,   y) { y = substr(d, 1, 4) + 0; if (substr(d, 6, 5) < "05-31") y--; return y }
    function mlist(d,   i, b) { b = ""; for (i = 1; i <= nmd; i++) if (md[i] <= d) b = md[i]; return b }
    function held(s, d,   i) { for (i = 1; i <= nh[s]; i++) if (hs[s, i] <= d && d < he[s, i]) return 1; return 0 }
    BEGIN { while ((getline l < Y) > 0) { split(l, x, " "); ym[x[1] " " x[2]] = 1 }
      while ((getline l < MO) > 0) { split(l, x, " "); mm[x[1] " " x[2]] = 1 }
      while ((getline l < MD) > 0) md[++nmd] = l
      while ((getline l < OT) > 0) { split(l, x, ","); oo[x[1] "," x[2]] = x[3] }
      while ((getline l < OTT) > 0) { split(l, x, ","); if (x[1] == "symbol") continue; nh[x[1]]++; hs[x[1], nh[x[1]]] = x[3]; he[x[1], nh[x[1]]] = x[4] }
      while ((getline l < OTO) > 0) { split(l, x, ","); if (x[1] == "symbol") continue; nh[x[1]]++; hs[x[1], nh[x[1]]] = x[3]; he[x[1], nh[x[1]]] = "9999-99-99" } }
    { k = $1 "," $2; print K, A, $1, $2, $3, ((k in oo) ? oo[k] : "absent"), (((yr($1) " " $2) in ym) ? 1 : 0), (((mlist($1) " " $2) in mm) ? 1 : 0), held($2, $1) }' "$(dec $a $k)"
done; done > "$O/annot.txt"
CLS='function cls(a, o, iny, inm, h) { if (o != "absent") return o; if (a == "S") { if (!inm) return "leaver" } else { if (!iny) return "entrant" } return h ? "held" : "cut" }'

{ echo "sanity: S decisions outside the yearly list in force / SM decisions outside the monthly list in force (both must be 0)"
  awk '$2 == "S" && $7 == 0 { a++ } $2 == "SM" && $8 == 0 { b++ } END { print a + 0, b + 0 }' "$O/annot.txt"
  echo; echo "top-N decisions by outcome per cell (fill-time cash refusals from cash_rejections.txt)"
  for k in $KS; do for a in S SM; do cr=$(cat "$(res $a $k)-cash_rejections.txt")
    awk -v c="$a p$k" -v A=$a -v K=p$k -v cr="$cr" '$1 == K && $2 == A { n[$5]++; t++ } END { printf "%-6s NSS %d Placed %d Insufficient_cash %d Sized_to_zero %d Share_class_held %d total %d | fill-time cash refusals %d\n", c, n["No_structural_stop"], n["Placed"], n["Insufficient_cash"], n["Sized_to_zero"], n["Share_class_held"], t, cr }' "$O/annot.txt"
  done; done
  echo; echo "placements -> the other arm's outcome on the same decision (absent split by membership)"
  for a in S SM; do echo "$a Placed:"
    awk "$CLS"' $2 == A && $5 == "Placed" { c = cls($2, $6, $7, $8, $9); n[$1 " " c]++; C[c] = 1; t[$1]++ }
      END { for (k = 0; k <= 5; k++) { printf "  p%d total %d:", k, t["p" k]; for (c in C) printf " %s %d", c, n["p" k " " c]; printf "\n" } }' A=$a "$O/annot.txt"
  done
  echo; echo "decisions absent from the other arm's top-N, per pair"
  awk "$CLS"' $6 == "absent" { n[$1 " " $2 ":" cls($2, $6, $7, $8, $9)]++; C[$2 ":" cls($2, $6, $7, $8, $9)] = 1 }
    END { for (k = 0; k <= 5; k++) { printf "p%d", k; for (c in C) printf " | %s %d", c, n["p" k " " c]; printf "\n" } }' "$O/annot.txt"
  echo; echo "SM decisions on entrant names, and S decisions on leaver names, by outcome"
  awk '($2 == "SM" && $7 == 0) || ($2 == "S" && $8 == 0) { n[$1 " " $2 " " $5]++; t[$1 " " $2]++ } { all[$1 " " $2]++ }
    END { for (k = 0; k <= 5; k++) for (a = 1; a <= 2; a++) { A = (a == 1) ? "SM" : "S"; K = "p" k " " A
      printf "%s %s %d of %d (%.1f%%): Placed %d Insufficient_cash %d Sized_to_zero %d NSS %d\n", K, (A == "SM" ? "entrant" : "leaver"), t[K], all[K], 100 * t[K] / all[K], n[K " Placed"], n[K " Insufficient_cash"], n[K " Sized_to_zero"], n[K " No_structural_stop"] } }' "$O/annot.txt"
  echo; echo "outcome flips on decisions both arms made (pooled)"
  awk '$2 == "S" && $6 != "absent" { n[$5 " -> " $6]++; t++ } END { for (x in n) printf "%6d %s\n", n[x], x; printf "%6d total\n", t }' "$O/annot.txt" | sort -rn
  echo; echo "first placement differences per pair"
  sort -k1,1 -k3,3 -k2,2 "$O/annot.txt" | awk "$CLS"' ($5 == "Placed" || $6 == "Placed") && $5 != $6 && n[$1] < 3 { n[$1]++; print $1, $3, $2, $4, $5, "other:" cls($2, $6, $7, $8, $9) }'
} > "$O/transitions.txt"

# 3. Tickets: arm pair class decision symbol position_id status fill pnl ret% size exit days exit_date stopdist R
mark() { tail -n +2 "$1" | while IFS=, read -r sym _side ed ep q; do
    c=$(awk -F, '$1 <= "2024-12-30" { c = $5 } END { print c }' "$(csv_of "$sym")")
    awk -v s="$sym" -v ed="$ed" -v ep="$ep" -v q="$q" -v c="$c" 'BEGIN { printf "%s %s %s %s %s %.2f\n", s, ed, ep, q, c, q * (c - ep) }'
  done; }
: > "$O/tickets.txt"; : > "$O/marks-check.txt"
for k in $KS; do for a in S SM; do r=$(res $a $k)
  mark "$r-open_positions.csv" > "$T/open"
  u=$(grep -oE 'unrealized_pnl [-0-9.e]+' "$r-actual.sexp" | awk '{print $2}')
  awk -v u="$u" -v c="$a p$k" '{ s += $6 } END { printf "%s marks %.0f vs actual.sexp unrealized_pnl %.0f\n", c, s, u }' "$T/open" >> "$O/marks-check.txt"
  awk -v A=$a -v K=p$k -v AE="$r-audit_entries.csv" -v TR="$r-trades.csv" -v EQ="$r-equity_curve.csv" -v OPEN="$T/open" "$CLS"' BEGIN {
      while ((getline l < AE) > 0) { split(l, x, ","); if (x[1] == "position_id") continue; pid[x[2] "|" x[3]] = x[1]; can[x[1]] = x[4] }
      while ((getline l < TR) > 0) { split(l, x, ","); if (x[1] == "symbol") continue; p = x[20]; tp[p] = x[9] + x[25]; tf[p] = x[3]; tx[p] = x[13]; tr_[p] = x[10]; nt[p] = x[6] * x[8]; dh[p] = x[5]; te[p] = x[4]; sd[p] = x[16]; rr[p] = (x[6] * x[8] > 0) ? (x[9] + x[25]) / (x[6] * x[8]) : 0 }
      while ((getline l < EQ) > 0) { split(l, x, ","); nav[x[1]] = x[2] }
      while ((getline l < OPEN) > 0) { split(l, x, " "); op[x[1]] = x[6]; of[x[1]] = x[2]; on[x[1]] = x[3] * x[4] } }
    $1 == K && $2 == A && $5 == "Placed" { c = cls($2, $6, $7, $8, $9); p = pid[$4 "|" $3]
      if (p == "") { print A, K, c, $3, $4, "-", "noaudit", "-", 0, "NA", "NA", "NA", "NA", "NA", "NA"; next }
      if (p in tp) { printf "%s %s %s %s %s %s filled %s %.0f %s %.4f %s %s %s %s %.6f\n", A, K, c, $3, $4, p, tf[p], tp[p], tr_[p], (tf[p] in nav ? nt[p] / nav[tf[p]] : -1), tx[p], dh[p], te[p], sd[p], rr[p]; next }
      cr = can[p]
      if (cr == "" && ($4 in op)) { printf "%s %s %s %s %s %s open %s %.0f %.2f %.4f open NA open NA %.6f\n", A, K, c, $3, $4, p, of[$4], op[$4], 100 * op[$4] / on[$4], (of[$4] in nav ? on[$4] / nav[of[$4]] : -1), op[$4] / on[$4]; next }
      print A, K, c, $3, $4, p, (cr == "" ? "resting_at_end" : cr), "-", 0, "NA", "NA", "NA", "NA", "NA", "NA" }' "$O/annot.txt" >> "$O/tickets.txt"
  nt=$(( $(wc -l < "$r-trades.csv") - 1 )); no=$(( $(wc -l < "$r-open_positions.csv") - 1 ))
  awk -v A=$a -v K=p$k -v nt=$nt -v no=$no '$1 == A && $2 == K { if ($7 == "filled") f++; if ($7 == "open") o++ } END { printf "%s %s coverage: filled %d of %d trades, open %d of %d\n", A, K, f, nt, o, no }' "$O/tickets.txt" >> "$O/marks-check.txt"
done; done

# 4. NAV gap per pair: by decision class, by tail name, and the shared tickets split by fill outcome.
fin() { tr -s ' \n' ' ' < "$(res $1 $2)-summary.sexp" | grep -oE "$3 [0-9.]+" | awk '{print $2}'; }
{ echo "pair | dNAV | shared SM-S | entrants | SM cut/held | S cash->SM placed | SM other | displaced at decision (-S) | leavers (-S) | S cut/held (-S) | S other (-S) | dInterest | residual (\$k)"
  for k in $KS; do
    awk -v k=p$k -v fS="$(fin S $k final_portfolio_value)" -v fN="$(fin SM $k final_portfolio_value)" -v iS="$(fin S $k cashinteresttotal)" -v iN="$(fin SM $k cashinteresttotal)" '$2 == k {
        if ($1 == "S") { if ($3 == "Placed") bS += $9; else if ($3 == "Insufficient_cash") dS += $9; else if ($3 == "leaver") lS += $9; else if ($3 == "cut" || $3 == "held") cS += $9; else xS += $9 }
        else { if ($3 == "Placed") bN += $9; else if ($3 == "entrant") eN += $9; else if ($3 == "cut" || $3 == "held") cN += $9; else if ($3 == "Insufficient_cash") wN += $9; else xN += $9 } }
      END { dt = (bN + eN + cN + wN + xN) - (bS + dS + lS + cS + xS); d = fN - fS; di = iN - iS
        printf "%s | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f\n", k, d/1000, (bN-bS)/1000, eN/1000, cN/1000, wN/1000, xN/1000, -dS/1000, -lS/1000, -cS/1000, -xS/1000, di/1000, (d-dt-di)/1000 }' "$O/tickets.txt"
  done
  echo; echo "pair | dNAV | seven tail names (APPS ADMA BBWI MMYT DXCM MSTR GLNG) SM-S | entrants | other tickets SM-S | dInterest | residual | ln(NAV_SM/NAV_S) (\$k)"
  for k in $KS; do
    awk -v k=p$k -v fS="$(fin S $k final_portfolio_value)" -v fN="$(fin SM $k final_portfolio_value)" -v iS="$(fin S $k cashinteresttotal)" -v iN="$(fin SM $k cashinteresttotal)" 'BEGIN { split("APPS ADMA BBWI MMYT DXCM MSTR GLNG", t, " "); for (i in t) TL[t[i]] = 1 }
      $2 == k { sg = ($1 == "SM") ? 1 : -1; if ($5 in TL) tl += sg * $9; else if ($1 == "SM" && $3 == "entrant") en += $9; else rest += sg * $9 }
      END { d = fN - fS; di = iN - iS; printf "%s | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.0f | %+.3f\n", k, d/1000, tl/1000, en/1000, rest/1000, di/1000, (d - tl - en - rest - di)/1000, log(fN / fS) }' "$O/tickets.txt"
  done
  echo; echo "decisions placed in both arms: both filled (n, SM-S) | filled in S only (n, -S P&L, big ones) | filled in SM only (n, SM P&L) (\$k)"
  for k in $KS; do
    awk -v k=p$k '$2 == k && $3 == "Placed" { key = $4 " " $5; f = ($7 == "filled" || $7 == "open"); if ($1 == "S") { s[key] = $9; fs[key] = f; ss[key] = $5 "(" $4 "," int($9/1000) "k)" } else { n[key] = $9; fn[key] = f; sn[key] = $7 } }
      END { for (x in s) { if (!(x in n)) continue; if (fs[x] && fn[x]) { a++; da += n[x] - s[x] } else if (fs[x]) { b++; db -= s[x]; if (s[x] > 50000) big = big " " ss[x] "->SM " sn[x] } else if (fn[x]) { c++; dc += n[x] } }
        printf "%s | %d %+.0f | %d %+.0f%s | %d %+.0f\n", k, a, da/1000, b, db/1000, big, c, dc/1000 }' "$O/tickets.txt"
  done
  echo; echo "cash detail of fill-time refusals of tail and swing tickets (results/sm cash_rejections.csv)"
  for k in $KS; do grep -hE '^(ADMA|BBWI|ADNT|MOH)-' "$SMR/ps-SM-p$k-s0-cash_rejections.csv" | sed "s/^/p$k /"; done
} > "$O/decomposition.txt"

# 5. Cohorts: ln(1+R) of filled or open tickets pooled over p0-p5, with exclusions; volume ratio; exit mix.
dist='function q(p,   h, i) { h = 1 + p * (n - 1); i = int(h); return (i >= n) ? v[n] : v[i] + (h - i) * (v[i + 1] - v[i]) }
  { n++; v[n] = log(1 + $16); s += log(1 + $16); P += $9; if ($16 > 1) t1++; if ($16 > 0.5) t5++; if ($7 == "open") op++ }
  END { if (!n) { printf "%-44s n=0\n", lab; exit } for (i = 2; i <= n; i++) { t = v[i]; for (j = i - 1; j >= 1 && v[j] > t; j--) v[j + 1] = v[j]; v[j + 1] = t }
    printf "%-44s n=%3d (open %2d) mean %+.4f median %+.4f p10 %+.4f p25 %+.4f p75 %+.4f p90 %+.4f max %+.4f >+50%% %4.1f%% >+100%% %4.1f%% P&L %+.0fk\n", lab, n, op, s/n, q(.5), q(.1), q(.25), q(.75), q(.9), v[n], 100*t5/n, 100*t1/n, P/1000 }'
coh() { awk -v A="$1" -v C="$2" -v ex="$3" -v CL="${5:-}" 'BEGIN { n = split(ex, e, " "); for (i = 1; i <= n; i++) X[e[i]] = 1 }
    $1 == A && $3 ~ ("^(" C ")$") && ($7 == "filled" || ($7 == "open" && CL != "closed")) && !($5 in X)' "$O/tickets.txt" | awk -v lab="$4" "$dist"; }
{ echo "pooled over p0-p5, filled or open tickets (open = 2024-12-30 mark), ln(1+R), R = TR P&L / notional"
  coh SM entrant "" "entrants (SM)"
  coh SM entrant "BMA" "entrants ex BMA"
  coh S Insufficient_cash "" "displaced at decision (S side)"
  coh S Insufficient_cash "" "displaced at decision, closed only" closed
  coh S Insufficient_cash "APPS" "displaced at decision ex APPS"
  coh S leaver "" "leavers (S side)"
  coh S "cut|held" "" "S cut/held (in SM list, not SM top-N)"
  coh SM "cut|held" "" "SM cut/held gains"
  coh SM Insufficient_cash "" "S cash -> SM placed (SM side)"
  coh SM Insufficient_cash "APPS" "S cash -> SM placed ex APPS"
  coh S Placed "" "shared, S side"
  coh SM Placed "" "shared, SM side"
  coh S Placed "ADMA APPS MMYT" "shared S side ex ADMA, APPS, MMYT"
  coh S "Insufficient_cash|leaver|cut|held" "" "S-only at the decision"
  coh SM "entrant|Insufficient_cash|cut|held|Share_class_held" "" "SM-only at the decision"
  coh S "Insufficient_cash|leaver|cut|held" "APPS" "S-only ex APPS"
  coh SM "entrant|Insufficient_cash|cut|held|Share_class_held" "APPS" "SM-only ex APPS"
  echo
  awk '$1 == "SM" && $3 == "entrant" { k = $5 " " $4; n[k]++; if ($7 == "filled" || $7 == "open") f[k] = 1 } END { for (x in n) { d++; if (n[x] == 6) a6++; if (x in f) df++ } printf "distinct entrant tickets (symbol, decision date): %d; placed in all six cells: %d; filled in at least one: %d\n", d, a6, df }' "$O/tickets.txt"
  echo; echo "entrant tickets pooled, by name: cells and status"
  awk '$1 == "SM" && $3 == "entrant" { k = $5 " " $4; c[k] = c[k] " " $2 ":" $7 ":" int($9/1000) "k" } END { for (x in c) print x, "|" c[x] }' "$O/tickets.txt" | sort -k2
  echo; echo "entry_volume_ratio (trades.csv) of SM closed trades: entrants vs the rest"
  for k in $KS; do awk -F, -v k=p$k 'NR > 1 { print k "|" $20 "|" $15 }' "$SMR/ps-SM-p$k-s0-trades.csv"; done > "$T/vr"
  awk '$1 == "SM" && $7 == "filled" { print $2 "|" $6 "|" $3 }' "$O/tickets.txt" | awk -F'|' 'NR == FNR { c[$1 "|" $2] = $3; next } ($1 "|" $2) in c { g = (c[$1 "|" $2] == "entrant") ? "entrant" : "rest"; n[g]++; v[g, n[g]] = $3 }
    END { for (g in n) { m = n[g]; for (i = 1; i <= m; i++) a[i] = v[g, i]; for (i = 2; i <= m; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j+1] = a[j]; a[j+1] = t }
      printf "%-8s n=%d p25 %.2f median %.2f p75 %.2f p90 %.2f max %.1f\n", g, m, a[int(.25*(m-1))+1], a[int(.5*(m-1))+1], a[int(.75*(m-1))+1], a[int(.9*(m-1))+1], a[m]; delete a } }' - "$T/vr"
  echo; echo "exit mix, closed SM trades pooled"
  awk '$1 == "SM" && $7 == "filled" { g = ($3 == "entrant") ? "entrant" : (($3 == "Placed") ? "shared" : "other-SM-only"); n[g]++; d[g] += $13; ex[g " " $12]++; r[g " " $12] += $16; w[g] += ($16 > 0); z[g] += $11 }
    END { for (g in n) { printf "%-14s n=%3d mean days %3.0f win %4.1f%% size %.1f%% of NAV |", g, n[g], d[g]/n[g], 100*w[g]/n[g], 100*z[g]/n[g]; for (x in ex) { split(x, y, " "); if (y[1] == g) printf " %s %.0f%% (mean R %+.1f%%)", y[2], 100*ex[x]/n[g], 100*r[x]/ex[x] } printf "\n" } }' "$O/tickets.txt"
} > "$O/cohorts.txt"

# 6. Tail ledger: every ticket above +100 % (closed or marked), its class, per arm and cell.
awk '($7 == "filled" || $7 == "open") && $16 != "NA" && $16 > 1 { printf "%-3s %s %-6s %s %-6s %-17s %+6.0fk %7.1f%%\n", $1, $2, $5, $4, $7, $3, $9/1000, 100 * $16 }' "$O/tickets.txt" | sort -k3,3 -k2,2 -k1,1 > "$O/tail-ledger.txt"

# 7. Same-data checks.
{ echo "first common date the paired NAVs differ (equity_curve.csv)"
  for k in $KS; do awk -F, -v k=p$k 'NR == FNR { if (FNR > 1) s[$1] = $2; next } FNR > 1 && ($1 in s) && s[$1] != $2 && !d { print k, $1, "S", s[$1], "SM", $2; d = 1 }' "$(res S $k)-equity_curve.csv" "$(res SM $k)-equity_curve.csv"; done
  echo; echo "equity-curve rows and dates present in one arm only"
  for k in $KS; do awk -F, -v k=p$k 'FNR == 1 { f++; next } f == 1 { s[$1] = 1; ns++; next } { n++; if (!($1 in s)) x = x " " $1 } END { printf "%s rows S %d SM %d; SM-only dates:%s\n", k, ns, n, x }' "$(res S $k)-equity_curve.csv" "$(res SM $k)-equity_curve.csv"; done
  grep -E '^(2019-01-0[12]|2019-12-31|2020-01-0[12]),' "$(res SM 0)-equity_curve.csv" | sed 's/^/SM p0 /'
  grep -E '^(2019-01-02|2019-12-31|2020-01-02),' "$(res S 0)-equity_curve.csv" | sed 's/^/S  p0 /'
  echo "USAS bars on those dates (data/): $(grep -E '^(2019-01-01|2020-01-01),' "$(csv_of USAS)" | tr '\n' ' ')"
  echo "USAS in yearly lists 2017-2024: $(grep -c ' USAS$' "$T/yearly"); in monthly lists dated 2018-05..2024-12: $(grep ' USAS$' "$T/monthly" | awk '{printf "%s ", $1}')"
  echo; echo "trades with the same symbol, entry and exit date in both arms: price, pnl%, stop and dividend-per-share mismatches"
  for k in $KS; do awk -F, -v k=p$k 'FNR == 1 { f++; next } f == 1 { s[$1 "|" $3 "|" $4] = $6 " " $7 " " $10 " " $11 " " $25 " " $8; next }
      { key = $1 "|" $3 "|" $4; if (!(key in s)) next; n++; split(s[key], a, " "); if (a[1] != $6 || a[2] != $7) pm++; if (a[3] != $10) rm++; if (a[4] != $11) sm++; if (a[6] > 0 && $8 > 0) { dd = a[5] / a[6] - $25 / $8; if (dd > 0.002 || dd < -0.002) dm++ } }
      END { printf "%s shared %d: price %d, pnl%% %d, entry_stop %d, dividend/share %d\n", k, n, pm, rm, sm, dm }' "$(res S $k)-trades.csv" "$(res SM $k)-trades.csv"; done
  echo; echo "macro_trend.sexp identical per pair"
  for k in $KS; do if cmp -s "$(res S $k)-macro_trend.sexp" "$(res SM $k)-macro_trend.sexp"; then echo "p$k identical"; else echo "p$k DIFFERS"; fi; done
  echo; echo "params.sexp differences, p0"
  for a in S SM; do tr -s ' \n' '  ' < "$(res $a 0)-params.sexp" | awk '{ gsub(/\) \(/, ")\n("); print }' > "$T/params-$a"; done
  diff "$T/params-S" "$T/params-SM" || true
} > "$O/same-data.txt" 2>&1

# 8. Years: returns per cell, year-end NAV ratio SM/S, and the 2022 mark-to-market attribution by class.
close_on() { awk -F, -v d="$2" 'NR > 1 && $1 <= d { c = $5 } END { print c }' "$(csv_of "$1")"; }
{ echo "yearly return per cell 2019..2024"
  for k in $KS; do for a in S SM; do awk -F, -v c="$a p$k" 'NR > 1 { last[substr($1, 1, 4)] = $2 } END { p = 1000000; printf "%-6s", c; for (y = 2019; y <= 2024; y++) { printf " %+6.1f%%", 100 * (last[y] / p - 1); p = last[y] } printf "\n" }' "$(res $a $k)-equity_curve.csv"; done; done
  echo; echo "year-end NAV ratio SM/S 2019..2024"
  for k in $KS; do awk -F, -v k=p$k 'FNR == 1 { f++; next } f == 1 { s[substr($1, 1, 4)] = $2; next } { n[substr($1, 1, 4)] = $2 } END { printf "%s", k; for (y = 2019; y <= 2024; y++) printf " %.3f", n[y] / s[y]; printf "\n" }' "$(res S $k)-equity_curve.csv" "$(res SM $k)-equity_curve.csv"; done
  echo; echo "2022: qty x (end - start) per position held in 2022 (start = 2021-12-31 close or the fill; end = exit or 2022-12-30 close), by class (\$k)"
  for k in $KS; do for a in S SM; do r=$(res $a $k)
    { awk -F, 'NR > 1 { print $1, $3, $4, $8, $6, $7, $20 }' "$r-trades.csv"; awk -F, 'NR > 1 { print $1, $3, "open", $5, $4, "NA", "open-" $1 }' "$r-open_positions.csv"; } \
      | awk '$2 <= "2022-12-31" && ($3 == "open" || $3 >= "2022-01-01") { print $0, ($2 < "2022-01-01" ? 1 : 0), (($3 != "open" && $3 < "2023-01-01") ? 0 : 1) }' \
      | while read -r s f e q ep xp pid before after; do
      if [ "$before" = 1 ]; then p0=$(close_on "$s" 2021-12-31); else p0=$ep; fi
      if [ "$after" = 0 ]; then p1=$xp; else p1=$(close_on "$s" 2022-12-31); fi
      echo "$a p$k $s $f $e $q $p0 $p1 $pid"; done
  done; done > "$T/y22"
  awk 'NR == FNR { if ($7 == "filled") c[$1 " " $2 " " $6] = $3; if ($7 == "open") c[$1 " " $2 " open-" $5] = $3; next } { k = $1 " " $2 " " $9; print $0, ((k in c) ? c[k] : "?"), $6 * ($8 - $7) }' "$O/tickets.txt" "$T/y22" > "$O/y2022-positions.txt"
  for k in $KS; do for a in S SM; do
    dn=$(awk -F, 'NR > 1 { if (substr($1, 1, 4) == "2021") x = $2; if (substr($1, 1, 4) == "2022") y = $2 } END { printf "%.0f", (y - x) / 1000 }' "$(res $a $k)-equity_curve.csv")
    awk -v A=$a -v K=p$k -v dn="$dn" '$1 == A && $2 == K { s[$10] += $11; t += $11; if ($3 == "TRT") tr += $11 } END { printf "%-3s %s dNAV %+5dk  MTM %+5.0fk (TRT %+.0fk) |", A, K, dn, t/1000, tr/1000; for (c in s) printf " %s %+.0fk", c, s[c]/1000; printf "\n" }' "$O/y2022-positions.txt"
  done; done
} > "$O/years.txt"

# 9. Exposure and return by SPY regime, per year and per period, S p0 vs SM p0 (the pack's regime rule).
j2l() { tr -d '[]"' < "$1" | tr '\n' ' ' | sed 's/ //g' | awk -v n="$2" -F, '{ for (i = 1; i <= NF; i += n) { s = $i; for (k = 1; k < n; k++) s = s "," $(i + k); print s } }'; }
j2l "$PSM/spy_warmup.json" 3 > "$T/spy_warm.csv"; j2l "$PSM/spy.json" 2 > "$T/spy.csv"
j2l "$PS/p0_nav.json" 4 > "$T/nav_S.csv"; j2l "$PSM/p0_nav.json" 4 > "$T/nav_SM.csv"
sed 's/np=split("2019-2021 2022-2024 2019-2024",PER," ");/np=split("2019-2019 2020-2020 2021-2021 2022-2022 2023-2023 2024-2024 2019-2021 2022-2024 2019-2024",PER," ");/' "$RAWK" > "$T/regime.awk"
grep -q '2019-2019 2020-2020' "$T/regime.awk" || { echo "regime.awk period list not found" >&2; exit 1; }
(cd "$T" && awk -f regime.awk spy_warm.csv spy.csv nav_S.csv nav_SM.csv) > "$O/regime-split.txt"

# 10. Entrant funnel: 12-month forward return (adjusted close, month end to month end) of every member of each
#     monthly list dated 2018-12-31..2024-11-30; entrant = outside the yearly list in force; a >= 50 % one-day
#     adjusted move inside the 12 months flags a possible splice. Then: did the >+300 % names reach the top-N?
awk '$1 >= "2018-12-31" { print $2 }' "$T/monthly" | sort -u > "$T/fsyms"
while read -r s; do f=$(csv_of "$s"); [ -f "$f" ] || continue
  awk -F, -v s="$s" 'NR > 1 && $1 >= "2018-11-01" && $1 <= "2025-12-31" && $6 > 0 { m = substr($1, 1, 7); last[m] = $6
      if (pv > 0) { r = $6 / pv - 1; if (r >= 0.5 || r <= -0.333) j = j " " $1 } pv = $6 }
    END { for (m in last) printf "%s ME %s %s\n", s, m, last[m]; if (j != "") printf "%s JUMPS%s\n", s, j }' "$f"
done < "$T/fsyms" > "$T/me"
awk 'function yr(d,   y) { y = substr(d, 1, 4) + 0; if (substr(d, 6, 5) < "05-31") y--; return y }
  function addm(m, k,   y, mo) { y = substr(m, 1, 4) + 0; mo = substr(m, 6, 2) + k; while (mo > 12) { mo -= 12; y++ } return sprintf("%04d-%02d", y, mo) }
  FILENAME == ARGV[1] { ym[$1 " " $2] = 1; next }
  FILENAME == ARGV[2] { if ($2 == "ME") me[$1 " " $3] = $4; else for (i = 3; i <= NF; i++) J[$1] = J[$1] " " $i; next }
  $1 >= "2018-12-31" && $1 <= "2024-11-30" { L = $1; s = $2; m0 = substr(L, 1, 7); m1 = addm(m0, 12); a = me[s " " m0]; b = me[s " " m1]
    sp = 0; n = split(J[s], jj, " "); for (i = 1; i <= n; i++) if (jj[i] > L && substr(jj[i], 1, 7) <= m1) sp = 1
    print L, s, (((yr(L) " " s) in ym) ? 0 : 1), ((a > 0 && b > 0) ? b / a - 1 : "NA"), sp }' "$T/yearly" "$T/me" "$T/monthly" > "$T/fwd"
{ echo "member-months of the monthly lists dated 2018-12-31..2024-11-30: 12-month forward return (adjusted close)"
  awk '{ n[$3]++; if ($4 != "NA") { v[$3]++; if ($4 > 3) t3[$3]++; if ($4 > 1) t1[$3]++; if ($4 > 3 && $5 == 0) c3[$3]++ } }
    END { for (e = 0; e <= 1; e++) printf "%s: rows %d, with R12 %d, >+100%% %d (%.2f%%), >+300%% %d (%.2f%%), >+300%% without a >=50%% day %d\n", (e ? "entrants" : "members "), n[e], v[e], t1[e], 100*t1[e]/v[e], t3[e], 100*t3[e]/v[e], c3[e]
      printf "entrant share: of rows %.1f%%, of >+100%% rows %.1f%%, of >+300%% rows %.1f%%, of >+300%% rows without a >=50%% day %.1f%%\n", 100*n[1]/(n[0]+n[1]), 100*t1[1]/(t1[0]+t1[1]), 100*t3[1]/(t3[0]+t3[1]), 100*c3[1]/(c3[0]+c3[1]) }' "$T/fwd"
  for e in 0 1; do awk -v e=$e '$3 == e && $4 != "NA" { print $4 }' "$T/fwd" | sort -g | awk -v e=$e '{ v[NR] = $1 } END { printf "%s R12: p10 %+.3f p25 %+.3f median %+.3f p75 %+.3f p90 %+.3f\n", (e ? "entrants" : "members "), v[int(.1*NR)+1], v[int(.25*NR)+1], v[int(.5*NR)+1], v[int(.75*NR)+1], v[int(.9*NR)+1] }'; done
  echo; echo "distinct names with a >+300 % R12 month (no >=50 % day): first such month; did the arm's p0 top-N decide them within 12 months?"
  for e in 1 0; do A=SM; [ $e = 0 ] && A=S
    awk -v e=$e '$3 == e && $4 != "NA" && $4 > 3 && $5 == 0 && !($2 in f) { f[$2] = $1; r[$2] = $4 } END { for (s in f) print s, f[s], r[s] }' "$T/fwd" | sort -k2 > "$T/m300"
    awk -v A=$A -v lab="$( [ $e = 1 ] && echo entrants || echo members)" 'NR == FNR { if ($1 == "p0" && $2 == A) d[$4] = d[$4] " " $3 ":" $5; next }
      { s = $1; L = $2; L2 = (substr(L, 1, 4) + 1) substr(L, 5); n = split(d[s], dd, " "); h = 0; o = ""; for (i = 1; i <= n; i++) { split(dd[i], z, ":"); if (z[1] >= L && z[1] <= L2) { h++; o = o " " z[2] } }
        N++; if (o ~ /Placed/) P++; if (h) { H++; det = det sprintf("  %s %s R12 %+.0f%%:%s\n", s, L, 100 * $3, o) } }
      END { printf "%s: %d names; reached %s p0 top-N within 12 months: %d; placed: %d\n%s", lab, N, A, H, P, (lab == "entrants" ? det : "") }' "$O/annot.txt" "$T/m300"
    if [ $e = 1 ]; then echo "  entrant names, trading days of history before their first >+300 % month:"
      while read -r s L r; do nb=$(awk -F, -v L="$L" 'NR > 1 && $1 <= L { n++ } END { print n + 0 }' "$(csv_of "$s")"); echo "$nb"; done < "$T/m300" | awk '{ if ($1 < 260) a++; else if ($1 < 520) b++; else c++ } END { printf "  < 260: %d | 260-519: %d | >= 520: %d\n", a, b, c }'
    fi
  done
} > "$O/entrant-funnel.txt"

{ echo; echo "entrant >+300 % names: top-N decisions in any SM cell within 12 months of the first such month, by outcome"
  awk '$3 == 1 && $4 != "NA" && $4 > 3 && $5 == 0 && !($2 in f) { f[$2] = $1 } END { for (s in f) print s, f[s] }' "$T/fwd" | sort -k2 > "$T/e300"
  awk 'NR == FNR { if ($2 == "SM") d[$4] = d[$4] " " $1 ":" $3 ":" $5; next }
    { s = $1; L = $2; L2 = (substr(L, 1, 4) + 1) substr(L, 5); n = split(d[s], dd, " "); delete oc; delete ce; h = 0
      for (i = 1; i <= n; i++) { split(dd[i], z, ":"); if (z[2] >= L && z[2] <= L2) { h = 1; oc[z[3]]++; ce[z[1]] = 1 } }
      N++; if (h) { H++; c = 0; for (x in ce) c++; printf "  %s %s: %d cells;", s, L, c; for (o in oc) printf " %s %d", o, oc[o]; printf "\n" } }
    END { printf "  %d names; reached any SM cell top-N: %d\n", N, H }' "$O/annot.txt" "$T/e300"
} >> "$O/entrant-funnel.txt"

# 11. README step 4 extras: tail per cell, the symbol|entry_date cohort join, paired by seed, max DD windows.
{ echo "tail per cell: trades, pnl_percent > 100, top trade by TR P&L, its share of realised TR P&L, end unrealised (actual.sexp)"
  for k in $KS; do for a in S SM; do r=$(res $a $k); un=$(grep -oE 'unrealized_pnl [-0-9.e]+' "$r-actual.sexp" | awk '{print $2}')
    awk -F, -v c="$a p$k" -v un="$un" 'NR > 1 { p = $9 + $25; t += p; n++; if ($10 > 100) b++; if (p > mx) { mx = p; ms = $1 " " $3 } }
      END { printf "%-6s trades %d | >+100%% %d | top %s %.0fk | top share %.0f%% of realised %.0fk | unrealised %.0fk\n", c, n, b, ms, mx/1000, 100*mx/t, t/1000, un/1000 }' "$r-trades.csv"
  done; done
  echo; echo "cohort join on symbol|entry_date (trades.csv): both (S, SM P&L) | S-only | SM-only"
  for k in $KS; do awk -F, -v k=p$k 'FNR == 1 { f++; next } { key = $1 "|" $3; p = $9 + $25; if (f == 1) s[key] = p; else n[key] = p }
      END { for (x in s) { if (x in n) { nb++; bs += s[x]; bn += n[x] } else { no++; po += s[x] } } for (x in n) if (!(x in s)) { nn++; pn += n[x] }
        printf "%s both %d (S %+.0fk, SM %+.0fk) | S-only %d %+.0fk | SM-only %d %+.0fk\n", k, nb, bs/1000, bn/1000, no, po/1000, nn, pn/1000 }' "$(res S $k)-trades.csv" "$(res SM $k)-trades.csv"; done
  echo; echo "paired by seed: ln(1+R) S, SM, difference (actual.sexp)"
  for k in $KS; do rs=$(grep -oE 'total_return_pct [-0-9.e]+' "$(res S $k)-actual.sexp" | awk '{print $2}'); rn=$(grep -oE 'total_return_pct [-0-9.e]+' "$(res SM $k)-actual.sexp" | awk '{print $2}')
    awk -v k=p$k -v a="$rs" -v b="$rn" 'BEGIN { printf "%s %.4f %.4f %+.4f\n", k, log(1 + a/100), log(1 + b/100), log(1 + b/100) - log(1 + a/100) }'; done > "$T/pairs"
  cat "$T/pairs"; awk '{ d = $4; s += d; ss += d * d; n++ } END { m = s / n; printf "mean %+.4f sd %.4f (n=%d)\n", m, sqrt((ss - n * m * m) / (n - 1)), n }' "$T/pairs"
  echo; echo "max drawdown peak -> trough per cell (equity_curve.csv)"
  for k in $KS; do for a in S SM; do awk -F, -v c="$a p$k" 'NR > 1 { v = $2; if (v > pk) { pk = v; pd = $1 } dd = 1 - v / pk; if (dd > mdd) { mdd = dd; tp = pd; td = $1 } } END { printf "%-6s %.1f%% %s -> %s\n", c, 100 * mdd, tp, td }' "$(res $a $k)-equity_curve.csv"; done; done
  echo; echo "tail names caught per arm and cell (TR P&L, \$k)"
  for k in $KS; do for a in S SM; do awk -v A=$a -v K=p$k 'BEGIN { split("APPS ADMA BBWI MMYT DXCM MSTR GLNG", t, " "); for (i in t) TL[t[i]] = 1 }
      $1 == A && $2 == K && ($7 == "filled" || $7 == "open") && ($5 in TL) { h[$5] += $9 }
      END { printf "%-3s %s:", A, K; split("APPS ADMA BBWI MSTR GLNG MMYT DXCM", o, " "); for (i = 1; i <= 7; i++) printf " %s %s", o[i], ((o[i] in h) ? sprintf("%+.0fk", h[o[i]]/1000) : "-"); printf "\n" }' "$O/tickets.txt"; done; done
  echo; echo "S Placed -> SM Insufficient_cash: SM placements earlier in the same week's list"
  for k in $KS; do awk -v K=p$k '$1 == K && $2 == "SM" { if ($3 != cur) { cur = $3; e = 0; o = 0 } if ($5 == "Placed" && $6 != "Placed") { if ($6 == "absent" && $7 == 0) e++; else o++ }
      if ($5 == "Insufficient_cash" && $6 == "Placed") { t++; if (e) a++; else if (o) b++; else c++ } }
      END { printf "%s displaced %d: after an entrant placement that week %d, after another SM-only placement %d, carry-over %d\n", K, t, a, b, c }' "$O/annot.txt"; done
} > "$O/step4.txt"

echo "wrote $O/{annot,transitions,tickets,marks-check,decomposition,cohorts,tail-ledger,same-data,years,regime-split,entrant-funnel,step4}.txt"
