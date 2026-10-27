# Codex vs Claude review agreement (issue #2905)

One row per PR that reached MERGE after a live advisory Codex review; appended by
`sh dev/scripts/codex_agreement_row.sh <PR> --append`. `agree` compares the Codex
verdict with the combined Claude verdict (rework if either gate said so). Read the
table monthly: the promotion path in `docs/howtos/codex_pr_reviews.md` becomes a
discussable option only after >= 20 rows with agree >= 90 % and no Codex-only
false rework (`.claude/rules/cross-agent-review.md`).

| date | PR | tip | struct | behav | codex | agree | codex-only items | claude-only items | codex tok in/out | note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-10-26 | #3429 | f7fa88444 | ok | ok | rework | no | 0 | 0 | 532360/3039 | Codex rework at every tip (3 rounds); rounds 1-2 matched behavioral rework; final-tip items (doc wording, scanner provenance) deferred to the SM build follow-up |
| 2026-10-26 | #3430 | 2c1ae3b41 | ok | ok | ok | yes | 0 | 0 | 270843/2085 |  |
| 2026-10-26 | #3435 | ee49b0b94 | ok | ok | ok@87ada4e6 (tip delta: 2 status lines) | yes | 0 | 0 | n/a |  |
| 2026-10-26 | #3445 | df3607fe7 | ok | ok | ok | yes | 0 | 0 | 256460/1147 |  |
