---
name: project_clock52_promoted
description: "entry_order_max_rest_weeks 0→52 MERGED (#2587); predicate RUNS on default path but finds nothing — MEASURED empty over goldens (11/12 bit-identical), effect concentrates behind trigger-at-E; D-null (#2610) contests the value on return"
metadata: 
  node_type: memory
  type: project
  originSessionId: c11b2096-8ab9-4b27-9dc8-fd68436f65f5
  modified: 2026-08-31T18:22:49.433Z
---

`entry_order_max_rest_weeks` default 0→52 **merged 2026-08-31** (PR #2587,
ledger ACCEPT `2026-08-27-entry-rest-weeks-surface.sexp`, user "OK 52" on
#2405). Full three gates + paired-run-done.

**The transferable mechanism finding (corrected per qc-behavioral
5069567666 — do NOT say "dead code"):** the clock predicate RUNS on every
default-config tick (`enable_sim_entry_stoplimit` defaults true since
#2569) but finds nothing to cancel on the default path:
`sim_entry_trigger_at_suggested` defaults false → tickets trigger at the
current close, fill within a bar, never rest 52w. Paired goldens (12
cells, one build, `goldens-paired-2026-08-30.md`): **11/12
bit-identical** — a MEASURED emptiness over the golden set, not a
structural guarantee; only `sp500-2019-2023-armed-stoplimit` (the one
golden arming trigger-at-E) moved — −3.94pp in-band, maxDD unchanged,
dissected to admission reshuffle (both divergent cohorts net losers). The
entire 183pp surface effect lives behind
`sim_entry_trigger_at_suggested=true` (record-convention lineage). Live
path: tickets lapse weekly → no live effect.

**Grid state — AMENDED 08-31 (D-null ran, #2600/#2610):** the −39.1pp at
D salt 0 was the FLOOR: paired Δreturn = −39/−395/−310pp across salts
{0,1,2}, consistent-sign; the s0 sharpe win was a salt artifact (loses
2/3). **Only maxDD is composition-robust** (−6.8/−6.8/−8.0, matching
A/B/C). Under promotion-confirmation's "never badly dominated in ANY
cell", value-52 would NOT have cleared the grid with this table — the
promoted VALUE is composition-sensitive (breadth-dependent return cost,
robust risk reduction). Mechanism hypothesis: >52w resting tickets that
fill are crash-recovery monsters; at top-1000 the candidate pool is too
shallow to replace a cancelled monster ([[project_edge_is_the_fat_tail]]).
**Default decision OPEN (ASKABLE)**: revert to 0 / keep 52 / keep+require
record-convention specs to pin — safe to defer because the default-path
blast radius is empty. Cell B's own null: paired Δ +7.3/+6.5/+9.6pp every
salt (pairing worked there; at D it convicts instead).

**Book-check (tier-2 VERIFIED):** the book's only GTC-cancel criterion is
"cancel it if the pattern changes and you later change your mind" (Ch. 3
quiz ans. 5) — condition + discretion, NEVER elapsed time; weekly-lapse
actively refuted ("surprised two or three weeks later"). Write-back in
`weinstein-book-reference.md` §4.7. Time-based cancel = adaptation
defensible only at outer bound (52w ≈ 17× book's rest horizon); the
condition-based reading (weekly re-screen) was REJECTED at −137pp.

**Follow-up golden (#2601):** `weinstein-2019-armed-e` pins the trigger-at-E
configuration on broad — closing the coverage gap the paired table exposed
(the armed path had ONE 5y sp500 pin). Big incidental finding: **identical
config, salt and build returns 25.31% on the delisted-aware snapshot
warehouse but 79.2% on CI's committed test_data CSV subset** — a ~54pp
survivorship/data-basis gap on a 5y broad book ([[project_pit_survivorship_inflation]]
at committed-store scale). Never compare warehouse-basis experiment numbers
to CSV-basis golden numbers in either direction.

Ops notes that saved the day: paired-golden methodology "pin midpoint IS
the old arm" (±15%-around-actuals convention) validated by a direct w0
re-run matching digit-for-digit; the 3001-symbol `all_eligible` emission
scan burns HOURS after actual.sexp is written in ~9min — always pass
`--no-emit-all-eligible` (a pre-reboot run lost ~20h to it, [[feedback_announce_wait_duration]]).
Related: [[project_fill_model_inversion]], [[project_entry_trigger_decision]].
