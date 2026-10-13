# Does the verdict hinge on outliers or on degenerate stops? P1 / P2 under trims; the events beyond +-100 %.
NR==1 { hdr(); next }
{ if (!isP()) next
  for (en = 1; en <= 2; en++) { e = "e" en; x = $(c[e "_o2_exc"]); if (x == "") continue; r = $(c[e "_room"]) + 0
    add("P" en " as computed", x); if (x + 0 < -1 || x + 0 > 1) { ext[en]++; lst[en] = lst[en] " " $1 "/" $2 "(" sprintf("%+.0f%%", 100*x) ")" }
    if (x + 0 >= -0.5 && x + 0 <= 0.5) add("P" en " drop |exc|>50%", x); if (r <= 1.0) add("P" en " drop room>100%", x)
    if (r > 0) add("P" en " drop entry at/above own stop", x); if (r > 0.02) add("P" en " drop room<=2%", x)
    if ($(c["below_sup"]) == 1) add("P" en " only real closes below support", x) } }
END { dump(40); for (en = 1; en <= 2; en++) printf "P%d events beyond +-100%%: %d:%s\n", en, ext[en], lst[en] }
