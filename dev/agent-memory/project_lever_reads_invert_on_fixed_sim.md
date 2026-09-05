---
name: project_lever_reads_invert_on_fixed_sim
description: "The 'fill-week eject gate is the whole 5y deficit' read (+48pp when off, 2026-09-02 ladder) was a D1/D2 artifact: on the fixed simulator (sim_exit_fill_next_open + stop_skip_entry_bar armed) eject-off ≈ base (−10.2% vs −10.4%, 2019-23 cell). Any exit-lever verdict measured before 2026-09-02 (stale Friday-open exit fills, entry-bar stops) is suspect and must be re-measured with the fixes armed."
metadata:
  type: project
  originSessionId: ea0190a3-7ee9-4a89-9d5b-89dfd6df71d3
  modified: 2026-09-03T03:46:27.866Z
---

**The observation (2026-09-02, `dev/experiments/arc-rerun-2026-09-01/`).**
On the defective simulator, arc vs arc-with-eject-off on the 2019–23 broad
cell: −24.4% → **+23.6%** (+48pp, ≈3× the cell's return null). On the fixed
simulator (both D1/D2 flags armed, build `94a8c6857`) the same flip:
−10.4% → **−10.2%** (+0.2pp). The lever vanished.

**Why.** D1 made every Friday-decided exit fill at Friday's OPEN, a price
that predates the decision; the arc's ejects (72% of all exits) were
systematically sold below what an honest Monday-open fill would fetch
(+$1.22M first-order, +$1.41M measured at 26y). So "hold instead of eject"
looked like +48pp of alpha when most of it was the defect's tax on the
eject leg. D2 (entry-bar stops) added churn on both arms. With honest
fills, ejecting the poke and re-entering later earns roughly what holding
does — and holding carries the larger drawdown (MaxDD 26% → 43%).

**Rule.** A lever that changes WHEN or HOW OFTEN positions exit cannot be
read on the pre-fix simulator. Every exit-mechanism verdict recorded before
2026-09-02 — eject on/off, stop width, laggard rotation timing, TTL/clock
cells, stop-anchor surface (#2408 sa2408), range-top freshness — was
measured with stale Friday-open fills on 100% of Friday-tick exits.
Their *relative* orderings may survive (both arms paid the tax) but any
lever whose arms differ in Friday-exit share was mis-measured. Re-run
before citing.

**What survives.** Entry-side reads that don't move exits (screen basis,
anchor window) and determinism/plumbing findings. The D3 *diagnosis*
(only 6–10% of fill weeks volume-confirm; first touch has no forward edge)
is a data fact, unaffected — what changed is its P&L attribution.

Related: [[project_saturday_stale_fill_defect]], [[project_edge_is_the_fat_tail]],
[[project_entry_cap_horizon_reversal]], [[feedback_run_the_null_control_first]].

**Grid verdict (2026-09-03 00:00, 3 windows × 4 arms on the fixed sim,
salt 0, ex-phantom realised):** eject-off is realised-neutral in 3/3
windows (−$119k→−$238k, +$222k→+$238k, +$82k→+$70k) with MaxDD worse in
3/3 → REJECT as a P&L lever; the 5.9% fallback stop wins 1 of 3 ex-monster
(g05 +$65k; g19's +$274k is one MSTR trade, g00 −$78k) → keep-as-axis;
both together = worst arm in 3/3. No lever cleared the pre-registered rule;
no 26y confirmation was run. The fixed arc's 5y realised is roughly flat to
mildly positive in every window (2000–04 +$222k with MaxDD 10.8%) — the
deficit vs the record is structural (what the ticket buys and when), not
the exit plumbing. Record: `dev/notes/arc-rerun-dissection-2026-09-01.md`
§5b.

**Record-side follow-up (2026-09-04):** the record convention's own exit
mechanisms (laggard rotation, extension stop, stage-3 force-exit) and the
clock were re-measured on the fixed basis at 3 salts × 2 windows —
[[project_exit_stack_survives_fixed_basis]]. Unlike the arc's eject gate,
they all survive (rotation and extension stop are regime dials worth
$200–370k on 2000–04; s3 inert; clock neutral-to-lottery). Exit-side
re-measurement is now complete: eject, stop width, stop anchor, rotation,
extension stop, s3, clock.
