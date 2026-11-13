#!/bin/sh
# onearm_split.sh -- where the P-S gap sits: per seed, sum of nav_pct (contribution / entry NAV, %) for shared,
# P-only and S-only positions (positions.sh classes), the one-arm net, and the net by band and by entry era; plus the
# symmetric top-k trim (drop the k largest P-only and the k largest S-only by nav_pct).
# usage: sh onearm_split.sh POSITIONS_TSV
P=${1:?usage: sh onearm_split.sh POSITIONS_TSV}
echo "per seed: shared P|S, P-only n/sum, S-only n/sum, net, net after trimming the top 1/2/3 of each side"
for k in 0 1 2 3 4; do
  awk -F'\t' -v k="k$k" 'NR > 1 && $1 == k { if ($2 == "shared") sh[$3] += $13; else { n[$2]++; s[$2] += $13; v[$2, n[$2]] = $13 } }
    END { for (c in n) { m = n[c]; for (i = 1; i <= m; i++) for (j = i + 1; j <= m; j++) if (v[c, j] > v[c, i]) { t = v[c, i]; v[c, i] = v[c, j]; v[c, j] = t } }
      net = s["P-only"] - s["S-only"]; printf "%s shared %.1f|%.1f  P-only %d/%+.1f  S-only %d/%+.1f  net %+.1f  trim", k, sh["P"], sh["S"], n["P-only"], s["P-only"], n["S-only"], s["S-only"], net
      tp = 0; ts = 0; for (i = 1; i <= 3; i++) { tp += v["P-only", i]; ts += v["S-only", i]; printf " %d:%+.1f", i, net - tp + ts }; print "" }' "$P"
done
echo; echo "pooled one-arm net by band (P-only minus S-only nav_pct sums)"
awk -F'\t' 'NR > 1 && $2 != "shared" { s[$2, $9] += $13; c[$2, $9]++ } END { for (b = 0; b <= 3; b++) printf "band %d: P-only %d/%+.1f  S-only %d/%+.1f  net %+.1f\n", b, c["P-only", b], s["P-only", b], c["S-only", b], s["S-only", b], s["P-only", b] - s["S-only", b] }' "$P"
echo; echo "pooled one-arm net by entry era"
awk -F'\t' 'NR > 1 && $2 != "shared" { y = substr($5, 1, 4) + 0; e = (y <= 2009) ? "2000-09" : (y <= 2012) ? "2010-12" : (y <= 2017) ? "2013-17" : (y <= 2023) ? "2018-23" : "2024-26"
    s[e, $2] += $13; c[e, $2]++; E[e] = 1 } END { for (e in E) printf "%s: P-only %d/%+.1f  S-only %d/%+.1f  net %+.1f\n", e, c[e, "P-only"], s[e, "P-only"], c[e, "S-only"], s[e, "S-only"], s[e, "P-only"] - s[e, "S-only"] }' "$P" | sort
