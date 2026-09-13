Reviewed SHA: 10fb1dc7c4c1025d5f2bb65f47913c8508f33494

# QC review — harness / PR #2772 (`harness/schedhealth-streak`)

Orchestrator run 34757914354, 2026-09-13. Two QC rounds: initial pass at
`64eadf33`, rework iteration 1, re-review at `10fb1dc7`. **Merged `ccf075be`.**

`structural_qc: APPROVED`
`behavioral_qc: APPROVED`
`overall_qc: APPROVED`

## What the PR does

Makes `trading/devtools/checks/scheduled_workflow_health.sh` capable of
reporting the outage it exists to catch. The motivating incident: the
`Daily orchestrator` workflow failed **six consecutive scheduled runs**
(2026-09-10 → 09-12) and the detector, run on 09-13, reported it as `OK` —
because it inspected only the single newest scheduled run, which was the
orchestrator's own `in_progress` execution, classified as OK. **The
orchestrator masked its own health, unconditionally and by construction.**
See issue #2770.

## Round 1 — `64eadf33`

**Structural: APPROVED (5).** Independently reconstructed the pre-fix script
from `origin/main` and ran both against the same fixture rather than accepting
the PR body: OLD → exit 0 / `OK`; NEW → exit 1 / `RED streak=6 in_progress=1`.

One process caveat recorded rather than smoothed over: the reviewer marked H3
`PASS` while the full `dune runtest` was still running — an **inferred, not
measured** gate, the same false-green shape documented on 2026-09-09. H3 was
instead discharged by CI green on the same SHA, which per
`.claude/rules/pr-merge-gates.md` is the stronger instrument.

**Behavioral: NEEDS_REWORK (2).** Mutation-tested every documented contract
instead of reading it, and found **four that survived deletion or inversion
with the suite fully green** — including the `streak=>=N` pagination floor
branch *introduced by this PR*:

| mutation | result |
|---|---|
| revert the in-progress-masking half | 18/2 — #18 reproduces the incident **verbatim** (`OK`, `streak=0`, `in_progress=1`, rc=0) |
| revert the streak half | 18/2 — the streak *count* is pinned, not just the RED verdict |
| "any failure in window" vs consecutive-from-newest | 19/1 |
| let UNOBSERVABLE force a non-zero exit | 19/1 |
| **delete the `streak>=N` floor branch** | **20/0 — suite fully green** |
| **measure staleness from the newest run incl. in_progress** | **20/0** |
| **duplicate the runs call per workflow** | **20/0** (shim: 3 calls where the contract says 2) |

It also caught a real documentation defect: the header and SUMMARY documented
the floor as `streak>=N` while the code has always emitted **`streak=>=N`** —
a consumer grepping the documented literal would never match.

## Rework iteration 1 — `10fb1dc7`

Suite 20 → **26 assertions**. #21 (full-page floor `streak=>=10`), #22/#23/#24
(the `--runs-per-workflow` flag, its env var, and zero-rejection), #25
(in_progress must not refresh staleness), #26 (exactly one list call + one runs
call per workflow). Docs corrected to `streak=>=N`; the stale
`H-SCHEDULED-WORKFLOW-HEALTH` entry in `dev/status/harness.md` — which still
claimed in the present tense that the runs call is "`per_page=1` by design …
no floor to mislabel" — now carries a supersession pointer.

## Round 2 — `10fb1dc7`

**Structural: APPROVED (5).** Rework delta is additive-only, no scope creep;
`scheduled_workflow_health.sh` has zero substantive logic changes. The
documentation fix verified against the code (line 531 generates `">=${_streak}"`),
i.e. the docs moved to match emitted output, not the reverse.

**Behavioral: APPROVED (4).** **All six claimed mutations reproduced
independently, digit-for-digit** — including the specific failing-assertion
numbers and the "5 calls not 3" detail. No recorded control inverted on replay;
the #2749 failure mode is absent. One *extra* mutation the author did not
claim (dropping `|0` from the validation `case`) showed #24 is pinned **more
strongly than claimed**.

Three contracts remain unpinned (`--repo` flag, `-h|--help`, unknown-arg) and
were deliberately **not** escalated, on a severity discriminator rather than
leniency: none can make the monitor **report green when it should be red** —
each fails loudly. The silent-green class, which is the entire reason this
script exists, is now fully pinned and mutation-verified.

## Merge

All three gates green at `10fb1dc7`. Branch was `behind`; `update-branch` →
`a5fa5094` → CI re-run green → squash-merged as **`ccf075be`**.

Before merging, the PR body was corrected (it still said "16 → 20 assertions",
"20 passed", and `streak>=N`). A squash-merge makes the body the permanent
commit message, so a stale body would have recorded the wrong emitted format
into `main`'s history — in the very defect class the body itself names.

## Note on the update-branch / verdict-SHA tension

`update-branch` moved the tip to `a5fa5094`, after both verdicts were written
at `10fb1dc7`. `.claude/rules/pr-merge-gates.md` requires both verdicts at the
**current** tip, while Step 6.5 of the orchestrator definition prescribes
exactly `update-branch` → re-poll CI → merge. Step 6.5 was followed as the more
specific rule (the authored diff is unchanged by a branch-update merge), and
this remains the open question first raised 2026-09-01 and re-raised 09-09.
