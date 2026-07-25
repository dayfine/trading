# Next-session priorities — 2026-07-24

**Supersedes** `next-session-priorities-2026-07-23.md`. The 07-24 session
closed everything that doc queued: **M4 was already complete** (record PR
#2063 merged, leverage REJECT, ledger
`2026-07-24-margin-m4-leverage-surface`); **P1b regime-dependency
evaluation DONE** (memo `regime-dependency-evaluation-2026-07-24.md`, in
#2063); **tax lens Phase 1 SHIPPED** (#2066, three-gate merged); **P1
picks follow-ups SHIPPED** (#2067 renderer grade column + prefix strip;
#2065 sectors.csv + manifest — no 3h scrape was needed, cache was warm);
memory snapshot refreshed (#2069); stale ci-red watchdog #2031 closed.

> **07-24 PM user decisions (same day):** (1) leverage-dawn **BUILD
> green-lit** — mechanism build dispatched (`feat/leverage-dawn`,
> default-off + WF spec; surface run after merge); (2) tax Phase 2
> **parked**; (3) v3 warehouses **deleted** (~4.2G freed); (4) 07-10
> picks backfill **done** (`dev/weekly-picks/7827bd6f1/2026-07-10.*`,
> Bullish, 20 tied longs, 0 shorts) **+ new picks-execution program
> launched**: portfolio state file + fixed-risk sized trade
> instructions (`feat/picks-protocol`, Phase A+B in flight; Phase C =
> HTML report with per-candidate SVG charts, next PR). Sizing protocol
> answer of record: orders are NOT equal-sized — fixed-risk 1% per
> trade via `Portfolio_risk.compute_position_size`, capped 30%/position.

## ~~P0 — leverage-dawn surface design~~ decided: BUILD (see above)

The P1b memo's verdict: regime-conditional leverage is the ONLY payload
earning a designed WF-CV surface (realistic lagging dawn label keeps
~15× of the 46× hindsight bound; ⅔ of that is fold-010 alone; levered
eras carry 34-64% intra-fold DDs). **Do not build until the user
green-lights.** If green-lit, the design constraints are pinned in memo
§3: default-off regime-conditional `initial_long_margin_req` axis on the
lagging MA-flip-up-age signal; surface must include a milder rung (req
0.85-0.90); gate must score DD/Sharpe continuously across fold
boundaries; 2024 melt-up-lag fold = named falsifier; margin-armed by
convention.

## P1 — tax lens follow-ups (issue #2006 remains open)

- Phase 2 (in-sim April tax outflows, default-off) — only if Phase-1
  numbers change decisions; user call.
- Wash-sale adjustment (optional, deferred from Phase 1).
- Non-blocking: error-path test for `Loader.load_exn` (qc-behavioral CP4
  note on #2066).
- Corrected reference of record: m4p-baseline pre-tax $87.9M → after-tax
  **$31.2M** (CAGR 18.4% → ~13.9%); the earlier $26.9M was an eyeball
  error, corrected on #2006 (exe $31.18M + independent awk $31.15M agree).

## P1 — M4 follow-up issues (filed, unowned)

- #2057 margin exit labels missing from round-trip outputs (harness gap;
  blocks per-event force-cover ordering forensics).
- #2059 LH phantom-short + dup row in record basis — CONFIRMED again in
  the P1b screen (LH 2001→2024 8,459-day short −$388k; FARM 2004→2021
  +$350k same family; they roughly cancel but pollute short-sleeve
  attribution).
- #2060 mean-ADV entry gate spoofable (LINK −$1.58M specimen).

## P2 — carried

- Trader-preset bundle audit; floor-quality P1b step 3; decision_audit
  Phase-2.
- Lever (b) regime-softener stays a designed default-off axis (no build
  gate).
- v3 warehouses (`snap_top3000_dedup_v3_sketch` 3.3G + sp500 851M)
  deletable on user OK.
- Optional prior-week picks backfill (as-of 07-10) if the user wants it.

## Operational notes (07-24)

- GHA runners hit **"No space left on device"** twice on PR #2067's
  build-and-test (link-heavy test exes) — both cleared on plain rerun.
  Signature: job dies in `dune build` with no `FAIL:` lines + no step
  conclusions. Treat as rerun-first before diagnosing.
- Merge-train friction: main's `strict` up-to-date requirement means
  every merge bumps the queue; arm `gh pr merge --auto` and
  `gh pr update-branch` sequentially — and NEVER chain the head-branch
  delete in the same command as the merge attempt (a blocked merge +
  executed delete auto-closed #2063; recovered by re-push + reopen).
- Docs-only PRs auto-merge fast and can jump ahead of slower code PRs
  in the train (#2069 landed before #2067, bumping it again) — arm
  auto-merge on the SLOW PR first, or expect an extra update cycle.
- QC agents ran git-only (explicit NO-JJ briefs) with no .jj incidents;
  4 QC verdicts + 1 re-verify delivered clean.

---

## Session-close addendum (07-24 PM) — state at handoff

**Merged today (PM half):** #2075 (07-10 backfill + decision record),
#2079 (ranked-mode LIVE arming — the #1782 code already existed on main
with grids REJECTing a backtest default-flip; #2079 arms
`(candidate_ranking Quality)` in live overrides only, fixing the
zero-overlap alphabetical artifact). #2078 (picks Phase A+B: portfolio
state + sized instructions) is **auto-merge armed with all three gates
green** (structural APPROVED after an A2 false-positive was overruled
with provenance evidence; behavioral APPROVED at tip b4256740e after a
dispatcher-added no-bars-fallback test) — should land on its CI cycle.

**P0 for next session — leverage-dawn B1 rework (iteration 1, in
flight, INTERRUPTED):** qc-behavioral on #2077 found the mechanism
never FUNDS (entry walk sizes levered but the simulator is constructed
at base req 1.0 and floor-rejects the increment — nothing ever hits
`long_margin_debit`, so interest/maintenance never price). The
endorsed fix: permissive-funding inversion (simulator at the levered
req for armed cells; dawn gates the ENTRY WALK, raising its req to 1.0
on non-dawn weeks). The rework agent hit its session limit mid-task;
its UNVERIFIED WIP (324 insertions, the redesign + tests) is salvaged
on branch `wip/leverage-dawn-b1-rework` (top of #2077's tip
d1416a0ee). Next session: inspect, verify (fmt/build/runtest + the
required end-to-end `long_margin_debit > 0` dawn-week pin), push to
`feat/leverage-dawn`, behavioral re-verify. Do NOT run the WF surface
until B1 is verified funded — the surface would measure a non-functional
mechanism.

**After #2077 lands:** user must edit `dev/weekly-picks/portfolio.sexp`
real cash (ships $100k placeholder, from #2078); then Phase C (HTML
report + per-candidate SVG charts, planned in
`dev/plans/weekly-picks-execution-protocol-2026-07-24.md`); then the
leverage-dawn WF surface run (~8-9h, sweep-hygiene applies).

**Ops notes (PM):** GHA runner disk-exhaustion flakes recurred (2×
#2067, cleared on rerun); QC false-positive precedent — A2 must check
diff-introduced deps, not the file's full dep list; agent session-limit
death is a new failure mode — salvage protocol = commit worktree WIP to
a `wip/*` branch + document on the PR.
