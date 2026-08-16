---
name: project-stop-gate-not-entry-anchor
description: "With the 4-week anchor armed, E is history-independent and AXTI's E is 2.71 everywhere — the 15% stop-width gate, not a stale entry anchor, is what excludes the crash-recovery cohort."
metadata: 
  node_type: memory
  type: project
  originSessionId: f3803253-a181-4a9d-88bc-d6fadb39647f
  modified: 2026-08-16T07:52:04.705Z
---

**Defect A ("the entry anchor E goes stale") is refuted for every ladder-v4
arm.** Established 2026-08-16;
`dev/notes/entry-anchor-defect-a-refuted-2026-08-16.md`, PR #2350.

**The armed anchor cannot go stale.** `entry_anchor_local_range_weeks = 4`
(which every v4 arm sets) makes the entry anchor the split-safe max high over
the last **4 weekly bars**. Four bars ending on a Friday are the same four bars
whether the run started in 2000 or 2024. Verified, not argued: `suggested_entry`,
`local_range_top`, `ma_value` and `installed_stop` are **bit-identical** between
a 26-year and a 2.5-year run on AAON 2025-10-17, ABT, ADP and AEE.

So the plan's "E = 4.05 in the full-history run vs 2.71 in the short one — the
window could see further back" was **armed-vs-unarmed config mislabelled as
long-vs-short window**. 4.05 comes from an arm with the knob at its **0**
default, where `Screener._build_candidate` falls back to the resistance
`breakout_price` — the already-known [[project-entry-E-stale-high-bug]].

**What actually gates AXTI: the stop.** The three diagnostic arms differ *only*
on the stop side (all carry anchor=4 + freeze):

| arm | stop config | AXTI tickets |
|---|---|---|
| core | `Window_extreme` | 0 (`Stop_too_wide`) |
| nearfloor | `Nearest` | 0 (`Stop_too_wide` ×4) |
| nf-anchor | `Nearest` + `stop_anchor_at_entry_base` | **1** |

E is 2.71 in all three. At 26y scale the core arm shows AXTI **29 times** in
`alternatives_considered`: **21 × `Stop_too_wide`**, 8 × `Insufficient_cash`,
**0 tickets** — all at a correct, fresh E.

**Consequences.**
- A's remaining scope is a *promotion question* for a default-off knob
  (`entry_anchor_local_range_weeks = 0` by default), needing a grid — not a fix.
- **B moved to the front** and shipped as `Stop_width_mode.Demote_over_max`
  (PR #2352, default-off): §5.1's "prefer other candidates" as a stable
  reordering — narrow-stop candidates get first claim on the week's capital,
  wide-stop ones are walked after. Keeps size, gives up rank; the mirror of
  `Size_down`, which keeps rank and gives up size.
- **`stop_anchor_at_entry_base` deserves its own surface.** It is the one flag
  demonstrated to change AXTI's admission, and `Nearest` alone does not do it —
  see [[project-nearfloor-is-risk-not-return]], which just failed its grid.

**Provenance trap.** With `freeze_entry_at_first_breakout` armed, the audit's
`local_range_top` is the *current* week's window top while `suggested_entry` is
the *frozen* E from an earlier week (AAON 2025-10-17: E 106.13 ⇒ anchor 105.60,
but `local_range_top` 106.58). Inverting E from the audit and comparing to
`local_range_top` reads as a wrong anchor when it is merely pinned.

**How to apply.** Before ranking an "X is stale/wrong" defect, ask whether the
quantity is even a *function* of the thing being varied — a 4-bar window is not
a function of run length, and that was knowable from the config before any run
([[feedback-always-dissect-before-reporting]]).
