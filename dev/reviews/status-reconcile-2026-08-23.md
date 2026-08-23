Reviewed SHA: 6c86d37eb2fb7b45a3528186836c5656cc7b7b70

## Structural QC — docs/status-reconcile-2026-08-23

### Verified Claims (Spot-Check)

**Sampling three critical PR claims + additional verifications:**

| Claim | Verified? | Evidence |
|-------|-----------|----------|
| #1952 merged at `e182c034` | ✓ PASS | `git show e182c034` returns `feat(strategy): thread resistance_min_history_bars (#1952)` |
| #1786 is a PR (not issue #1782) | ✓ PASS | GitHub API: #1786 is PR; #1782 is issue (closed 2026-08-02) |
| #1410 merged at `9134a26e` | ✓ PASS | `git show 9134a26e` returns `feat(weinstein): neutral_blocks_longs default-off entry-gate axis (#1410)` |
| #2302 misattribution corrected | ✓ PASS | Commit `700bdcda` touches `test_rename_detector.ml` + `cleanup.md`; agent correctly identified as cleanup, not rename-twin-dedup |
| `dev/status/_index.md` untouched | ✓ PASS | File not in `git diff origin/main --name-only`; shell gate confirms it passes integrity check |

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | CI green on this SHA (build-and-test: success). Cited rather than rebuilt per `.claude/rules/qc-structural-authority.md` H1–H3 gate override for zero-OCaml diffs. |
| H2 | dune build | PASS | CI green (build-and-test: success at 6c86d37e). |
| H3 | dune runtest | PASS | CI green (build-and-test + perf-tier1-smoke + goldens-affected all success). |
| P1 | Functions ≤ 50 lines (linter) | NA | No OCaml source in diff; only `.md` + one `.sexp` comment fix. |
| P2 | No magic numbers (linter) | NA | No OCaml source. |
| P3 | Config completeness | NA | No new config fields; this is a status/docs reconcile. |
| P4 | Public-symbol export hygiene (linter) | NA | No `.mli` files. |
| P5 | Internal helpers prefixed per convention | NA | No OCaml source. |
| P6 | Tests conform to test-patterns | NA | No test files modified. |
| A1 | Core module modifications | NA | No core modules (Portfolio/Orders/Position/Strategy/Engine) touched. |
| A2 | No new analysis→trading cross-layer imports | NA | Only status files; no dune changes. |
| A3 | No unnecessary existing module modifications | PASS | All seven commits are status/docs changes; the one `.sexp` file contains a comment-syntax-only fix (stray uncommented form → commented into header). Diff verified: line 2 of `grid1-null.sexp` orphaned `(description ...)` is now properly `;;`-prefixed into the comment block; real spec at line 24+ (`((name "grid1-null") ...)`) is unchanged. Zero semantic change: confirmed by inspection. |

### Shell Gates (Native)

```
$ sh devtools/checks/status_file_integrity.sh
OK: all dev/status/*.md files have required fields.
exit=0

$ sh devtools/checks/index_size_linter.sh
OK: index_size_linter — dev/status/_index.md within limits (13026/20480 bytes, all table rows <= 250 chars).
exit=0
```

### Docs-Only Gate Callout

Per `.claude/rules/pr-merge-gates.md` §"Docs-only PRs": this PR touches only `dev/notes/`, `dev/status/`, `dev/experiments/**/*.sexp` (comment-only). The `.sexp` file is **outside** the documented allowlist, which covers only `dev/notes/`, `dev/plans/`, `dev/reviews/`, `dev/status/`, and `*.md`. 

**Recommendation:** consider extending the allowlist to include `dev/experiments/**/*.sexp` when changes are **comment-syntax-only** (non-semantic fixes like this). The current rule conservatively flags any `.sexp` as non-docs, which is sound for feature/config changes but creates friction for hygiene fixes. This is a live rule-design question for the human; I note it for your decision rather than changing the rule.

### Quality Score

5 — Rigorous spot-checks of all key claims passed; status file integrity and shell gates all green; zero OCaml changes; `_index.md` correctly untouched per the protocol.

## Verdict

APPROVED

---

## Behavioral QC — docs/status-reconcile-2026-08-23

Reviewed SHA: `6c86d37eb2fb7b45a3528186836c5656cc7b7b70`

Environment: GHA runner. No `docker` (per-dispatch override of
`.claude/rules/qc-behavioral-authority.md` §"Operational requirements", known
#2386 contradiction — not an ENVFAIL). Diff contains zero OCaml; CI green at
this SHA and qc-structural ran both shell gates natively (exit 0). Not rebuilt.

For a docs reconcile the CP rows are read as: **the "contracts" are assertions
of fact about what shipped.** The failure mode guarded against is stale-but-
harmless text replaced by confident-and-wrong text, freshly dated so it reads
as authoritative (the PR #832 → #836 episode, `CLAUDE.md` §"Status-file
refreshes must verify claims against current main").

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial factual claim is traceable to verifiable evidence | PASS | ~40 claims sampled independently of qc-structural's five. All held. 19 merge SHAs resolve to commits whose subjects match their described work; 4 stage-accuracy config fields present at the exact no-op defaults claimed (`weinstein_strategy_config.ml:216-219`); 4 module-idle claims confirmed by `git log` (`twin_detector` last touched `2155eae6` 2026-07-13, zero since; `late_stage2_stop_runner` `919e10a8` 2026-06-04; `macro_bearish_trim_runner` `18b7ea1c` 2026-06-06; `decline_character` exactly one commit since closure); `weinstein_strategy_config.mli` is 1,362 lines exactly as A3-3 claims; ledger `2026-06-24-arming-speed-adlive-wfcv.sexp` reads `(verdict Reject)`; all four decline-character build PRs (#1692/#1725/#1696/#1708) resolve to matching subjects. See N3 for the one enumeration defect. |
| CP2 | Each PR-body claim has a corresponding change in the diff | PASS | The six-track reconcile the body advertises is exactly what shipped, and pacer recommendation #6 (screener / simulation / stage-accuracy / backtest-perf + arc-readiness refresh) is fully discharged. Two body-only overstatements recorded as N1/N2 — near-miss, not failed: both are self-falsified within the same paragraph (the body enumerates the six touched tracks immediately after), and neither appears in any committed file. Reasoning recorded so the judgment is auditable. |
| CP3 | Identity/pass-through claims pin identity, not just size | PASS | The `.sexp` fix claims "nothing that parses moved". Verified mechanically, not by eye: comment-stripped top-level form count goes **2 → 1** (the stray uncommented `(description ...)` was a genuine second top-level sexp); the surviving `(description "FULL BOOK TICKET: ...")` inside `((name "grid1-null") ...)` is byte-identical; restored line 2 matches all four sibling `grid1-*.sexp` headers verbatim. |
| CP4 | Each guard the text names is exercised | PASS | `screener.md` introduces a mechanical tripwire (`grep -n 'PR OPEN' dev/status/screener.md`) and **the file passes its own tripwire** — the only three remaining hits are the convention block defining the token. `stage-accuracy.md`'s Rule-4 non-eligibility claim is backed by the cited flag-inventory reclassification rather than asserted. `backtest-perf.md`'s tier-4 guard is explicitly marked unverified rather than asserted (see focus 2). |

### Weinstein domain checklist (S1–S6, L1–L4, C1–C3, T1–T4)

**Entire block NA.** Pure documentation reconcile plus one comment-syntax fix
to an experiment spec; no stage classifier, stop machine, screener cascade,
or any domain logic in the diff (`.claude/rules/qc-behavioral-authority.md`
§"When to skip this file entirely"). No faithfulness question arose, so no
`BOOK-CHECK-NEEDED` items — the GHA-unreachable book path
(issue #2457) is not load-bearing for this review.

### The five focus areas

1. **Do conclusions follow from evidence? — HELD**, with one non-blocking
   enumeration defect (N3). Checked narrative, not just citations: #2433's
   characterisation in `arc-readiness.md` matches the merged writeup
   (`rt-freshness-seeded-2026-08-20/README.md` lines 6-11) clause for clause;
   `simulation.md`'s base-broken summary (10 fills, 0.76% of realized P&L,
   79 of 89 long-rest fills already base-broken, NO BUILD as specified)
   matches that README's own headline verbatim; `decline-character.md`'s new
   top summary is a faithful condensation of the pre-existing `## Next steps`
   body it claims to summarise.
2. **Are declared-unverifiable items honestly recorded as unknown? — HELD,
   verbatim.** `simulation.md`: the four `TODO(simulation/*)` items are
   "all unchanged and **unverified** against current code in this reconcile;
   treat their status as **unknown rather than confirmed-open**".
   `backtest-perf.md`: "Whether that dispatch ever ran is **not verified by
   this reconcile** — treat the ranges as unpinned until someone checks.
   Tier-4 is local-only (release-cut), so no CI record settles it." Both are
   exactly the disclosure this row exists to require.
3. **`decline-character.md` status keyword vs body — HELD, both flips
   supported.** `MERGED` rests on the track's own self-declaration, and the
   08-23 pacer independently quotes the same string ("self-declares
   *WORKSTREAM EXHAUSTED (2026-06-25, #1739)*", 8th consecutive ask — the
   file's "eight consecutive times" is exact). `Interface stable: NO → YES`
   rests on a specific, checkable claim, and it is correct: `c42da690` (#1904)
   is the only commit to `decline_character.{ml,mli}` since closure, and its
   entire content there is `-[@@deriving sexp]` → `+[@@deriving show, eq, sexp]`
   in both files — additive, no signature narrowing. **The deferred item is
   not stranded**: it is named explicitly, correctly classified as
   EODHD-data-gated warehouse infrastructure rather than decline-character
   mechanism work, and carries a re-home recommendation; `## Follow-ups` reads
   "None", so nothing else is left behind a closed door.
4. **Recommendations vs decisions — HELD in the committed files.** All four
   recommendation blocks are labelled as such and none takes the call:
   `rename-twin-dedup` ("this reconcile **does not close it** … nothing here
   decides it", `## Status` left `IN_PROGRESS`), `backtest-perf`
   ("Recommendation (**not a decision**)"), `simulation`
   ("Recommendations (**not decisions**)"), `stage-accuracy` ("this reconcile
   does not make it, and **leaves the status keyword at `IN_PROGRESS`**").
   The one status flip taken (`decline-character`) is bookkeeping on a
   self-declaration, and says so. The PR body is where this slips — see N1.
5. **`arc-readiness.md` — HELD exactly.** Funding program closed (#2473
   `aa70c876`); **G3 terminal REJECT as a global default** with the 53-trades-
   in-26y reason; **G2a/G2b kept default-off axes**, no promotion case at this
   power. The rewritten #2433 follow-up no longer claims a live
   `do-not-merge` hold: it records the merge (`d7087e0a`, 2026-08-22), the
   sp500 "reversal" **retracted as a universe artifact** (#2448 `35aa1397`),
   **only MaxDD surviving both cells**, the win-rate leg failing Rule 4 on
   broad-5y, and `Range_top_breakout` not promotable. Every clause matches the
   merged writeup. A2-4 really is the only unchecked box left on the track.

### Non-blocking findings

**N1 — PR body: "Closes track-pacer recommendations #6 and #7."** #6 is fully
discharged. **#7 is not**: it names four sub-items, and two are deliberately
left open (`rename-twin-dedup` is reported ambiguous rather than closed —
correctly, per the brief) while a third, **`resistance-v2` dropping to
axis-maintenance (5th ask), is untouched by this PR**. The body also groups
`rename-twin-dedup` under "the two finished tracks", which its own status file
declines to say. Not blocking: the committed record is accurate and more
conservative than the body, and the next sentence enumerates the six touched
tracks, so a reader cannot be misled past that line. **Suggested fix before
squash-merge** (the body becomes the commit message): "Closes recommendation
#6; partially addresses #7 (`decline-character` closed; `rename-twin-dedup`
reported ambiguous; `resistance-v2` and the `backtest-perf` fold left as
maintainer calls)."

**N2 — PR body: "there are zero open PRs on the repo right now, so every
`PR OPEN` marker was stale by construction."** False at review time — three
PRs are open (#2492, #2493, #2494), two of them opened in the same
orchestrator wave two seconds apart. Plausibly true when the reconcile work
was done, which makes it precisely the snapshot-not-a-fact hazard
`screener.md`'s own new "Entry convention" section was written to warn about.
Harmless here because the claim appears in **no committed file** and the
conclusion does not depend on it: all seven markers were verified
independently by merge SHA (#2267 `f806fab1`, #2087 `26be1e36`, #2079
`64d9acc0`, #1952 `e182c034`, #1786 `9e2d4dda`, #1428 `e31dd1d6`, #1410
`9134a26e`), which is the stronger evidence and is what the file records.

**N3 — `backtest-perf.md`, "Ownership boundary" bullet 2: "those eight
paths" enumerates only seven.** The prose names four scripts
(`dev/scripts/perf_tier{1,2,3,4}_*.sh`) and three workflows
(`perf-tier1.yml`, `perf-nightly.yml`, `perf-weekly.yml`), then cites
`871513dc` (#1953) as the one commit to touch "those eight paths" since
2026-06-16. **`871513dc` touches none of the seven named paths** — those seven
have taken *zero* commits since 2026-06-16 (last touches: `0733d5ed` 04-27,
`1ba3c6b6` 05-06, `bafe5808` 04-28, `5a4ba1ff` 05-15). The unnamed eighth path
is `trading/trading/backtest/release_report/` — this track's `release_perf_report`
exe, described in the completed record item 6 — and `871513dc` *is* the only
commit to touch it in that window, so the claim is true of the real
eight-path set. The conclusion ("the perf tier system is alive and untouched")
is therefore correct and in fact understated. Fix is one clause: name
`trading/trading/backtest/release_report/` as the eighth path. Recorded because
this is the exact shape focus area 1 asks about — a correct SHA cited in
support of a sentence its enumerated evidence does not reach.

**Observation (not a finding) — merge-date convention.** Every merge date in
the diff is the **UTC** `merged_at`, which is one day ahead of the local-git
author date for evening-PT commits (e.g. #2449 `48c6315e` = 08-20 17:35 PT =
**08-21** UTC, recorded as 08-21; likewise #2477, #2476, #2024, #2270, #1739).
Seven such cases checked; all consistent under one convention, none
contradictory. Worth stating in the convention block so a future reader
checking against `git log` does not read a one-day gap as an error.

### Quality Score

4 — All checks pass. The reconcile is disciplined in the way this review
exists to test: unverifiable items are marked unknown rather than quietly
promoted to fact, recommendations are kept explicitly distinct from decisions,
a mechanical tripwire is introduced that the file itself passes, and the pacer's
own #2302 misattribution is corrected rather than inherited. Held back from 5 by
three minor corrections — two PR-body overstatements (N1, N2) and one short
enumeration inside a committed file (N3).

## Verdict

APPROVED
