# stop-width-surface-2026-09-03 — `initial_stop_buffer` {1.0, 0.98}, anchor off, record convention, fixed basis

Follow-on to `stop-anchor-rebase-2026-09-03`, where the anchor-off 5.9%
fallback stop (`initial_stop_buffer 0.98`) beat the 4% null 3/3 salts on the
2019–23 cell-B base with no monster and shared-trade drift ≈ 0 — the first
fixed-basis lever read that is not a lottery ticket. This surface asks whether
it holds on the **record convention** (the canonical spec, clock-0 pin) across
windows and salts.

## Design

- Build `e4984c5fe` (pinned worktree `sweep-record0903`), warehouse
  `/tmp/snap_top3000_dedup_v5thin_adj`, `--no-emit-all-eligible --parallel 1`.
- Arms: the record-baseline spec with the window swapped (as in
  `record-rebase-2026-09-03`) — **null** = default `initial_stop_buffer 1.0`
  (≈4.0% fallback, §5.3 band floor); **wide** = `((initial_stop_buffer 0.98))`
  prepended (≈5.9%, band ceiling). Anchor off (spec default).
- Cells: 2019–23 × top-3000-2019 and 2000–04 × top-3000-2000, both arms at
  salts {0,1,2}; 26y × top-3000-2000, wide arm at salt 0 (confirmation only,
  per the user's iterate-on-5y-first rule). **Salt-0 nulls are reused from
  `record-rebase-2026-09-03/results/rec5y-2019-new-s0-*`,
  `rec5y-2000-new-s0-*`, `rec26y-new-s0-*`** — identical spec, build and
  salt, so no re-run.
- Pre-registered decision rule (as in the arc grid): promote to a confirmation
  read only if wide beats null in ≥2 of 3 salts on BOTH 5y windows, is never
  badly dominated, and the 26y salt-0 arm does not worsen MaxDD; every delta
  read **ex-monster** (join `symbol|entry_date`, shared-trade drift vs unique
  cohort, top-trade check) — a win carried by one admitted monster does not
  count (`project_stop_anchor_surface_is_dds`).

## Results

_(filled in as cells land — `chain.log`)_

### Interim — salt 0, both 5y windows (20:45 PDT)

| window | arm | return % | trades | sharpe | maxDD % | realised $ | stops | top trade |
|---|---|---:|---:|---:|---:|---:|---:|---|
| 2019–23 | null b1.0 (`rec5y-2019-new-s0`) | 3.02 | 184 | 0.118 | 30.33 | −68,074 | 129 | LOGI +149k |
| 2019–23 | wide b0.98 | 49.31 | 162 | 0.465 | 39.92 | +415,748 | 101 | **MSTR 2020-10-12 +579k (wide-only)** |
| 2000–04 | null b1.0 (`rec5y-2000-new-s0`) | 76.64 | 98 | 0.655 | 28.36 | +622,371 | 74 | WNC +271k; **IPIXQ 2004-04 +256k (null-only)** |
| 2000–04 | wide b0.98 | 76.02 | 76 | 0.792 | 20.58 | +573,918 | 53 | WNC +292k |

Dissection (join `symbol|entry_date`):

- **2019–23:** shared 93 trades drift **−$67k** (ΣΔpnl% 0.0 — the drift is sizing,
  not price); null-only 91 entries −$300k (the 4% stop's extra whipsaws); wide-only
  69 entries +$250k **of which MSTR is +$579k** — ex-MSTR the wide arm's unique
  cohort is −$329k and the arm realises **−$164k vs the null's −$68k**. The +46pp
  is one admitted monster; maxDD is 9.6pp worse.
- **2000–04:** shared 64 trades drift **+$78k** (ΣΔpnl% +49, ≈ +0.8pp per shared
  trade — the wider stop survives the bear's shakeouts); null-only 34 entries +$151k
  **of which IPIXQ is +$256k**; wide-only 12 entries +$24k. Ex-IPIXQ the wide arm is
  **+$207k better** with maxDD 28.4 → 20.6 and Sharpe 0.66 → 0.79.

So at salt 0 the structural effect is the same in both windows — fewer stop exits
(−28 / −21), a calmer book in the bear window — while the *level* in each window is
set by one monster that happened to land in one arm. Neither window's return delta
is evidence on its own; the salts (running) and the 26y arm are what this surface
is for.

### 2019–23, salts 0–2 (21:35 PDT) — the width's win on the record convention is MSTR

| salt | null b1.0 return / trades / realised | wide b0.98 return / trades / realised | Δ realised | MSTR 2020-10-12 | ex-MSTR Δ | shared drift | stops null → wide |
|---|---|---|---:|---|---:|---:|---|
| 0 | 3.02 / 184 / −68,074 | 49.31 / 162 / +415,748 | +483,822 | wide only, +579,478 | **−95,656** | −67,023 (93 shared) | 129 → 101 |
| 1 | 22.90 / 184 / +99,598 | 49.02 / 162 / +412,815 | +313,217 | wide only, +582,003 | **−268,786** | −12,974 (100) | 119 → 101 |
| 2 | 3.84 / 185 / −60,630 | 49.22 / 162 / +414,635 | +475,265 | wide only, +581,372 | **−106,107** | −62,414 (94) | 130 → 101 |

The wide arm is salt-invariant (49.3 / 49.0 / 49.2, 162 trades every time) because one
position dominates its book; the null wanders (3 → 23 → 4). **MSTR 2020-10-12 → extension-stop exit 2021-03-01 (+378%) is in the wide arm at
every salt and never in the null (screened there — 30 audit mentions — but the
null's book was 7 deep that week, the wide arm's 6); net of it the
wide arm is *worse* than the null at every salt, and the shared trades drift against
it too.** On the record convention (clock 0, no freeze / anchor-4) the 5.9% width does
not survive the ex-monster read on this window — the opposite of the cell-B result in
`stop-anchor-rebase-2026-09-03` (where off-b0.98 won 3/3 ex-monster). The
structural footprint is identical in both bases (−28 / −18 / −29 stop exits): fewer
whipsaws, but here the survivors do not pay for themselves once MSTR is removed.
The 2000–04 salts and the 26y arm decide whether the band-ceiling width is a
regime-dependent dial or noise.

### 2000–04, salts 0–2 (22:25 PDT) — the width IS a positive here, ex-monster and at every salt

| salt | null b1.0 return / trades / maxDD / realised | wide b0.98 return / trades / maxDD / realised | Δ realised | IPIXQ 2004-04 | ex-IPIXQ Δ | shared drift | stops null → wide |
|---|---|---|---:|---|---:|---:|---|
| 0 | 76.64 / 98 / 28.36 / +622,371 | 76.02 / 76 / 20.58 / +573,918 | −48,453 | null only, +255,902 | **+207,449** | +78,390 (64 shared) | 74 → 53 |
| 1 | 55.52 / 94 / 19.56 / +424,202 | 76.12 / 76 / 20.57 / +574,439 | +150,237 | neither | **+150,237** | +85,868 (63) | 71 → 53 |
| 2 | 75.73 / 98 / 28.36 / +613,603 | 77.38 / 76 / 20.61 / +587,863 | −25,740 | null only, +254,944 | **+229,204** | +87,036 (64) | 74 → 52 |

WNC 2003-05-09 (the window's monster) is in BOTH arms at every salt (+$270k null,
+$291k wide — the wider stop rides it slightly further). The only lopsided monster,
IPIXQ, sits in the null at two salts and in neither at the third; net of it the wide
arm wins by +$150k–$229k at every salt, and — unlike 2019–23 — the **shared trades
themselves drift +$78k–$87k in the wide arm's favour** (≈ +1.2pp per shared trade:
the 2000–04 tape's shakeouts pierce a 4% stop and spare a 5.9% one). maxDD improves
by ~8pp at two salts and is flat at the third; Sharpe 0.65 / 0.64 / 0.65 → 0.79 / 0.79 /
0.80.

### Cross-window read (5y complete; 26y wide arm running)

| | 2019–23 (bull, top-3000-2019) | 2000–04 (bust + recovery, top-3000-2000) |
|---|---|---|
| structural footprint | −28 / −18 / −29 stop exits | −21 / −18 / −22 stop exits |
| shared-trade drift | **−$67k / −$13k / −$62k** | **+$78k / +$86k / +$87k** |
| lopsided monster | MSTR in the wide arm (every salt) | IPIXQ in the null (2 of 3 salts) |
| ex-monster Δ | −$96k / −$269k / −$106k | +$207k / +$150k / +$229k |
| maxDD wide − null | +9.6 / +11.9 / +9.6pp (worse) | −7.8 / +1.0 / −7.7pp (better) |

The pre-registered rule ("wide beats null in ≥2 of 3 salts on BOTH windows,
ex-monster") is **not met**: 2000–04 passes 3/3, 2019–23 fails 3/3. The
mechanism is coherent — the wider stop converts whipsaw deaths into held
positions — but whether those held positions pay depends on the tape: in a
high-volatility bust/recovery they do (and the book is calmer); in the 2019–23
melt-up they do not, and the wider stop also carries more drawdown. This is a
**regime-dependent dial, not a default flip** (`experiment-flag-discipline.md`
Rule 4's "REJECT-as-default-but-legitimate-axis" shape), consistent with the arc
grid's s6 "keep-as-axis" and with Weinstein's own framing of the percentage
fallback as a trader-mode adaptation (§5.3; the book's caveat that "investors
should never use automatic percentages" was surfaced by the #2658 review). The
26y arm below is confirmation of the long-run level only.

### 26y confirmation arm (salt 0; landed 2026-09-04 00:56, wall 2h34m)

| arm | return % | trades | win % | sharpe | maxDD % | realised $ | stops | laggard |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| null b1.0 (`rec26y-new-s0`) | 302.65 | 723 | 34.3 | 0.397 | 36.26 | +2,205,226 | 469 | 237 |
| wide b0.98 (`sw26y-b0.98-s0`) | 376.38 | 626 | 36.1 | 0.445 | 37.65 | +3,264,717 | 376 | 234 |

Join on `symbol|entry_date`: 383 shared / 340 null-only / 243 wide-only, first
divergence 2000-02-07. **Shared trades drift −$34k** (price effect −$134k, i.e. the
wider stop's shared exits are slightly worse at 26y, as in 2019–23 and unlike 2000–04).
The +$1.06M realised gap is cohort: null-only 340 entries +$1.33M (LOGI +$424k, BBWI
2020-08-08 +$414k, IPIXQ +$256k, PCYC +$245k) vs wide-only 243 entries +$2.43M (**MOS
2006-10-30 +$795k**, BBWI 2020-08-05 +$625k — the same name entered three days earlier
and ridden further, IDXX +$406k, STI-WS-B +$390k). The wide arm holds 14 trades ≥ $250k
vs the null's 7; the shared monsters are larger under the wider stop (NVDA 2020-04
+$338k → +$588k, MKSI +$280k → +$423k, BPT +$281k → +$445k, WNC +$271k → +$292k) while
the shared small trades give it back. Ex-MOS the wide arm is +$264k over the null;
maxDD +1.4pp worse; 93 fewer stop exits.

## Verdict

**`initial_stop_buffer` stays 1.0 (≈4% fallback) by default. 0.98 (≈5.9%, the §5.3
band ceiling) is a legitimate regime / trader-mode dial, not a promotion candidate.**

- Pre-registered rule (wide beats null ex-monster in ≥2/3 salts on BOTH 5y windows,
  26y maxDD not worse): **not met** — 2000–04 3/3 yes, 2019–23 0/3, 26y maxDD +1.4pp.
- The structural effect is the same everywhere: −20…−30 stop exits per 5y window,
  −93 at 26y (whipsaw deaths become held positions). Whether the held positions pay
  is regime-dependent — positive shared drift and calmer book in the 2000–04 bust,
  negative shared drift and more drawdown in the 2019–23 melt-up, negative shared
  drift but a larger monster harvest at 26y.
- Every raw level in this surface is set by one or two admissions (MSTR, IPIXQ, MOS,
  DDS on the sibling surface); the honest signals are shared-trade drift and the
  ex-monster delta per salt. Reported that way, the width is a wash-to-positive with
  a regime sign flip, which is precisely what a dial, not a default, looks like.
- Faithfulness: the percentage fallback is the trader's tool in Weinstein's framing
  (§5.3, with the investor caveat surfaced in the #2658 review); keeping the floor of
  the band as the default and exposing the ceiling as a preset dial is the
  book-consistent arrangement (`weinstein-faithful-core.md` dials list, item
  "Exit aggressiveness / numeric thresholds").
