# Entry trigger semantics → then GTC breakout orders (rewritten 2026-08-05)

> **REWRITE.** The original version of this plan motivated GTC persistence
> from the BKE specimen ("Day order at E=28.66 expired before the Nov
> breakout"). The diagnosis (`dev/notes/bke-order-diagnosis-2026-08-05.md`)
> falsified that premise: sim entry orders trigger at the CURRENT CLOSE (G14
> `effective_entry_price`), fill within a bar or two, and never rest at E —
> and unfilled StopLimit orders already persist at the engine level
> (pin tests: `trading/simulation/test/test_gtc_entry_persistence.ml`).
> There is no population of resting orders for GTC lifecycle management to
> manage. The faithful mechanics (rest at the breakout, GTC, tight band —
> book Ch.3 p.67-68, reference §4.7) require a PREREQUISITE change first.

## Step 0 — DECIDED (b) 2026-08-05 (user): book-faithful E-anchored orders

The sim (and therefore the record) moves to E-triggered resting stops: entry
orders rest at the screener's breakout level `E` (`suggested_entry`), matching
the book (Ch.3 p.67-68, reference §4.7) and the live report's tickets. Sizing
also anchors at E (the sizing-at-E sub-decision below is resolved: E, consistent
with live tickets). Implemented as Step 1's default-off flag
`sim_entry_trigger_at_suggested` (PR `feat/entry-trigger-at-e`); the fill-model
ladder is to be re-derived honestly on the E-anchored basis (Step 3).

Today's three-layer divergence (pre-flag):

| Layer | Entry anchored at |
|---|---|
| Weekly report ticket (live orders the user places) | `suggested_entry` E (graded breakout level) |
| Sim, all fill models incl. #2202 StopLimit | current close (G14 fix B) |
| Book | E, GTC, ~2% band |

User decision (open): (a) current-close entries are the design → make the
REPORT print close-anchored tickets for live/sim consistency; (b) move the
sim to E-triggered resting stops → build the flag below, then re-derive the
fill-model ladder honestly; (c) dual convention, documented.

## Step 1 — `sim_entry_trigger_at_suggested : bool [@sexp.default false]` — DONE (PR `feat/entry-trigger-at-e`)

Default-off flag that pins `effective_entry_price` (and hence
`CreateEntering.entry_price` + sizing) to the candidate's `suggested_entry` (E)
instead of the current close. With the flag on AND `enable_sim_entry_stoplimit`
on, the emitted `StopLimit (E, E * (1 +/- entry_extension_max_pct/100))`
genuinely rests at E — engine-level persistence already carries it (pinned in
`test_gtc_entry_persistence.ml`, whose entry_price=160=E scenario is exactly
"E above current close → resting StopLimit fills only on the later cross").
Sizing anchors at E (sizing reads `effective_entry`). R1: off = bit-identical
(pinned). R2: flat config field, axis-expressible.

Split-safety (resolved): G14 fix B pinned the trigger to the close because
`suggested_entry` *could* land in a different price space on a symbol whose
screener lookback spanned a split. That hazard is already closed by G14 fix A —
the screener truncates its high/low lookback at the most recent split boundary
(`Stock_analysis._no_split_between`), so `suggested_entry` is computed in
*current* raw close-price space. In-sim the screener bars and fill bars share
one snapshot source, so E and the close share one basis by construction. No
per-symbol split guard is added, and deliberately no epsilon-fallback to close
(E is by design *above* the close for a long breakout — a disagreement guard
would misfire on every normal breakout). Full argument in the
`sim_entry_trigger_at_suggested` .mli doc.

## Step 2 — management semantics (only meaningful after Step 1)

Cancel-on-candidacy-loss, re-grade amend, optional K-week grace: as in the
original plan §Mechanism items 2-4. Now correctly framed: today orders
persist FOREVER (never cancelled) — with E-resting orders that becomes a
real faithfulness/capital question (stale levels, stale sizing), so the
managed lifecycle is where the design work is. Band axis: {2 (book), 15}.

## Step 3 — measurement

Re-run the deep-pair ladder with honest arms (market / E-stop-Day-equivalent
/ E-stop-GTC × band) + the WF-CV surface. The 2026-08-04 ladder's terminal
numbers remain as as-built measurements; its attribution narrative is
superseded (see the diagnosis note).

## Status

Step 0 DECIDED (b). Step 1 DONE (PR `feat/entry-trigger-at-e`, default-off).
Steps 2 (managed GTC lifecycle) and 3 (honest ladder re-derivation + WF-CV
surface) remain.
