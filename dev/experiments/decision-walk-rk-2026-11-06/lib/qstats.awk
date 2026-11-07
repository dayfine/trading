# stdin: "group<TAB>value" sorted by group, then value ascending (sort -t'\t' -k1,1 -k2,2g).
# prints one row per group: n mean p10 p25 median p75 p90 max share>T1 share>T2 (values scaled by S, default 100 = %).
BEGIN { FS = "\t"; if (S == "") S = 100; if (T1 == "") T1 = 0.5; if (T2 == "") T2 = 1.0
  printf "%-28s %6s %8s %8s %8s %8s %8s %8s %9s %7s %7s\n", "group", "n", "mean", "p10", "p25", "median", "p75", "p90", "max", ">" T1*S, ">" T2*S }
function flush(   m) { if (n == 0) return
  printf "%-28s %6d %+8.2f %+8.2f %+8.2f %+8.2f %+8.2f %+8.2f %+9.1f %6.1f%% %6.1f%%\n", g, n, S * s / n, S * v[int(.10 * (n - 1)) + 1], S * v[int(.25 * (n - 1)) + 1], S * v[int(.5 * (n - 1)) + 1], S * v[int(.75 * (n - 1)) + 1], S * v[int(.90 * (n - 1)) + 1], S * v[n], 100 * a / n, 100 * b / n
  n = 0; s = 0; a = 0; b = 0; delete v }
$1 != g { flush(); g = $1 }
{ n++; v[n] = $2; s += $2; if ($2 > T1) a++; if ($2 > T2) b++ }
END { flush() }
