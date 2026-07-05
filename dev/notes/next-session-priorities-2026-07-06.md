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

## ~~P0 candidate — the envelope pair-sweep~~ — CANCELLED 2026-07-05 (premise false)

**Both knobs are dead code in the sim path** — see
`dev/notes/envelope-knobs-dead-2026-07-05.md`. `min_cash_pct` is consumed only
by the never-called `check_limits`; `max_long_exposure_pct` is per-position
min()'d (0.70 vs 0.30 per-position cap → never binds) and its aggregate check
is also only in `check_limits`. Smoke A/B with `min_cash_pct=0.90` =
bit-identical on all 3 windows; actual deployment is 89–99% invested. There is
no 70% ceiling — the sweep would have been 9 bit-identical cells (~9h wasted).

Consequences: the envelope cannot be *loosened* (already ~100%; only margin
would expand it) → the precondition for revisiting continuation adds is
unsatisfiable in the current architecture → scale-in stays closed. The only
buildable envelope experiment is a *tightening* mechanism (working cash-reserve
flag, default-off) — likely a breadth tax; decision item, not a default next
step. Also decision item: wire or delete the dead `check_limits` battery
(`max_positions`, `min_cash_pct`, aggregate exposure, sector counts all
unwired).

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
