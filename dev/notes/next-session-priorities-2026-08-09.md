# Next-session priorities — 2026-08-09 (evening)

**Supersedes** `next-session-priorities-2026-08-08.md` (its P0 — the
entry-ticket right-basis program — completed this session: audit fields
#2254, ladder v3 run + dissection, async-v2 plan #2255).

## What this session established

- **#2254** E-provenance audit fields (`close_at_decision`, `ma_value`,
  `local_range_top`) — merged through full gates; first real use in the
  ladder-v3 dissection worked as designed.
- **Ladder v3 verdict** (`dev/notes/ladder-v3-faithful-stoplimit-2026-08-09.md`,
  memory `project_faithful_ticket_structural_exclusion` ⭐): faithful
  StopLimit arms +262/+318% vs record +7,321%; the gap is the 15% gate
  structurally excluding crash-recovery monsters + backfill anti-selection.
  Three timing mis-mappings identified (stage clock at MA-cross not breakout;
  synchronous screen vs asynchronous GTC ticket; gate semantics that don't
  transfer across entry models).
- **Book review reframe**: §4.3 overhead grading + reward/risk mean the book
  itself would likely pass on AXTI at 2.71 — a faithful process may
  legitimately exclude the monsters. AXTI-capture is NOT a success criterion.

## P0 — execute `dev/plans/entry-ticket-async-v2-2026-08-10.md`

The reconciled plan (writer agent + adversarial book review, verdict
SOUND-WITH-AMENDMENTS, all folded in). Build order:

1. **PR-1 (F1 `entry_freshness_basis`)** and **PR-2 (F3 `stop_width_mode` +
   nearest-floor anchor arm)** — independent, dispatchable in parallel.
2. **PR-3 (F2 TTL + re-screen cancel)** then **PR-4 (F5
   volume-confirm-at-fill)**. PR-4 is **blocked on a pre-build TODO**: verify
   the source book's low-volume-breakout sell passage and add it to
   `weinstein-book-reference.md` §4.2/§4.7 with a chapter cite (the distilled
   doc lacks the explicit sentence; needs the actual book).
3. PR-5 audit fields, PR-6 ladder-v4 scenarios (+ commit the v3 scenario
   sexps from `.sweep-output`/scratchpad for reproducibility).
4. Ladder v4 per plan §5 — predictions pre-registered; if fills don't drop or
   composition doesn't shift, stop and re-dissect (no knob-search).

## P1 — mechanism-retirement workstream (context-dilution control)

User concern 2026-08-09: rejected/nonfunctional mechanisms accumulate as
default-off flags + docstrings + code paths + tests and dilute context
(`weinstein_strategy_config.mli` ~1,450 lines, much of it dead-mechanism
docstrings). Deletion is SAFE by construction — a never-promoted
`[@sexp.default no-op]` flag is bit-identical to remove (R1), and goldens +
full gates prove it. What's missing is the protocol:

1. **Rule addition** to `.claude/rules/experiment-flag-discipline.md`: a
   mechanism with a terminal ledger REJECT marked do-not-revive is removed
   (flag + code + tests) after it has sat unused for N sessions; the ledger
   entry is the durable record. Distinguish from REJECT-as-default-but-
   legitimate-axis (keep).
2. **Flag inventory**: table of every `Weinstein_strategy_config` /
   `stops_config` / screener mechanism flag × ledger verdict × keep/retire
   call. Graveyard candidates from memory: `early_admission` (do-not-revive),
   stage3 `hysteresis` knob, `harvest_rotate`, scale-in v2 continuation-add,
   `macro_bearish_trim`, weekly-close stop, vol-scaled stop, `cash_reserve`.
   Keep-as-axis: `early_stage2_max_weeks` values, breadth-preset knobs,
   declining-MA gate, decline-character trio (screens blocked on data, not
   rejected).
3. **First trim PR(s)**: mechanical removals off the inventory, one mechanism
   per commit, goldens green = proof. Route through full gates (not
   docs-only). `stop_anchor_at_entry_base` joins the list only after ladder
   v4 (it's referenced by v3 history and the plan's retirement note).

This can run as a code-health/feat dispatch parallel to P0 — it touches
different files than PR-1/PR-2 except the config .mli (serialize config
edits).

## Not blocking / context-on-demand

- Ladder-v3 artifacts: `.sweep-output/ladder-v3-artifacts/` (w4/w13 trades +
  audit + faithfulness report). w8 killed by user decision (no marginal info).
- Warehouse `/tmp/snap_top3000_dedup_v5thin_adj` (1.3G) — verify before any
  re-run (ephemeral /tmp).
- Audit caveat: `ma_value` in trade_audit is adjusted-basis vs raw close/E —
  basis mismatch for close-vs-MA consumers; small follow-up candidate.
- V12 position_id join for resting-order arms (carried from 08-08 doc).
- FARM 2004 duplicate trades.csv rows w/ 879% stop_fill_distance outlier
  (split/corrupt-bar class, 4-5 rows) — low-priority data follow-up.

## State at handoff

Main green; #2247, #2254, #2255 merged. Working copy on main. No stray
worktrees, no running sweeps, 58G free. Memory index compacted 55KB→15KB
(entries preserved, annotations trimmed).
