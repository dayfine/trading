# Defect A does not gate AXTI — the anchor window is history-independent, and the stop is the binding constraint

Task 17 / queue position 3 of `dev/notes/next-session-priorities-2026-08-16.md`.
The answer is that **A, as scoped, is not a live defect for any ladder-v4 arm**,
and the diagnostic that was read as its "sharpest evidence" was measuring
something else. B moves up the queue; A shrinks to a promotion question.

## The claim under test

`dev/plans/entry-anchor-and-ttl-2026-08-15.md` and
`dev/experiments/entry-anchor-diagnostic-2026-08-15/README.md`:

> On the exact 2025-06-27 decision the anchor arm gives **E = 2.71, risk 2.1% —
> admitted**, against **E = 4.05, risk 57.3% — rejected** in the full-history run.
> The only difference is **how far back the anchor window could see**: a 2024
> start cannot reach the pre-crash high.

## It is refuted by construction, and then empirically

`entry_anchor_local_range_weeks = 4` — which **every** ladder-v4 arm sets, including
all three diagnostic arms — makes the entry anchor
`Stock_analysis.local_range_top`: the split-safe maximum high over the last **4
weekly bars**. Four bars ending on a given Friday are the same four bars whether
the run started in 2000 or in 2024. A window that short cannot reach a pre-crash
high; there is nothing for a longer history to change.

Measured rather than argued. Same symbol, same decision date, 26-year run
(`v4-00-core-w4`, 2000-2026) vs 2.5-year run (`d2-core`, 2024-2026), both at
`entry_anchor_local_range_weeks = 4`:

| | 26y run | 2.5y run |
|---|---|---|
| AAON 2025-10-17 `suggested_entry` | 106.13 | **106.13** |
| AAON 2025-10-17 `local_range_top` | 106.58 | **106.58** |
| AAON 2025-10-17 `ma_value` | 86.518784731182819 | **86.518784731182819** |
| AAON 2025-10-17 `installed_stop` | 91.670399999999987 | **91.670399999999987** |

Bit-identical, digit for digit, on every entry field — and likewise on ABT
2024-08-23, ADP 2024-02-09 and AEE 2024-05-17. **The armed anchor is
history-independent.** So E on AXTI 2025-06-27 was **2.71 in the 26-year run
too**, not 4.05.

Where 4.05 actually comes from: an arm where the knob is **0** (its default).
Then `Screener._build_candidate` falls back —
`entry_anchor = Option.value a.local_range_top ~default:breakout` — and
`breakout` is the resistance-derived breakout price, which can be years old.
That is the already-recorded `project_entry_E_stale_high_bug`
(`E = scan_max_high` 8-60 weeks back). The comparison was **armed-vs-unarmed
config**, mislabelled as **long-window-vs-short-window**.

## What actually gates AXTI

The three diagnostic arms differ **only on the stop side** — all three carry
`entry_anchor_local_range_weeks 4` and `freeze_entry_at_first_breakout true`:

| arm | stop config | AXTI tickets placed |
|---|---|---|
| `d2-core` | `support_floor_anchor_scope Window_extreme` | **0** (`Stop_too_wide`) |
| `d2-nearfloor` | `Nearest` | **0** (`Stop_too_wide` ×4) |
| `d2-nf-anchor` | `Nearest` + `stop_anchor_at_entry_base` | **1** |

(Ticket counts corrected — the README's 1 / 4 / 5 are `grep -c AXTI`, which also
counts rows where AXTI appears inside another ticket's
`alternatives_considered`. See `dev/notes/ticket-death-on-cash-2026-08-16.md`.)

E is identical across all three arms. **`stop_anchor_at_entry_base` is the flag
that admits AXTI**, and it is the only difference between the arm that placed a
ticket and the arm that did not.

The 26-year core arm says the same thing at scale: AXTI appears **29 times** in
`alternatives_considered` — **21 × `Stop_too_wide`**, 8 × `Insufficient_cash`,
**0 tickets** — all at E = 2.71.

**Under the v4 configuration the binding constraint on AXTI is the stop-width
gate, not the entry anchor.**

## Consequences for the queue

- **A is not a code defect for the v4 arms.** Its remaining true scope is: the
  *default* config leaves `entry_anchor_local_range_weeks = 0`, so a
  default-config run still anchors E on a possibly-stale `breakout_price`. That
  is a **promotion question for an existing default-off knob** — a confirmation
  grid per `promotion-confirmation.md`, not a fix. It is not urgent, and it is
  certainly not "impact: high, complexity: med, order 3".
- **B moves up.** The 15%-rule hard rejection is what excludes AXTI 21 times at a
  correct, fresh E. The book says *"prefer other candidates"*, not *"reject"*;
  turning it into a rank demotion is now the live lever for this whole cohort.
- **`stop_anchor_at_entry_base` deserves its own surface.** It is the one flag
  demonstrated to change AXTI's admission, and it has never been run as an
  experiment axis in its own right — nearfloor was, and just failed its grid
  (`dev/experiments/nearfloor-confirmation-grid-2026-08-16/results.md`).
  Note that these are different mechanisms: `d2-nearfloor` alone did **not**
  admit AXTI.

## A provenance trap worth fixing (the honest remainder of F)

With `freeze_entry_at_first_breakout` armed, the audit's `local_range_top` is the
**current** week's 4-week window top, while `suggested_entry` is the **frozen**
E pinned at an earlier week. They do not correspond:

```
AAON 2025-10-17:  suggested_entry 106.13  =>  anchor 105.60
                  local_range_top  106.58  <-  this week's window, NOT the anchor
```

Anyone inverting E from the audit (`E / 1.005`) and comparing it to
`local_range_top` will conclude the anchor is wrong when it is merely pinned.
AXTI 2025-06-27 happens not to show it (2.7 × 1.005 = 2.7135 → 2.71, an unpinned
first breakout), which is exactly why the trap went unnoticed. **Emit the frozen
anchor alongside the current window top.**

## Method note

The refutation cost one `grep` across two existing artifacts. The claim it
refutes had stood for a day and was ranked the third-highest-impact item in the
queue. Per `.claude/rules/mechanism-validation-rigor.md` the check that would
have caught it at the time is the estimand question — *is the quantity I am
comparing actually a function of the thing I am varying?* A 4-bar window is not a
function of run length, and that is knowable from the config before any run.
