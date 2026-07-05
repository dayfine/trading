# Next-session priorities — 2026-07-06

**Supersedes** `next-session-priorities-2026-07-04.md` (rev 2). Main green.

## What 2026-07-04→05 delivered (all merged)

**The scale-in arc, closed end to end:**

- **#1846** retraction of #1843's wrong add-channel root cause (adds DO fill;
  the artifact was a real reporting bug).
- **#1847** the reporting fix: position-faithful round-trip pairing in
  `Metrics.extract_round_trips` (sibling chimera bug; triple-gated).
  ⚠ pre-#1847 trades.csv from scale-in runs stays unreliable — re-run.
- **#1852/#1855/#1856** continuation-add v2: book re-read (Ch. 3 §The
  Trader's Way) → `Consolidation_breakout` trigger + `add_fraction` knob,
  default-off, triple-gated → broad-only WF-CV surface.
- **Verdict: REJECT** (ledger `2026-07-05-continuation-add-v2-surface`,
  writeup `dev/notes/continuation-add-v2-wfcv-2026-07-05.md`): gate FAIL all
  variants; faithful trigger too rare to matter (5–6/13 folds unchanged);
  regime-mixed when it fires (f010 +10.7pp vs f007 −15.7pp); volume 1.5×
  removes the harm and the edge; full-size adds are financed by displaced
  entries — breadth is the edge (9th fat-tail confirmation).
- **Docker.raw fixed non-destructively** (55→21 GB: 37 GB stale container
  `/tmp` scratch; no rebuild). Preflight for future sweeps is clear.

## SCALE-IN PROGRAM CLOSED — standing directive

Both halves tested and rejected: v1 ½-sizing (fat-tail tax) + v2 book-faithful
continuation adds (flat redistribution). **Stop proposing intra-envelope
capital-reallocation variants** (v1, v2, harvest-rotate, laggard-cap,
macro-trim all dead — the class is exhausted). Mechanisms stay merged,
default-off, searchable.

## P0 candidate — the envelope pair-sweep (the one reallocation lever never tested)

Every reallocation rejection shares one root cause: the binding cash
constraint (`min_cash_pct 0.30` / `max_long_exposure_pct 0.70` — the same 70%
ceiling from both sides). This pair has NEVER been swept together (single-knob
sweeps read "inert" because the other side binds —
`project_capital_mgmt_scale_in_design` §two-orthogonal-levers). A 2-axis
surface (e.g. min_cash {0.30, 0.20, 0.10} × max_exposure {0.70, 0.80, 0.90},
coupled cells only) answers whether the strategy is capacity-starved — and is
the stated precondition for ever revisiting continuation adds. Bear-fold risk
is the obvious cost; the 13-fold WF-CV prices exactly that. ~9h broad run,
preflight now clear.

## Other open threads (carried)

- Catastrophic-stop sibling alignment (#1831 review) — inert, unchanged.
- Live add-order shape (`StopLimit(close,close)` divergence) — only matters
  if a scale-in mechanism is ever promoted; parked.
- P2/P4 from 2026-07-02 (≤4-week gate tuning; continuous-RS display).

## Process notes

- The #1843→#1846 retraction cycle: verify the reporting layer handles a new
  mechanism's structure before reading conclusions off it (one 11-min
  pipeline trace would have prevented a merged wrong conclusion).
- Docker.raw bloat ≠ reset needed: check `docker system df` + container
  `/tmp` first; TRIM reclaims automatically once VM-internal space is freed.
- Background Bash wrappers died repeatedly this session; the durable pattern
  for long in-container runs: `docker exec -d ... > /tmp/x.log` + poll the
  log for an explicit `EXIT=`/done marker. Never let a chain write to the
  wrapper's stdout (dead-pipe hangs, 40+ min observed twice).
