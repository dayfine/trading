#!/bin/sh
# lists_compare.sh -- how often the price-band order changes the post-cut top-20 list, read from entries.tsv.
#
# entries.tsv holds, for every decision date on which an arm placed >= 1 ticket, the whole post-cut list that its
# entry walk saw (placed rows + every skipped alternative with its reason). Names cut at the top-20 never appear, and
# a date with no placement records nothing. So the cut channel is visible only on dates where BOTH arms recorded.
#
# usage: sh lists_compare.sh RESULTS_DIR LIST_BANDS_TSV
# Prints, per seed and pooled:
#   A. band mix of every list member (all recorded dates) per arm, and of the placed tickets;
#   B. on dates both arms recorded: identical lists, list overlap, and the bands of P-not-S / S-not-P members;
#   C. placed tickets of one arm whose name is ABSENT from the other arm's same-date list (cut or held/cooldown in
#      the other arm), or PRESENT there but skipped (with the other arm's skip reason), by band.
R=${1:?}; LB=${2:?}
for k in 0 1 2 3 4; do
  awk -F'\t' -v k="k$k" '
    FNR == 1 { f++ }
    f == 1 { band[$1 "|" $2] = $3; next }
    $1 == "position_id" { next }
    { arm = (f == 2) ? "S" : "P"; key = $2 "|" $3; b = band[key]
      if (in_list[arm, key] != "placed") in_list[arm, key] = ($4 == "placed") ? "placed" : $6; dates[arm, $3] = 1; alld[$3] = 1
      mix[arm, b]++; tot[arm]++; if ($4 == "placed") { pmix[arm, b]++; ptot[arm]++ }
      mem[arm, $3] = mem[arm, $3] " " $2 }
    END {
      for (i = 1; i <= 2; i++) { a = (i == 1) ? "S" : "P"
        printf "%s A %s list n=%d b0=%.1f%% b1=%.1f%% b2=%.1f%% b3=%.1f%% | placed n=%d b0=%.1f%% b1=%.1f%% b2=%.1f%% b3=%.1f%%\n", k, a, tot[a],
          100 * mix[a, 0] / tot[a], 100 * mix[a, 1] / tot[a], 100 * mix[a, 2] / tot[a], 100 * mix[a, 3] / tot[a], ptot[a],
          100 * pmix[a, 0] / ptot[a], 100 * pmix[a, 1] / ptot[a], 100 * pmix[a, 2] / ptot[a], 100 * pmix[a, 3] / ptot[a] }
      for (d in alld) { if (!((("S", d) in dates) && (("P", d) in dates))) continue; both++
        nS = split(mem["S", d], ms, " "); nP = split(mem["P", d], mp, " "); delete inS; delete inP
        for (j = 1; j <= nS; j++) inS[ms[j]] = 1; for (j = 1; j <= nP; j++) inP[mp[j]] = 1
        same = 1; for (x in inS) if (!(x in inP)) { same = 0; sOnly++; sOb[band[x "|" d]]++ } else common++
        for (x in inP) if (!(x in inS)) { same = 0; pOnly++; pOb[band[x "|" d]]++ }
        ident += same; listS += nS; listP += nP }
      printf "%s B both-recorded dates=%d identical-lists=%d (%.1f%%) common=%d S-not-P=%d [b0 %d b1 %d b2 %d b3 %d] P-not-S=%d [b0 %d b1 %d b2 %d b3 %d]\n",
        k, both, ident, 100 * ident / both, common, sOnly, sOb[0], sOb[1], sOb[2], sOb[3], pOnly, pOb[0], pOb[1], pOb[2], pOb[3]
      for (key in in_list) { split(key, kk, SUBSEP); a = kk[1]; o = (a == "S") ? "P" : "S"; split(kk[2], sd, "|")
        if (in_list[key] != "placed") continue
        if (!((o, sd[2]) in dates)) { cls = "other-no-record" }
        else if (!((o, kk[2]) in in_list)) { cls = "absent-in-other" }
        else cls = "other:" in_list[o, kk[2]]
        c[a, cls, band[kk[2]]]++; cc[a, cls]++ }
      for (x in cc) { split(x, xx, SUBSEP)
        printf "%s C %s-placed %-28s n=%4d  b0 %3d b1 %3d b2 %3d b3 %3d\n", k, xx[1], xx[2], cc[x], c[xx[1], xx[2], 0], c[xx[1], xx[2], 1], c[xx[1], xx[2], 2], c[xx[1], xx[2], 3] } }
  ' "$LB" "$R/k$k/pb-S-k$k-s0-entries.tsv" "$R/k$k/pb-P-k$k-s0-entries.tsv" | sort
done
