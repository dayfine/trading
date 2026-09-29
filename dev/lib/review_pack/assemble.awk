# Join every per-trade source into one JSON array (stdout).
# usage: awk -f assemble.awk trades.csv x_trades.tsv x_audit.tsv x_macro.tsv x_stage.tsv
#   x_audit.tsv : sym<TAB>entry_date<TAB>rs<TAB>macro<TAB>grade<TAB>score<TAB>fill_vs_trig<TAB>faithful
#   x_stage.tsv : pid<TAB>stage_at_entry<TAB>stage_at_exit<TAB>s3_weeks<TAB>s4_weeks<TAB>hold_weeks
function q(s) { gsub(/"/, "", s); return "\"" s "\"" }
function n(s) { return (s == "" ? "null" : s + 0) }
FNR == 1 { fi++ }
fi == 1 { if (FNR == 1) next; nt++; row[nt] = $0; next }
fi == 2 { split($0, a, "\t"); x[a[1]] = $0; next }
fi == 3 { split($0, a, "\t"); au[a[1] "|" a[2]] = $0; next }
fi == 4 { split($0, a, "\t"); nm++; md[nm] = a[1]; mtr[nm] = a[2]; mbr[nm] = a[3]; next }
fi == 5 { split($0, a, "\t"); st[a[1]] = $0; next }
function macro_at(d,   i, r) { r = 0; for (i = 1; i <= nm && md[i] <= d; i++) r = i; return r }
END {
  printf "["
  for (t = 1; t <= nt; t++) {
    split(row[t], c, ",")
    pid = c[20]; ie = macro_at(c[3]); ix = macro_at(c[4]); bw = 0; hw = 0
    for (i = ie; i <= ix && i > 0; i++) { hw++; if (mtr[i] == "Bearish") bw++ }
    printf "%s{\"id\":%s,\"sym\":%s,\"ed\":%s,\"xd\":%s,\"days\":%s,\"ep\":%s,\"xp\":%s,\"qty\":%s,\"pnl\":%s,\"pct\":%s,\"xs\":%s,\"trig\":%s,\"stg\":%s,\"vr\":%s,\"sid\":%s,\"kind\":%s,\"d1st\":%s,\"score\":%s,\"sfd\":%s,\"maxs\":%s,\"nraise\":%s", \
      (t > 1 ? ",\n" : ""), q(pid), q(c[1]), q(c[3]), q(c[4]), n(c[5]), n(c[6]), n(c[7]), n(c[8]), n(c[9]), n(c[10]), n(c[12]), q(c[13]), q(c[14]), n(c[15]), n(c[16]), q(c[17]), n(c[18]), n(c[19]), n(c[21]), n(c[22]), n(c[23])
    printf ",\"mE\":%s,\"bE\":%s,\"mX\":%s,\"bearW\":%d,\"macroW\":%d", q(ie ? mtr[ie] : ""), q(ie ? mbr[ie] : ""), q(ix ? mtr[ix] : ""), bw, hw
    if (pid in x) { split(x[pid], e, "\t")
      if (e[2] ~ /^NO/) printf ",\"nodata\":true"
      else printf ",\"fe\":%s,\"fx\":%s,\"mfe\":%s,\"mae\":%s,\"pmax\":%s,\"pmin\":%s,\"p13\":%s,\"g\":%s,\"onE\":%s,\"onX\":%s,\"inE\":%s,\"inX\":%s,\"gap\":%s,\"ebar\":%s,\"xbar\":%s,\"postN\":%s,\"f40\":%s,\"blag\":%s,\"cf\":[%s],\"eadj\":%s,\"xadj\":%s", \
        e[2], e[3], e[4], e[5], e[6], e[7], e[8], q(e[9]), e[10], e[11], e[12], e[13], e[14], q(e[15]), q(e[16]), e[17], e[18], e[19], e[20], e[21], e[22] }
    k = c[1] "|" c[3]
    if (k in au) { split(au[k], u, "\t"); printf ",\"rs\":%s,\"aMacro\":%s,\"aGrade\":%s,\"aScore\":%s,\"fvt\":%s,\"faithful\":%s", q(u[3]), q(u[4]), q(u[5]), n(u[6]), n(u[7]), (u[8] == "✓" ? "true" : "false") }
    if (pid in st) { split(st[pid], s, "\t"); printf ",\"rsE\":%s,\"rsX\":%s,\"s3w\":%s,\"s4w\":%s,\"holdW\":%s", q(s[2]), q(s[3]), s[4], s[5], s[6] }
    printf "}"
  }
  print "]"
}
