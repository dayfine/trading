#!/bin/sh
# Cancel cohort from trade_audit.sexp — the artifact side of
# dev/plans/ticket-funding-2026-08-16.md step 2 (G1 / #2348 made this possible).
#
# One row per PLACED ticket: symbol, placement date, cascade score/grade, and
# how it resolved (filled at age N / cancelled at age N for reason R / still
# resting). Reads only the FIRST symbol of each audit record — the ones inside
# `alternatives_considered` are other candidates, and counting them is the
# 2026-08-16 artifact error (memory: feedback_always_dissect_before_reporting).
#
# Usage: sh dev/experiments/ticket-funding-cohort-2026-08-18/cohort_from_audit.sh <trade_audit.sexp>

SEXP=${1:?usage: audit_cancel_cohort.sh <trade_audit.sexp>}

awk '
  function flush(   ) {
    if (sym != "") printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", \
      sym, edate, score, grade, (cage == "" ? "-" : cage), \
      (creason == "" ? "-" : creason), (fage == "" ? "-" : fage)
    sym = ""; edate = ""; score = ""; grade = ""
    cage = ""; creason = ""; fage = ""; in_rec = 0
  }
  /\(\(entry$/ { flush(); in_rec = 1; next }
  in_rec && sym == "" && /\(symbol / {
    s = $0; sub(/.*\(symbol /, "", s); sub(/\).*/, "", s); sym = s
  }
  in_rec && edate == "" && /\(entry_date / {
    d = $0; sub(/.*\(entry_date /, "", d); sub(/\).*/, "", d); edate = d
  }
  in_rec && score == "" && /\(cascade_score / {
    v = $0; sub(/.*\(cascade_score /, "", v); sub(/\).*/, "", v); score = v
  }
  in_rec && grade == "" && /\(cascade_grade / {
    v = $0; sub(/.*\(cascade_grade /, "", v); sub(/\).*/, "", v); grade = v
  }
  in_rec && cage == "" && /\(ticket_age_weeks_at_cancel / {
    v = $0; sub(/.*\(ticket_age_weeks_at_cancel /, "", v); sub(/\).*/, "", v); cage = v
  }
  in_rec && creason == "" && /\(cancel_reason / {
    v = $0; sub(/.*\(cancel_reason /, "", v); sub(/\).*/, "", v); gsub(/"/, "", v); creason = v
  }
  in_rec && fage == "" && /\(ticket_age_weeks_at_fill / {
    v = $0; sub(/.*\(ticket_age_weeks_at_fill /, "", v); sub(/\).*/, "", v); fage = v
  }
  END { flush() }
' "$SEXP" > /tmp/_tickets.tsv

N=$(wc -l < /tmp/_tickets.tsv | tr -d ' ')
echo "placed tickets (audit records): $N"
[ "$N" -gt 0 ] || exit 0

echo
echo "== resolution =="
awk -F'\t' '
  { if ($6 != "-") c[$6]++; else if ($7 != "-") filled++; else unresolved++ }
  END {
    printf "  filled                : %d\n", filled + 0
    for (r in c) printf "  cancelled %-34s: %d\n", r, c[r]
    printf "  neither (still resting / not enriched): %d\n", unresolved + 0
  }' /tmp/_tickets.tsv

echo
echo "== funding-rejection cohort by cascade grade (vs all placed) =="
awk -F'\t' '
  { all[$4]++; if ($6 == "entry_fill_rejected_by_portfolio") rej[$4]++ }
  END { for (g in all) printf "  %-8s placed=%-6d rejected=%-5d (%.1f%%)\n",
          g, all[g], rej[g] + 0, 100 * (rej[g] + 0) / all[g] }' /tmp/_tickets.tsv | sort

echo
echo "== rest-time before the funding rejection (weeks) =="
awk -F'\t' '$6 == "entry_fill_rejected_by_portfolio" { print $5 }' /tmp/_tickets.tsv \
  | sort -n | awk '{ a[++n] = $1; s += $1 }
      END { if (n == 0) { print "  none"; exit }
            printf "  n=%d mean=%.1f p10=%d p50=%d p90=%d max=%d\n",
                   n, s / n, a[int(.1 * n) + 1], a[int(.5 * n) + 1], a[int(.9 * n) + 1], a[n] }'

echo
echo "== calendar clustering of funding rejections (by year) =="
awk -F'\t' '$6 == "entry_fill_rejected_by_portfolio" { print substr($2, 1, 4) }' \
  /tmp/_tickets.tsv | sort | uniq -c | sed 's/^/  /'

echo
echo "  per-ticket rows: /tmp/_tickets.tsv (sym date score grade cancel_age reason fill_age)"
