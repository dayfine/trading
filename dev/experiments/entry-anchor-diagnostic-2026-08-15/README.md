# Entry-anchor diagnostic — 2026-08-15

Does fixing the **stop** side admit AXTI, or is the **entry anchor** the binding
constraint? Gates defect A in `dev/plans/entry-anchor-and-ttl-2026-08-15.md`.

> ## ⛔ Both of this file's original conclusions were wrong. Corrected 2026-08-16.
>
> The answer the diagnostic actually gives is **the stop is the binding
> constraint, not the entry anchor** — i.e. defect A is refuted for every arm
> here. Full derivation:
> `dev/notes/entry-anchor-defect-a-refuted-2026-08-16.md`; the zero-fill thread
> is resolved in `dev/notes/ticket-death-on-cash-2026-08-16.md`. The original
> text is kept below, struck through, so the error is legible.

## Result — corrected

Real top-3000 universe, real 15% gate, window 2024-01-01..2026-06-26, salt 0.
All three arms carry `entry_anchor_local_range_weeks 4` and
`freeze_entry_at_first_breakout true`; they differ **only on the stop side**:

| arm | stop config | AXTI tickets placed | AXTI fills |
|---|---|---|---|
| `d2-core` | `Window_extreme` | **0** (`Stop_too_wide`) | 0 |
| `d2-nearfloor` | `Nearest` | **0** (`Stop_too_wide` ×4) | 0 |
| `d2-nf-anchor` | `Nearest` + `stop_anchor_at_entry_base` | **1** | 0 |

E is **2.71 in all three arms**. `stop_anchor_at_entry_base` is the flag that
admits AXTI, and it is the only difference between the arm that placed a ticket
and the arm that did not. `d2-nearfloor` alone does **not** admit it — the two
stop flags are different mechanisms.

BFX is absent from the top-3000 universe, so it cannot be screened here at all —
only the record arm, on a different universe, ever saw it.

## The two errors

1. ~~"Stop-side fixes raise admissions 1 → 4 → 5."~~ Those counts are
   `grep -c AXTI trade_audit.sexp`, which also counts rows where AXTI appears
   inside some *other* ticket's `alternatives_considered`. Real ticket counts
   (`grep -c '(symbol AXTI) (entry_date'`) are **0 / 0 / 1**.
2. ~~"E = 2.71 here vs E = 4.05 in the full-history run; the only difference is
   how far back the anchor window could see."~~ At
   `entry_anchor_local_range_weeks = 4` the anchor is the max high over **4
   weekly bars**, which cannot reach a pre-crash high and is identical in a 26y
   and a 2.5y run — verified bit-identical on `suggested_entry`,
   `local_range_top`, `ma_value` and `installed_stop` across four shared
   tickets. The 4.05 figure comes from an arm where the knob is **0** (its
   default), where E falls back to the resistance `breakout_price`. The
   comparison was armed-vs-unarmed **config**, mislabelled as
   long-window-vs-short-window.

## ~~⚠ Open thread~~ — RESOLVED 2026-08-16

~~A ticket resting at E = 2.71 from 2025-06-27 ... should have filled — and did
not, in any arm.~~ It **did** trigger, on ~2025-08-22, and the engine filled it
at 2.7475 — inside the 2.7642 do-not-chase cap, so `entry_extension_max_pct` was
not the cause. The **portfolio** then rejected the fill for cash (needed
\$124,039, had \$16,531) and the ticket was destroyed with no artifact trace.
See `dev/notes/ticket-death-on-cash-2026-08-16.md`.

## The first attempt failed by design — recorded so it is not repeated

`specs/two-symbol.sexp` is from that attempt. Two errors:

1. **A 2-symbol universe does not reproduce the decisions.** Ranking, sector RS
   and the macro gate all behave differently with 2 symbols instead of 3,000; the
   decision dates came out entirely different. The candidate-universe soundness
   argument (#2311/#2319) only holds when *every* symbol that ever became a
   candidate is retained.
2. **Widening `max_stop_distance_pct` to 0.99 disabled the mechanism under
   test.** `stop_anchor_at_entry_base` fires only when the floor stop *exceeds*
   the gate, so at 0.99 it never triggered — the anchor arm came out
   byte-identical to nearfloor.

It did establish one real thing: **`Nearest` is not uniformly tighter than
`Window_extreme`** — tighter on AXTI 2025-12-19 (26.22% vs 28.65%), *deeper* on
BFX 2020-01-10 (27.37% vs 2.08%). That complicates the "nearfloor fixes
crash-recovery stops" reading and deserves its own look.

## Reproducing

Specs in `specs/`. Run each against the pinned worktree with
`--snapshot-dir /tmp/snap_top3000_dedup_v5thin_adj --parallel 1`; ~10 min per arm.
