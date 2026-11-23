# weekly_lib.sh -- helpers of weekly.sh that guard something and so are sourced by
# weekly_picks_dry_run_check.sh and exercised directly. Sourced, never run: no shebang.
#
#   bucket_shards          the shard-disjoint fetch buckets (#3645)
#   check_public_price_free  the price-free tripwire on the one file that reaches the public repo
#   check_container_args   no whitespace in an argument bound for run-in-env.sh (#3698)
#
# The sourcing script defines die() (print a message, exit non-zero) before calling these.

# bucket_shards <symbols> <prefix> <n>: <prefix>_NN.txt, whole shard keys (first + last letter,
# upper-cased, as Csv_storage's Symbol_shard) per bucket, largest key first onto the lightest bucket.
bucket_shards() {
  rm -f "$2"_??.txt
  awk '{ print toupper(substr($1, 1, 1)) toupper(substr($1, length($1), 1)) "\t" $1 }' "$1" | sort | awk -F'\t' -v prefix="$2" -v nb="$3" '
    { key[NR] = $1; sym[NR] = $2; cnt[$1]++ }
    END {
      for (k in cnt) keys[++n] = k
      for (i = 2; i <= n; i++) {
        v = keys[i]; j = i - 1
        while (j >= 1 && (cnt[keys[j]] < cnt[v] || (cnt[keys[j]] == cnt[v] && keys[j] > v))) { keys[j + 1] = keys[j]; j-- }
        keys[j + 1] = v }
      for (b = 0; b < nb; b++) load[b] = 0
      for (i = 1; i <= n; i++) {
        best = 0
        for (b = 1; b < nb; b++) if (load[b] < load[best]) best = b
        bucket[keys[i]] = best; load[best] += cnt[keys[i]] }
      for (i = 1; i <= NR; i++) { f = sprintf("%s_%02d.txt", prefix, bucket[key[i]]); print sym[i] > f } }'
}

# The public summary is committed: refuse a table row carrying a two-decimal number (a price).
check_public_price_free() {
  if grep '^| [0-9]' "$1" | grep -Eq '[0-9]\.[0-9][0-9]'; then
    die "$1: a table row carries a number with two decimals; not staging it"
  fi
}

# check_container_args <arg>...: refuse an argument holding whitespace. run-in-env.sh runs the
# command as `bash -c "... $*"` locally, which re-splits every argument on whitespace (#3698).
# Runs in --dry-run too, so the dry run catches it.
check_container_args() {
  for _a in "$@"; do
    case "$_a" in *[[:space:]]*) die "container argument with whitespace (run-in-env.sh would split it): '$_a'" ;; esac
  done
}
