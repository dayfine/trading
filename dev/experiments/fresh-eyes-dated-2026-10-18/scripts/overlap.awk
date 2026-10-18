# overlap.awk: plan §6 read 1 for one date dir: the reader's orders and shortlist against our screener's list and
# our entries (union over salts). Missing inputs are passed as /dev/null.
# Usage: awk -F, -v d=DATE -v rep=R -v side=S -f overlap.awk <ours/top.csv> <ours/entries.csv> <orders.csv> \
#          <shortlist.txt> <pool.csv> <reader-trades.csv>
# Prints: date,rep,side,orders,filled,shortlist,ours_top,orders_in_top,orders_in_entries,shortlist_in_top
FNR == 1 { for (i = 1; i < ARGC; i++) if (ARGV[i] == FILENAME) { fi = i; break } }
fi == 1 && FNR > 1 { if (!($3 in top)) nt++; top[$3] = 1; next }
fi == 2 && FNR > 1 { ent[$2] = 1; next }
fi == 3 && FNR > 1 { no++; os[no] = $2; next }
fi == 4 && $1 != "" { ns++; sl[ns] = $1; next }
fi == 5 && FNR > 1 { sym[$1] = $2; next }
fi == 6 && FNR > 1 && $4 != "" { nf++; next }
END {
  for (i = 1; i <= no; i++) { if (os[i] in top) a++; if (os[i] in ent) b++ }
  for (i = 1; i <= ns; i++) if (sym[sl[i]] in top) c++
  printf "%s,%s,%s,%d,%d,%d,%d,%d,%d,%d\n", d, rep, side, no, nf, ns, nt, a, b, c
}
