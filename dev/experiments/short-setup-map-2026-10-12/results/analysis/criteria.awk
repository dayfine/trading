# The six pre-registered criteria on every descriptive cell (beat >= 58 % for a non-primary cell). -v floor=5|17
function lev_adv(x) { return (x == "") ? "na" : (x < 0.30 ? "<30%" : (x < 1.0 ? "30-100%" : ">=100%")) }
function lev_w(x) { return (x <= 8) ? "<=8" : (x <= 20 ? "9-20" : ">20") }
function lev_room(x) { return (x <= 0.15) ? "<=15%" : (x <= 0.30 ? "15-30%" : ">30%") }
function lev_yld(x) { return (x <= 0) ? "none" : (x < 0.02 ? "<2%" : (x <= 0.05 ? "2-5%" : ">5%")) }
function lev_grp(x) { return (x == "") ? "na" : (x < 0 ? "weak" : "not_weak") }
function put(key, x, o60, h) { if (x == "") return; add(key, x); add(key "|" h, x); add(key "|o60", o60) }
NR==1 { hdr(); next }
{ if ($(c["raw_close"]) + 0 < floor) next; yr = substr($2,1,4) + 0; h = (yr <= 2012) ? "h1" : "h2"
  for (en = 1; en <= 2; en++) { e = "e" en; x = $(c[e "_o2_exc"]); o = $(c[e "_o1_60"])
    put(e " phase=" $(c["phase"]), x, o, h); put(e " advance=" lev_adv($(c["advance"])), x, o, h); put(e " top_width=" lev_w($(c["top_width"])), x, o, h)
    put(e " hs=" $(c["hs"]), x, o, h); put(e " rs=" $(c["rs_class"]), x, o, h); put(e " group=" lev_grp($(c["group_rel"])), x, o, h)
    put(e " room=" lev_room($(c[e "_room"])), x, o, h); put(e " yield=" lev_yld($(c["yield"])), x, o, h); put(e " bigdiv_in_hold=" $(c["bigdiv"]), x, o, h)
    if (yr <= 2002) put(e " bear 2000-02", x, o, h); if (yr >= 2007 && yr <= 2009) put(e " bear 2007-09", x, o, h); if (yr == 2022) put(e " bear 2022", x, o, h) } }
END { for (i = 1; i <= nord; i++) { k = ord[i]; if (k ~ /\|/) continue
    n = cnt[k]; m = sm[k]/n; md = med(k); b = ps[k]/n; h1 = (cnt[k "|h1"] ? sm[k "|h1"]/cnt[k "|h1"] : 0); h2 = (cnt[k "|h2"] ? sm[k "|h2"]/cnt[k "|h2"] : 0); o = sm[k "|o60"]/cnt[k "|o60"]
    np = (n >= 100) + (m >= 0.02) + (md > 0) + (b >= 0.58) + (h1*h2 > 0) + (o*m > 0); if (np == 6) cand++
    printf "%-26s n=%5d mean=%+7.2f%% med=%+6.2f%% beat=%5.1f%% halves %+.2f/%+.2f O1+60 %+.2f | met %d/6%s\n", k, n, 100*m, 100*md, 100*b, 100*h1, 100*h2, 100*o, np, (np == 6 ? " CANDIDATE" : "") }
  printf "cells meeting all six (beat >= 58%%): %d\n", cand + 0 }
