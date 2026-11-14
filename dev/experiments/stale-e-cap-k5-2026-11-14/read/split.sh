#!/bin/sh
# split.sh -- the pre-registered read of stale-e-cap-k5-2026-11-14 (../README.md §Decision rule, §The price/size split,
# §Arm G, §Reported regardless). POSIX sh + awk; reads only the committed per-arm artifacts, plus the bar store for the
# open-position marks when DATA_DIR is given.
#
# usage: sh split.sh RESULTS_DIR [DATA_DIR] > read.txt
#   RESULTS_DIR holds k0..k4/ as `chain.sh collect` writes them: sec-{S,C,G}-kK-s0-{tickets.tsv,entries.tsv,trades.csv,
#     open_positions.csv,equity_curve.csv,splits.csv,actual.sexp}, sec-{C,G}-kK-s0.v6diff-S.log and chain-kK.log.
#   DATA_DIR (optional) is the bar store (data/<first letter>/<last letter>/<SYMBOL>/data.csv). Open positions are then
#     marked at the last raw close on or before the arm's last equity-curve date. The marks feed only the outcome's bars
#     (D, trim3 and the A-without-top-3 count): no printed sum includes a key whose ticket is still open in either arm
#     (an "open-leg key", README §What the read prints). Without DATA_DIR, or for an open position with no bar file,
#     such a key is left out of the bars too, it is counted in the output, and the outcome is printed as PROVISIONAL
#     (the in-session read in chain.sh is the first case).
#   PAIRS (default "S:C S:G G:C") the arm pairs read, each BASE:TEST, in that order. A pair's BASE takes the role the
#     README calls S and its TEST the role it calls C: delta = ln(1 + R_TEST) - ln(1 + R_BASE), and so on. S:C is the
#     flag as built (§Decision rule), S:G the screen's lever and G:C the admissions (§Arm G); with all three the
#     combined outcome follows (lib/combine.awk). A pair no seed holds both arms of prints one line and is skipped.
#   VALIDITY=skip reads pairs without the chain's validity lines (the local smoke only). Default: check.
#   KEYS=FILE also writes the per-key rows (keys.awk) of every pair to FILE, each prefixed by its pair. With DATA_DIR
#     they carry marked open-position contributions, from which a raw close can be recovered, so that file is never
#     committed.
# What reaches stdout (README §What the read prints): counts, the simulator's own return, drawdown and ratio figures
# (actual.sexp), NAV-% sums over the keys with no open leg, per-key lines for those keys only (symbol, Friday, class,
# NAV-% difference), the number of open-leg keys each table leaves out, and the pass or fail of the bars that read the
# marks. No price, bar or mark is printed, and no sum that includes an open-leg key.
R=${1:?usage: sh split.sh RESULTS_DIR [DATA_DIR]}; D=${2:-}
PAIRS=${PAIRS:-"S:C S:G G:C"}
LIB=$(cd "$(dirname "$0")/lib" && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/sec-split.XXXXXX"); trap 'rm -rf "$TMP"' EXIT
[ -n "${KEYS:-}" ] && : > "$KEYS"

marks() { # $1 base prefix, $2 test prefix -> symbol, date, raw close of every open position at its arm's last curve date
  for p in "$1" "$2"; do
    e=$(tail -1 "${p}equity_curve.csv" | cut -d, -f1)
    awk -F, -v e="$e" 'FNR > 1 { print $1 "\t" e }' "${p}open_positions.csv"
  done | LC_ALL=C sort -u | while IFS="$(printf '\t')" read -r sym d; do
    l1=$(printf %s "$sym" | cut -c1); l2=$(printf %s "$sym" | rev | cut -c1 | tr '[:lower:]' '[:upper:]')
    f=$D/$l1/$l2/$sym/data.csv; [ -f "$f" ] || continue
    awk -F, -v s="$sym" -v d="$d" 'FNR > 1 && $1 <= d { last = $5; have = 1 } END { if (have) print s "\t" d "\t" last }' "$f"
  done
}

metrics() { # $1 seed, $2 role (S = base, C = test), $3 prefix -> one M row
  awk -v k="$1" -v a="$2" '
    FILENAME ~ /actual\.sexp$/ { l = $0; gsub(/[()]/, " ", l); m = split(l, t, " "); for (i = 1; i < m; i++) v[t[i]] = t[i + 1]; next }
    FILENAME ~ /trades\.csv$/ { if (FNR > 1) { n++; if ($10 + 0 >= 100) b++ } next }
    FILENAME ~ /open_positions\.csv$/ { if (FNR > 1) o++; next }
    END { printf "M\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\n", k, a, v["total_return_pct"], v["max_drawdown_pct"], v["sharpe_ratio"],
          v["ulcer_index"], n, o, b }' FS=, "$3actual.sexp" "$3trades.csv" "$3open_positions.csv"
}

# Arm S's own return, for delta's reshuffle null m_S whatever the pair (README §Decision rule 2).
sret() { # $1 seed, $2 S prefix -> one N row
  awk -v k="$1" '{ l = $0; gsub(/[()]/, " ", l); m = split(l, t, " "); for (i = 1; i < m; i++) v[t[i]] = t[i + 1] }
    END { printf "N\t%s\t%s\n", k, v["total_return_pct"] }' "$2actual.sexp"
}

validity() { # $1 seed dir, $2 K, $3 base, $4 test -> one V row
  v6=ok; tw=missing; ab=missing; l=$1/chain-k$2.log
  for a in $3 $4; do [ "$a" = S ] && continue   # every non-S arm of the pair is V6-checked against S
    f=$1/sec-$a-k$2-s0.v6diff-S.log
    if [ ! -f "$f" ]; then [ "$v6" = ok ] && v6=missing
    elif [ "$(tail -1 "$f")" != exit=0 ]; then v6=fail; fi
  done
  if [ -f "$l" ]; then
    if grep -q "TRIPWIRE MATCH sec-S-k$2-s0 " "$l"; then tw=match
    elif grep -q "TRIPWIRE WAIVED for sec-S-k$2-s0:" "$l"; then tw=waived
    elif grep -q "TRIPWIRE MISMATCH sec-S-k$2-s0 " "$l"; then tw=mismatch; fi
    n=0; nr=0; na=0
    for a in $(printf '%s\n' S "$3" "$4" | LC_ALL=C sort -u); do n=$((n + 1))   # S and the pair's arms, once each
      grep -q "RESULT sec-$a-k$2-s0 " "$l" && nr=$((nr + 1))
      grep "RESULT sec-$a-k$2-s0 " "$l" | grep -q 'n_symbols_absent=1 ' && na=$((na + 1))
    done
    [ "$nr" = "$n" ] && { [ "$na" = "$n" ] && ab=ok || ab=bad; }
  fi
  printf 'V\tk%s\t%s\t%s\t%s\n' "$2" "$v6" "$tw" "$ab"
}

# A stop-gate skip does not depend on the portfolio, so any S seed's record of one is evidence for every seed.
cat "$R"/k[0-4]/sec-S-k[0-4]-s0-entries.tsv 2>/dev/null |
  awk -F'\t' '$4 == "skipped" && ($6 == "No_structural_stop" || $6 == "Stop_too_wide") { print $2 "|" $3 }' | LC_ALL=C sort -u > "$TMP/gate.tsv"

# The G check (README §Arm G): G's capped long tickets on a key an S cell skipped at the stop gate that Friday, over
# the pooled S record and over each seed's own; the premise (S's own long tickets on a pooled gate key, 0 when the
# gate is portfolio-independent); and C's capped tickets on a pooled gate key beside it. One GC row, if G has tickets.
gcheck() {
  gs=0; gp=0; go=0; pr=0; cp=0
  for k in 0 1 2 3 4; do d=$R/k$k
    for f in "$d"/sec-S-k$k-s0-tickets.tsv; do [ -f "$f" ] || continue
      pr=$((pr + $(awk -F'\t' 'FILENAME == ARGV[1] { g[$1] = 1; next } FNR > 1 && $4 == "Long" && (($2 "|" $3) in g) { n++ } END { print n + 0 }' "$TMP/gate.tsv" "$f"))); done
    g=$d/sec-G-k$k-s0-tickets.tsv; [ -f "$g" ] || continue; gs=$((gs + 1))
    awk -F'\t' '$4 == "skipped" && ($6 == "No_structural_stop" || $6 == "Stop_too_wide") { print $2 "|" $3 }' \
      "$d/sec-S-k$k-s0-entries.tsv" 2>/dev/null | LC_ALL=C sort -u > "$TMP/gate-own.tsv"
    for x in pool own; do gk=$TMP/gate.tsv; [ "$x" = own ] && gk=$TMP/gate-own.tsv
      v=$(awk -F'\t' 'FILENAME == ARGV[1] { g[$1] = 1; next }
        FNR > 1 && $4 == "Long" && $5 == "Local_range_top" && (($2 "|" $3) in g) { n++ } END { print n + 0 }' "$gk" "$g")
      [ "$x" = pool ] && gp=$((gp + v)) || go=$((go + v)); done
    c=$d/sec-C-k$k-s0-tickets.tsv
    [ -f "$c" ] && cp=$((cp + $(awk -F'\t' 'FILENAME == ARGV[1] { g[$1] = 1; next }
      FNR > 1 && $4 == "Long" && $5 == "Local_range_top" && (($2 "|" $3) in g) { n++ } END { print n + 0 }' "$TMP/gate.tsv" "$c")))
  done
  [ "$gs" -gt 0 ] && printf 'GC\t%d\t%d\t%d\t%d\t%d\n' "$gs" "$gp" "$go" "$pr" "$cp"
}
gcheck > "$TMP/gc.tsv"

pair() { # $1 base, $2 test -> the pair's read on stdout
  b=$1; t=$2; rows=$TMP/rows-$b$t.tsv; : > "$rows"; n=0; skipped=""
  for k in 0 1 2 3 4; do
    d=$R/k$k; s=$d/sec-$b-k$k-s0-; c=$d/sec-$t-k$k-s0-
    if [ ! -d "$d" ]; then skipped="$skipped k$k(no directory)"; continue; fi
    miss=""; for f in tickets.tsv entries.tsv trades.csv open_positions.csv equity_curve.csv splits.csv actual.sexp; do
      [ -f "$s$f" ] && [ -f "$c$f" ] || miss="$miss $f"; done
    [ -f "$d/sec-S-k$k-s0-actual.sexp" ] || miss="$miss S-actual.sexp"
    if [ -n "$miss" ]; then skipped="$skipped k$k(missing$miss)"; continue; fi
    n=$((n + 1))
    validity "$d" "$k" "$b" "$t" >> "$rows"
    metrics "k$k" S "$s" >> "$rows"; metrics "k$k" C "$c" >> "$rows"; sret "k$k" "$d/sec-S-k$k-s0-" >> "$rows"
    mk=""; if [ -n "$D" ]; then marks "$s" "$c" > "$TMP/marks-k$k.tsv"; mk=$TMP/marks-k$k.tsv; fi
    awk -v seed="k$k" -v test="$t" -f "$LIB/keys.awk" "$TMP/gate.tsv" $mk \
      "${s}equity_curve.csv" "${c}equity_curve.csv" "${s}splits.csv" "${c}splits.csv" "${s}tickets.tsv" "${c}tickets.tsv" \
      "${s}entries.tsv" "${c}entries.tsv" "${s}trades.csv" "${c}trades.csv" "${s}open_positions.csv" "${c}open_positions.csv" \
      | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -k2,2 -k3,3 >> "$rows"
  done
  if [ "$n" = 0 ]; then echo "######## pair $b:$t -- no seed holds both arms; not read"; echo; return 0; fi
  [ -n "$skipped" ] && printf 'W\tseeds\tnot-read\t%s\n' "${skipped# }" >> "$rows"   # a seed left out of the pair is reported, never silent
  cat "$TMP/gc.tsv" >> "$rows"
  [ -n "${KEYS:-}" ] && grep '^K' "$rows" | sed "s/^/$b:$t	/" >> "$KEYS"
  echo "######## pair $b:$t -- delta = ln(1 + R_$t) - ln(1 + R_$b); in the tables $b takes the role README calls S, $t the role it calls C"
  awk -v validity="${VALIDITY:-check}" -v marked="$([ -n "$D" ] && echo 1 || echo 0)" -v base="$b" -v test="$t" \
    -f "$LIB/summary.awk" "$rows"
  echo
}

for p in $PAIRS; do pair "${p%%:*}" "${p#*:}"; done > "$TMP/pairs.txt"
cat "$TMP/pairs.txt"
has() { case " $PAIRS " in *" $1 "*) return 0 ;; esac; return 1; }
if has S:C && has S:G && has G:C; then awk -f "$LIB/combine.awk" "$TMP/pairs.txt"; fi
