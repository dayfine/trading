function jdn(s,   y, m, d, a, y2, m2) { y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return d + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045 }
FNR == 1 { f++; next }
f == 1 { k = $1; ns[k]++; sd[k, ns[k]] = jdn($2); next }          # setup map events
f == 2 { n++; k = $1; j = jdn($2); best = 1e9
  for (q = 1; q <= ns[k]; q++) { dd = j - sd[k, q]; if (dd < 0) dd2 = -dd; else dd2 = dd; if (dd2 < (best < 0 ? -best : best)) best = dd }
  if (best == 1e9) none++; else { ab = (best < 0) ? -best : best; if (ab <= 28) w4++; if (ab <= 91) w13++; if (best >= 0 && best <= 182) sm_before++ }
}
END { printf "wide-top events: %d; a setup-map event on the same symbol within 4 weeks: %d (%.1f%%), within 13 weeks: %d (%.1f%%); setup-map event 0-26 weeks BEFORE the wide-top breakdown: %d (%.1f%%); symbol with no setup-map event at all: %d\n", n, w4, 100*w4/n, w13, 100*w13/n, sm_before, 100*sm_before/n, none }
