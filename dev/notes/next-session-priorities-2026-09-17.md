# Next-session priorities — 2026-09-17 (supersedes 2026-09-16)

Written 11:35 PT 2026-09-16 at the end of the 09-15/16 session (00:08 PT 09-15 → 11:35 PT 09-16), before a `/clear`.
Main `03df2c2f8`, green. Container idle (207 MB), host free 73 GB, no agent worktrees, no chain running.

## State in one paragraph

The PIT top-3000 migration is complete (steps 1–6 merged) and **the record baseline is the PIT band**:
`a0-pit-null-s{0,1,2}-v11` on `_v11pit` (9,364 entries), **152 / 188 / 457 %** (salts 2/1/0), maxDD 40.6–53.0,
732–766 trades, V6 = 0 every salt (#2843; ledger `2026-09-15-pit-universe-record-baseline`; memory
`project_record_rebase_2026_09_15`). Every arm from now pairs against that band at the same salt, gated by
`validator_diff -check V6`. Levels are not comparable to the 2000-vintage 312 / 383 / 640. The drawdown dissection
(#2856, README §"Drawdown dissection", memory `project_pit_drawdown_2021_25_macro_veto`) found the band's NAV is one
episode — late-2021 peak → 2024/25 trough, −38..−53 % on every arm and both universes — and that the largest
universe-independent lever is that **`Macro.analyze`'s composite outvotes a Stage-4 primary index** (2022: SPX below
a falling 30-week MA all year, `trend` Bullish 25+ weeks → 126 entries, 82 % losers, −$0.8M/salt).

## Step 0 — the open-PR wave (do this first; `sh dev/scripts/pr_gate_status.sh`)

Five CI-green PRs opened by the orchestrator cron / Codex after the last gate wave; none reviewed by this session:

| PR | author | what | gate state at write time |
|---|---|---|---|
| #2851 | orchestrator | harness(dispatch): pin the disk-guard constant split uniquely | STRUCT ok → dispatch qc-behavioral |
| #2852 | orchestrator | harness(gate): pin N3 wrong-source projection mutation | dispatch qc-structural |
| #2853 | orchestrator | harness(gate): refuse to verify a stale-dated daily summary (#2850) | dispatch qc-structural |
| #2855 | Codex | fix(codex): constrain unattended pushes to current feature branch (closes #2793 — the option-2 helper) | dispatch qc-structural |
| #2857 | Codex | fix(orchestrator): share prior-summary timestamp lookup (closes #2835) | dispatch qc-structural |

Batch structural (≤ 3 agents), then behavioral, then merge. Briefs MUST carry the interpreter-discipline paragraph
(run suites as dune does, `sh <script>` INSIDE the container, `sh -n` output verbatim for any syntax claim — see
`memory/feedback_qc_false_positive_needs_tip_move`). Mutation-proven rework fixtures → apply dispatcher-side as
`fix(review): address QC rework iteration N (#PR)` and re-run both gates; patch PR-body counts via REST PATCH.
For #2855 check the `codex_push.sh` decision on #2793 (no args, `HEAD:refs/heads/<codex/* branch>` only, raw
`git push` → prompt, probes in the howto, AGENTS.md step 3).

## P0 — the experiment queue on the new band (after Step 0)

1. **Index-stage veto surface** — `experiment-gap-closing`, **pre-register before any cell runs**.
   - Book check first (tier 2, local; `.claude/rules/book-as-authority.md`): is the primary index's stage a veto
     on buying or one vote among the Ch. 8 gauges? Reference §2.1 calls it the "most important single indicator".
     Write the answer back to `weinstein-book-reference.md` §2.1 with chapter + short phrase.
   - Mechanism (default-off, `experiment-flag-discipline.md` R1/R2): `macro_index_stage_veto : bool
     [@sexp.default false]` in the macro/strategy config — a Stage-3→4 or Stage-4 primary index blocks long entries
     regardless of composite confidence; the composite keeps governing aggressiveness. Must be an
     `Overlay_validator` axis.
   - Surface: 3 salts vs `a0-pit-null-s{0,1,2}-v11`, `validator_diff -check V6` on every pair; criteria realised
     AND Calmar at ≥ 2 of 3 salts; the paired 2022 entry cohort (126 entries pooled, 82 % losers) is the mechanism
     read; also report 2008–09 and 2000–02 so a veto that helps 2022 is not bought with a slower 2009/2003 re-entry.
   - Cost: ~6.3 h per cell, one lane (single worker sits at 5.5–6.5 GB) → ~19 h for the arm; run from a pinned
     worktree with `chain-pit.sh`-style file logs; container-exclusive (no agents while it runs).
2. **#2823 twin-detector direct-edge fix** (`agent/claude`, feat-backtest/feat-data; `require_direct_match`
   default-off knob + hub guard; existing reports bit-identical). Needs the container → schedule around the
   surface (agents first, then launch the chain).
3. **#2839 PIT cell cost** — bit-identical only; profile first; membership pruning is out of scope (user, 09-15).
4. **Top-of-funnel screen** (breakout-gate width, top-N) — after the veto result; the dissection also showed
   ≥ +20 % winners fell from 10 % to 2 % of entries in 2022–25, so read this with the regime in mind.

## Codex queue

`ready-for-agent` + `agent/codex` at write time: #2835 and #2793 have PRs open (#2857, #2855) — gate them, do not
re-dispatch. Nothing else queued for Codex; #2837 / #2702 / #2634 closed by #2840 / #2842 / #2841. #2394 stays
`needs-info`. Candidates to hand Codex next if the queue is empty: file an issue for the `-twin-only` (closes-only)
mode of `build_snapshots` (a full-union twin scan OOMs; pairwise scans cost ~3.5 h) — harness-shaped, well-specified
in `memory/project_pit_chunked_twin_miss`.

## Carried / small

- L6 taxonomy (R7 two-meaning) — `dev/status/trade-audit.md` design item.
- Rule-4 hygiene, orchestrator D2 push, #2729 residuals: unchanged.
- `dev/status/_index.md` says steps 1–6 MERGED and the RED-weekly note cites #2841/#2842; the next weekly firing
  (Mon 09-21) is the first evidence the REST publish works.

## Decisions taken this session (user)

- Commit the 27 as-run PIT lists (done, #2843). Membership pruning of `_classify_all` is rejected: any speedup must
  be bit-identical (#2839). The index-stage veto goes ahead of top-of-funnel.

## Ops notes

- **One lane on `_v11pit`; `CELL_TIMEOUT=36000`**; the 6 h cap killed a cell at 96 % once.
- **Chunked warehouse builds miss cross-chunk twins** — run `step4/twin-scan/pair-scan.sh` before the first measured
  cell on any chunk-built warehouse; a full-union scan OOMs.
- Host state safe to delete now that everything is committed: `/tmp/pit-fetch/`, `/tmp/pit-run/`, `/tmp/twin-scan/`
  (keep `pit-v11-composition-as-run.tgz` only if you want a second copy), container `/tmp/sweeps/pit-null/`
  (trade_audit + equity_curve per cell — the only copies; 34 MB, keep), `/tmp/twin-scan/*` in the container. Keep
  `/tmp/snap_top3000_pit_v11pit` (the record's warehouse) and `.claude/worktrees/sweep-pit` (pinned @3a20f4987) until
  the veto arm has run — the arm should build its own pinned worktree off current main and pair against the
  committed band artifacts, not re-run the null.
- Codex's own worktrees under `.claude/worktrees/codex-*` are Codex's to remove (its step 6); leave them.
- `gh run list --branch main --workflow CI --limit 1` can return a stale row; read the CI run at `origin/main`'s sha.
- Host memory pressure killed two cheap background polls on 09-16 morning (Docker VM + Chrome + Codex's cycle);
  poll in the foreground with bounded loops (≤ 9 min per call) instead of `run_in_background`.
