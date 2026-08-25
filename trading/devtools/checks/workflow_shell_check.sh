#!/bin/sh
# Shellcheck linter for GitHub Actions workflow `run:` blocks.
#
# Motivation (issue #2521): a `run:` step in orchestrator.yml referenced a
# variable that was only assigned inside a subshell (command substitution
# forks a subshell; any variable it assigns is invisible to the caller),
# and the step ran under `set -euo pipefail`. It was invisible to every
# other gate: `bash -n` (posix_sh_check.sh's dash -n sibling check) is
# parse-only and never evaluates variable scoping; CI never lints workflow
# YAML at all; and nothing runs shellcheck over embedded `run:` bodies,
# because they live inside YAML, not as standalone `.sh` files
# posix_sh_check.sh's *.sh glob would ever see. See commit ce88954 for the
# motivating defect and its fix (#2517, cited inline in orchestrator.yml's
# merge_pr_when_clean comment).
#
# IMPORTANT SCOPE LIMITATION (verified against shellcheck 0.8.0, the
# version installed by this repo's Dockerfile): this check does NOT catch
# the exact ce88954 defect shape. shellcheck models scope loss across a
# *pipeline* subshell (SC2030/SC2031 -- see the defect fixture in
# workflow_shell_check_test.sh) but has no model for scope loss across a
# *command-substitution* subshell that invokes a function
# (`X="$(some_fn)"` where `some_fn` assigns a variable the caller reads).
# Verified directly: reconstructing the ce88954 shape (a function
# assigning MERGE_RESPONSE, invoked as `MERGED="$(fn)"`, caller reading
# `${MERGE_RESPONSE}`) and running `shellcheck -s bash` on it produces
# ZERO findings -- even with the `check-unassigned-uppercase` optional
# rule enabled, because the assignment is lexically present somewhere in
# the file and shellcheck does not track which shell process actually
# performs it. The class of
# bug that MOTIVATED this issue therefore remains open; see #2521 for the
# residual gap and its follow-up. What this check DOES reliably catch:
# pipeline-subshell scope loss (SC2030/SC2031) and shellcheck's general
# hygiene ruleset over every workflow `run:` body -- a real and useful
# guard, just narrower than the issue originally asked for. See the
# "known gap" fixture in workflow_shell_check_test.sh, which pins this
# limitation as a regression test.
#
# What this script does:
#   1. Extracts every step's `run:` body (block-scalar `run: |` and
#      single-line `run: <cmd>`) out of each `.github/workflows/*.yml`
#      file into standalone fragment files.
#   2. Neutralizes GitHub Actions `${{ expr }}` expressions by replacing
#      each with the bare token `GHEXPR` before linting -- shellcheck has
#      no notion of GH's templating syntax and mis-parses `${{ ... }}` as
#      malformed parameter expansion. GH itself performs this substitution
#      textually before the runner ever sees the script, so replacing the
#      whole `${{ ... }}` span with an inert token preserves whatever
#      quoting/adjacency context the expression sat in (e.g.
#      `"${{ github.workspace }}/foo"` -> `"GHEXPR/foo"`) without ever
#      needing to know the expression's actual runtime value.
#   3. Determines each step's shell dialect (`shell:` step override, else
#      the job/workflow `defaults: run: shell:` block, else GitHub's own
#      default of `bash` on Linux runners) and runs
#      `shellcheck -s <dialect>` over the fragment.
#
# YAML parsing approach: this is an indentation-based extractor (awk),
# NOT a general YAML parser -- there is no YAML library available without
# adding a non-OCaml, non-jq dependency (see .claude/rules/no-python.md;
# this repo also has no yq). It is built and tested against every workflow
# file that exists in this repo today (all single-job files, `steps:` at
# 4-space indent, step items at 6-space indent, step properties incl.
# `run:`/`shell:` at 8-space indent -- verified structurally identical
# across all 17 files under .github/workflows/ as of #2521). A workflow
# file that deviates from that layout (e.g. a multi-job file, or steps
# nested under a matrix at different indentation) may be extracted
# incorrectly or skipped; this is a known, accepted limitation of the
# indentation-based approach. The final "N run: block(s) clean" count
# covers every fragment extracted across all workflow files, so a broad
# drop in that number (e.g. after adding a workflow with a layout this
# extractor doesn't handle) is visible run-over-run even though the count
# is not broken out per file.
#
# Graceful degrade: shellcheck is not yet installed in the
# trading-devcontainer base image (see .devcontainer/Dockerfile; the apt
# package is added alongside this check, takes effect after the image
# rebuild workflow next runs). Until then -- and in any environment
# without shellcheck on PATH -- this check prints SKIP and exits 0, so it
# never blocks local dev or CI ahead of the image rebuild. Once shellcheck
# is on PATH it becomes enforcing.
#
# Env overrides for testing:
#   WORKFLOW_SHELL_CHECK_DIR=<dir>   scan this dir instead of
#                                    <repo_root>/.github/workflows
#   SHELLCHECK=<path>                shellcheck binary to use (default:
#                                    "shellcheck" on PATH)

set -e

. "$(dirname "$0")/_check_lib.sh"

SHELLCHECK="${SHELLCHECK:-shellcheck}"

if ! command -v "$SHELLCHECK" >/dev/null 2>&1; then
  echo "SKIP: workflow_shell_check -- shellcheck not installed (see .devcontainer/Dockerfile)"
  exit 0
fi

REPO_ROOT="$(repo_root)"

if [ -n "${WORKFLOW_SHELL_CHECK_DIR:-}" ]; then
  SCAN_DIR="$WORKFLOW_SHELL_CHECK_DIR"
else
  SCAN_DIR="${REPO_ROOT}/.github/workflows"
fi

if [ ! -d "$SCAN_DIR" ]; then
  echo "OK: workflow-shell linter -- scan dir $SCAN_DIR does not exist, nothing to check."
  exit 0
fi

FRAG_DIR="$(mktemp -d)"
trap 'rm -rf "$FRAG_DIR"' EXIT

# ---------------------------------------------------------------------
# Extract every step's run: body from one workflow file into fragment
# files under $FRAG_DIR, one file per fragment plus a sidecar ".shell"
# file naming its shellcheck dialect.
#
# Two-pass awk (same file given as two positional args -- NR==FNR is the
# classic POSIX-awk idiom for "am I still reading the first copy"):
#   pass 1 (NR==FNR): walk the file once to record, per step index, any
#     `shell:` override found within that step, and separately the
#     workflow/job default shell (any `shell:` line seen before the first
#     step marker -- i.e. inside a `defaults: run:` block, which in every
#     file in this repo appears before `steps:`).
#   pass 2: walk the file again, re-deriving step indices in lockstep with
#     pass 1, and this time emit the run: bodies, tagging each with the
#     shell resolved from pass 1's tables.
#
# Step boundaries: a line matching /^      - / (6-space indent, dash,
# space) starts a new step -- verified as the uniform step-item indent
# across every workflow file in this repo (steps: itself sits at 4-space
# indent, one level under a job key at 2-space indent). Step properties
# (run:, shell:, name:, ...) sit at 8-space indent.
# ---------------------------------------------------------------------
_extract_one() {
  wf="$1"
  wfbase="$2"
  awk -v outdir="$FRAG_DIR" -v wfbase="$wfbase" '
    function trim(s) {
      sub(/^[ \t]+/, "", s)
      sub(/[ \t]+$/, "", s)
      return s
    }
    function neutralize(s) {
      gsub(/\$\{\{[^}]*\}\}/, "GHEXPR", s)
      return s
    }

    # ---- pass 1: shell: overrides per step, + job/workflow default ----
    NR == FNR {
      line = $0
      if (line ~ /^      - /) {
        step_idx++
      }
      if (match(line, /^[ \t]*shell:[ \t]*/)) {
        val = substr(line, RSTART + RLENGTH)
        gsub(/[ \t]+$/, "", val)
        gsub(/^"|"$/, "", val)
        gsub(/^'"'"'|'"'"'$/, "", val)
        if (step_idx == 0) {
          default_shell = val
        } else {
          step_shell[step_idx] = val
        }
      }
      next
    }

    # ---- pass 2: extract run: bodies, tagged with resolved shell ----
    {
      line = $0
      if (line ~ /^      - /) {
        step_idx2++
        cur_shell = (step_idx2 in step_shell) ? step_shell[step_idx2] : \
          (default_shell != "" ? default_shell : "bash")
        in_block = 0
      }

      # Block-scalar run: | (or run: with nothing else on the line, which
      # in a step context -- step_idx2 > 0 -- is always a block scalar
      # whose indicator got trimmed above; a bare "run:" at step_idx2==0
      # is the defaults: sub-mapping, not a command, and must be skipped).
      if (!in_block && match(line, /^        run:[ \t]*(\|[+-]?|>[+-]?)?[ \t]*$/)) {
        if (step_idx2 == 0) { next }
        frag_idx++
        fragfile = outdir "/" wfbase "__s" step_idx2 "_" frag_idx ".sh"
        shellfile = outdir "/" wfbase "__s" step_idx2 "_" frag_idx ".shell"
        print cur_shell > shellfile
        close(shellfile)
        printf "" > fragfile
        close(fragfile)
        in_block = 1
        block_indent = -1
        next
      }

      # Single-line run: <cmd> (anything not starting the block-scalar
      # indicators | or > right after the colon).
      if (!in_block && match(line, /^        run:[ \t]+[^|>[:space:]].*/)) {
        if (step_idx2 == 0) { next }
        frag_idx++
        fragfile = outdir "/" wfbase "__s" step_idx2 "_" frag_idx ".sh"
        shellfile = outdir "/" wfbase "__s" step_idx2 "_" frag_idx ".shell"
        cmd = line
        sub(/^        run:[ \t]+/, "", cmd)
        print cur_shell > shellfile
        close(shellfile)
        print neutralize(cmd) > fragfile
        close(fragfile)
        next
      }

      if (in_block) {
        if (trim(line) == "") {
          print "" >> fragfile
          next
        }
        indent = match(line, /[^ ]/) - 1
        if (block_indent == -1) {
          block_indent = indent
        }
        if (indent < block_indent) {
          # Block ended (dedent to a sibling property or the next step).
          # The line itself is re-examined by nothing further this
          # iteration -- acceptable because every dedent target in this
          # repo is either a new step marker (handled by the step-boundary
          # check at the top of this rule, on ITS OWN turn through the
          # loop -- but note we are already past that check for the
          # current line) or a step property this script does not care
          # about. A dedent straight into a NEW step marker on the same
          # line never happens in valid YAML (one key per line), so no
          # step boundary is ever missed by this fallthrough.
          in_block = 0
        } else {
          content = substr(line, block_indent + 1)
          print neutralize(content) >> fragfile
        }
      }
    }
  ' "$wf" "$wf"
}

# ---------------------------------------------------------------------
# Baseline exclusions (issue #2539 tracks burning these down).
#
# The default shellcheck ruleset was run against every workflow file as
# they existed when this check was introduced (#2521). Two classes of
# findings came back:
#   - Mechanical, zero-behavior-risk fixes: applied directly in the same
#     PR that added this check (SC2046 unquoted `eval $(opam env)` x8;
#     SC2034 an unused `OWNER` variable in orchestrator.yml).
#   - Findings that touch live workflow logic this PR cannot validate
#     against a real GHA run (golden-run/perf-run cron schedules, and an
#     orchestrator.yml block with a documented history of regressions
#     from exactly this kind of "obviously correct" edit) -- excluded
#     below, one code per line, each with its own reason. Not blanket:
#     each is a specific, named code, not a severity-level cutoff.
#
# Remove a line here once its last occurrence is fixed (see #2539).
# ---------------------------------------------------------------------
SHELLCHECK_EXCLUDES="-e SC2012 -e SC2086 -e SC2010"
# SC2012 (info, "use find instead of ls"): 7 occurrences, the
#   `ls -1t <dir-glob>/summary.txt | head -1` pattern in
#   golden-runs-{custom-universe,sp500-15y,sp500-5y}.yml,
#   perf-{nightly,tier1,weekly}.yml, and orchestrator.yml. These only run
#   on push:main / cron -- no PR-time signal to verify a fix against.
# SC2086 (info, "double quote to prevent globbing/word splitting"): 2
#   occurrences in orchestrator.yml's daily-summary-file lookup. The
#   surrounding block has its own inline comments documenting a prior
#   regression from an "obviously correct" edit to this exact logic.
# SC2010 (warning, "don't use ls | grep"): 1 occurrence, same
#   orchestrator.yml block as the SC2086 pair above.

CLEAN_COUNT=0
FAIL_COUNT=0
VIOLATIONS=""

for wf in "$SCAN_DIR"/*.yml "$SCAN_DIR"/*.yaml; do
  [ -f "$wf" ] || continue
  wfbase="$(basename "$wf")"
  _extract_one "$wf" "$wfbase"
done

for frag in "$FRAG_DIR"/*.sh; do
  [ -f "$frag" ] || continue
  shellfile="${frag%.sh}.shell"
  dialect="bash"
  if [ -f "$shellfile" ]; then
    dialect="$(cat "$shellfile")"
  fi
  # shellcheck only understands sh/bash/dash/ksh dialects; GH also allows
  # pwsh/python/cmd for other runner OSes, none of which appear in this
  # repo's Linux-only workflows (checked: every job is runs-on:
  # ubuntu-latest). Fall back to bash for anything shellcheck can't parse
  # via -s so an unrecognized dialect string doesn't hard-crash the whole
  # check.
  case "$dialect" in
    sh | bash | dash | ksh) ;;
    *) dialect="bash" ;;
  esac
  # shellcheck disable=SC2086
  # (SHELLCHECK_EXCLUDES is an internally-built fixed flag list, not user
  # input; word-splitting it into separate -e SCxxxx arguments is intended.)
  if err=$("$SHELLCHECK" -s "$dialect" $SHELLCHECK_EXCLUDES "$frag" 2>&1); then
    CLEAN_COUNT=$((CLEAN_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    fragname="$(basename "$frag" .sh)"
    VIOLATIONS="${VIOLATIONS}FAIL: ${fragname} (dialect=${dialect})
${err}

"
  fi
done

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAIL: workflow-shell linter -- $FAIL_COUNT run: block(s) have shellcheck violations:"
  echo ""
  printf '%s' "$VIOLATIONS"
  echo "Fix: address the shellcheck findings above, or if a finding is a false"
  echo "     positive for GH Actions' \${{ }} templating, add a targeted"
  echo "     # shellcheck disable=SCxxxx comment at the site in the workflow's"
  echo "     run: block (not a blanket exclusion)."
  exit 1
fi

echo "OK: workflow-shell linter -- ${CLEAN_COUNT} run: block(s) clean."
