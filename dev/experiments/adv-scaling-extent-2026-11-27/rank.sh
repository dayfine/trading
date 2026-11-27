#!/bin/sh
# Rank scan.sh's scores per year under each rule and count what moves. POSIX sh + awk + sort; host only.
#
# Usage: WORK=<scan.sh's WORK> OUT=<results dir> sh rank.sh
# Reads $WORK/scores-v12.tsv and $WORK/scores-v13.tsv (+ .files), the committed lists and twin-drops.txt.
# Rules ranked: current (the builder), consistent (per-file vote), and two bounds that move only the mixed files:
# all-restated (every close-confirmed split applied) and all-raw (none applied). Every other file keeps its
# current score under the bounds.
# Writes ranks and counts only (no scores):
#   $OUT/per-year.tsv       one row per (family, year) for the consistent rule
#   $OUT/bounds.tsv         one row per (family, year, list): leave counts under consistent and both bounds
#   $OUT/top-movers.tsv     the largest rank moves per family (consistent rule)
#   $OUT/repeat-movers.tsv  symbols that cross a list edge in the most years (consistent rule)
#   $OUT/record-list.tsv    v12 top-3000 cells that change, by year and symbol, with direction
#   $OUT/mixed-files.tsv    every mixed file in either inventory: its close-confirmed splits and the votes
#   $OUT/validation.tsv     current-rule lists against the committed lists
set -eu
: "${WORK:?set WORK}"
: "${OUT:?set OUT}"
HERE=$(cd "$(dirname "$0")" && pwd)
TD=$HERE/../../../trading/test_data/backtest_scenarios
TAB=$(printf '\t')
mkdir -p "$OUT"

# rank1 <fam> <col> <tag>: rank each year on column <col> of $WORK/rules-<fam>.tsv, descending; NA unranked.
# sort -s keeps the inventory order on ties, as the builder's stable List.sort does.
rank1() {
  awk -F'\t' -v c="$2" '$c != "NA"' "$WORK/rules-$1.tsv" | sort -s -t "$TAB" -k1,1n -k"$2","$2"gr |
    awk -F'\t' '{ if ($1 != y) { y = $1; r = 0 } r++; print $1 "\t" $2 "\t" r }' >"$WORK/r-$3-$1.tsv"
}

# ranks <fam>: $WORK/ranks-<fam>.tsv = year symbol r_cur r_con r_allrestated r_allraw ratio mixed raw
# (rank 0 = unranked; ratio = current / consistent score).
ranks() {
  fam=$1
  awk -F'\t' 'BEGIN { OFS = "\t" } { a = $7 == 1 ? $5 : $3; n = $7 == 1 ? $6 : $3; print $1, $2, $3, $4, a, n, $7, $8 }' \
    "$WORK/scores-$fam.tsv" >"$WORK/rules-$fam.tsv"
  rank1 "$fam" 3 cur
  rank1 "$fam" 4 con
  rank1 "$fam" 5 all
  rank1 "$fam" 6 raw
  awk -F'\t' -v w="$WORK" -v fam="$fam" '
    function load(tag, A,   l, a) { while ((getline l < (w "/r-" tag "-" fam ".tsv")) > 0) { split(l, a, "\t"); A[a[1] SUBSEP a[2]] = a[3] } }
    BEGIN { load("cur", C); load("con", K); load("all", A); load("raw", R) }
    {
      k = $1 SUBSEP $2
      ratio = ($3 == "NA" || $4 == "NA" || $4 + 0 == 0) ? "NA" : sprintf("%.3f", $3 / $4)
      print $1 "\t" $2 "\t" (C[k] + 0) "\t" (K[k] + 0) "\t" (A[k] + 0) "\t" (R[k] + 0) "\t" ratio "\t" $7 "\t" $8
    }' "$WORK/rules-$fam.tsv" >"$WORK/ranks-$fam.tsv"
}

# The awk prelude every counter shares: D[N, year, symbol] = twin-dropped from top-N-year; DA[year, symbol] = dropped
# from any list of that year. A dropped leg is not a list cell under any rule.
DROPS_AWK='
  function loaddrops(f,   l, a, p, n) {
    while ((getline l < f) > 0) {
      if (l ~ /^#/) continue
      split(l, a, " "); n = split(a[1], p, "-")
      D[p[2], p[3], a[2]] = 1; DA[p[3], a[2]] = 1
    }
  }
  function inl(r, n) { return r > 0 && r <= n }'

# per_year <fam> <sizes>: per year, for the consistent rule. A crossing at 1000 / 3000 / 4000 excludes the drops of
# that list where the family has it, and any same-year drop where it does not.
per_year() {
  awk -F'\t' -v fam="$1" -v sizes="$2" -v drops="$TD/pit-$1/twin-drops.txt" "$DROPS_AWK"'
    BEGIN {
      loaddrops(drops); ns = split(sizes, S, ","); nc = split("1000,3000,4000", C, ",")
      for (i = 1; i <= nc; i++) { has[C[i]] = 0; for (j = 1; j <= ns; j++) if (S[j] == C[i]) has[C[i]] = 1 }
    }
    {
      y = $1; Y[y] = 1; if ($3 > 0) pool[y]++
      if ($8 == 1) mixed[y]++
      if ($7 != "NA" && ($7 > 1.02 || $7 < 0.98)) moved[y]++
      for (i = 1; i <= nc; i++) {
        c = C[i]
        if (has[c] ? ((c SUBSEP y SUBSEP $2) in D) : ((y SUBSEP $2) in DA)) continue
        in0 = inl($3, c); in1 = inl($4, c)
        if (in0 != in1) cross[y, c]++
        if (in0 && !in1) leave[y, c]++
        if (in1 && !in0) enter[y, c]++
        if (in0) cells[y, c]++
        if (in0 && $8 == 1) mixedin[y, c]++
      }
    }
    END {
      for (y in Y) {
        line = fam "\t" y "\t" pool[y] + 0 "\t" mixed[y] + 0 "\t" moved[y] + 0
        for (i = 1; i <= nc; i++) line = line "\t" cross[y, C[i]] + 0
        for (j = 1; j <= ns; j++) {
          n = S[j]
          line = line "\t" cells[y, n] + 0 "\t" mixedin[y, n] + 0 "\t" enter[y, n] + 0 "\t" leave[y, n] + 0 "\t" \
            sprintf("%.2f", cells[y, n] ? 100 * leave[y, n] / cells[y, n] : 0)
        }
        print line
      }
    }' "$WORK/ranks-$1.tsv" | sort -t "$TAB" -k2,2n
}

# bounds <fam> <sizes>: per (year, list), cells that leave under the consistent rule and under each bound.
bounds() {
  awk -F'\t' -v fam="$1" -v sizes="$2" -v drops="$TD/pit-$1/twin-drops.txt" "$DROPS_AWK"'
    BEGIN { loaddrops(drops); ns = split(sizes, S, ",") }
    {
      Y[$1] = 1
      for (j = 1; j <= ns; j++) {
        n = S[j]
        if ((n SUBSEP $1 SUBSEP $2) in D) continue
        c0 = inl($3, n)
        if (c0) cells[$1, n]++
        if (c0 && !inl($4, n)) lc[$1, n]++
        if (c0 && !inl($5, n)) la[$1, n]++
        if (c0 && !inl($6, n)) lr[$1, n]++
      }
    }
    END {
      for (y in Y) for (j = 1; j <= ns; j++) {
        n = S[j]; d = cells[y, n] ? cells[y, n] : 1
        printf "%s\t%s\ttop-%s\t%d\t%d\t%d\t%d\t%.2f\t%.2f\t%.2f\n", fam, y, n, cells[y, n], lc[y, n], la[y, n], lr[y, n],
          100 * lc[y, n] / d, 100 * la[y, n] / d, 100 * lr[y, n] / d
      }
    }' "$WORK/ranks-$1.tsv" | sort -t "$TAB" -k2,2n -k3,3
}

# top_movers <fam> <max N>: names inside top-<max N> under either rule, by absolute rank change (an unranked side
# counts as the year's pool size + 1).
top_movers() {
  awk -F'\t' -v maxn="$2" -v drops="$TD/pit-$1/twin-drops.txt" "$DROPS_AWK"'
    BEGIN { loaddrops(drops) }
    { if ($3 > 0) pool[$1]++; row[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        split(row[i], f, "\t")
        if ((f[1] SUBSEP f[2]) in DA) continue
        a = f[3] ? f[3] : pool[f[1]] + 1; b = f[4] ? f[4] : pool[f[1]] + 1
        if (a > maxn && b > maxn) continue
        d = b - a; ad = d < 0 ? -d : d
        if (ad > 0) print ad "\t" f[1] "\t" f[2] "\t" a "\t" b "\t" d "\t" f[7] "\t" f[8] "\t" f[9]
      }
    }' "$WORK/ranks-$1.tsv" | sort -t "$TAB" -k1,1nr -k2,2n -k3,3 | head -100 | cut -f2- | sed "s/^/$1$TAB/"
}

# repeat_movers <fam> <sizes>: per symbol, the (year, list size) cells it enters (+) or leaves (-).
repeat_movers() {
  awk -F'\t' -v sizes="$2" -v drops="$TD/pit-$1/twin-drops.txt" "$DROPS_AWK"'
    BEGIN { loaddrops(drops); ns = split(sizes, S, ",") }
    {
      for (j = 1; j <= ns; j++) {
        n = S[j]
        if ((n SUBSEP $1 SUBSEP $2) in D) continue
        in0 = inl($3, n); in1 = inl($4, n)
        if (in0 != in1) { cnt[$2]++; yrs[$2] = yrs[$2] (yrs[$2] == "" ? "" : ",") $1 "@" n (in1 ? "+" : "-") }
      }
      if ($9 == 1) rw[$2] = 1
    }
    END { for (s in cnt) print cnt[s] "\t" s "\t" rw[s] + 0 "\t" yrs[s] }' "$WORK/ranks-$1.tsv" |
    sort -t "$TAB" -k1,1nr -k2,2 | head -60 | sed "s/^/$1$TAB/"
}

# record_list: every v12 top-3000 cell that changes under the consistent rule.
record_list() {
  awk -F'\t' -v drops="$TD/pit-v12/twin-drops.txt" "$DROPS_AWK"'
    BEGIN { loaddrops(drops) }
    !((3000 SUBSEP $1 SUBSEP $2) in D) && inl($3, 3000) != inl($4, 3000) {
      print $1 "\t" $2 "\t" $3 "\t" $4 "\t" (inl($4, 3000) ? "enters" : "leaves") "\t" $7 "\t" $9
    }' "$WORK/ranks-v12.tsv" | sort -t "$TAB" -k1,1n -k5,5 -k2,2
}

# validate <fam> <sizes>: the current-rule list (rank <= N, that list's drops excluded) against the committed list.
validate() {
  fam=$1
  for n in $(echo "$2" | tr ',' ' '); do
    for f in "$TD/pit-$fam/composition/top-$n-"*.sexp; do
      y=$(basename "$f" .sexp | sed 's/.*-//')
      grep -o '(symbol [^)]*)' "$f" | sed 's/(symbol //; s/)//' | sort -u >"$WORK/committed.txt"
      awk -F'\t' -v y="$y" -v n="$n" -v drops="$TD/pit-$fam/twin-drops.txt" "$DROPS_AWK"'
        BEGIN { loaddrops(drops) }
        $1 == y && inl($3, n) && !((n SUBSEP y SUBSEP $2) in D) { print $2 }' "$WORK/ranks-$fam.tsv" |
        sort -u >"$WORK/mine.txt"
      both=$(comm -12 "$WORK/committed.txt" "$WORK/mine.txt" | wc -l | tr -d ' ')
      conly=$(comm -23 "$WORK/committed.txt" "$WORK/mine.txt" | wc -l | tr -d ' ')
      monly=$(comm -13 "$WORK/committed.txt" "$WORK/mine.txt" | wc -l | tr -d ' ')
      printf '%s\ttop-%s-%s\t%s\t%s\t%s\n' "$fam" "$n" "$y" "$both" "$conly" "$monly"
    done
  done
}

ranks v12
ranks v13

{
  printf '# family year pool mixed_files score_moved_gt2pct cross_1000 cross_3000 cross_4000, then per list size N:'
  printf ' cells_N mixed_cells_N enter_N leave_N leave_pct_N (v12: N=1000,3000; v13: N=3000,4000). Consistent rule.\n'
  per_year v12 1000,3000
  per_year v13 3000,4000
} >"$OUT/per-year.tsv"

{
  echo '# family year list cells leave_consistent leave_all_restated leave_all_raw pct_consistent pct_all_restated pct_all_raw'
  bounds v12 1000,3000
  bounds v13 3000,4000
} >"$OUT/bounds.tsv"

{
  echo '# family year symbol rank_current rank_consistent delta adv_ratio_current/consistent mixed file_raw'
  top_movers v12 3000
  top_movers v13 4000
} >"$OUT/top-movers.tsv"

{
  echo '# family n_cells symbol file_raw cells(year@N, + entered / - left under the consistent rule)'
  repeat_movers v12 1000,3000
  repeat_movers v13 3000,4000
} >"$OUT/repeat-movers.tsv"

{
  echo '# v12 top-3000 cells that change under the consistent rule: year symbol rank_current rank_consistent direction adv_ratio_current/consistent file_raw'
  record_list
} >"$OUT/record-list.tsv"

{
  echo '# symbol file_raw(consistent vote) close-confirmed splits as date:factor:volume_jump_share:applied_by_current_rule'
  cat "$WORK/scores-v12.tsv.files" "$WORK/scores-v13.tsv.files" | sort -u
} >"$OUT/mixed-files.tsv"

{
  echo '# family list in_both committed_only mine_only (mine = current rule, rank <= N, that list'"'"'s twin-dropped legs excluded)'
  validate v12 1000,3000
  validate v13 3000,4000
} >"$OUT/validation.tsv"
