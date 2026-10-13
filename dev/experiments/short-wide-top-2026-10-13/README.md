# Short wide-top screen (2026-10-13)

Option (b) of the shorts-track decision. Pre-registration: `dev/plans/short-wide-top-screen-2026-10-13.md`, committed
in `6a0177107` before any number here was computed. Host-only; no container, no strategy code.

## Rule output (price floor $5)

```
Step 1 O1+60: n=24790 beat=51.3% (>=55% FAIL) median=+0.50% (>0 ok) => CLOSE (no-build)
Step 2 O2 (not reached; shown for the record): n=24790 (>=100 ok) mean=-2.12% (>=+2% FAIL) median=+1.10% (>0 ok) beat=52.0% (>=55% FAIL) halves -6.56/+2.13% (FAIL) O1+60 mean -2.19% (ok) => no edge
VERDICT: CLOSE (no-build)
```

$17 floor (robustness): n 18,308; O1 +60 beat 50.8 %, median +0.26 % → CLOSE; O2 mean −0.29 %, median +0.69 %,
beat 51.3 %, halves −2.79 / +1.79 %.

## Numbers (from `results/summary-floor5.txt`)

| outcome | n | mean | median | p10 | p25 | p75 | p90 | beat |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| O1 +20 | 24,790 | +0.13 % | +0.09 % | −12.6 | −5.6 | +5.9 | +13.4 | 50.4 % |
| O1 +60 | 24,790 | −2.19 % | +0.50 % | −21.0 | −9.5 | +10.8 | +22.7 | 51.3 % |
| O1 +120 | 24,790 | −1.47 % | +1.85 % | −29.3 | −12.4 | +16.3 | +32.4 | 53.4 % |
| O2 | 24,790 | −2.12 % | +1.10 % | −28.4 | −13.6 | +16.1 | +32.3 | 52.0 % |
| O2 2000–12 | 12,118 | −6.56 % | −1.18 % | −30.5 | −15.8 | +14.1 | +30.4 | 47.7 % |
| O2 2013–25 | 12,672 | +2.13 % | +3.48 % | −25.8 | −11.5 | +17.7 | +33.6 | 56.0 % |
| O2 clipped ±100 % | 24,790 | +1.13 % | +1.10 % | | | | | 52.0 % |

- O2 stopped: 4,580 (18.5 %). The stop sits above the whole right shoulder, so room is wide: 16,396 events (66 %) have
  room > 30 %, 980 have ≤ 15 %.
- The mean and the ±100 %-clipped mean differ in sign (−2.12 % vs +1.13 %): the negative mean is carried by a short
  tail: 136 events lose more than 100 % and 21 gain more than 100 % (some are vendor splices, as in the setup map, #3239). The median and beat do not move.
- Room split (O2 beat): ≤ 15 % 45.5 %, 15–30 % 49.5 %, > 30 % 53.5 %.
- SPY phase split (O2 beat): s4_early 47.2 %, s4_late 46.7 %, s3 50.3 %, s12 55.3 %.
- Bear years (O2 beat): 2000–02 48.0 %, 2007–09 55.1 %, 2022 48.9 %.

## Notes on the implementation

- Weekly bars built from the daily bars (weeks end Friday) and the 30-week MA computed here; our stage classifier is
  not used. The SPY weekly stage CSV only labels the phase split.
- Entry at the next daily bar's adjusted open; the SPY leg starts at SPY's adjusted open on the same day. (The setup
  map's `events.awk` entered at that day's adjusted close.)
- Membership and the $5 floor are read at the breakdown week's last daily bar.

## Files

- `scripts/run.sh` regenerates everything (`DATA=<bar store>`, default `data/`): `run_events.sh` → `event_one.sh` →
  `events.awk` per symbol, then `summarize.sh` (`analyze.awk`).
- `results/events/<year>.csv` (one header each; columns in `scripts/header.txt`), `results/summary-floor5.txt`,
  `results/summary-floor17.txt`.
