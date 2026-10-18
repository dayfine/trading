# input: sym,date,stage (sorted by sym,date); output run lengths in weeks per stage
function flush() { if (cur != "") { len = (days(nd) - days(sd)) / 7; if (len > 0) { r[cur, ++nr[cur]] = len } } }
{ if ($1 != ps) { if (ps != "") { nd = pd_end; flush() }; ps = $1; cur = ""; }
  if ($3 != cur) { if (cur != "") { nd = $2; flush() }; cur = $3; sd = $2 }
  pd_end = $2 }
END { nd = pd_end; flush()
  for (s = 1; s <= 4; s++) { n = nr[s]; for (i = 1; i <= n; i++) a[i] = r[s, i]
    for (i = 2; i <= n; i++) { t = a[i]; j = i - 1; while (j >= 1 && a[j] > t) { a[j+1] = a[j]; j-- }; a[j+1] = t }
    tot = 0; for (i = 1; i <= n; i++) tot += a[i]
    printf "stage %d: runs=%d median=%.0fw p25=%.0fw p75=%.0fw mean=%.1fw\n", s, n, a[int((n+1)/2)], a[int((n+3)/4)], a[int((3*n+1)/4)], tot/n }
}
