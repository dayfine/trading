---
name: faithful-ticket-structural-exclusion
description: "Ladder v3 verdict — faithful StopLimit arms (+262/+318%) vs record (+7,321%); gap = 15% gate structurally excludes crash-recovery monsters; async-v2 plan is the successor"
metadata: 
  node_type: memory
  type: project
  originSessionId: b2db7349-a6dd-4dc8-9fb1-9be24cb7b5b2
  modified: 2026-08-10T00:47:52.879Z
---

Ladder v3 (2026-08-09, top-3000 26y, pinned a19938a8b): faithful-StopLimit
arms (local-range E + frozen E + next-open + support-floor stop, 15% as
filter) — w4 +318%/Sharpe .46, w13 +262%/.42 vs record-nextopen +7,321%,
book-honest +310%. w8 killed (no marginal info). **Gap = structural
exclusion of crash-recovery monsters, verified at trade level**: AXTI ($56.2M
= 76% of record) skipped 28× `Stop_too_wide` incl. the exact entry Friday
(trigger 2.71 vs crash-floor 1.728 = 36%; record's close-basis = 14.9%,
passes by 0.1pp); SKYW 2023-03-17, BPT 2022-01-21 same. Trade counts nearly
equal (1,139 vs 1,121) → entry walk BACKFILLS dropped wide-range names with
calm bases = adverse selection against the fat tail (11th
[[edge-is-the-fat-tail]] confirmation). 9,520 Stop_too_wide skips run-wide.

**Three timing mis-mappings** (user insight 2026-08-10): stage clock starts
at MA cross not the book's breakout (AXTI aged out of early_stage2≤4 while
still BASING below its range top — its actual Aug-2025 cross of 2.71 found no
candidate); synchronous Friday screen vs book's asynchronous GTC
place-then-wait (volume is judged AT the breakout, post-fill); gates
validated under market-entry don't transfer to resting tickets (the ticket IS
the discipline; 15% drop-filter amputates where fixed-risk sizing would just
size down ~1/stop_distance).

**Book review reframe (the elephant):** Weinstein would likely PASS on AXTI
at 2.71 anyway — §4.3 overhead C-grade (2.71→4.03 crash range overhead),
~1:1 reward/risk, §5.1. A faithful process may legitimately exclude the
monsters; AXTI-capture is NOT the success criterion. The book-native
discriminator for wide-range names is §4.5 triple confirmation (vol ≥2-3×, RS
zero-cross, pre-breakout advance ≥40% — AXTI's 1.13→2.71 = +140% qualifies).

**Successor: `dev/plans/entry-ticket-async-v2-2026-08-10.md`** (PR #2255) —
F1 freshness-from-breakout basis, F2 order TTL + re-screen cancel, F3
size-down mode (honest: not a book mechanism) + nearest-floor anchor arm, F4
stop-width diagnostic axis (0.35/0.50 diagnostic-only, never promotable), F5
volume-confirm-at-fill w/ mandatory eject (pre-build TODO: verify source-book
sell-on-unconfirmed passage), F6 triple-confirmation audit tag. Artifacts:
`.sweep-output/ladder-v3-artifacts/`. Audit caveat found: `ma_value` is
adjusted-basis vs raw close/E in trade_audit.
