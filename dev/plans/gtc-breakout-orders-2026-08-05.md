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

## Step 0 (the actual open decision) — what is the entry trigger?

Today's three-layer divergence:

| Layer | Entry anchored at |
|---|---|
| Weekly report ticket (live orders the user places) | `suggested_entry` E (graded breakout level) |
| Sim, all fill models incl. #2202 StopLimit | current close (G14 fix B) |
| Book | E, GTC, ~2% band |

User decision (open): (a) current-close entries are the design → make the
REPORT print close-anchored tickets for live/sim consistency; (b) move the
sim to E-triggered resting stops → build the flag below, then re-derive the
fill-model ladder honestly; (c) dual convention, documented.

## Step 1 (if (b)) — `sim_entry_trigger_at_suggested : bool [@sexp.default false]`

Default-off flag routing `Order_generator`'s entry trigger to the candidate's
`suggested_entry` instead of `effective_entry_price`'s close (the close stays
the audit/sizing anchor unless decided otherwise — sizing-at-E vs sizing-at-
close is itself a sub-decision; live sizes at E). With the flag on AND
`enable_sim_entry_stoplimit` on, orders genuinely rest at E — engine-level
persistence already carries them (pinned). R1: off = bit-identical. R2: flat
config field, axis-expressible.

Watch-outs from the diagnosis: G14 fix B exists for split-basis safety —
`suggested_entry` is a screener-buffer value; verify it is split-consistent
with the fill-time bar basis before trusting E-anchored fills (this is WHY
G14 moved to the close; the flag must not silently reintroduce that bug —
may need the split-safe re-anchoring applied to E).

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

Step 0 awaits the user. Nothing builds before that call.
