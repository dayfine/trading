#!/bin/sh
# Verdict extraction for dev/reviews/*.md, shared by check_06 and its test.
#
# extract_heading_verdict <file>: prints APPROVED or NEEDS_REWORK (nothing if
# absent) from the LAST "## Verdict" heading. The verdict is the first token
# of the first non-blank line at or after the heading (text on the heading
# line itself counts), with markdown bold/backtick markers stripped. Only that
# one line is inspected, so a later prose mention never counts.
# A later "## Verdict" heading with no parseable verdict resets the result to
# none (fails safe: "could not extract", never a stale earlier verdict). The
# heading must end the word ("## Verdict: APPROVED" counts; "## Verdicts
# summary" and a glued "APPROVEDX" do not).
extract_heading_verdict() {
  awk '
    function tok(s) {
      gsub(/[*`]/, "", s); sub(/^[ \t:-]+/, "", s)
      if (s ~ /^APPROVED([^A-Za-z_]|$)/) return "APPROVED"
      if (s ~ /^NEEDS_REWORK([^A-Za-z_]|$)/) return "NEEDS_REWORK"
      return ""
    }
    /^##[ \t]+Verdict([ \t(:]|\r?$)/ {
      armed = 1; res = ""
      rest = $0; sub(/^##[ \t]+Verdict/, "", rest)
      t = tok(rest); if (t != "") { res = t; armed = 0 }
      next
    }
    armed && /[^ \t\r]/ { res = tok($0); armed = 0 }
    END { if (res != "") print res }
  ' "$1" 2>/dev/null
}
