#!/bin/sh
# athgap_overlap.sh -- the #3588 qc-results note: how much of ath_gap Q1 (<= -0.6349, i.e. >= 63.5 % below the
# all-time high) is low price (price Q1 <= $14.12)? 2x2 of the screen's events.tsv (col 8 ath_gap, col 10 raw price,
# col 3 monster, col 5 ride capped at +190 % per Amendment 1), per half. Aggregates only.
# usage: sh athgap_overlap.sh EVENTS_TSV
awk -F'\t' '{ h = (substr($2, 1, 4) <= "2012") ? "00-12" : "13-25"; if ($8 == "" || $10 == "") next
  a = ($8 + 0 <= -0.6349) ? "athQ1" : "athQ2-5"; p = ($10 + 0 <= 14.12) ? "pxQ1" : "pxQ2-5"; r = $5 + 0; if (r > 1.90) r = 1.90
  k = h " " a " " p; n[k]++; m[k] += $3; s[k] += r; na[h " " a]++ }
  END { for (k in n) { split(k, f, " "); printf "%s %-7s %-6s n=%5d (%.1f%% of %s %s) monster %5.1f%% ride %+5.1f%%\n", f[1], f[2], f[3], n[k],
          100 * n[k] / na[f[1] " " f[2]], f[1], f[2], 100 * m[k] / n[k], 100 * s[k] / n[k] } }' "${1:?usage: athgap_overlap.sh EVENTS_TSV}" | sort
