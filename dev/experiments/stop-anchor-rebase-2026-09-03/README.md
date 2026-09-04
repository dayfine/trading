# stop-anchor-rebase-2026-09-03 — the #2408 surface re-measured on the fixed exit basis

The 2026-08-31 stop-anchor surface (`wip/sa2408-specs`, never PR'd:
`stop_anchor_at_entry_base` {off,on} × `initial_stop_buffer` {1.0, 0.98, 0.96,
0.92, 0.885}, 2019–23 × top-3000-2019, record-lineage cell-B base) read
**anchor-on × buffer 0.92 = +81 / +95 / +91% across salts 0–2 vs a
25 / 24 / 13% null** — the strongest "salt-robust" exit-lever read on record.
It was measured on the defective simulator (Friday-open exit fills, entry-bar
stop-outs; `project_lever_reads_invert_on_fixed_sim`), and a wider stop is
precisely the kind of lever whose arms differ in stop-exit share. This
experiment re-runs the identical 11 specs at ONE build on the fixed basis
(`e4984c5fe`, pinned worktree `sweep-record0903`; the specs pin neither
`sim_exit_fill_next_open` nor `stop_skip_entry_bar`, so they inherit the
shipped defaults) plus the same salt spreads (null and on-b0.92 at salts 1–2,
off-b0.98 at 1–2, on-b1.0 at 1).

`old-basis/` holds the 2026-08-31 actuals verbatim for the paired read; the
comparison of interest is **within this build** (surface vs its own null),
with old-basis → new-basis per arm as the "how much was the defect" column.

## Read-before-verdict (carried from the 08-31 README)

- Tail-touching lever: read max single-trade P&L and the tail decomposition,
  not the top line (`project_edge_is_the_fat_tail`); join arms on
  `symbol|entry_date` and separate shared-trade drift from cohort reshuffle.
- Salt 0 alone is a floor, not a verdict; the spreads are in the chain.
- Warehouse-basis numbers are not comparable to CSV-basis goldens; and the
  2019 window runs on the 2000-vintage warehouse (32% coverage) — A/B valid,
  levels survivor-tilted.
- The blind-judge question from #2389 (book trigger = "no nearby structure"
  vs flag trigger = "structure exists but far") must be settled before any
  promotion reading. This pass is measurement only.

## Results

_(filled in as cells land — `chain.log`)_

### Interim (2026-09-03 18:10 PDT, first 4 cells, salt 0)

| arm | old basis (08-31) | fixed basis (this run) |
|---|---:|---:|
| sa-off-b1.0 (null) | 25.31 / 182 / 0.35 / 27.0 | **9.30 / 179 / 0.19 / 36.6** |
| sa-null-dup | 25.31 (bit-identical) | 9.30 (bit-identical — determinism holds) |
| sa-on-b1.0 | −8.89 / 200 / −0.03 / 39.2 | 73.35 / 173 / 0.63 / 39.5 |
| sa-on-b0.92 | 80.93 / 177 / 0.68 / 34.2 | 55.59 / 180 / 0.54 / 36.6 |

The anchor flag changes the *entry cohort*, not just the stop: only 77 of
~175 trades are shared with the null. Dissection vs the null
(`symbol|entry_date`): shared 77 trades drift **−$78k** (slightly against
anchor-on); null-only 102 entries −$6k; **arm-only 96 entries +$594k, of
which DDS 2020-10-05 → laggard exit is +$665k** (BKE 2020-10-05 +$128k,
EAT +$80k next). For on-b0.92 the same DDS trade is +$496k of the +$398k
arm-only cohort. **The +64pp / +46pp over the null is one admitted monster**
— the anchored stop let DDS through the `Stop_too_wide` gate that the
null's structural floor rejected (or sized it to pass). The old-basis
ordering (b0.92 ≫ b1.0) has flipped (b1.0 > b0.92); the buffer axis is not
what moves this cell, the anchor's admission set is. Verdict deferred to the
salt spreads (on-b0.92 s1/s2, null s1/s2) and, per
`project_top500_composition_golden_is_gme`, to whether DDS survives them.

### Salt-0 surface complete for the buffer axis (18:45 PDT) — one trade carries the anchor

| buffer | anchor off (fixed basis) | anchor on (fixed basis) | anchor-on realised $ | DDS 2020-10-05 in that arm | anchor-on ex-DDS |
|---|---:|---:|---:|---:|---:|
| 1.0 (null) | **9.30** / 179 / 0.19 / 36.6 | 73.35 / 173 / 0.63 / 39.5 | +445,638 | +664,790 | **−219k** |
| 0.98 | 21.53 / 165 / 0.31 / 28.3 | 83.12 / 147 / 0.69 / 45.3 | +624,796 | +796,275 | **−171k** |
| 0.96 | −15.72 / 177 / −0.11 / 35.9 | 66.09 / 156 / 0.58 / 40.3 | +527,297 | +682,041 | **−155k** |
| 0.92 | 22.24 / 190 / 0.31 / 35.3 | 55.59 / 180 / 0.54 / 36.6 | +383,191 | +496,068 | **−113k** |

Null realised is −$75,597. **DDS 2020-10-05 → 2022-02-14 (a laggard-rotation
exit after 16 months) is present in every anchor-on arm and absent from every
anchor-off arm, and it is larger than each on-arm's entire realised P&L.**
Net of that one trade, anchor-on is *below* the null at every buffer. The
anchor did not improve the stop; it changed the admission set — the
E-anchored stop sits within `max_stop_distance_pct` (0.15) where the null's
support-floor stop did not, so DDS passes the `Stop_too_wide` gate only with
the anchor on. With the anchor off, the buffer axis is non-monotone (9.3 →
21.5 → −15.7), i.e. path noise around a flat lever.

**Read (pending the salt spreads):** on the fixed basis the #2408 surface is a
single-admission lottery, exactly the shape of `project_top500_composition_golden_is_gme`
and `project_funding_grid_monster_lottery`. The old-basis headline (on-b0.92
+81/+95/+91 across salts) survived salts because DDS was admitted at every
salt — the salt perturbs paths, not the gate decision. Any promotion reading
would have to argue the gate change is *systematically* right, which
requires the blind-judge question from #2389 and a second window, not this
cell.

### Why the old surface showed a "salt-robust" buffer effect — resolved

Old-basis trades (`wip/sa2408-specs` bookmark, `stop-anchor-surface-2026-08-31/results/`): `on-b1.0-s0` entered DDS on 2020-10-05
and exited **2020-10-06 for +$824** — an entry-bar stop-out (D2), the pre-fill
low of the entry day piercing the 4% stop; `on-b0.92` (≈11.7% width) survived
that bar and rode DDS to +$564k / +$564k / +$547k at salts 0/1/2 (b0.92 over b1.0 by
89.8 / 77.8 / 72.8pp — "robust" in sign, not in size). The salts moved paths
but never that first-day decision. **The old buffer "signal" was the D2 artifact interacting with one
monster**, not a property of stop width. With D2 fixed, every buffer keeps
DDS and the buffer axis is flat within path noise; the only thing the anchor
flag still does is *admit* DDS through the `Stop_too_wide` gate.

This is the cleanest instance yet of `project_lever_reads_invert_on_fixed_sim`:
a lever whose arms differed in entry-bar-stop exposure read as +60pp of alpha.

## Results — all 18 cells incl. the null-dup control (2026-09-03 17:33–20:09 PDT, `chain.log`)

Fixed basis, build `e4984c5fe`, 2019–23 × top-3000-2019, warehouse. Raw per-arm
`actual` / `params` / `summary` / `trades` under `results/`; old-basis actuals
under `old-basis/`.

| arm | salt | return % | trades | sharpe | maxDD % | realised $ | DDS 2020-10-05 |
|---|---:|---:|---:|---:|---:|---:|---:|
| off-b1.0 (null) | 0 | 9.30 | 179 | 0.187 | 36.56 | −75,597 | — |
| null-dup | 0 | 9.30 | 179 | 0.187 | 36.56 | −75,597 | — |
| off-b1.0 | 1 | 7.93 | 183 | 0.173 | 26.76 | −61,743 | — |
| off-b1.0 | 2 | −6.40 | 180 | 0.014 | 34.44 | −175,982 | — |
| off-b0.98 | 0 | 21.53 | 165 | 0.308 | 28.27 | +79,653 | — |
| off-b0.98 | 1 | 21.82 | 164 | 0.311 | 32.92 | +13,684 | — |
| off-b0.98 | 2 | 40.25 | 158 | 0.471 | 25.11 | +165,215 | — |
| off-b0.96 | 0 | −15.72 | 177 | −0.114 | 35.92 | −296,346 | — |
| off-b0.92 | 0 | 22.24 | 190 | 0.311 | 35.32 | +65,540 | — |
| off-b0.885 | 0 | 23.83 | 187 | 0.344 | 25.29 | +60,722 | — |
| on-b1.0 | 0 | 73.35 | 173 | 0.633 | 39.50 | +445,638 | +664,790 |
| on-b1.0 | 1 | 64.05 | 179 | 0.584 | 40.97 | +459,655 | +662,923 |
| on-b0.98 | 0 | 83.12 | 147 | 0.690 | 45.26 | +624,796 | +796,275 |
| on-b0.96 | 0 | 66.09 | 156 | 0.582 | 40.29 | +527,297 | +682,041 |
| on-b0.92 | 0 | 55.59 | 180 | 0.539 | 36.62 | +383,191 | +496,068 |
| on-b0.92 | 1 | 71.03 | 173 | 0.648 | 38.29 | +508,018 | +496,298 |
| on-b0.92 | 2 | 102.46 | 172 | 0.813 | 32.42 | +617,229 | +495,366 |
| on-b0.885 | 0 | 23.83 | 187 | 0.344 | 25.29 | +60,722 | — (bit-identical to off-b0.885) |

### Verdict on `stop_anchor_at_entry_base` — REJECT as a promotion candidate off this cell (keep as axis)

- DDS 2020-10-05 → 2022-02-14 is in **every** anchor-on arm at every salt
  (+$495k–$796k) and in **no** anchor-off arm; at buffer 0.885 (≈15%) the two
  arms are bit-identical, pinning the mechanism: the anchor acts only where it
  moves an entry across the `Stop_too_wide` gate.
- Ex-DDS, anchor-on realised vs the null at the same salt: −$37k / +$74k /
  +$298k (s0 / s1 / s2, on-b0.92) — sign-indeterminate, and its own spread
  ($335k) is three times the null's ($114k): there is no stable ex-DDS margin
  to read. The salt-robust +46 to +109pp headline is one admission that the
  path perturbation never touches.
- The old-basis "buffer 0.92 beats 1.0 at every salt" (by 89.8 / 77.8 /
  72.8pp) was D2 stopping DDS out on its entry bar at the narrow width (old on-b1.0: DDS held one day,
  +$824). With D2 fixed the buffer axis is flat under the anchor.
- A promotion case would have to show the *admission* change is systematically
  right (blind-judge #2389 on DDS-like names; ≥1 more broad window; ex-monster
  read), per `promotion-confirmation.md`. Not this cell.

### The one anchor-off finding worth carrying — the 5.9% fallback width

`off-b0.98` (fallback stop ≈ 5.9%, book band §5.3 ceiling) beats the null at
**3 of 3 salts**: realised +$79.7k / +$13.7k / +$165.2k vs −$75.6k / −$61.7k /
−$176.0k (**+$155k / +$76k / +$341k**), return +12.2 / +13.9 / +46.6pp,
trades 165 / 164 / 158 vs 179 / 183 / 180. Dissection vs the null per salt
(`symbol|entry_date`): shared ~105 trades drift ≈ **0** (+5.6k / +6.4k /
−6.8k); the same LOGI 2020-05 monster tops both arms; the edge is the null's
**unique** cohort — its unique cohort (70 / 75 / 79 trades, carrying the 19 / 31 / 26 extra
4%-stop exits: 112 / 122 / 115 stops vs 93 / 91 / 89) loses −$212k / −$125k /
−$358k, while the wider stop's
unique cohort loses −$63k / −$56k / −$10k (the extra stop exits themselves
are 19 / 31 / 26; the dollar figures are the whole 70 / 75 / 79-trade unique
cohorts). **No shared monster and the same direction at every salt** — with one
qualification: at salt 2 a single null-only loser, STMP 2021-07-30 (−$166k),
is 49% of the +$341k delta; ex-STMP the deltas are **+$155k / +$76k / +$175k,
still 3/3**. Mechanism = fewer whipsaw deaths at the book-band ceiling. This agrees
with the arc grid's `s6` "keep-as-axis" read (`arc-rerun-2026-09-01`) on a
different preset and window, and with `project_fallback_stop_half_book_band`.
Neighbours: 0.96 (7.8%, past the band) is −$296k at s0 — the effect is not
monotone in width, it is a band effect. **Next step:** a proper surface for
`initial_stop_buffer ∈ {1.0, 0.98}` (anchor off) on the record convention
across the 2000–04 and 26y windows, salts {0,1,2}, read ex-monster — the
first fixed-basis lever candidate that is not a lottery ticket.
