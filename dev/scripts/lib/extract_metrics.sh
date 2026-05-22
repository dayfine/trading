#!/usr/bin/env bash
# extract_metrics.sh — sourceable helpers for parsing actual.sexp + composing
# scratch scenario files in promote_config.sh's cross-scenario validation step.
#
# The actual.sexp written by scenario_runner has a flat (key value) sexp shape:
#   ((total_return_pct N) (total_trades N) (win_rate N) (sharpe_ratio N)
#    (max_drawdown_pct N) (avg_holding_days N) (open_positions_value N)
#    (unrealized_pnl N) (force_liquidations_count N))
#
# Each (k v) pair is whitespace-separated; the value is the second token. This
# mirrors dev/scripts/check_sp500_baseline.sh's extraction approach but exposes
# the helpers for reuse from promote_config.sh.
#
# Source from promote_config.sh as:
#   . "$(dirname "$0")/lib/extract_metrics.sh"
#
# Functions exported:
#   extract_metric <path> <field>
#       Print the float value of <field> from the actual.sexp at <path>.
#       Returns empty if the field is missing.
#
#   abs_delta <a> <b>
#       Print |<a> - <b>| via awk. Both args are floats.
#
#   regresses_by_more_than <actual> <baseline> <threshold>
#       Exit 0 if (baseline - actual) > threshold (i.e. actual is worse than
#       baseline by more than the gate). Exit 1 otherwise. <threshold> is the
#       allowed regression in the same units as <actual> / <baseline>.
#       For Sharpe: baseline=0.78, actual=0.65, threshold=0.10 → regression
#       0.13 > 0.10 → exit 0 (fail).
#
#   extract_scenario_overrides_body <scenario_path>
#       Emit the inner contents of the (config_overrides ( ... )) list from a
#       scenario sexp, stripping just the field-name and outer list parens.
#       Used to compose scratch scenarios that merge base + candidate overrides.
#       Implemented via paren-depth tracking awk.
#
#   strip_outer_list_parens <candidate_path>
#       Read candidate config.sexp (a list of override sexps wrapped in one
#       outer `(...)`) and emit just the inner content. The result, concatenated
#       with extract_scenario_overrides_body output, forms the merged inner list
#       for a scratch scenario's config_overrides.

# Extract a single field's float value from an actual.sexp file.
extract_metric() {
  local path="$1" field="$2"
  # actual.sexp values may be integers, decimals, or scientific notation.
  sed -n "s/.*($field \\([0-9.eE+-]*\\)).*/\\1/p" "$path" | head -1
}

# Absolute value of difference between two floats, via awk (POSIX shell can't).
abs_delta() {
  local a="$1" b="$2"
  awk -v a="$a" -v b="$b" \
    'BEGIN { d = a - b; if (d < 0) d = -d; printf "%g", d }'
}

# Returns 0 (true) iff <actual> regresses from <baseline> by more than
# <threshold> in the strict direction: (baseline - actual) > threshold.
# Sharpe / return are "higher is better" → caller passes them directly.
# For "lower is better" metrics (max_dd), caller should invert.
regresses_by_more_than() {
  local actual="$1" baseline="$2" threshold="$3"
  awk -v a="$actual" -v b="$baseline" -v t="$threshold" \
    'BEGIN { exit !((b - a) > t) }'
}

# Pretty-print a signed delta with explicit sign for the validation table.
signed_delta() {
  local actual="$1" baseline="$2"
  awk -v a="$actual" -v b="$baseline" \
    'BEGIN { d = a - b; printf (d >= 0 ? "+%.4f" : "%.4f"), d }'
}

# Extract the inner contents of the (config_overrides (...)) field from a
# scenario sexp. The output is the body without the outer field-wrapper and
# the immediate list parens, so each emitted line is one override sexp.
#
# Algorithm:
#   1. Find the `(config_overrides` opening token in the file.
#   2. Consume from that offset, counting parens, until the field's outer paren
#      closes (depth back to 0). Buffer everything up to but excluding that
#      closing paren.
#   3. From the buffer, strip the leading `(config_overrides` plus whitespace.
#      What remains is the immediate inner list, e.g. `(((o1)) ((o2)) ... )`.
#   4. Find the first `(` and last `)` of that remaining content; everything
#      between is the list body — what we emit.
#
# Done in one awk pass so multi-line `(config_overrides ...)` blocks (the
# usual case) work uniformly.
extract_scenario_overrides_body() {
  local scenario_path="$1"
  awk '
    BEGIN { found = 0; depth = 0; buf = "" }
    {
      line = $0
      if (!found) {
        idx = index(line, "(config_overrides")
        if (idx == 0) { next }
        line = substr(line, idx)
        found = 1
      }
      i = 1; n = length(line)
      while (i <= n) {
        c = substr(line, i, 1)
        if (c == "(") depth++
        else if (c == ")") {
          depth--
          if (depth == 0) {
            # Capture everything up through this closing paren, then strip
            # the wrapper. The buffer at this point is:
            #   "(config_overrides ... (...) ... )"
            buf = buf substr(line, 1, i)
            # Strip leading "(config_overrides" + whitespace.
            sub(/^\(config_overrides[[:space:]]+/, "", buf)
            # Strip trailing ")" (the closing of config_overrides field).
            buf = substr(buf, 1, length(buf) - 1)
            # buf is now the immediate inner list `(((o1))...((oN)))`.
            # Strip the outermost parens of that list.
            sub(/^[[:space:]]*\(/, "", buf)
            sub(/\)[[:space:]]*$/, "", buf)
            print buf
            exit
          }
        }
        i++
      }
      buf = buf line "\n"
    }
  ' "$scenario_path"
}

# Strip the outermost list parens from a candidate config.sexp. The candidate
# is one outer list `( <override1> <override2> ... )` where each child is a
# partial-config sexp. We want just the children, suitable for appending to
# a scenario's config_overrides body.
strip_outer_list_parens() {
  local candidate_path="$1"
  awk '
    BEGIN { started = 0; depth = 0; out = "" }
    {
      line = $0
      i = 1; n = length(line)
      while (i <= n) {
        c = substr(line, i, 1)
        if (!started) {
          if (c == "(") { started = 1; depth = 1; i++; continue }
          if (c == " " || c == "\t" || c == "\n") { i++; continue }
        } else {
          if (c == "(") depth++
          else if (c == ")") {
            depth--
            if (depth == 0) { print out; exit }
          }
          out = out c
        }
        i++
      }
      out = out "\n"
    }
  ' "$candidate_path"
}

# Extract a single top-level scenario field that fits on one line, e.g.
# `(name "sp500-2019-2023")` or `(universe_path "universes/sp500.sexp")`. The
# regex matches the field name and captures the quoted-string or single-token
# value verbatim. Returns the literal sexp child including any quotes.
#
# Limited intentionally — used only for the small set of fields the scratch-
# scenario composer needs, where each field is a single-line `(key value)` in
# every goldens-sp500* scenario. For multi-line / nested fields use
# extract_scenario_overrides_body instead.
extract_scenario_field() {
  local scenario_path="$1" field="$2"
  awk -v field="$field" '
    BEGIN { pat = "^[[:space:]]*\\(" field "[[:space:]]+" }
    $0 ~ pat {
      # Drop "(field " prefix and the matching trailing ")".
      sub(pat, "", $0)
      sub(/\)[[:space:]]*$/, "", $0)
      print
      exit
    }
  ' "$scenario_path"
}

# Compose a scratch scenario file by merging base scenario's config_overrides
# with the candidate's overrides. Writes to <out_path>.
#
# The composed scenario carries the base's name, description, period,
# universe_path, and config_overrides — extended by the candidate. The
# `expected` block is set to NaN-tolerant wide ranges since validation cares
# only about the metrics, not the PASS/FAIL gate against pinned cell-E ranges.
#
# Args:
#   base_scenario_path  — path to the base scenario .sexp
#   candidate_path      — path to the candidate config.sexp
#   scratch_name        — name for the scratch scenario (used in actual.sexp
#                         output dir; should differ from base to keep output
#                         dirs isolated)
#   out_path            — where to write the composed scratch scenario .sexp
compose_scratch_scenario() {
  local base_scenario_path="$1"
  local candidate_path="$2"
  local scratch_name="$3"
  local out_path="$4"

  local period universe_path base_overrides candidate_overrides
  period=$(extract_scenario_field "$base_scenario_path" period)
  universe_path=$(extract_scenario_field "$base_scenario_path" universe_path)
  base_overrides=$(extract_scenario_overrides_body "$base_scenario_path")
  candidate_overrides=$(strip_outer_list_parens "$candidate_path")

  if [ -z "$period" ] || [ -z "$universe_path" ]; then
    echo "[extract_metrics] failed to extract period/universe_path from $base_scenario_path" >&2
    return 1
  fi

  # Description is best-effort: multi-line descriptions don't extract cleanly,
  # and the description is not load-bearing for validation (only name, period,
  # universe_path, and config_overrides matter to the runner).
  local description
  description='"promote-validation scratch scenario"'

  # Wide expected ranges — these intentionally accept any reasonable backtest
  # result so the scenario_runner writes actual.sexp without flapping the
  # PASS/FAIL gate. The promote-gate's regression check is separate.
  cat > "$out_path" << EOF
;; Auto-generated scratch scenario for promote-gate cross-scenario validation.
;; Base: $base_scenario_path
;; Candidate overrides appended from: $candidate_path
((name "$scratch_name")
 (description $description)
 (period $period)
 (universe_path $universe_path)
 (config_overrides
  ($base_overrides
   $candidate_overrides))
 (expected
  ((total_return_pct       ((min -100.0) (max 10000.0)))
   (total_trades           ((min 0)      (max 100000)))
   (win_rate               ((min 0.0)    (max 100.0)))
   (sharpe_ratio           ((min -100.0) (max 100.0)))
   (max_drawdown_pct       ((min 0.0)    (max 100.0)))
   (avg_holding_days       ((min 0.0)    (max 10000.0))))))
EOF
}
