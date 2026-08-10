---
name: blind-judge
description: Sanity-check the Weinstein screener's entry decisions against an independent LLM judge given ONLY minimal book rules and a blinded weekly OHLC series — never our config, thresholds, or code. Use when a faithfulness result (e.g. ladder-v3's claim that a book-faithful gate legitimately excludes crash-recovery monsters like AXTI/SKYW/BPT) is our own self-validated reading and needs an outside check, when someone asks "would a human reading the book actually place this ticket", or before treating a screener exclusion/admission as a settled verdict rather than a hypothesis. Produces SCREENS (agreement/divergence counts), never a promote/reject verdict on our code.
---

# Blind judge — an independent oracle for entry-ticket faithfulness

Our screener's read of "book-faithful" is self-validated: the same code that
implements the rule also grades whether the rule was followed. This skill
builds a second, independent reader — an LLM given only the book's minimal
buy/sell rules and a blinded weekly price series — and compares its calls to
ours. It exists because ladder-v3 (`dev/notes/ladder-v3-faithful-stoplimit-2026-08-09.md`,
memory `project_faithful_ticket_structural_exclusion`) found that a faithful
15%-risk gate structurally excludes crash-recovery monsters (AXTI, SKYW, BPT)
that the record arm captures — and concluded "a faithful process may
legitimately exclude the monsters." That conclusion is currently only our own
code's opinion of itself. A blind reader tests it.

Companion tooling: `weekly_bars_dump` (`trading/analysis/scripts/weekly_bars_dump/`)
— the exe that produces the blinded per-decision-week series this skill feeds
to the judge. This skill is the protocol around that tool; it does not itself
run judge calls (no judge runs are part of building this harness — see the
task that created it).

## When it fires

- A screener admit/exclude decision (or a whole class of them, like the
  ladder-v3 monsters) rests on our own code's self-assessment of
  book-faithfulness and the stakes are high enough to want an outside check.
- Someone asks "would a human trader reading the book actually take this
  trade" for a specific symbol/week.
- Before treating a faithfulness finding as closed — this is a confirmatory
  screen, not a substitute for the trade-dissection / code-reading work that
  found the finding in the first place.

## What this is NOT

Per `.claude/rules/mechanism-validation-rigor.md` — this produces a **screen**,
not a verdict. It can conclude "our gate excludes setups a book-faithful reader
would take — worth investigating" or "no systematic divergence found in this
cohort." It can NEVER conclude "our code is right/wrong," promote or reject a
mechanism, or justify a default flip. The judge is a noisy, prompt-sensitive
LLM reading a static table — disagreement is a flag to dig with
trade-dissection, not proof of a bug.

## Step 1 — Produce the blinded series

```
dune exec analysis/scripts/weekly_bars_dump/weekly_bars_dump.exe -- \
  -symbol AXTI -through-week 2025-08-26 -weeks-back 260 \
  -warehouse-dir /tmp/snap_top3000_dedup_v5thin_adj \
  -blind -out case1.txt -mapping-out mapping.txt
```

- `-through-week`: the decision Friday — the week the ticket would have been
  placed/evaluated. `weekly_bars_dump` NEVER emits a bar dated after this
  week (the lookahead guard is `Bar_window.select`'s entire reason to exist,
  pinned by its own test suite) — a judge that sees future bars is answering
  "what happened next," not "would you enter here." One caveat: the weekly
  fold uses `include_partial_week:true` (`bar_source.mli`), so if the
  decision week is still in progress (its 5 trading days haven't all
  happened yet as of the data pull) the last row's volume is truncated and
  renders identically to a genuine low-volume week — a judge applying the
  mandatory §4.2 volume-confirmation rule could misread that as a volume
  collapse. Prefer a `-through-week` that names a *complete* historical
  week, not a currently-in-progress one.
- `-blind`: symbol → stable pseudonym (`SYM-XXXXXX`), dates → sequential
  `w1..wN` week labels. Prices are **NOT rescaled** — §5.1's round-number
  stop rule and §4.3's overhead-resistance grading both depend on real price
  levels, so blinding only strips the *identity*, never the *geometry*. This
  requires the warehouse's `.snap` `Close` column to actually be the raw
  (unadjusted) close — confirmed for `snap_top3000_dedup_v5thin_adj` and any
  of its siblings: the `_adj` suffix denotes a clone whose `.weekly`
  side-tables (used by the resistance sketches) were rebuilt on the
  split/dividend-adjusted basis (`dev/notes/split-basis-blast-radius-2026-07-28.md`)
  -- a *different* artifact from the `.snap` files, which are hard-linked,
  unchanged, and still hold the original raw `Close` / adjusted
  `Adjusted_close` pair as two separate columns (`Pipeline.build_for_symbol`'s
  contract: "Open / High / Low / Close / Adjusted_close: copied verbatim").
  `weekly_bars_dump` reads only `.snap` via `Bar_source`, never `.weekly`
  side-tables, so it is unaffected by which basis a given warehouse's
  side-tables were rebuilt on. If a future warehouse ever stores an adjusted
  series directly in `Close`, the round-number / resistance-grading rationale
  above breaks silently -- re-verify this note before pointing the tool at an
  unfamiliar warehouse.
- `-mapping-out` is **required** with `-blind` (the CLI exits 1 without it) --
  a routine `... > case1.txt 2>&1` redirect would otherwise write the
  de-blinding key into the judge's own file, since the mapping used to
  default to stderr. `case1.txt` (the `-out` file) never contains the
  mapping; `mapping.txt` (the `-mapping-out` file) is the operator's answer
  key. **Never paste the mapping file, or a filename/prompt that reveals it,
  into the judge's context.**
- Stderr also carries a `# source: warehouse-snap` or `# source: csv-store`
  line reporting which store served the bars -- operator-only, never routed
  to `-out`. If a cohort mixes sources across cases (e.g. one symbol's
  `.snap` happened to be missing), that is a comparability problem worth
  checking for before treating the cohort's counts as homogeneous.

## Step 2 — The judge prompt contract

Give the judge ONLY this rule card plus the blinded table from Step 1.
Nothing about our config, thresholds, code, `trade_audit.sexp` fields, or
what our screener decided. Quote verbatim from
`docs/design/weinstein-book-reference.md` — do not paraphrase or add rules
the judge might use as a tie-breaker we didn't intend.

```
You are evaluating a weekly OHLC price series against these rules from Stan
Weinstein's "Secrets for Profiting in Bull and Bear Markets". You will NOT be
told the ticker, the real dates, or anything about any trading system. Decide
only from the rules below and the table.

STAGES (book-reference.md SS1): every stock is in exactly one of 4 stages,
determined by price vs. its 30-week moving average and the MA's slope.
  Stage 1 Basing: MA flattening, price oscillates around it. DO NOT BUY.
  Stage 2 Advancing: MA rising, price consistently above it. BUY ZONE.
  Stage 3 Topping: MA flattening after rising, price oscillates around it.
    DO NOT BUY.
  Stage 4 Declining: MA falling, price consistently below it. NEVER BUY.

BUY CRITERIA (SS4.1, SS4.2, SS4.3, SS4.5):
  1. Price breaks out above a resistance level AND above the 30-week MA.
  2. The 30-week MA is no longer declining (flat or rising) at the breakout.
  3. A breakout below a still-declining MA is a TRAP, not a buy.
  4. Volume confirmation is mandatory: breakout-week volume >= 2x the average
     of the prior 4 weeks, OR a 3-4 week volume build-up >= 2x prior average
     with some increase on the breakout week itself. No confirmed volume ->
     do not trust the breakout.
  5. Grade the overhead resistance above the breakout on this scale:
     A+ Virgin territory (never traded above this price, or not in 10+
       years) -- most explosive potential.
     A Clean (no significant resistance visible in this series).
     B Moderate (some resistance overhead, not dense).
     C Heavy (a dense prior trading zone just above the breakout -- the
       stock will use up buying power getting through it).
  6. Partial big-winner confirmation (2 of the book's 3 legs -- the
     relative-strength leg is not available in this series, see "Known
     judge-vs-book gaps" below) if BOTH of: volume >= 2x (preferably 3x+)
     and stays heavy afterward; AND the stock already advanced significantly
     (~40%+) during its base before breaking out.

ORDER MECHANICS (SS4.7): the entry is a buy-stop placed at the top of the
current trading range, good-til-canceled, with a tight limit band (~2%)
above the stop. It rests until filled or cancelled -- it is not "buy at
today's close."

INITIAL STOP (SS5.1): place the stop just below the significant support
floor / prior correction low (round it down past any round number).
Pre-calculate the stop BEFORE buying: if the stop would require MORE THAN
15% risk from the entry/trigger price, PREFER OTHER CANDIDATES -- do not
take this trade even if every other criterion is met.

TASK: given the table below (columns: week, open, high, low, close,
volume; the last row is the decision week -- you see nothing after it),
decide: would Weinstein's rules have you place a buy-stop-limit ticket at
the top of the current range as of the decision week? Output ONLY the
JSON object specified below, no other prose.
```

## Known judge-vs-book gaps

The rule card above deliberately omits three things the book requires, and
one item is presented in a weakened form. **This is forced, not sloppy**: a
single symbol's blinded price series carries no market or peer context, so
the judge genuinely cannot apply a rule that compares the candidate against
other stocks or the tape. But the omissions are undisclosed to the judge and
are **all one-directional toward "place"**:

- **§4.4 Relative Strength is absent entirely**, including the book's
  hardest exclusion rule -- "Negative RS in negative territory → NEVER buy,
  no matter how good other factors" (spine item 7,
  `.claude/rules/weinstein-faithful-core.md`). A judge with no RS signal
  cannot decline on this basis; our code can and does.
- **The macro gate and sector gating are absent** (spine item 6; the book's
  §4 cascade preamble is "only after macro and sector pass do we evaluate
  individual stocks"). A judge with no market/sector context cannot decline
  on this basis either.
- **§4.5's third leg (RS confirmation) is dropped** -- the rule card's item
  6 above is relabeled "partial big-winner confirmation (2 of 3 legs)" so
  the judge is not told it is applying the book's full triple-confirmation
  test when it is applying two-thirds of it.

Every one of these omissions removes a reason the book would say "decline."
None removes a reason to buy. So the judge is **structurally more permissive
than the book**, in the exact same direction as the harness's headline
measured quantity: `we-declined-judge-places` (candidate over-exclusion,
the ladder-v3 question). A raw `we-declined-judge-places` count is therefore
**not** clean evidence of our gate being wrong -- part of any such divergence
is the judge's forced blindness to RS/macro/sector, not a flaw in our code.

**Mitigation — an RS/macro-driven decline control class.** The mandatory
cohort (below) already includes non-gate-decline controls, but none of them
probe this specific bias: `Insufficient_cash`, Stage 1/3/4, and missing
volume confirmation are all decisions the judge *can* make from the series
alone. Add at least one case where our code declined specifically for an RS
or macro reason (a case the judge, lacking that context, is expected to get
"wrong" by placing). If such a case cannot be constructed under blinding
(e.g. no RS-driven decline exists in the available trade_audit history),
say so explicitly in the writeup and treat every `we-declined-judge-places`
finding as upper-bound-only until one is available -- do not read the raw
rate as calibrated.

## Output contract

The judge must emit exactly one JSON (or sexp) object per decision week,
machine-parseable, nothing else:

```json
{
  "decision": "place_ticket | no_ticket",
  "trigger_level": 71.23,
  "stop_level": 58.10,
  "stage": 2,
  "overhead_grade": "A+ | A | B | C",
  "volume_confirms": "yes | no | unknown",
  "reason": "one short sentence",
  "confidence": "low | med | high"
}
```

`trigger_level` / `stop_level` are `null` when `decision = "no_ticket"`.
Reject and re-prompt once on a malformed response; discard the case (do not
hand-correct it) on a second failure — a judge that cannot format its answer
is not a usable data point.

## Step 3 — Protocol

1. **One call per decision week.** Build the blinded table fresh for each
   case (`weekly_bars_dump -through-week <that week>`); never reuse one
   table across multiple "what if the decision week were earlier" probes in
   the same judge context — that leaks lookahead through the conversation.
2. **N repeats per case, default 3, BEFORE any code comparison.** Run the
   identical prompt 3 times (fresh context each time — no memory of prior
   runs) and compute the judge's own self-consistency (agreement rate across
   the 3 calls, and whether `trigger_level`/`stop_level` cluster or scatter).
   **Code-vs-judge agreement is uninterpretable until judge-vs-judge
   agreement is known.** Report both numbers, always. A judge that agrees
   with itself 40% of the time makes any single-run comparison to our code
   noise, not signal — say so plainly rather than reporting only the
   code-comparison headline.
3. **Comparison categories**, per case (using the judge's majority call
   across its N repeats, or reporting "no majority" if none exists):
   - **agree-place**: judge says place, we placed.
   - **agree-decline**: judge says no ticket, we declined.
   - **we-declined-judge-places**: candidate over-exclusion — the ladder-v3
     question. This is the category that would flag "our gate excludes
     setups a book-faithful reader would take."
   - **we-placed-judge-declines**: over-admission — the mirror-image risk.
   Report per-category counts. On `agree-place` cases, additionally report
   level agreement: `|judge.trigger_level - our_E| / our_E` and the same for
   the stop, distribution not point estimate (mean/median/p10/p90) per
   `mechanism-validation-rigor.md` check 2.

## Cohort selection (mandatory: disputed cases + controls)

A cohort of only disputed cases cannot distinguish "our gate is wrong" from
"the judge says yes to everything" — controls are required, not optional.

**Disputed cases** (the ladder-v3 monsters our faithful arm declined via
`Stop_too_wide`):
- **AXTI**: `-through-week 2025-06-27` (the record's actual entry Friday,
  close 2.03) and separately `-through-week 2025-08-26` (the week the 2.71
  local-range-top trigger was crossed) — both are legitimate "decision week"
  candidates depending on which entry model you're probing.
- **SKYW**: `-through-week 2023-03-17`.
- **BPT**: `-through-week 2022-01-21` (and `2022-02-11`, a second
  `Stop_too_wide` week for the same name).

**Controls** (mandatory):
- Weeks where our code DID place a ticket (any faithful-arm fill from
  `trades.csv` — pick several across different years/sectors so the judge
  isn't just confirming one calm-base pattern).
- Weeks where our code declined for a **non-gate** reason (`Insufficient_cash`,
  a Stage 1/3/4 week, missing volume confirmation) — these should read as
  clear judge declines too; if they don't, the judge itself is unreliable and
  the whole run's findings are suspect.
- **At least one week where our code declined for an RS or macro reason**
  (see "Known judge-vs-book gaps" above). Without this class, RS/macro-driven
  divergence lands entirely on the disputed side of the ledger with nothing
  to calibrate it — the judge's forced blindness to RS and macro context
  otherwise reads as evidence for over-exclusion when it may just be the
  gap. If no such case exists in the available `trade_audit.sexp` history,
  say so explicitly in the deliverable and downgrade every
  `we-declined-judge-places` finding to upper-bound-only.

Aim for a cohort where disputed cases are a minority (e.g. 5 disputed + 10+
controls) so the agreement-rate denominator isn't dominated by the very
cases under question.

## Verdict calibration (mandatory — read `.claude/rules/mechanism-validation-rigor.md` first)

Permitted conclusions:
- "N of M disputed cases got a judge over-exclusion flag (we-declined,
  judge-places), vs. a K% baseline over-exclusion rate on controls — worth a
  trade-dissection follow-up on those N cases."
- "No systematic divergence: disputed and control over-exclusion rates are
  statistically indistinguishable at this judge self-consistency level."

Forbidden conclusions:
- "The judge proves our gate is wrong/right."
- Any promote/reject verdict on `stop_anchor_at_entry_base`,
  `max_stop_distance_pct`, or any other mechanism/flag.
- Treating a single judge run (no self-consistency check) as evidence at
  all.
- **Treating a raw `we-declined-judge-places` count as calibrated evidence
  of over-exclusion**, ignoring "Known judge-vs-book gaps" above. The judge
  is structurally more permissive than the book (no RS, no macro/sector
  gate, a weakened §4.5) — every disputed-case rate must be read as a
  differential against the control baseline rate, never as an absolute
  number, and even the differential is only trustworthy to the extent the
  RS/macro-driven control class exists. A run that skips that control class
  may report a differential but must caveat it as **not fully controlling
  for the judge's permissiveness bias**.

## The deliverable

A short writeup (`dev/notes/blind-judge-<topic>-YYYY-MM-DD.md`) reporting:
judge self-consistency (the number that gates everything else), the 4-way
comparison table, level-agreement distribution on agree-place cases, and
which specific disputed cases (if any) warrant a trade-dissection follow-up.
Per `mechanism-validation-rigor.md`'s "real deliverable is the why" — if
divergence is found, name which disputed cases and take them to
`trade-dissection` next, don't stop at the aggregate count.
