# exit-lever-surface-2026-09-04 — the record convention's exit mechanisms, one knob at a time, on the fixed basis

Third chain on the fixed exit basis (post #2648), after
`record-rebase-2026-09-03` (the null) and `stop-width-surface-2026-09-03`.
The record-rebase README names this as the next chain: every exit-side
mechanism the record convention arms — laggard rotation, stage-3 force-exit,
the extension stop — was validated on the defective simulator (stale
Friday-open exit fills, entry-bar stop-outs), and
`project_lever_reads_invert_on_fixed_sim` says every such verdict is suspect.
The clock (`entry_order_max_rest_weeks`) rides along because the record pins
it at 0 while main's default is 52 (#2587), and its 08-27/09-01 cells were
also pre-fix.

## Design

- **Build `e4984c5fe`** (pinned worktree `sweep-lever0904`) — the SAME build as
  the two prior chains, so their nulls are reused, not re-run:
  salt 0 = `record-rebase-2026-09-03/results/rec5y-{2019,2000}-new-s0-*`;
  salts 1, 2 = `stop-width-surface-2026-09-03/results/sw5y-{2019,2000}-b1.0-s{1,2}-*`.
- **Arms** — the record spec with the window swapped and ONE line changed
  (`specs/`, diffed against `record-rebase-2026-09-03/specs/rec5y-*-new.sexp`):

  | arm | change | record value |
  |---|---|---|
  | `lagoff` | `((enable_laggard_rotation false))` | true, hysteresis 2 |
  | `s3off` | `((enable_stage3_force_exit false))` | true, hysteresis 1 |
  | `extoff` | `extension_stop_config` trigger 0.0 / trail 0.0 (the no-op) | 2.0 / 0.25 |
  | `clock52` | `((entry_order_max_rest_weeks 52))` | 0 (GTC-forever pin) |

- **Cells**: 2019–23 × top-3000-2019 and 2000–04 × top-3000-2000, salts
  {0,1,2} — 24 arm cells, the two windows of one arm 2-concurrent
  (`chain.sh`, `chain.log`). Warehouse `/tmp/snap_top3000_dedup_v5thin_adj`
  (2000 vintage: A/B valid within a cell; the 2019 window's LEVEL is
  survivor-tilted — `project_warehouse_vintage_coverage`).
  `SNAPSHOT_CACHE_MB=1024 --no-emit-all-eligible --parallel 1`.
- **Every read is ex-monster**, via `dissect.sh NULL.csv ARM.csv` (join
  `symbol|entry_date`; validated digit-for-digit against the stop-width
  README's salt-0 2019 pair): shared-trade drift, null-only and arm-only
  cohorts, top trades per cohort, exit-trigger histogram.

## Pre-registered decision rule (written before the first cell landed)

For each arm, per salt and window, the primary statistic is the **ex-monster
realised delta** (arm − null after removing any single trade that is > 50% of
|Δ| and present in only one arm) plus the **shared-trade drift**.

- An arm "wins" a window if it beats the null ex-monster in **≥ 2 of 3 salts**
  and is never badly dominated (no salt where it loses more than the window's
  null-to-null salt spread) and maxDD is not worse by > 5pp at the majority of
  salts.
- **Win on BOTH windows → escalate** to a 26y salt-0 confirmation arm against
  `rec26y-new-s0` before any change to the record convention.
- **Win on ONE window → regime-dependent dial** (the stop-width shape); record
  it, keep the record convention as is.
- **Win on NEITHER → the mechanism survives the fix** (for the three `*off`
  arms: the record keeps it; for `clock52`: the record keeps its 0 pin and
  main's 52 default stays a separately-justified maxDD lever).

What the arms mean: for `lagoff` / `s3off` / `extoff` an arm win says the
record's mechanism was paying only on the defect; a null win says it earns
its place on honest fills. `clock52` reads the other way — an arm win says
the main default is at least neutral on the record convention.

## Results

_(filled in as cells land — `chain.log`; raw per-arm `actual` / `params` /
`summary` / `trades` under `results/`)_

### Interim — lagoff, 2019–23, salt 0 (15:41 PDT): the +97pp is ONE NVDA hold, unrealised

| arm | return % | trades | sharpe | maxDD % | realised $ | unrealised $ (open) | stops / laggard / s3 |
|---|---:|---:|---:|---:|---:|---:|---|
| null (`rec5y-2019-new-s0`) | 3.02 | 184 | 0.118 | 30.33 | −68,074 | +111,331 | 129 / 53 / 0 |
| lagoff | 100.06 | 97 | 0.732 | 32.94 | +22,842 | +985,205 (5 open) | 91 / 0 / 4 |

`dissect.sh` on closed trades: shared 70, drift **−$180k** (the null's laggard
exits took profits the arm later gave back to a stop — AUDC +28k → −8k, CHDN
+28k → +7k, POOL +24k → +12k); null-only 114 trades −$301k (STMP −171k, but
also NVDA +117k, AN +94k, CPT +51k — laggard exits that *were* the profit);
arm-only 27 trades −$30k. Realised delta only +$91k (−$80k ex-STMP).

The return gap is **unrealised**: the arm's open book at 2023-12-29 is
NVDA 2020-04-06 (1,988 sh @ 66.51 → 495.22) **+$852k**, MSTR 2023-11-13
+$78k, PKG +$22k, R +$18k, PAA −$6k. The null entered the same NVDA
position on the same day and laggard-rotated it out on 2020-11-30 for
+$117k; the arm, with no rotation, simply never sold it. Ex-NVDA (removed
from both arms) the arm is +$235k ahead on equity, of which STMP is +$171k;
ex-NVDA-ex-STMP ≈ +$64k with shared drift running −$180k against it — a
mixed read, not a lever. Per the pre-registered rule this cell's headline is
a monster and does not count; whether the arm wins ex-monster is what salts
1–2 and the 2000–04 window are for.

Note for the mechanism read: laggard rotation's realised channel
(`project_trade_forensics_2026_06_12`: "laggard rotation = profit channel")
is intact on the fixed basis — 53 rotations, +$180k on the shared cohort —
but its cost is the occasional ejected future monster, and on this window
that one eject is worth more than every rotation combined.

### Interim — lagoff, 2000–04, salt 0 (15:45 PDT): the rotation earns its place, ex-monster

| arm | return % | trades | sharpe | maxDD % | realised $ | unrealised $ | stops / laggard / ext |
|---|---:|---:|---:|---:|---:|---:|---|
| null (`rec5y-2000-new-s0`) | 76.64 | 98 | 0.655 | 28.36 | +622,371 | +158,240 | 74 / 19 / 3 |
| lagoff | 19.67 | 70 | 0.294 | 28.29 | +151,503 | +51,670 | 67 / 0 / 2 |

Equity delta **−$577k**. Shared 66 trades drift **−$169k** — the rotation sold
WNC 2003-05-09 at +$271k (2004-03-01) where the arm held it to a stop at
+$155k (2004-10-26), BEC +12k → −36k, BSC +15k → −5k: in this tape the
rotation exits *at the top*. Null-only 32 trades **+$276k** — IPIXQ +256k
(extension stop) and CNX 2000-06 +142k are entries the null could fund
because rotations released the capital; the arm's 4 unique entries lost
−$26k. Ex-IPIXQ (the only lopsided monster) the arm is still **−$320k**.
maxDD flat. The rotation survives the fix on this window at salt 0 with the
opposite sign to 2019–23 — same regime split as the stop width, and for the
same structural reason: in 2000–04 the things you hold instead of rotating
go down.

### Interim — s3off, both windows, salt 0 (16:07 PDT): stage-3 force-exit is INERT on the record convention

| window | null | s3off | Δ | fires in null |
|---|---|---|---:|---|
| 2019–23 | 3.02 / 184 / 0.118 / 30.33 | **3.02 / 184 / 0.118 / 30.33** (digit-for-digit) | 0 | 0 |
| 2000–04 | 76.64 / 98 / 0.655 / 28.36 | 75.99 / 98 / 0.652 / 28.37 | −$6k realised | 1 (CRE_old 2000-06-12: +15k force-exit → +10k stop three days later) |

98/98 shared on 2000–04, every other trade identical to the dollar (two
sub-$100 sizing ripples). With hysteresis 1 the mechanism fires 0–1 times
per five-year window on the record convention: the stop and the laggard
rotation take every position out before a Stage-3 streak forms. Not a
lever in either direction; its salts-1/2 cells are kept for completeness
(expect the same).

### Interim — extoff, both windows, salt 0 (16:31 PDT): the extension stop is the blow-off catcher, and only 2000–04 has blow-offs

| window | null | extoff | Δ realised | ext fires in null |
|---|---|---|---:|---|
| 2019–23 | 3.02 / 184 / 0.118 / 30.33 | **3.02 / 184 / 0.118 / 30.33** (digit-for-digit) | 0 | 0 |
| 2000–04 | 76.64 / 98 / 0.655 / 28.36 | 48.57 / 94 / 0.459 / 32.55 | **−$190k** (shared drift −$225k over 90) | 3 |

Every dollar is shared-trade drift — the same three positions, exited by the
2×WMA30 / 25%-trail extension stop in the null and by the ordinary stop or
rotation in the arm: APWR 2000-01-24 **+$89k → +$2k** (the dot-com blow-off
round-tripped in a week), IPIXQ 2004-04-03 **+$256k → +$184k**, and WNC sized
smaller in the arm (+$271k → +$235k) because the APWR giveback left less
cash. No lopsided monster (the IPIXQ entry is in both arms); maxDD
28.4 → 32.6. The mechanism fires only when a position runs to twice its
30-week MA — three times in the 2000–04 tape, never in the 2019–23 book —
so like the stop width it is a regime lever, but one whose off-state costs
money and drawdown wherever it fires. It survives the fix.

### Interim — clock52, 2019–23, salt 0 (16:56 PDT): MSTR again

| arm | return % | trades | sharpe | maxDD % | realised $ | unrealised $ |
|---|---:|---:|---:|---:|---:|---:|
| null (clock 0) | 3.02 | 184 | 0.118 | 30.33 | −68,074 | +111,331 |
| clock52 | 54.54 | 182 | 0.508 | **41.13** | +354,846 | +206,022 |

Shared 134 trades drift **−$129k** (STMP −171k → −259k on larger sizing);
null-only 50 trades −$101k; arm-only 48 trades **+$451k of which MSTR
2020-10-12 → 2021-03-01 extension-stop exit is +$561k** and TPL 2021-01
+$118k. Ex-MSTR the arm is **−$138k** realised (−$256k ex-MSTR-ex-TPL) and
its maxDD is 11pp worse. Same admission as the stop-width wide arm
(`stop-width-surface-2026-09-03`): cancelling ≥52-week tickets left the book
one slot lighter in the week MSTR broke out. The 2019–23 read of the clock
on the record convention is a lottery ticket, consistent with
`project_clock52_promoted` ("A = 26y salt-lottery").

### Interim — clock52, 2000–04, salt 0 (16:58 PDT): neutral

73.65 / 91 / 0.642 / 28.48 vs the null's 76.64 / 98 / 0.655 / 28.36.
Shared 85 trades drift −$4.5k; null-only 13 trades −$42k; arm-only 6 trades
−$33k; realised **+$5k**, unrealised −$35k (123k vs 158k open). The clock
removes seven low-value tickets and changes nothing that matters on this
window.

### Salt-0 summary (all four arms, both windows)

| arm | 2019–23 Δ equity | 2019–23 ex-monster | 2000–04 Δ equity | 2000–04 ex-monster | read |
|---|---:|---|---:|---|---|
| lagoff | +$970k | NVDA hold +$852k; ex-NVDA-ex-STMP ≈ +$64k, shared drift −$180k | −$577k | ex-IPIXQ −$320k, shared drift −$169k | rotation survives; 2019 is a lottery |
| s3off | 0 (identical) | never fires | −$6k (1 fire) | — | inert |
| extoff | 0 (identical) | never fires | −$283k | all shared drift (3 blow-off exits) | survives; regime lever |
| clock52 | +$515k | MSTR +$561k; ex-MSTR −$138k, maxDD +11pp | −$30k | neutral | lottery on 2019, neutral on 2000 |

**Chain trimmed after salt 0 (deviation from the design, recorded here):**
s3off (both windows) and extoff-2019 are dropped from salts 1–2 — a
mechanism that never fires produces the null digit-for-digit at every salt,
so those six cells would be copies of the existing nulls. Salts 1–2 run
lagoff (both windows), extoff-2000 and clock52 (both windows): 10 cells.

### lagoff, salt 1 (17:27 PDT) — the same two shapes

| window | null (b1.0-s1) | lagoff | Δ realised | shared drift | NVDA / WNC | unrealised null → arm | maxDD |
|---|---|---|---:|---:|---|---|---|
| 2019–23 | 22.90 / 184 / 28.41 | 111.44 / 96 / 33.26 | −$61k | −$182k (66) | NVDA 2020-04-06 open **+$857k** in the arm; +$119k rotated in the null | +143k → +1,083k | +4.8pp |
| 2000–04 | 55.52 / 94 / 19.56 | 19.01 / 70 / 28.59 | −$279k | −$173k (66) | WNC +$270k rotated → +$154k stopped; CNX +$142k null-only | +144k → +54k | **+9.0pp** |

2019–23: on closed trades the arm is behind at every level (realised −$61k,
shared drift −$182k); the headline is the unsold NVDA. 2000–04: the arm loses
on every line and carries 9pp more drawdown. Two salts in, laggard rotation
wins 2/2 on 2000–04 ex-monster and is a lottery ticket on 2019–23.

### clock52-2019 and extoff-2000, salt 1 (17:56 PDT)

| cell | null (b1.0-s1) | arm | Δ realised | shared drift | the trade(s) | maxDD |
|---|---|---|---:|---:|---|---|
| clock52-2019 | 22.90 / 184 / 28.41 | 54.36 / 182 / 41.44 | +$254k | −$66k (136) | **MSTR 2020-10-12 +$563k arm-only**; ex-MSTR **−$309k** | **+13.0pp** |
| extoff-2000 | 55.52 / 94 / 19.56 | 33.98 / 95 / 28.22 | −$187k | −$155k (91) | APWR +$90k → +$3k, BDLN +$34k → +$2k (blow-offs given back), WNC sized smaller | **+8.7pp** |

The clock's 2019–23 arm is nearly salt-invariant (54.54 / 54.36, 182 trades,
maxDD 41) because one position dominates its book, exactly the wide-stop
signature from `stop-width-surface-2026-09-03`. The extension stop's value
on 2000–04 is 2/2 and shows up in drawdown as much as return.

### lagoff-2019 salt 2 and clock52-2000 salt 1 (18:20 PDT)

| cell | null | arm | Δ realised | shared drift | the trade | unrealised null → arm | maxDD |
|---|---|---|---:|---:|---|---|---|
| lagoff-2019-s2 | 3.84 / 185 / 30.55 | 100.73 / 97 / 32.92 | +$85k | −$160k (68) | NVDA 2020-04-06 open **+$857k** (3/3 salts) | +112k → +990k | +2.4pp |
| clock52-2000-s1 | 55.52 / 94 / 19.56 | 53.64 / 86 / 19.56 | +$15k | −$3k (81) | none; 13 null-only −$44k, 5 arm-only −$26k | +144k → +109k | 0.0 |

Salt 1 complete. The 2019–23 lagoff arm is now NVDA-driven at all three
salts (+$852k / +$857k / +$857k unrealised) with shared-trade drift against
it at all three (−$180k / −$182k / −$160k). The clock is neutral on 2000–04
at two salts.

### 2000–04, salt 2: lagoff and extoff (18:45 PDT) — 3/3 each

| cell | null (b1.0-s2) | arm | Δ realised | shared drift | the trades | maxDD |
|---|---|---|---:|---:|---|---|
| lagoff-2000-s2 | 75.73 / 98 / 28.36 | 18.96 / 70 / 28.48 | −$469k | −$168k (66) | WNC +$270k rotated → +$154k stopped; null-only IPIXQ +$255k, CNX +$141k; **ex-IPIXQ −$214k** | +0.1pp |
| extoff-2000-s2 | 75.73 / 98 / 28.36 | 47.94 / 94 / 32.57 | −$187k | −$224k (90) | APWR +$90k → +$3k, IPIXQ +$255k → +$184k, WNC sized smaller | **+4.2pp** |

Salt-by-salt on 2000–04 the two mechanisms are near-invariant: laggard
rotation is worth +$320k / +$369k / +$214k ex-monster (realised + unrealised),
the extension stop +$190k / +$187k / +$187k — the same named trades every
time. Only the clock's salt-2 pair remains.

### clock52, salt 2 (19:06 PDT) — chain complete, 18 cells

| cell | null (b1.0-s2) | arm | Δ realised | shared drift | the trade | maxDD |
|---|---|---|---:|---:|---|---|
| clock52-2019-s2 | 3.84 / 185 / 30.55 | 54.36 / 182 / 41.38 | +$414k | −$117k (135) | MSTR +$562k arm-only; ex-MSTR **−$148k** | **+10.8pp** |
| clock52-2000-s2 | 75.73 / 98 / 28.36 | 72.65 / 91 / 28.50 | +$4k | −$5k (85) | none | +0.1pp |

## Verdicts (pre-registered rule, all salts)

Realised + unrealised, arm − null, ex-monster where a lopsided single trade
exceeds half of |Δ|; shared drift in parentheses.

| arm | 2019–23 s0 / s1 / s2 | 2000–04 s0 / s1 / s2 | rule outcome | what the record does |
|---|---|---|---|---|
| **lagoff** | raw +$970k / +$885k / +$969k = NVDA hold +$852k / +$857k / +$857k; ex-NVDA ≈ +$235k / +$147k / +$231k (drift −$180k / −$182k / −$160k); maxDD +2.6 / +4.8 / +2.4pp | −$577k / −$369k / −$469k; ex-IPIXQ −$320k / −$369k / −$214k (drift −$169k / −$173k / −$168k); maxDD 0 / +9.0 / +0.1pp | wins ONE window ex-monster (2019, on fewer re-entries), loses the other 3/3 on every line → **regime-dependent dial** | **keeps laggard rotation on** |
| **s3off** | 0 / — / — (never fires) | −$6k / — / — (one fire) | inert | keeps it; it is a no-op on this convention |
| **extoff** | 0 / — / — (never fires) | −$283k / −$217k / −$280k, all shared drift (−$225k / −$155k / −$224k); maxDD +4.2 / +8.7 / +4.2pp | loses 3/3 where it fires, never wins | **keeps the extension stop on** |
| **clock52** | +$515k / +$316k / +$507k = MSTR +$561k / +$563k / +$562k; ex-MSTR **−$46k / −$247k / −$55k**; maxDD **+10.8 / +13.0 / +10.8pp** | −$30k / −$20k / −$31k (realised +$5k / +$15k / +$4k) | wins NEITHER ex-monster; worse maxDD 3/3 on 2019 | **keeps the clock-0 pin**; see the flag below |

No arm cleared "win on BOTH windows", so no 26y confirmation ran and the
record convention is unchanged. **Every exit mechanism the record arms
survives the fixed basis** — the opposite of the arc's eject gate
(`project_lever_reads_invert_on_fixed_sim`), whose apparent value was the
defect. Their footprint is stable across salts because each one acts on
the same handful of named trades: WNC / APWR / IPIXQ / BEC in 2000–04, NVDA
/ MSTR / STMP in 2019–23.

### Why — the mechanism, decomposed

- **Laggard rotation is a top-seller in a bear tape and a monster-ejector
  in a melt-up.** On 2000–04 its shared-trade channel is +$170k every salt
  (it sold WNC at +$271k where the held position stopped at +$154k, and
  turned BEC/BSC/FLMIQ profits into stop losses when held) and the freed
  capital funded CNX and IPIXQ. On 2019–23 the same channel is +$160–182k,
  but the freed capital re-entered into a chop that lost −$290k (STMP,
  QGEN, BBVA …), and the one thing it rotated out of was the NVDA
  2020-04-06 ticket that, held, is worth +$852k unrealised. The rotation's
  cost is a monster tax; its benefit is exiting distribution before the
  stop does. Which dominates is the regime — the same split the 5.9% stop
  width showed (`stop-width-surface-2026-09-03`). Do not read the +97pp;
  read the two channels.
- **The extension stop is blow-off insurance.** It fired 0 times in the
  2019–23 book and 3 times in 2000–04 — APWR (+$89k → +$2k without it),
  BDLN, IPIXQ (+$256k → +$184k) — and each time the position gave most of
  the gain back within days. Its off-state costs money AND 4–9pp of
  drawdown wherever it fires. It is inert in a tape without parabolic
  moves, which is why the 2019 cells are digit-identical.
- **Stage-3 force-exit (hysteresis 1) never gets a turn.** The stop and
  the rotation take every position out before a Stage-3 streak forms; one
  fire in six window-salts. Not a lever; a dead knob on this convention.
- **The clock's 2019 headline is a book-slot effect.** Cancelling ≥52-week
  tickets left the book one position lighter in the week of 2020-10-12 and
  MSTR filled — the identical admission the wide stop produced. Ex-MSTR it
  loses at every salt and its maxDD is 11–13pp worse because that one
  position dominates the book. On 2000–04 it is a no-op (+$4–15k realised).

### ⚠ Flag for the clock-52 default (user decision item)

`project_clock52_promoted` rests the KEEP-52 decision on a **universal maxDD
win** measured on the pre-fix simulator with the default bundle. On the
fixed basis, on the record convention, the clock's maxDD is **worse by
10.8 / 13.0 / 10.8pp** on 2019–23 (MSTR concentration) and flat on 2000–04.
That is not the same base (the record pins several knobs the default does
not), so it does not overturn the decision — but the one property the
decision leans on has now inverted on one base. The default-config paired
re-measure (clock 0 vs 52 on the default bundle, fixed basis, 3 salts, both
windows) is the next chain before the 52 default is quoted as a drawdown
lever again.

### Forward guidance

- Exit-side reads on the fixed basis are now: eject gate (arc) = neutral;
  stop width = regime dial; stop anchor = one trade; laggard rotation =
  regime dial (keep); extension stop = keep; stage-3 force-exit = inert;
  clock = neutral-to-lottery. **The record's exit stack is settled.** The
  remaining gap vs the record is entry-side and top-of-funnel
  (`project_monster_funnel_top_of_funnel`), not exit plumbing.
- Every 2019–23 number here is on the 2000-vintage warehouse (32% of the
  2019 composition, survivor-tilted). A/B within a cell is valid; the levels
  are not. The 2019-vintage warehouse (built tonight) is the base for any
  re-run that needs a level.
- Read any arm that holds longer via `unreal.sh` — the return-vs-realised
  gap of a hold-longer arm lives in open positions, and `trades.csv` cannot
  see it (the lagoff arm's +97pp was invisible to the closed-trade join).
