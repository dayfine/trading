#!/bin/sh
# analyst_checks.sh -- every derived figure the results-analyst reading of this experiment quotes beyond
# decide.sh / report.sh / capacity.sh / cash.sh. It reads the committed per-arm artifacts of this experiment (R) and of
# #3595 (O), the committed pit-v12 composition lists (C) and, through the committed read/positions.sh and
# read/list_bands.sh, the local bar store (D). Those per-row tables go to a temporary directory and are never printed;
# this script prints only summaries: counts, sums of NAV shares, bands, dates, ranks and log ratios, never a close.
#
# usage (repo root): sh dev/experiments/price-band-confirm-2026-11-13/results/read/analyst_checks.sh [DATA_DIR]
#   > dev/experiments/price-band-confirm-2026-11-13/results/read/analyst_checks.txt
X=dev/experiments/price-band-confirm-2026-11-13
R=${R:-$X/results}; O=${O:-dev/experiments/price-band-tiebreak-2026-11-13/results}
C=${C:-trading/test_data/backtest_scenarios/pit-v12/composition}; D=${1:-data}
T=${TMPDIR:-/tmp}/pbc-analyst.$$; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
for c in 1 2; do
  sh $X/read/positions.sh "$R" pbc$c "$D" > "$T/pos-$c.tsv"
  sh $X/read/list_bands.sh "$R" pbc$c "$D" > "$T/lb-$c.tsv"
done
sh $X/read/positions.sh "$O" pb "$D" > "$T/pos-pb.tsv"
cell() { [ "$1" = pb ] && echo "26y top-3000 (#3595)" || echo "C$1"; }
pref() { [ "$1" = pb ] && echo "$O/k$2/pb-$3-k$2-s0-" || echo "$R/k$2/pbc$1-$3-k$2-s0-"; }

echo "A. Spread of ln(1+R) per arm, and all 25 cross-seed P vs S comparisons (actual.sexp)"
for c in 1 2 pb; do
  for k in 0 1 2 3 4; do for a in S P; do
    printf '%s %s ' "$k" "$a"; tr '\n' ' ' < "$(pref $c $k $a)actual.sexp" | sed -E 's/.*\(total_return_pct ([-0-9.e]+)\).*/\1/'; echo
  done; done | awk -v tag="$(cell $c)" '{ L[$1, $2] = log(1 + $3 / 100) }
    END { u = 0; for (i = 0; i < 5; i++) for (j = 0; j < 5; j++) if (L[i, "P"] > L[j, "S"]) u++
      for (a = 1; a <= 2; a++) { arm = (a == 1) ? "S" : "P"; m = 0; for (i = 0; i < 5; i++) m += L[i, arm]; m /= 5
        v = 0; for (i = 0; i < 5; i++) v += (L[i, arm] - m) ^ 2; mean[arm] = m; sd[arm] = sqrt(v / 4) }
      printf "  %s: mean ln S %.4f (SD %.3f), P %.4f (SD %.3f), mean paired diff %+.4f; P above S in %d of 25 cross pairs\n",
        tag, mean["S"], sd["S"], mean["P"], sd["P"], mean["P"] - mean["S"], u }'
done

echo; echo "B. Max drawdown episodes (equity_curve.csv): depth, peak date, trough date"
for c in 1 2 pb; do for k in 0 1 2 3 4; do for a in S P; do
  awk -F, -v tag="  $(cell $c) k$k $a" 'NR > 1 { v = $2 + 0; if (v > pk) { pk = v; pkd = $1 } dd = (pk - v) / pk
      if (dd > m) { m = dd; mp = pkd; mt = $1 } }
    END { printf "%s %.2f %% %s -> %s\n", tag, 100 * m, mp, mt }' "$(pref $c $k $a)equity_curve.csv"
done; done; done

echo; echo "C. C1 against #3595 at the same seed and arm"
echo "C1. First year from which C1's positions (symbol|entry_date, trades + open) equal #3595's"
for k in 0 1 2 3 4; do for a in S P; do
  { awk -F, 'FNR > 1 && $3 >= "2013-01-01" { print "O", $1 "|" $3 }' "$(pref pb $k $a)trades.csv" "$(pref pb $k $a)open_positions.csv"
    awk -F, 'FNR > 1 { print "N", $1 "|" $3 }' "$(pref 1 $k $a)trades.csv" "$(pref 1 $k $a)open_positions.csv"; } |
  awk -v tag="  k$k $a" '{ s[$1, $2] = 1; keys[$2] = 1 }
    END { for (x in keys) { y = substr(x, index(x, "|") + 1, 4) + 0; if (!(("O", x) in s) || !(("N", x) in s)) bad[y] = 1
            if (("N", x) in s) { n[y]++; if (("O", x) in s) mm[y]++ } }
      f = 2027; for (y = 2026; y >= 2013; y--) { if (bad[y]) break; f = y }
      line = ""; for (y = 2013; y <= 2018; y++) line = line sprintf(" %d %d/%d", y, mm[y], n[y])
      printf "%s: identical from %d; matched/C1 positions by entry year:%s\n", tag, f, line }'
done; done
echo "C2. Year-on-year change in year-end ln(NAV_P / NAV_S), 2013-2026: #3595 | C1"
for k in 0 1 2 3 4; do
  for c in pb 1; do for a in S P; do
    awk -F, -v c=$c -v a=$a 'NR > 1 { y = substr($1, 1, 4); v[y] = $2 } END { for (y in v) print c, a, y, v[y] }' "$(pref $c $k $a)equity_curve.csv"
  done; done | awk -v k=$k '{ V[$1, $2, $3] = $4 }
    END { line = "  k" k ":"; for (y = 2013; y <= 2026; y++) {
        g26 = log(V["pb", "P", y] / V["pb", "S", y]) - log(V["pb", "P", y - 1] / V["pb", "S", y - 1])
        g1 = log(V["1", "P", y] / V["1", "S", y]) - ((y == 2013) ? 0 : log(V["1", "P", y - 1] / V["1", "S", y - 1]))
        line = line sprintf(" %d %+.3f|%+.3f", y % 100, g26, g1) }
      print line }'
done

echo; echo "D. Closed one-arm positions at >= +100 % (positions.sh class), and P minus S doublers per seed"
for c in 1 2 pb; do
  awk -F'\t' -v tag="$(cell $c)" 'NR > 1 && $7 == "closed" && $14 + 0 >= 100 { n[$1, $3]++
      if ($2 != "shared") printf "  %s %s %s %s %s band %s %+.1f %% %.1f %% of entry NAV\n", tag, $1, $2, $4, $5, $9, $14, $13 }
    END { line = "  " tag " P minus S:"; for (k = 0; k < 5; k++) line = line sprintf(" k%d %+d", k, n["k" k, "P"] - n["k" k, "S"]); print line }' "$T/pos-$c.tsv"
done

echo; echo "E. Positions grouped by nP - nS (seeds holding the key in P minus in S); net = P minus S, points of entry NAV"
for c in 1 2; do
  awk -F'\t' -v tag="$(cell $c)" 'NR > 1 { x = $4 "|" $5; if ($3 == "P") { nP[x]++; sP[x] += $13 } else { nS[x]++; sS[x] += $13 }; b[x] = $9; K[x] = 1 }
    END { for (x in K) { d = nP[x] - nS[x]; v = sP[x] - sS[x]; g = (d >= 3) ? "P>=S+3" : (d <= -3) ? "S>=P+3" : (d == 0) ? "equal" : "1<=|d|<=2"
          G[g] += v; N[g]++; a = (v < 0) ? -v : v; if (a >= 8) printf "  %s key %s band %s nP %d nS %d net %+.1f\n", tag, x, b[x], nP[x], nS[x], v }
      for (g in G) printf "  %s group %s: %d keys, net %+.1f\n", tag, g, N[g], G[g] }' "$T/pos-$c.tsv" | sort
done

echo; echo "F. Net (P minus S over all positions) by dollar-volume rank in the top-3000 list in force at entry"
for y in $(seq 1999 2025); do
  sed -n 's/.*(symbol \([^)]*\)).*/\1/p' "$C/top-3000-$y.sexp" | awk -v y=$y '{ print y "\t" $1 "\t" NR }'
done > "$T/rank.tsv"
for c in pb 1 2; do
  awk -F'\t' -v tag="$(cell $c)" 'FILENAME ~ /rank\.tsv$/ { rk[$1 "|" $2] = $3; next }
    FNR > 1 { y = substr($5, 1, 4) + 0; ly = (substr($5, 6, 5) >= "05-31") ? y : y - 1; r = rk[ly "|" $4]; if (r == "") r = 9999
      v = ($3 == "P") ? $13 : -$13; for (i = 1; i <= 6; i++) if (r <= cut[i]) inn[i, $1] += v; else out[i, $1] += v }
    BEGIN { cut[1] = 500; cut[2] = 750; cut[3] = 1000; cut[4] = 1500; cut[5] = 2000; cut[6] = 2500 }
    END { for (i = 1; i <= 6; i++) { line = sprintf("  %s rank <= %d:", tag, cut[i]); ti = 0; to = 0
        for (k = 0; k < 5; k++) { line = line sprintf(" k%d %+.1f/%+.1f", k, inn[i, "k" k], out[i, "k" k]); ti += inn[i, "k" k]; to += out[i, "k" k] }
        printf "%s | pooled inside %+.1f, outside %+.1f\n", line, ti, to } }' "$T/rank.tsv" "$T/pos-$c.tsv"
done
echo "F2. top-1000 list in force on the decision date (+ member, - not): #3595's deciding names"
for e in "MERC 2010" "ATML 2010" "WAL 2011" "DINO 2009" "REGN 2010" "ADMA 2023"; do
  set -- $e; if grep -q "(symbol $1)" "$C/top-1000-$2.sexp"; then m=+; else m=-; fi
  if grep -q "(symbol $1)" "$C/top-3000-$2.sexp"; then t=+; else t=-; fi
  echo "  $1: top-1000-$2 $m, top-3000-$2 $t"
done

echo; echo "G. List slots and list swaps by band (decision-date band, list_bands.sh)"
for c in 1 2; do
  for k in 0 1 2 3 4; do
    awk -F'\t' -v k=k$k 'FILENAME ~ /lb-/ { b[$1 "|" $2] = $3; next } FILENAME ~ /pos-/ { if (FNR > 1 && $1 == k) { n = ++np[$3, $4]; en[$3, $4, n] = $5; ex[$3, $4, n] = ($6 == "-") ? "9999" : $6 } next }
      FNR == 1 { next } { a = (FILENAME ~ /-S-k/) ? "S" : "P"; L[a, $3, $2] = 1; R[a, $3] = 1; print "SLOT", a, b[$2 "|" $3] }
      END { for (x in L) { split(x, z, SUBSEP); a = z[1]; d = z[2]; s = z[3]; if (!((("S", d) in R) && (("P", d) in R))) continue
          o = (a == "S") ? "P" : "S"; if ((o, d, s) in L) continue; h = 0; for (i = 1; i <= np[o, s]; i++) if (en[o, s, i] <= d && d < ex[o, s, i]) h = 1
          print "SWAP", a, b[s "|" d], h } }' "$T/lb-$c.tsv" "$T/pos-$c.tsv" "$R/k$k/pbc$c-S-k$k-s0-entries.tsv" "$R/k$k/pbc$c-P-k$k-s0-entries.tsv"
  done | awk -v c=$c '$1 == "SLOT" { n[$2]++; s[$2, $3]++ } $1 == "SWAP" { m[$2]++; w[$2, $3]++; if ($4) h[$2, ($3 == 3)]++ }
    END { for (a in n) printf "  C%s %s list slots %d: <8 %.1f %%, 8-14 %.1f %%, 14-33 %.1f %%, >=33 %.1f %%\n", c, a, n[a], 100 * s[a, 0] / n[a], 100 * s[a, 1] / n[a], 100 * s[a, 2] / n[a], 100 * s[a, 3] / n[a]
      for (a in m) { o = (a == "S") ? "P" : "S"; printf "  C%s %s-not-%s names %d: <8 %.1f %%, 8-14 %.1f %%, 14-33 %.1f %%, >=33 %.1f %%; held by %s that Friday: >=33 %d of %d, <33 %d of %d\n",
          c, a, o, m[a], 100 * w[a, 0] / m[a], 100 * w[a, 1] / m[a], 100 * w[a, 2] / m[a], 100 * w[a, 3] / m[a], o, h[a, 1], w[a, 3], h[a, 0], m[a] - w[a, 3] } }' | sort
  for k in 0 1 2 3 4; do for a in S P; do
    awk -F'\t' -v k=k$k -v a=$a 'FILENAME ~ /lb-/ { b[$1 "|" $2] = $3; next } FILENAME ~ /pos-/ { if ($1 == k && $3 == a) pb[$4 "|" $5] = $9; next }
      FILENAME ~ /entries/ { if ($4 == "placed") dec[$1] = $2 "|" $3; next }
      { split($0, t, ","); if (t[20] in dec) { n++; if (b[dec[t[20]]] == pb[t[1] "|" t[3]]) g++ } } END { print n, g }' \
      "$T/lb-$c.tsv" "$T/pos-$c.tsv" "$R/k$k/pbc$c-$a-k$k-s0-entries.tsv" "$R/k$k/pbc$c-$a-k$k-s0-trades.csv"
  done; done | awk -v c=$c '{ n += $1; g += $2 } END { printf "  C%s decision-date band = fill band on %d of %d filled tickets (%.1f %%)\n", c, g, n, 100 * g / n }'
done

echo; echo "H. Gap by what the other arm did with each placed ticket (cash.sh classes); P tickets minus S tickets, points of entry NAV"
sed -n '1,/^done | awk/p' $X/read/cash.sh | sed '$d' > "$T/rows.sh"; echo done >> "$T/rows.sh"
for c in 1 2; do
  sh "$T/rows.sh" "$R" pbc$c "$T/pos-$c.tsv" | awk -F'\t' -v c=$c '{ v = ($2 == "P") ? $5 : -$5; net[$3] += v; nk[$3, $1] += v; t += v }
    END { for (ch in net) { line = sprintf("  C%s %-15s %+7.1f by seed:", c, ch, net[ch]); for (k = 0; k < 5; k++) line = line sprintf(" %+6.1f", nk[ch, "k" k]); print line }
      printf "  C%s total %+.1f\n", c, t }' | sort
done

echo; echo "I. One-arm positions' return (pnl_pct; open positions marked at the last curve date)"
for c in 1 2 pb; do for cls in P-only S-only; do
  awk -F'\t' -v cls=$cls 'NR > 1 && $2 == cls && $14 != "NA" { print $14 + 0 }' "$T/pos-$c.tsv" | sort -g |
  awk -v tag="$(cell $c) $cls" '{ v[NR] = $1; s += $1; if ($1 > 0) w++; if ($1 >= 50) f++; if ($1 >= 100) h++ }
    END { n = NR; printf "  %s: n %d, mean %+.1f, p10 %+.1f, p25 %+.1f, median %+.1f, p75 %+.1f, p90 %+.1f, win %.1f %%, >= +50 %% %.1f %%, >= +100 %% %.1f %%\n",
      tag, n, s / n, v[int(0.1 * (n - 1)) + 1], v[int(0.25 * (n - 1)) + 1], v[int(0.5 * (n - 1)) + 1], v[int(0.75 * (n - 1)) + 1], v[int(0.9 * (n - 1)) + 1], 100 * w / n, 100 * f / n, 100 * h / n }'
done; done

echo; echo "J. Entry fills the portfolio rejected for cash (cell .log), per seed: S / P"
for c in 1 2; do
  line="  C$c:"; for k in 0 1 2 3 4; do
    s=$(grep -c 'Insufficient cash for trade' "$R/k$k/pbc$c-S-k$k-s0.log"); p=$(grep -c 'Insufficient cash for trade' "$R/k$k/pbc$c-P-k$k-s0.log")
    line="$line k$k $s/$p"; done; echo "$line"
done

echo; echo "K. P NAV on 2023-07-03 (equity_curve.csv): #3595 / C1"
for k in 0 1 2 3 4; do
  a=$(awk -F, '$1 == "2023-07-03" { print $2 }' "$(pref pb $k P)equity_curve.csv"); b=$(awk -F, '$1 == "2023-07-03" { print $2 }' "$(pref 1 $k P)equity_curve.csv")
  awk -v k=$k -v a="$a" -v b="$b" 'BEGIN { printf "  k%d: ratio %.2f\n", k, a / b }'
done

echo; echo "L. Traced decisions (entries.tsv rows; * = placed; band from list_bands.sh)"
tr1() {   # cell seed arm date [symbol]: the arm's recorded list that Friday, with bands
  awk -F'\t' -v d=$4 'FILENAME ~ /lb-/ { b[$1 "|" $2] = $3; next } $3 == d { printf " %s:%s%s", $2, b[$2 "|" $3], ($4 == "placed") ? "*" : "" ; n++ }
    END { if (!n) printf " (no list recorded)"; print "" }' "$T/lb-$1.tsv" "$R/k$2/pbc$1-$3-k$2-s0-entries.tsv"
}
for k in 0 3 1; do for a in S P; do printf "  C1 k$k $a 2023-08-18:"; tr1 1 $k $a 2023-08-18; done; done
for k in 0; do for a in S P; do printf "  C2 k$k $a 2020-09-18:"; tr1 2 $k $a 2020-09-18; done; done
for k in 0 2; do for a in S P; do printf "  C2 k$k $a 2013-04-05:"; tr1 2 $k $a 2013-04-05; done; done
for c in 1 2; do for s in "SAGE 2017-12-01" "AVGO 2013-08-30" "TSLA 2013-04-12" "NIO 2020-09-18"; do set -- $s
  for k in 0 1 2 3 4; do for a in S P; do
    awk -F'\t' -v s=$1 -v d=$2 -v tag="  C$c k$k $a" '$2 == s && $3 == d { print tag, s, d, $4, $6 }' "$R/k$k/pbc$c-$a-k$k-s0-entries.tsv"
  done; done; done; done
for k in 0 2 3; do for a in S P; do
  awk -F'\t' -v tag="  #3595 k$k $a" '$2 == "SAGE" && $3 == "2017-12-01" { print tag, "SAGE 2017-12-01", $4, $6 }' "$(pref pb $k $a)entries.tsv"
done; done
for k in 1 4; do printf "  C2 k$k P:"; grep -A2 'rejected fill for AVGO' "$R/k$k/pbc2-P-k$k-s0.log" | tr -s ' \n' ' ' |
  sed -E 's/.*qty=([0-9.]+).*Required: ([0-9.]+).*Available: ([0-9.]+).*/ AVGO fill rejected, qty \1, required \2, available \3/'; echo; done
for k in 1 4; do printf "  C2 k$k fills 2013-09-03..09-10 S:"; awk -F, '$3 >= "2013-09-03" && $3 <= "2013-09-10" { printf " %s %s qty %s", $1, $3, $8 }' "$R/k$k/pbc2-S-k$k-s0-trades.csv"
  printf " | P:"; awk -F, '$3 >= "2013-09-03" && $3 <= "2013-09-10" { printf " %s %s qty %s", $1, $3, $8 }' "$R/k$k/pbc2-P-k$k-s0-trades.csv"; echo; done

echo; echo "M. One-arm positions open across P's 2018-01-26 NAV peak, C1 k0 and k3"
for k in k0 k3; do
  awk -F'\t' -v k=$k '$1 == k && $2 != "shared" && $5 <= "2018-01-26" && ($6 > "2018-01-26" || $6 == "-") {
      printf "  C1 %s %s %s entry %s exit %s band %s %+.1f %% %.1f %% of entry NAV\n", k, $2, $4, $5, $6, $9, $14, $13 }' "$T/pos-1.tsv"
done

echo; echo "N. Deciding names: which cells hold a position (trades + open), by entry date"
for c in 1 2; do
  for e in "MERC 2010-11-15" "ATML 2010-09-01" "WAL 2012-05-01" "DINO 2010-10-13" "REGN 2010-12-07" "ADMA 2023-12-19" "TSLA 2013-04-09" "NIO 2020-09-24"; do
    set -- $e; line="  C$c $1 $2:"
    for k in 0 1 2 3 4; do for a in S P; do
      if awk -F, -v s=$1 -v d=$2 'FNR > 1 && $1 == s && $3 == d { f = 1 } END { exit !f }' "$(pref $c $k $a)trades.csv" "$(pref $c $k $a)open_positions.csv"; then line="$line $a-k$k"; fi
    done; done; echo "$line"
  done
done

echo; echo "O. Splits applied to held positions (per-arm splits.csv): the close's move on the split date against 1/f"
for c in 1 2 pb; do for k in 0 1 2 3 4; do for a in S P; do
  awk -F, 'FNR > 1 { print $1, $2, $3 }' "$(pref $c $k $a)splits.csv" | while read -r sym d fac; do
    l1=$(printf %s "$sym" | cut -c1); l2=$(printf %s "$sym" | rev | cut -c1 | tr '[:lower:]' '[:upper:]'); f=$D/$l1/$l2/$sym/data.csv
    [ -f "$f" ] || { echo "$(cell $c) k$k $a $sym $d $fac no-bar-file"; continue; }
    awk -F, -v t="$(cell $c) k$k $a" -v s=$sym -v d=$d -v fac=$fac 'FNR > 1 && $1 < d { p = $5 } FNR > 1 && $1 == d { q = $5 }
      END { r = (p > 0 && q > 0) ? q / p : 0; sh = (r > 0 && fac != 1) ? (1 / r - 1) / (fac - 1) : 0
            printf "%s %s %s f %s close move %+.3f gap share %.2f%s\n", t, s, d, fac, r - 1, sh, (sh < 0.5) ? "  NO RAW GAP" : "" }' "$f"
  done
done; done; done > "$T/splits.txt"
awk '{ n[$1 == "26y" ? "#3595" : $1]++ } END { for (x in n) printf "  %s: %d split events applied to held positions\n", x, n[x] }' "$T/splits.txt" | sort
grep 'NO RAW GAP' "$T/splits.txt" | sed 's/^/  /'
for f in "$R/k0/pbc2-S-k0-s0" "$R/k0/pbc2-P-k0-s0" "$R/k1/pbc2-S-k1-s0"; do
  awk -F, -v t=$(basename $f) '$1 == "2013-06-28" { a = $2 } $1 == "2013-07-01" { b = $2 } END { printf "  %s NAV 2013-06-28 -> 07-01: %+.0f (%+.2f %%)\n", t, b - a, 100 * (b / a - 1) }' "$f-equity_curve.csv"
done
awk -F, '$1 == "CERN" && $20 == "CERN-wein-739" { printf "  C2 S-k0 CERN-wein-739 row: entry %s exit %s qty %s entry_price %s exit_price %s pnl $%s (%s %%)\n", $3, $4, $8, $6, $7, $9, $10 }' "$R/k0/pbc2-S-k0-s0-trades.csv"
echo "O2. Last bar date: committed trading/test_data file (the validator's td-full) vs the bar store"
for s in PBR NVS QCOM SNA; do
  l1=$(printf %s "$s" | cut -c1); l2=$(printf %s "$s" | rev | cut -c1)
  a=$(tail -1 "trading/test_data/$l1/$l2/$s/data.csv" 2>/dev/null | cut -d, -f1); b=$(tail -1 "$D/$l1/$l2/$s/data.csv" 2>/dev/null | cut -d, -f1)
  echo "  $s: test_data ${a:-none}, store ${b:-none}"
done

echo; echo "P. Trim-3 one-arm net trimming the three largest |contributions| per side (decide.sh trims the largest)"
for c in 1 2; do
  awk -F'\t' -v c=$c 'NR > 1 && $2 != "shared" { k = $1; n[k, $2]++; v[k, $2, n[k, $2]] = $13; s[k, $2] += $13; K[k] = 1 }
    END { for (k in K) { for (ci = 1; ci <= 2; ci++) { cl = (ci == 1) ? "P-only" : "S-only"; m = n[k, cl]
            for (i = 1; i <= m; i++) for (j = i + 1; j <= m; j++) { a = v[k, cl, i]; b = v[k, cl, j]; if ((b < 0 ? -b : b) > (a < 0 ? -a : a)) { v[k, cl, i] = b; v[k, cl, j] = a } }
            t[cl] = 0; for (i = 1; i <= 3 && i <= m; i++) t[cl] += v[k, cl, i] }
          printf "  C%s %s %+.1f\n", c, k, s[k, "P-only"] - s[k, "S-only"] - t["P-only"] + t["S-only"] } }' "$T/pos-$c.tsv" | sort
done
