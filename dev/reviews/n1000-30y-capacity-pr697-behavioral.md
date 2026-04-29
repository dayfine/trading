Reviewed SHA: 25885eaa7a3f6253eb6541e3d0fa4c51154699bf

# Behavioral QC — n1000-30y-capacity (PR #697)
Date: 2026-04-29
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | Pure docs/test-data PR — no .mli files added or modified. |
| CP2 | Each claim in PR body / note is supported by the artefacts and is internally consistent | PASS | Spot-checked the six load-bearing claims against the note; all consistent (see "CP2 spot-check" below). |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are, not size_is) | NA | No test code in this PR. |
| CP4 | Each guard called out in code docstrings has a test that exercises the guarded scenario | NA | No new code with guards; the curate script's guards (`set -euo pipefail`, exits on insufficient backfill, exits on dedup-size mismatch) are deterministic shell preconditions, not behavioural contracts requiring tests. |

### CP2 spot-check (six empirical claims from the user's review prompt)

1. **Peak RSS 6,328 MB** with `OCAMLRUNPARAM=o=60,s=512k`.
   - Claim location: note line 92 (table) and line 110 (prose).
   - Reproducibility: command spelled out in full at note lines 78–86 (raw `docker exec` invocation with `/usr/bin/time -v`). PASS, with one nit: the note does not route through `dev/lib/run-in-env.sh`, so the user's prompt-suggested cross-check ("verify via `dev/lib/run-in-env.sh` reproducibility section") doesn't apply. The raw `docker exec` line is itself fully reproducible. Not a blocker.
   - Unit nit: the table reports "6,328 MB" while prose says "6.18 GB" / "6.18 GB" (lines 37, 132, 245). 6,328 / 1024 = 6.18 GiB. The note conflates MB-decimal with MiB-binary in the units. Minor — not a numerical error, just labelling drift; flagged for awareness, not requiring rework.

2. **Wall 31:58.63 → super-linear vs 10y baseline.**
   - Verified arithmetically: 31:58.63 = 1,918.63 s vs 10y 4:26.65 = 266.65 s → 7.196× wall for 7,977/2,757 = 2.893× more days. Note states "7.20× wall for 2.89× more days" (lines 122, 128). PASS.
   - The super-linear framing is well supported by the major page faults jump (74 → 279,831 = 3,781×, line 125), which the note correctly attributes to VM-pressure paging.

3. **OOM on run #1 — default GC peaked at 6.96 GB, kernel-OOM-killed.**
   - Note lines 22–26 + 107–111 document this honestly. Numbers are internally consistent (6,953 MB / 7,936 MB ceiling = 87.6% before kill). PASS.
   - The note explicitly warns the next reader: "GC tuning is REQUIRED, not optional, for this cell at the current VM size" (lines 249–251). Honest framing — does not hide the failure.

4. **Docker Desktop VM ceiling ≈ GHA ceiling — framing as GHA-equivalent run.**
   - Note lines 13–17: "Docker Desktop VM ceiling is 7.75 GiB. ... identical in size to the GHA ubuntu-latest 8 GB ceiling — so the run is in fact a *GHA-equivalent* capacity test, not a full-host capacity test." PASS.
   - Note further calls out at lines 244–248 that "GHA ubuntu-latest feasibility at N=1000×30y" is "Marginal: peak 6.18 GB inside an 8 GB ceiling = 77 % utilization, with substantial paging. Probably runs but slowly." Honest pessimistic framing.

5. **Cohort dead-zone (8 trades, all entered 1996-01-06, all stopped out by 1997-03-20, 0 positions for ~28.7 years).**
   - Note lines 175–196 explain the mechanism: every symbol surviving 30 years is already deep in Stage 2 by 1996, so no Stage-1 → Stage-2 transitions remain for the screener to fire on. The few "stage-2-now-but-recently-1" candidates that did exist on 1996-01-06 stopped out under post-#682 tight initial stops.
   - Math check: 1996-01-06 → 1997-03-20 ≈ 14 months; 1997-03-20 → 2025-12-31 ≈ 28.78 years. Matches "~28.7 years" claim. PASS.
   - Diagnosis is causally coherent and consistent with Weinstein stage analysis (see weinstein-book-reference.md §Stage Definitions: a security in Stage 2 with rising 30-week MA is *not* a fresh entry candidate).

6. **macro_trend.sexp truncation — flagged as a new finding.**
   - Note lines 213–217: "The `macro_trend.sexp` artefact contains only weeks 1995-06-09 to 1996-01-05 (31 Bullish entries) — the post-warmup macro trend never gets persisted. This appears to be a separate issue with `Result_writer` / dump cadence; tracked here as a follow-up observation rather than blocking the capacity result."
   - Verified the module exists: `trading/trading/backtest/lib/macro_trend_writer.{ml,mli}` is present. Whether this truncation is a real bug is not in scope here — the note explicitly tags it as a follow-up observation, not a fix. PASS.
   - The note does NOT silently gloss over it: it appears in the "Observations" section as bullet 3, where future readers will find it.

## Behavioral Checklist (Weinstein domain rows)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | No core module changes (qc-structural confirmed A1=PASS; the diff is 4 new docs/data/script files, zero OCaml source modifications). |
| S1–S6 | Stage definitions / buy criteria | NA | Pure capacity-validation PR; touches no stage classifier, screener, or signal logic. The note explicitly disclaims strategy validation (lines 1–9, 151–158). |
| L1–L4 | Stop-loss rules | NA | No stop-loss logic touched. |
| C1–C3 | Screener cascade / macro / sector RS | NA | No screener / macro / sector code touched. |
| T1–T4 | Test coverage of domain transitions and assertions | NA | No test code in this PR. |

All Weinstein-domain rows are NA: this PR is a capacity-measurement note, a 1,000-symbol survivor universe, a scenario sexp explicitly marked `perf-tier: capacity-only`, and a deterministic shell script that builds the universe. None of it constitutes strategy logic, and the note (and the scenario sexp header) repeatedly emphasise that the run is NOT a strategy validation. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely": *"For pure infrastructure / library / refactor / harness PRs that touch no domain logic — the generic CP1–CP4 in the qc-behavioral agent file alone constitute the full review."*

The note's load-bearing message — *"capacity passes, strategy validation requires #696's historical-membership work"* — is consistently framed and never overstated. Specifically:

- The scenario sexp (`sp500-30y-capacity-1996.sexp`) opens with three explicit warnings: "perf-tier: capacity-only", "CAPACITY VALIDATION ONLY — NOT A STRATEGY VALIDATION", and "Do NOT add this cell to tier-3 or tier-4 perf workflows. Do NOT compare its return/drawdown to 'expected' values."
- The universe sexp (`broad-1000-30y.sexp`) header carries the survivorship-bias warning verbatim.
- The note opens (lines 5–9) and re-opens the strategy-metrics section (lines 153–158) with the same warning, and the Cohort dead-zone section (lines 175–196) provides a *causal* survivorship-bias diagnostic rather than a generic disclaimer.
- The "What this run does NOT establish" section (lines 225–251) is exhaustive: it explicitly bounds the claim to "GHA-equivalent VM-bounded capacity" and disclaims (a) strategy quality, (b) non-survivor capacity envelope, (c) full-host capacity envelope, (d) GHA feasibility (acknowledged as marginal), (e) GC-untuned envelope (acknowledged as required-not-optional).

The cross-reference to `dev/notes/historical-universe-membership-2026-04-30.md` is valid: that file landed via PR #696, which merged 2026-04-29 23:02 UTC. PR #697's merge will follow on a `main` that already contains it.

## Quality Score

5 — Exemplary capacity-validation note. The framing is honest about both successes (clean run, capacity envelope mapped) and limits (OOM at default GC, cohort dead-zone, marginal GHA feasibility). The cohort dead-zone diagnostic is a particularly strong piece of analytical hygiene — it preempts the obvious misreading of "this strategy lost money over 30 years" by causally connecting the survivor-cohort selection to the Stage-2-saturation mechanism. The arithmetic checks out everywhere I cross-multiplied. One minor unit-labelling nit (MB vs MiB) that does not affect any conclusion.

(Does not affect verdict. Tracked for quality trends over time.)

## Verdict

APPROVED

(All applicable items PASS or NA. CP2 spot-check PASS on all six empirical claims; the strategy-validation hedge is load-bearing and is consistently framed across all four files.)
