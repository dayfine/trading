# Codex vs Claude review agreement (issue #2905)

One row per PR that reached MERGE after a live advisory Codex review; appended by
`sh dev/scripts/codex_agreement_row.sh <PR> --append`. `agree` compares the Codex
verdict with the combined Claude verdict (rework if either gate said so). Read the
table monthly: the promotion path in `docs/howtos/codex_pr_reviews.md` becomes a
discussable option only after >= 20 rows with agree >= 90 % and no Codex-only
false rework (`.claude/rules/cross-agent-review.md`).

| date | PR | tip | struct | behav | codex | agree | codex-only items | claude-only items | codex tok in/out | note |
|---|---|---|---|---|---|---|---|---|---|---|
