#!/bin/sh
# held_confound.sh -- how many top-20 list differences are the held-set path effect rather than the band order?
# The screener drops names an arm holds (Entering / Holding / Exiting) before the top-N cut. For every name in one
# arm's recorded list and not the other's on the same Friday (both arms recorded), test whether the OTHER arm held it
# that Friday: a filled position with entry_date <= d <= exit_date (open rows: entry_date <= d), or a placed ticket
# decided before d and not yet filled (decision < d < fill date, or never filled within 26 weeks of the decision).
# Cooldown after a stop-out is not reconstructed (a remaining, smaller confound).
# usage: sh held_confound.sh RESULTS_DIR CHANNELS_TSV POSITIONS_TSV
R=${1:?}; CH=${2:?}; POS=${3:?}
for k in 0 1 2 3 4; do
  awk -F'\t' -v k="k$k" '
    function dnum(s) { return substr(s, 1, 4) * 372 + substr(s, 6, 2) * 31 + substr(s, 9, 2) }
    FNR == 1 { f++ }
    f == 1 { if ($1 != k) next; a = $2; n = ++np[a, $4]; ps[a, $4, n] = dnum($5)
             pe[a, $4, n] = ($8 == "unfilled") ? dnum($5) + 26 * 7 : dnum($9); next }       # pending window
    f == 2 { if (FNR == 1 || $1 != k) next; a = $3; n = ++nh[a, $4]; hs[a, $4, n] = dnum($5)
             he[a, $4, n] = ($6 == "-") ? 999999 : dnum($6); next }                         # held window
    $1 == "position_id" { next }
    { a = (f == 3) ? "S" : "P"; mem[a, $3, $2] = 1; rec[a, $3] = 1; dates[$3] = 1 }
    function held(a, s, d,   i, x) { x = dnum(d)
      for (i = 1; i <= nh[a, s]; i++) if (hs[a, s, i] <= x && x <= he[a, s, i]) return 1
      for (i = 1; i <= np[a, s]; i++) if (ps[a, s, i] < x && x < pe[a, s, i]) return 1
      return 0 }
    END { for (key in mem) { split(key, kk, SUBSEP); a = kk[1]; d = kk[2]; s = kk[3]; o = (a == "S") ? "P" : "S"
            if (!((o, d) in rec) || ((o, d, s) in mem)) continue
            tot[a]++; if (held(o, s, d)) h[a]++ }
          printf "%s  S-not-P %d, of which held/pending in P %d (%.1f%%) | P-not-S %d, of which held/pending in S %d (%.1f%%)\n",
            k, tot["S"], h["S"], 100 * h["S"] / tot["S"], tot["P"], h["P"], 100 * h["P"] / tot["P"] } ' \
    "$CH" "$POS" "$R/k$k/pb-S-k$k-s0-entries.tsv" "$R/k$k/pb-P-k$k-s0-entries.tsv"
done
