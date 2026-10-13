# Filled shorts split at a score cut, optionally excluding position_ids. -v CUT=100 -v EXCL=<pid,pid>
BEGIN { n = split(EXCL, e, ","); for (i = 1; i <= n; i++) ex[e[i]] = 1 }
FNR > 1 && !($20 in ex) { b = ($19 + 0 >= CUT) ? "hi" : "lo"; c[b]++; s[b] += $10; d[b] += $9; if ($10 > 0) w[b]++; v[b, c[b]] = $10 }
END { for (bi = 1; bi <= 2; bi++) { b = (bi == 1 ? "hi" : "lo"); m = c[b]; if (!m) continue
    for (i = 1; i <= m; i++) a[i] = v[b, i]
    for (i = 2; i <= m; i++) { x = a[i]; j = i - 1; while (j > 0 && a[j] > x) { a[j + 1] = a[j]; j-- } a[j + 1] = x }
    printf "  score %s %3d: n=%3d win=%3.0f%% mean=%+5.2f%% median=%+5.2f%% pnl=$%+.0fk\n", (b == "hi" ? ">=" : "< "), CUT, m, 100 * w[b] / m, s[b] / m, a[int((m + 1) / 2)], d[b] / 1000 } }
