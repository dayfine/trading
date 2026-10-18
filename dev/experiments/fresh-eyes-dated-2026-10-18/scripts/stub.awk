# stub.awk: dry-run stand-in answers for day.sh's steps A and C (NOT a strategy; it only exercises the pipeline,
# like the 2026-10-13 dummy_agent.awk, which stands in for step D and the follow looks).
# mode=A: awk -F, -v mode=A -v date=D -f stub.awk <spy-weekly.csv> <sector-strength.csv>
#   longs when SPY's last weekly close <= the date is above its 30-week MA, else neither; the 3 sectors with the
#   highest rel that week.
# mode=C: awk -F, -v mode=C -v date=D -v k=3 -f stub.awk <weekly.csv ...>   (pseudonym = file name)
#   up to k names whose last close <= the date is above the MA, highest RS first, scored 5, 4, 3.
FNR == 1 { fi++; if (mode == "C") { cl = ""; ma = ""; rs = ""; nm = FILENAME; sub(/.*\//, "", nm); sub(/\.csv$/, "", nm) } ; next }
mode == "A" && fi == 1 && $1 <= date { c = $5; m = $7 }
mode == "A" && fi == 2 && $1 <= date { if ($1 != wk) { wk = $1; n = 0 } ; n++; sn[n] = $2; sr[n] = $6 + 0 }
mode == "C" && $1 <= date { cl = $5 + 0; ma = $7; rs = $8; last[nm] = (ma != "" && cl > ma + 0 && rs != "") ? rs + 0 : "x" }
END {
  if (mode == "A") {
    side = (m != "" && c + 0 > m + 0) ? "long" : "neither"
    for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) if (sr[j] > sr[i]) { t = sr[i]; sr[i] = sr[j]; sr[j] = t; t = sn[i]; sn[i] = sn[j]; sn[j] = t }
    g = ""; for (i = 1; i <= 3 && i <= n; i++) g = g (i > 1 ? "," : "") "\"" sn[i] "\""
    printf "{\"phase\":\"stub\",\"side\":\"%s\",\"groups\":[%s],\"reason\":\"stub: SPY vs its MA, top-3 sector rel\"}\n", side, g
    exit
  }
  m = 0; for (p in last) if (last[p] != "x") { m++; nm2[m] = p; v[m] = last[p] }
  for (i = 1; i <= m; i++) for (j = i + 1; j <= m; j++) if (v[j] > v[i] || (v[j] == v[i] && nm2[j] < nm2[i])) { t = v[i]; v[i] = v[j]; v[j] = t; t = nm2[i]; nm2[i] = nm2[j]; nm2[j] = t }
  s = ""; for (i = 1; i <= k && i <= m; i++) s = s (i > 1 ? "," : "") sprintf("{\"name\":\"%s\",\"score\":%d}", nm2[i], 6 - i)
  printf "{\"picks\":[%s],\"reason\":\"stub: above the MA, highest RS\"}\n", s
}
