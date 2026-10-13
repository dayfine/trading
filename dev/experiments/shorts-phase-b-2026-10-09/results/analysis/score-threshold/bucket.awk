# Cumulative score-threshold buckets of excess.csv for one horizon. -v H=<20|60|120> -v T=<min score>
$2 == H && $1 >= T { n++; v[n] = $3; s += $3; if ($3 > 0) p++ }
END { if (!n) exit
  for (i = 2; i <= n; i++) { x = v[i]; j = i - 1; while (j > 0 && v[j] > x) { v[j + 1] = v[j]; j-- } v[j + 1] = x }
  printf "  score>=%3d n=%4d beat-SPY=%4.1f%% mean=%+5.1f%% median=%+5.1f%% p10=%+6.1f%% p90=%+6.1f%%\n", \
    T, n, 100 * p / n, 100 * s / n, 100 * v[int(n / 2) + 1], 100 * v[int(n * 0.1) + 1], 100 * v[int(n * 0.9)] }
