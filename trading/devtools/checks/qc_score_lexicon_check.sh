#!/usr/bin/env bash
# qc_score_lexicon_check.sh — warn-level quality-score digit/adjective
# mismatch check (H-QC-SCORE-ADJECTIVE-LEXICON).
#
# Filed from PR #2135's rework (qc-behavioral finding N3, 2026-07-27) as NEW
# scope, not built there. PR #2115's root cause was a literal digit/adjective
# mismatch — a quality score of 1 captioned "Excellent". Both QC agent
# definitions now state the score polarity explicitly and instruct the
# reviewing agent to self-check its own rationale's adjective against the
# digit before posting (H-QC-SCALE) — but that check is pure self-discipline
# with no mechanical backstop. This file is the backstop.
#
# Design constraints (dev/status/harness.md H-QC-SCORE-ADJECTIVE-LEXICON):
#
#   - WARN-LEVEL ONLY, never a hard failure. `qc_score_lexicon_warn` always
#     returns 0 regardless of what it finds. Its caller (record_qc_audit.sh)
#     invokes it for its stderr side-effect only and explicitly ignores its
#     return value too. This is a secondary backstop for a rare,
#     already-mitigated-by-instruction failure mode — not a primary gate. A
#     hard fail here would red main on nuanced rationale text, which is
#     worse than the mismatch it guards against.
#
#   - NARROW, curated lexicon. No sentiment analysis, no scoring, no
#     weighting — a short list of words that read as UNAMBIGUOUS in QC
#     review prose specifically. Deliberately excluded, because they are
#     ambiguous in this domain and would produce false positives that train
#     readers to ignore the warning (and then the real mismatch — the #2115
#     shape — gets ignored too):
#       - "critical"  — "critical bug" reads bad, but "critical path" /
#                        "critical section" is neutral engineering
#                        vocabulary that shows up constantly in this
#                        codebase's own domain prose.
#       - "sound"      — "sound design" reads good, but "a sound assumption
#                        that turned out to be wrong" inverts it mid-sentence.
#       - "fine"       — near-universally a hedge or a sign-off-with-caveat
#                        ("it's fine, but ..."), not a genuine positive.
#       - "good"       — too common and too weakly-valenced on its own
#                        ("good test coverage", "good faith effort") to be a
#                        reliable positive signal; the rubric's own label for
#                        score 4 uses it, but as ordinary prose it appears in
#                        both positive and neutral/hedged sentences.
#     The two lists below are intentionally short. Extend them only with
#     words that are similarly unambiguous — narrow-on-purpose.
#
#   - SCOPED TO THE QUALITY-SCORE RATIONALE LINE, never the full review
#     body. qc-behavioral.md's own Quality Score contract documents the
#     output as "N — <brief rationale (1-2 sentences)>" on the first
#     non-blank line after the `## Quality Score` heading — this check only
#     ever scans that one extracted line, via
#     `qc_score_lexicon_extract_rationale_line` below, never the Findings /
#     Checklist sections of the review. The backlog item's own named
#     false-positive risk ("a negative word inside a quoted finding") is a
#     property of a review's FINDINGS section, not its one-line Quality
#     Score rationale — scoping to the rationale line avoids that class of
#     false positive by construction, not by detecting quotation marks.
#     We deliberately do NOT special-case a rationale line that itself
#     quotes a finding verbatim (e.g. `5 — Exemplary; only nit: the
#     docstring said "wrong" instead of "invalid" in one error message`) —
#     on an already-narrow, warn-only surface, added quote-detection logic
#     would cost more maintenance than the false positives it would avoid.
#     If this fires on a quoted-rationale false positive in practice, that
#     observation is the trigger to revisit this paragraph, not a reason to
#     add the special case pre-emptively.
#
# Extraction reuses record_qc_audit.sh's own quality-score parsing shape
# (same "## Quality Score" / "### Quality Score" heading match, same
# "skip blank lines then take the next line" rule, same leading-"**"
# bold-stripping, same "last section wins" precedence for a multi-pass
# rework file) rather than inventing a second, divergent parser — see
# `qc_score_lexicon_extract_rationale_line` below. It is intentionally a
# separate function, not a shared refactor of record_qc_audit.sh's own
# heavily-hardened awk blocks (see that script's "Extract quality score"
# section for the edge cases those blocks already carry the scar tissue
# for) — this avoids touching code with 50+ pinned regression scenarios
# to add a feature that only needs the same 6-line shape.
#
# Usage (sourced, not executed standalone):
#   . qc_score_lexicon_check.sh
#   rationale="$(qc_score_lexicon_extract_rationale_line "$SOME_TEXT_BLOB")"
#   qc_score_lexicon_warn "$DIGIT" "$rationale"   # prints WARN to stderr or nothing; always rc=0

# Positive lexicon — words that read as unambiguously "high quality" in QC
# review prose. Curated from the backlog item's own examples ("excellent",
# "exemplary", "clean") plus close, similarly unambiguous synonyms.
QC_LEXICON_POSITIVE_WORDS="excellent exemplary flawless impeccable outstanding pristine clean"

# Negative lexicon — words that read as unambiguously "a real defect" in QC
# review prose. Curated from the backlog item's own examples ("significant",
# "fundamental", "wrong") plus close, similarly unambiguous synonyms; both
# "significant" and "fundamental" also appear verbatim in qc-behavioral.md's
# own score-1 rubric label ("Significant issues" / "Fundamental domain logic
# errors"), so a score-1 rationale legitimately using them is the CORRECT
# polarity, not a mismatch — see qc_score_lexicon_warn's digit gating below.
QC_LEXICON_NEGATIVE_WORDS="significant fundamental egregious broken unacceptable wrong"

# qc_score_lexicon_extract_rationale_line <text-blob>
#
# Returns the rationale line (bold-stripped) following the LAST
# "## Quality Score" / "### Quality Score" heading found in <text-blob>,
# taking the first non-blank line after it — same rule record_qc_audit.sh
# uses to extract just the leading digit, extended here to return the
# whole line. Empty string if no such heading is found.
qc_score_lexicon_extract_rationale_line() {
  printf '%s\n' "$1" | awk '
    /^## Quality Score|^### Quality Score/ { in_qs=1; next }
    in_qs && /^[[:space:]]*$/ { next }
    in_qs {
      line=$0
      gsub(/^\*\*/, "", line)
      gsub(/\*\*[[:space:]]*$/, "", line)
      last_line=line
      in_qs=0
    }
    END { if (last_line != "") print last_line }'
}

# qc_score_lexicon_warn <digit> <rationale-line>
#
# Prints a "WARN: ..." line (plus the offending rationale) to stderr when:
#   - <digit> is 1 or 2 (a LOW score) and <rationale-line> contains a
#     positive-lexicon word, or
#   - <digit> is 4 or 5 (a HIGH score) and <rationale-line> contains a
#     negative-lexicon word.
#
# Digit 3 (the middle of the scale) never warns — there is no "should read
# positive" / "should read negative" expectation for a middling score, so
# there is no polarity to mismatch. A non-"1".."5" <digit> (empty, or an
# out-of-range value) also never warns here — record_qc_audit.sh's own
# 1..5 range validation (H-QC-SCALE) is the place that enforces range as a
# hard failure; duplicating that as a second, softer check here would
# blur which check owns which outcome.
#
# Always returns 0. This function is advisory-only by design (see file
# header) — callers must not branch on its exit status for anything other
# than "did the shell built-in itself error", which it structurally cannot.
qc_score_lexicon_warn() {
  local digit="$1"
  local rationale="$2"
  local word found=""

  case "${digit}" in
    1 | 2)
      for word in ${QC_LEXICON_POSITIVE_WORDS}; do
        if printf '%s\n' "${rationale}" | grep -qiw -- "${word}"; then
          found="${word}"
          break
        fi
      done
      if [ -n "${found}" ]; then
        echo "WARN: quality score ${digit} (low) rationale contains positive-lexicon word '${found}' — possible digit/adjective mismatch (H-QC-SCORE-ADJECTIVE-LEXICON)" >&2
        echo "  rationale: ${rationale}" >&2
      fi
      ;;
    4 | 5)
      for word in ${QC_LEXICON_NEGATIVE_WORDS}; do
        if printf '%s\n' "${rationale}" | grep -qiw -- "${word}"; then
          found="${word}"
          break
        fi
      done
      if [ -n "${found}" ]; then
        echo "WARN: quality score ${digit} (high) rationale contains negative-lexicon word '${found}' — possible digit/adjective mismatch (H-QC-SCORE-ADJECTIVE-LEXICON)" >&2
        echo "  rationale: ${rationale}" >&2
      fi
      ;;
    *)
      : # 3, empty, or out-of-range — nothing to check, see docstring above.
      ;;
  esac
  return 0
}
