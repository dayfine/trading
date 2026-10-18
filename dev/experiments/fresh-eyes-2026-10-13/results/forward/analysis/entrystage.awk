# For each trade: the last order-placing decision (buy_stop/short_stop) at a cut before the entry date, our stage and
# weeks at that cut, and our stage and weeks at the fill week (the Friday ending the entry week).
FNR == 1 { fi++; next }
fi == 1 { k = $1; nst[k]++; sd[k, nst[k]] = civil(friday(days($2))); ss[k, nst[k]] = substr($5, 6, 1); sw[k, nst[k]] = $6; next }
fi == 2 { if ($4 == "buy_stop" || $4 == "short_stop") { nd[$1]++; dc[$1, nd[$1]] = $2; da[$1, nd[$1]] = $4; dr[$1, nd[$1]] = $9 }; next }
fi == 3 {
  s = $1; side = $2; e = $3; fe = civil(friday(days(e)))
  want = (side == "long") ? "buy_stop" : "short_stop"
  cut = ""; for (i = 1; i <= nd[s]; i++) if (dc[s, i] < e && da[s, i] == want) cut = dc[s, i]
  st_c = "?"; wk_c = ""; st_f = "?"; wk_f = ""
  for (i = 1; i <= nst[s]; i++) { if (sd[s, i] <= cut) { st_c = ss[s, i]; wk_c = sw[s, i] }; if (sd[s, i] <= fe) { st_f = ss[s, i]; wk_f = sw[s, i] } }
  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%.4f\n", s, side, e, cut, st_c, wk_c, st_f, wk_f, $7, $10
}
