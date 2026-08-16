---
name: project-entry-anchor-stale-e
description: "E is anchored to a year-old high, so measured risk is inflated and candidates are rejected on a number unrelated to real risk — but only where price sits near its MA; a 2.2x-MA parabolic is a correct rejection."
metadata: 
  node_type: memory
  type: project
  originSessionId: f38d1024-5259-467e-95cf-9aa2c8fe4ddb
  modified: 2026-08-16T01:54:41.473Z
---

`E = round2(entry_anchor × (1 + entry_buffer_pct))`, `entry_buffer_pct = 0.005`
(`screener.ml:29`). Risk is then measured **from E**, not from where the stock
trades: `(E − installed_stop)/E > max_stop_distance_pct (0.15)` → `Stop_too_wide`.

**AXTI 2025-06-27 — a false rejection.** E = 4.05 = **2.25× its own 30-week MA**
(1.801), from a pre-crash high. `installed_stop` 1.728 sits **just below the MA**
— exactly where the book puts it. Real risk 11-15%; recorded 57.33%. Ranked #1,
skipped **24 times**.

**BFX 2020-04-17 — a CORRECT rejection.** Close 5.05, 30w MA 2.298 → **2.20× the
MA** after doubling in one week. A book-placed stop below the MA would be 54%
risk; the "tight" 4.3488 stop is 4% under a one-week spike low with nothing
beneath it for 50%. The 15% rule is doing its job.

**The 30-week MA is the check that separates them** — pull it first. Two earlier
readings of these cases were wrong: the stop does NOT reach into a crash floor
(it is 4% under a recent swing low: BFX `4.53 × 0.96` from the decision bar
itself, AXTI `1.80 × 0.96` from four days earlier), and "the gate measures the
wrong thing" does not generalise from AXTI to BFX.

**Diagnostic (2026-08-15).** Real top-3000, real gate, 2024-2026: AXTI tickets
placed 1 (core) → 4 (`Nearest`) → 5 (`+stop_anchor_at_entry_base`), with **zero
fills in every arm**. Same decision under a 2024-start window yields **E = 2.71,
risk 2.1%, admitted** vs **E = 4.05, risk 57.3%, rejected** on full history — the
only difference is how far back the anchor can see. ⚠ The zero fills are
UNEXPLAINED (price rose through E within weeks); resolve before acting.

`stop_anchor_at_entry_base` re-anchors the **stop**, which in AXTI's case is
already correct — so it treats the wrong end.

Also: `Nearest` is **not** uniformly tighter than `Window_extreme` — tighter on
AXTI, deeper on BFX.

Plan: `dev/plans/entry-anchor-and-ttl-2026-08-15.md`. Dissection:
`dev/notes/ttl-and-record-dissection-2026-08-15.md`.
Related: [[project_entry_E_stale_high_bug]],
[[project_faithful_ticket_structural_exclusion]], [[project_edge_is_the_fat_tail]].
