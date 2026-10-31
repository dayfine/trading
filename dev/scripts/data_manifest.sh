#!/bin/sh
# data_manifest.sh -- hash manifest of the local bar store (issue #3476).
#
# Lets two copies of the data (the local Mac copy, a cloud session's fresh
# EODHD fetch) prove they hold the same inputs without moving the data: the
# manifest holds hashes only, so it is safe to commit to the public repo.
#
# Usage:
#   data_manifest.sh build --data-dir DIR --cutoff YYYY-MM-DD [--symbols FILE] --out FILE
#   data_manifest.sh compare A B
#
# build: walks DIR/<L1>/<L2>/<SYM>/ and writes one leaf per symbol directory.
#   --symbols FILE  keep only the symbols listed (one per line; blank lines
#                   and lines starting with # are ignored).
#   A symbol directory with no data.csv is skipped with a warning on stderr.
#
# compare: exit 0 if the two manifests have equal roots. Otherwise exit 1 and
#   list symbols only in A, only in B, and with different leaves. Exit 2 on a
#   usage or read error.
#
# Leaf rule (version 1) -- a leaf is the sha256 of this text:
#     #bars
#     date,open,high,low,close,volume        data.csv rows with date <= cutoff
#     #splits
#     date,factor                            splits.csv rows, date <= cutoff
#     #dividends
#     ex_date,unadjusted_amount              dividends.csv rows, ex_date <= cutoff
#   - Columns are picked by header name, so column order in the file is free.
#     adjusted_close, active_through and adjusted_amount are NOT hashed: EODHD
#     recomputes them backwards after every later split or dividend.
#   - Each section's rows are sorted with LC_ALL=C. Trailing CRs are dropped.
#   - A missing splits.csv or dividends.csv is an empty section, identical to a
#     file holding only its header.
#   - Number normalisation, so 43.9688 and 43.968800 hash the same: a field
#     matching [+-]digits[.digits] (or .digits) is rewritten as sign (only if
#     negative and non-zero), integer part with leading zeros removed (at
#     least "0"), and the fraction with trailing zeros removed (the "." goes
#     too when nothing is left). A field of the form N/M or N:M (a split
#     factor) has each side normalised. Anything else (dates, exponent
#     notation, empty fields) is hashed as written.
#
# Folding: a folder hash is the sha256 of its children's "<name> <hash>"
# lines sorted with LC_ALL=C, one line per child. L2 folders fold their
# "<sym> <leaf>" lines; L1 folders fold "<L2> <hash>"; the root folds
# "<L1> <hash>". The cutoff is stored in the header but not in any hash.
#
# Output file: header lines starting with "# " (cutoff, leaf rule version,
# symbol count, root), then one "<sym> <leafhash>" line per symbol, sorted
# with LC_ALL=C.
#
# Hashing uses sha256sum when present, else shasum -a 256 (macOS).

set -eu

LEAF_RULE_VERSION=1

_die() {
  printf 'data_manifest: %s\n' "$*" >&2
  exit 2
}

_usage() {
  cat >&2 <<'EOF'
usage: data_manifest.sh build --data-dir DIR --cutoff YYYY-MM-DD [--symbols FILE] --out FILE
       data_manifest.sh compare A B
EOF
  exit 2
}

# Reads stdin, prints the hex sha256.
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d' ' -f1
  else
    _die "neither sha256sum nor shasum found"
  fi
}

# _canon_csv FILE CUTOFF COLS: print the named columns (comma-separated list
# COLS; the first is the date column) of every row with date <= CUTOFF,
# numbers normalised. Exit 1 if a named column is missing from the header.
_canon_csv() {
  awk -F, -v cutoff="$2" -v cols="$3" '
    function norm1(s,   sign, ip, fp, k) {
      if (s !~ /^[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)$/) return s
      sign = ""
      if (substr(s, 1, 1) == "-") { sign = "-"; s = substr(s, 2) }
      else if (substr(s, 1, 1) == "+") { s = substr(s, 2) }
      k = index(s, ".")
      if (k) { ip = substr(s, 1, k - 1); fp = substr(s, k + 1) }
      else { ip = s; fp = "" }
      sub(/0+$/, "", fp)
      sub(/^0+/, "", ip)
      if (ip == "") ip = "0"
      if (ip == "0" && fp == "") sign = ""
      return sign ip (fp == "" ? "" : "." fp)
    }
    function norm(s,   n, p, i, sep, out) {
      for (sep = 1; sep <= 2; sep++) {
        c = (sep == 1) ? "/" : ":"
        if (index(s, c)) {
          n = split(s, p, c)
          out = norm1(p[1])
          for (i = 2; i <= n; i++) out = out c norm1(p[i])
          return out
        }
      }
      return norm1(s)
    }
    { sub(/\r$/, "") }
    NR == 1 {
      for (i = 1; i <= NF; i++) pos[$i] = i
      nc = split(cols, want, ",")
      for (i = 1; i <= nc; i++)
        if (!(want[i] in pos)) {
          printf "missing column %s\n", want[i] > "/dev/stderr"
          bad = 1; exit 1
        }
      next
    }
    NF == 0 { next }
    {
      if ($(pos[want[1]]) > cutoff) next
      line = norm($(pos[want[1]]))
      for (i = 2; i <= nc; i++) line = line "," norm($(pos[want[i]]))
      print line
    }
    END { if (bad) exit 1 }
  ' "$1"
}

# _section DIR FILE CUTOFF COLS LABEL: print "#LABEL" then the sorted rows.
# A missing file is an empty section.
_section() {
  printf '#%s\n' "$5"
  if [ -f "$1/$2" ]; then
    _canon_csv "$1/$2" "$3" "$4" >"$TMP/sec" || _die "$1/$2: cannot read columns $4"
    LC_ALL=C sort "$TMP/sec"
  fi
}

# _leaf SYMDIR CUTOFF: print the leaf hash of one symbol directory.
_leaf() {
  {
    _section "$1" data.csv "$2" date,open,high,low,close,volume bars
    _section "$1" splits.csv "$2" date,factor splits
    _section "$1" dividends.csv "$2" ex_date,unadjusted_amount dividends
  } | _sha256
}

# _fold_by N: stdin is sorted lines whose first N fields are a group key.
# Prints "<key> <hash of the group's remaining text>" per group, in order.
_fold_by() {
  rm -rf "$TMP/grp"
  mkdir "$TMP/grp"
  awk -v n="$1" -v dir="$TMP/grp" '
    {
      key = $1
      for (i = 2; i <= n; i++) key = key " " $i
      rest = $(n + 1)
      for (i = n + 2; i <= NF; i++) rest = rest " " $i
      if (key != prev) { close(f); g++; f = dir "/" g; print g " " key > (dir "/keys"); prev = key }
      print rest >> f
    }
  ' >/dev/null
  [ -f "$TMP/grp/keys" ] || return 0
  while read -r g key; do
    printf '%s %s\n' "$key" "$(_sha256 <"$TMP/grp/$g")"
  done <"$TMP/grp/keys"
}

_build() {
  data_dir=""; cutoff=""; symbols=""; out=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --data-dir) [ $# -ge 2 ] || _usage; data_dir=$2; shift 2 ;;
      --cutoff) [ $# -ge 2 ] || _usage; cutoff=$2; shift 2 ;;
      --symbols) [ $# -ge 2 ] || _usage; symbols=$2; shift 2 ;;
      --out) [ $# -ge 2 ] || _usage; out=$2; shift 2 ;;
      *) _usage ;;
    esac
  done
  [ -n "$data_dir" ] && [ -n "$cutoff" ] && [ -n "$out" ] || _usage
  [ -d "$data_dir" ] || _die "no such directory: $data_dir"
  case "$cutoff" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *) _die "cutoff must be YYYY-MM-DD: $cutoff" ;;
  esac
  if [ -n "$symbols" ]; then
    [ -f "$symbols" ] || _die "no such symbols file: $symbols"
    grep -v '^[[:space:]]*\(#\|$\)' "$symbols" >"$TMP/wanted" || true
  fi

  : >"$TMP/leaves"
  for d in "$data_dir"/*/*/*/; do
    [ -d "$d" ] || continue
    d=${d%/}
    sym=${d##*/}; p=${d%/*}; l2=${p##*/}; q=${p%/*}; l1=${q##*/}
    if [ -n "$symbols" ] && ! grep -qxF -- "$sym" "$TMP/wanted"; then
      continue
    fi
    if [ ! -f "$d/data.csv" ]; then
      printf 'data_manifest: warning: %s has no data.csv, skipped\n' "$d" >&2
      continue
    fi
    printf '%s %s %s %s\n' "$l1" "$l2" "$sym" "$(_leaf "$d" "$cutoff")" >>"$TMP/leaves"
  done

  LC_ALL=C sort "$TMP/leaves" >"$TMP/sorted"
  _fold_by 2 <"$TMP/sorted" | LC_ALL=C sort >"$TMP/l2"
  _fold_by 1 <"$TMP/l2" | LC_ALL=C sort >"$TMP/l1"
  root=$(_sha256 <"$TMP/l1")
  count=$(wc -l <"$TMP/sorted" | tr -d ' ')

  {
    printf '# data-manifest\n'
    printf '# cutoff %s\n' "$cutoff"
    printf '# leaf-rule-version %s\n' "$LEAF_RULE_VERSION"
    printf '# symbols %s\n' "$count"
    printf '# root %s\n' "$root"
    awk '{ print $3 " " $4 }' "$TMP/sorted" | LC_ALL=C sort
  } >"$out"
  printf 'data_manifest: %s symbols, root %s -> %s\n' "$count" "$root" "$out"
}

# _header FILE KEY: the value of the "# KEY value" header line.
_header() {
  awk -v k="$2" '$1 == "#" && $2 == k { print $3; exit }' "$1"
}

_compare() {
  [ $# -eq 2 ] || _usage
  a=$1; b=$2
  [ -f "$a" ] || _die "no such manifest: $a"
  [ -f "$b" ] || _die "no such manifest: $b"
  root_a=$(_header "$a" root); root_b=$(_header "$b" root)
  [ -n "$root_a" ] && [ -n "$root_b" ] || _die "manifest without a root line"
  if [ "$root_a" = "$root_b" ]; then
    printf 'roots equal: %s\n' "$root_a"
    return 0
  fi
  printf 'roots differ:\n  A %s\n  B %s\n' "$root_a" "$root_b"
  for key in cutoff leaf-rule-version; do
    va=$(_header "$a" "$key"); vb=$(_header "$b" "$key")
    [ "$va" = "$vb" ] || printf 'note: %s differs (A %s, B %s)\n' "$key" "$va" "$vb"
  done
  grep -v '^#' "$a" | LC_ALL=C sort >"$TMP/a"
  grep -v '^#' "$b" | LC_ALL=C sort >"$TMP/b"
  awk '{ print $1 }' "$TMP/a" >"$TMP/a.sym"
  awk '{ print $1 }' "$TMP/b" >"$TMP/b.sym"
  printf 'only in A:\n'
  LC_ALL=C comm -23 "$TMP/a.sym" "$TMP/b.sym" | sed 's/^/  /'
  printf 'only in B:\n'
  LC_ALL=C comm -13 "$TMP/a.sym" "$TMP/b.sym" | sed 's/^/  /'
  printf 'different leaf:\n'
  LC_ALL=C join "$TMP/a" "$TMP/b" | awk '$2 != $3 { print "  " $1 }'
  return 1
}

[ $# -ge 1 ] || _usage
TMP=$(mktemp -d "${TMPDIR:-/tmp}/data_manifest.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
cmd=$1; shift
case "$cmd" in
  build) _build "$@" ;;
  compare) _compare "$@" ;;
  *) _usage ;;
esac
