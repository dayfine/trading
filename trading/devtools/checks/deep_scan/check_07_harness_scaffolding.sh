#!/bin/sh
# Check 7: Harness scaffolding review.
#
# Usage: sh check_07_harness_scaffolding.sh <report_file> [findings_file]
#
# Three heuristics (all advisory — WARNING or PASS, no FAIL):
#
#   H1: Shell script in trading/devtools/checks/ not referenced from any
#       dune file, GitHub workflow YAML, other *.sh in the same dir, or
#       any .claude/agents/*.md.  Exemptions: _check_lib.sh (library),
#       deep_scan.sh (run manually/by agent), write_audit.sh (run by
#       humans / ops-data agent, no dune rule).
#
#   H2: OCaml linter binary (fn_length_linter, cc_linter, nesting_linter)
#       whose %{exe:...} reference does not appear in
#       trading/devtools/checks/dune — built but never wired into runtest.
#
#   H3: .claude/agents/*.md references a harness script path
#       (matching "devtools/checks/*.sh" pattern) that does not exist
#       in the repo — broken reference in an agent definition.

set -e

REPORT_FILE="${1:?Usage: check_07_harness_scaffolding.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 7: Harness scaffolding review
# ────────────────────────────────────────────────────────────────

SCAFFOLD_DETAILS=""

# Exempt scripts: library helper, the deep scan shim/dir, audit writer.
_is_exempt_script() {
  case "$(basename "$1")" in
    _check_lib.sh|deep_scan.sh|write_audit.sh) return 0 ;;
    *) return 1 ;;
  esac
}

# H1: shell scripts not referenced anywhere meaningful
CHECKS_DIR="${TRADING_DIR}/devtools/checks"
AGENTS_DIR="${REPO_ROOT}/.claude/agents"
WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"
CHECKS_DUNE="${CHECKS_DIR}/dune"

for sh_file in "${CHECKS_DIR}"/*.sh; do
  [ -f "$sh_file" ] || continue
  _is_exempt_script "$sh_file" && continue

  script_name="$(basename "$sh_file")"
  found=false

  # Check in dune file
  if [ -f "$CHECKS_DUNE" ] && grep -q "$script_name" "$CHECKS_DUNE" 2>/dev/null; then
    found=true
  fi

  # Check in GitHub workflow YAMLs
  if ! $found && [ -d "$WORKFLOWS_DIR" ]; then
    if grep -rl "$script_name" "$WORKFLOWS_DIR" 2>/dev/null | grep -q .; then
      found=true
    fi
  fi

  # Check in other *.sh files in the same directory (source/call chain)
  if ! $found; then
    for other_sh in "${CHECKS_DIR}"/*.sh; do
      [ -f "$other_sh" ] || continue
      [ "$other_sh" = "$sh_file" ] && continue
      if grep -q "$script_name" "$other_sh" 2>/dev/null; then
        found=true
        break
      fi
    done
  fi

  # Check in agent definitions
  if ! $found && [ -d "$AGENTS_DIR" ]; then
    if grep -rl "$script_name" "$AGENTS_DIR" 2>/dev/null | grep -q .; then
      found=true
    fi
  fi

  # Check in deep_scan/ per-check scripts (new location after decompose)
  if ! $found; then
    for sub_sh in "${CHECKS_DIR}"/deep_scan/*.sh; do
      [ -f "$sub_sh" ] || continue
      if grep -q "$script_name" "$sub_sh" 2>/dev/null; then
        found=true
        break
      fi
    done
  fi

  if $found; then
    SCAFFOLD_DETAILS="${SCAFFOLD_DETAILS}PASS: \`${script_name}\` — referenced\n"
  else
    add_warning "Harness scaffolding: \`${script_name}\` not referenced in dune, workflows, other scripts, or agent definitions"
    SCAFFOLD_DETAILS="${SCAFFOLD_DETAILS}WARNING: \`${script_name}\` — not referenced in dune, workflows, other scripts, or agent definitions\n"
  fi
done

# H2: OCaml linter binaries not wired into dune runtest
for linter_dir in "${TRADING_DIR}/devtools"/*/; do
  [ -d "$linter_dir" ] || continue
  linter_name="$(basename "$linter_dir")"
  # Only check directories with an OCaml executable (has a dune file with "executable")
  linter_dune="${linter_dir}dune"
  [ -f "$linter_dune" ] || continue
  grep -q '(executable' "$linter_dune" 2>/dev/null || continue

  # Extract the executable name from the dune file
  exe_name="$(grep '(name ' "$linter_dune" 2>/dev/null | head -1 | sed 's/.*name[[:space:]]*//' | tr -d '()[:space:]')"
  [ -z "$exe_name" ] && continue

  # Skip the checks dir itself (it has no executables, only shell scripts)
  [ "$linter_name" = "checks" ] && continue

  # Check if %{exe:../<linter_name>/<exe_name>.exe} appears in the checks dune
  if [ -f "$CHECKS_DUNE" ] && grep -q "${exe_name}[.]exe" "$CHECKS_DUNE" 2>/dev/null; then
    SCAFFOLD_DETAILS="${SCAFFOLD_DETAILS}PASS: \`${linter_name}/${exe_name}.exe\` — wired into dune runtest\n"
  else
    add_warning "Harness scaffolding: \`${linter_name}/${exe_name}.exe\` built but not referenced in \`devtools/checks/dune\`"
    SCAFFOLD_DETAILS="${SCAFFOLD_DETAILS}WARNING: \`${linter_name}/${exe_name}.exe\` — built but not referenced in devtools/checks/dune\n"
  fi
done

# H3: agent definitions referencing a harness script path that no longer exists.
# Only fires when the agent file explicitly mentions a devtools/checks/*.sh
# path.  Relative paths used in code-block examples (e.g. ../devtools/…)
# are normalised before the existence check so they don't produce noise.
if [ -d "$AGENTS_DIR" ]; then
  for agent_file in "${AGENTS_DIR}"/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name="$(basename "$agent_file")"
    # Extract paths matching *devtools/checks/*.sh from the agent definition.
    # grep -o emits one match per line; filter empty lines defensively.
    ref_paths="$(grep -o '[a-zA-Z0-9_./]*devtools/checks/[a-zA-Z0-9_.-]*\.sh' \
      "$agent_file" 2>/dev/null | sort -u || true)"
    [ -z "$ref_paths" ] && continue

    while IFS= read -r ref_path; do
      # Skip empty lines (defensive)
      [ -z "$ref_path" ] && continue
      # Normalize: strip leading "../" sequences and "trading/" prefix so
      # paths like "../devtools/checks/foo.sh" resolve from TRADING_DIR.
      norm_path="$ref_path"
      while echo "$norm_path" | grep -q '^\.\./' 2>/dev/null; do
        norm_path="${norm_path#../}"
      done
      norm_path="${norm_path#trading/}"
      # Try resolving from TRADING_DIR and from REPO_ROOT
      if [ -f "${TRADING_DIR}/${norm_path}" ] || \
         [ -f "${REPO_ROOT}/${norm_path}" ] || \
         [ -f "${REPO_ROOT}/trading/${norm_path}" ]; then
        : # path exists — no finding
      else
        add_warning "Harness scaffolding: \`${agent_name}\` references \`${ref_path}\` which does not exist on disk"
        SCAFFOLD_DETAILS="${SCAFFOLD_DETAILS}WARNING: \`${agent_name}\` — references missing path \`${ref_path}\`\n"
      fi
    done << EOF
${ref_paths}
EOF
  done
fi

flush_findings

if [ -n "$SCAFFOLD_DETAILS" ]; then
  printf "\n## Harness Scaffolding\n" >> "$REPORT_FILE"
  printf "Per-component audit (PASS = referenced/wired, WARNING = unused or broken reference):\n\n" >> "$REPORT_FILE"
  printf '%b' "$SCAFFOLD_DETAILS" >> "$REPORT_FILE"
fi
