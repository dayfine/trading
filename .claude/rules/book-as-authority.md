# The book is a first-class resource — consult the source, then cache the answer

**Whenever a specific faithfulness question is in doubt, read Stan Weinstein's
book.** It is available locally. The distilled reference is a summary of it, not
a replacement for it.

User instruction, 2026-08-20: *"Book faithfulness is [a] problem hard to
enforce — but the book is available locally and should be a first class resource
whenever we are in doubt with specific faithfulness question."*

## Why this rule exists

Book faithfulness is the one validation axis with **no tooling at all**. There
is no check in `trading/devtools/` or `.github/`; "faithful" appears only in
`.mli` prose. Enforcement is qc-behavioral's manual S1–S6 / L1–L4 / C1–C3
checklist, read per-PR by an agent.

That is not fixable by automation — faithfulness is a question about intent and
interpretation, not a predicate over source. What *is* fixable is the cost of
looking up the answer, and whether the answer survives the session that found it.

## Where it is

```
/Users/difan/Downloads/486827303-Stan-Weinstein-s-Secrets-For-Profiting-in-Bull-and-Bear-Mark-pdf.txt
```

Plain-text extraction, 12,417 lines / 540 KB / 20 chapter markers. The `.pdf`
sits beside it. **Do not commit either** — it is purchased copyrighted text.
This rule records the path so no session has to rediscover it.

### ⚠ OCR spacing — exact long-phrase greps fail

The extraction has spacing artifacts. Line 738 reads:

```
the y e a r s , I've found that a 30-week moving average (MA) is the
```

So `grep "I've found that a 30-week"` succeeds, but `grep "over the years"`
finds nothing even where the text says it. **Search short distinctive terms**
(`30-week`, `Stage 2`, `breakout`, `protective stop`, `relative strength`) and
read the surrounding context. Never conclude "the book doesn't say X" from one
failed multi-word grep — that is a negative existence claim on an unreliable
search surface (see `feedback_check_memory_before_claiming_about_code`).

## The three-tier protocol

1. **`docs/design/weinstein-book-reference.md`** (423 lines) — the distilled
   decision rules. If it answers the question, you are done.
2. **The book** — whenever the reference is **silent**, **ambiguous**, or a
   faithfulness claim is **contested**. This is the authority; tier 1 is a
   summary of it, and a summary cannot settle a dispute about its own scope.
3. **Write the answer back to tier 1.** Append the resolved question, the
   answer, and a citation: **chapter plus a short distinctive quote — not a page
   number**, because OCR pagination is unreliable.

Step 3 is the load-bearing step. It turns the reference into a **cache of
resolved faithfulness questions that grows toward the questions actually
asked**, with the book as the backing store. The judgment still happens per
question; it just happens *once*.

## When this fires

- A PR adapts a dial and must cite Weinstein authority
  (`weinstein-faithful-core.md` W2).
- qc-behavioral fills an S / L / C row and the reference does not clearly cover
  the case.
- Someone claims a mechanism is or is not faithful and the record disagrees, or
  is silent.
- A default or convention is found to diverge from the book — e.g. the record
  convention's non-book market + deep-floor fill rule
  (`project_fill_model_inversion`), which remains an open decision.

## What this rule does not do

It does not make faithfulness checkable by a linter, and it does not license
citing the book to justify a mechanism the book does not discuss. The spine in
`weinstein-faithful-core.md` still governs what may be adapted at all; this rule
only governs **how to find out what the book actually says**.

Related: `.claude/rules/weinstein-faithful-core.md`,
`.claude/rules/qc-behavioral-authority.md`,
`docs/design/weinstein-book-reference.md`.
