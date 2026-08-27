# Shared GNU /usr/bin/time peak-RSS parser.
#
# Use:
#   . "$REPO_ROOT/dev/lib/gnu_time_rss.sh"
#   rss_value=$(_parse_gnu_time_rss "$rss_path")
#
# _parse_gnu_time_rss <rss-file> -- extract the peak-RSS kB value written by
# GNU /usr/bin/time -f '%M' into <rss-file>.
#
# The file has one of two shapes depending on whether the timed command
# exited zero or non-zero:
#   zero exit:     the file is exactly the %M value, e.g. "745192\n"
#   non-zero exit: GNU time additionally writes a leading status line, e.g.
#                  "Command exited with non-zero status 1\n745192\n" (or
#                  "Command terminated by signal N\n<value>\n" if killed)
# In both shapes the %M value is the LAST line. Read that line specifically
# rather than stripping all newlines from the whole file: `tr -d '\n'` over
# the two-line non-zero-exit shape concatenates the trailing status digit
# onto the RSS digits (e.g. "...status 1" + "745192" -> "1745192", off by
# ~1GB) -- and only on FAILING cells, exactly when someone reads the number.
#
# Originally landed only in dev/scripts/golden_sp500_postsubmit.sh (#2553);
# the same bug was independently present in perf_tier1_smoke.sh,
# perf_tier2_nightly.sh, perf_tier3_weekly.sh, perf_tier4_release_gate.sh,
# and run_tier4_release_gate.sh -- extracted here as the single shared
# implementation so a future fix only has one call site to change (#2559).
# perf_tier1_smoke.sh in particular backs the REQUIRED `perf-tier1-smoke` PR
# gate, so a fused-digit RSS misread there is the highest-stakes instance.
#
# The UNAVAILABLE sentinel (written by callers when GNU time isn't present
# at all) is a single line and passes through unchanged.
#
# Regression test: trading/devtools/checks/gnu_time_rss_smoke.sh.
# See issues #2553, #2559.
_parse_gnu_time_rss() {
  tail -n 1 "$1" | tr -d '\n'
}
