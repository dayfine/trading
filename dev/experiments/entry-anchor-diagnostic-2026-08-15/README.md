# Entry-anchor diagnostic — 2026-08-15

Does fixing the **stop** side admit AXTI, or is the **entry anchor** the binding
constraint? Gates defect A in `dev/plans/entry-anchor-and-ttl-2026-08-15.md`.

## Result

Real top-3000 universe, real 15% gate, window 2024-01-01..2026-06-26, salt 0:

| arm | AXTI tickets placed | AXTI fills |
|---|---|---|
| `d2-core` — `Window_extreme` | 1 | **0** |
| `d2-nearfloor` — `Nearest` | 4 | **0** |
| `d2-nf-anchor` — `Nearest` + `stop_anchor_at_entry_base` | 5 | **0** |

**Stop-side fixes raise admissions 1 → 4 → 5 and produce zero fills.**

On the exact 2025-06-27 decision the anchor arm gives **E = 2.71, risk 2.1% —
admitted**, against **E = 4.05, risk 57.3% — rejected** in the full-history run.
The only difference is how far back the anchor window could see: a 2024 start
cannot reach the pre-crash high. That is the sharpest evidence that E, not the
stop, is the binding constraint.

BFX is absent from the top-3000 universe, so it cannot be screened here at all —
only the record arm, on a different universe, ever saw it.

## ⚠ Open thread

A ticket resting at E = 2.71 from 2025-06-27, with AXTI first trading above 4.05
on 2025-09-16, **should have filled** — and did not, in any arm. Check
`entry_extension_max_pct 2.0` rejecting a fill that gaps past E, budget
starvation in the entry walk, or ticket supersession. **Resolve before acting on
A**; it may be a second, independent defect.

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
