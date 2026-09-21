# Index-stage veto on the PIT band — P0 #1 of the 09-17 queue (2026-09-16)

**Status: PRE-REGISTERED** (written 17:10 PT 2026-09-16, before the mechanism merged and before any cell ran). One arm,
three salts, paired against the committed PIT record null.

## Why

- `pit-universe-2026-09-14/README.md` §"Drawdown dissection": the band's NAV is one episode (late-2021 peak → 2024/25
  trough, −38..−53 % on every arm). The largest universe-independent mechanism found is that **`Macro.analyze`'s composite
  outvotes a Stage-4 primary index**: in 2022 SPX closed below a falling 30-week MA from 01-21 through November, yet the
  weekly `trend` read Bullish for 25+ weeks (index-stage weight 3.0 vs 7.0 of breadth-type gauges; `confidence > 0.65`).
  126 entries in 2022 (103–117 per salt under a Bullish label), 82 % losers, median hold 15 d vs 37, −$0.8M per salt.
- Book check (tier 2, local, 2026-09-16; written back to `docs/design/weinstein-book-reference.md` §2.1 "Resolved
  2026-09-16", PR #2861): the index's Stage-4 breakdown is an explicit, unconditional suspension of new buying — Ch. 8
  "Stage Analysis for the Market Averages", "Suspend buying even if you see a few stocks breaking out on their charts".
  Stage 3 is caution only. So the veto is a **faithful dial** (`weinstein-faithful-core.md` W2, tightening spine item 6),
  not an invented mechanism.
- Standing priors this arm must respect: `project_edge_is_the_fat_tail` (a gate that also blocks the 2009 / 2003 / 2020
  re-entries can lose more than the 2022 cohort it saves — hence the per-episode read below);
  `project_deteriorating_gate_reject` (a regime label on admission was anti-predictive — but that label was a breadth
  composite; this one is the book's primary gauge, and the 2022 cohort is where the composite and the index disagreed).

## Mechanism (lands first, default-off — `experiment-flag-discipline.md` R1/R2)

`index_stage_veto_blocks_longs : bool [@sexp.default false]` on `Weinstein_strategy.config` (PR: feat/index-stage-veto,
branch of 2026-09-16). A pure extra conjunct on the long admission gate — fresh candidates via `screening_config` and the
F2 resting-ticket re-screen, exactly like `deteriorating_blocks_longs` (#2755) — that rejects longs while
`Macro.result.index_stage.stage = Stage4 _`. `trend`, shorts, halts, the macro-bearish trim and `breadth_state` are
untouched: the composite keeps governing aggressiveness. Default-off is bit-identical (goldens unchanged, CI).

## Arm (specs/, run by chain-veto.sh from a pinned worktree `sweep-veto` built off main after the flag merged)

| arm | change vs `a0-pit-null` | pairs against |
|---|---|---|
| `v1-index-veto` | `((index_stage_veto_blocks_longs true))` — nothing else | committed `pit-universe-2026-09-14/step4/results/a0-pit-null-s{0,1,2}-v11-*` |

The null is NOT re-run (6.3 h/cell). Build drift between the null's build (3a20f4987) and the arm's is runtime-inert by
inspection: 11 commits under `trading/` — harness / orchestrator / codex fixes (#2852 #2855 #2842 #2841 #2834 #2836
#2830 #2821), the scheduled smoke golden #2846 (CI-only, its golden re-pinned bit-identical), the record artifacts #2843,
and the trade-audit R7 pin #2813 (reporting only) — plus the veto PR itself, whose default-off path is bit-identical.
Same warehouse (`/tmp/snap_top3000_pit_v11pit`, 9,364 entries — the chain aborts on any other count), same 27 as-run
composition lists, same `CELL_TIMEOUT=36000`, one lane. Pairing gate: `validator_diff -check V6` exit 0 on every pair
(the chain runs it per cell against the committed null report; V6 = 0 on every null salt).

## Pre-registered decision rule

**The arm clears if realised P&L AND Calmar are both better than the null at ≥ 2 of 3 salts** (same rule as the 09-13
concentration probe). MaxDD, Sharpe, level, trade count, exit mix and open-MTM are reported; level is not a criterion
(the null's salt-0 level is a salt-lottery top). A clearing arm is an ACCEPT for the *mechanism* on this base; promotion
to default-on still needs the grid (`promotion-confirmation.md`: broad-vs-broad breadth tier + a period-disjoint cell)
and the paired-golden table (`config-default-blast-radius.md`). A failing arm is a REJECT-as-default; the flag stays an
axis unless the mechanism read says do-not-revive.

**Mechanism read (the number this arm exists to produce):** `symbol|entry_date` join of the arm's and null's
`trades.csv` per salt → shared / null-only / arm-only, then the **2022 entry cohort** (null: 126 entries pooled, 82 %
losers, −$2.43M): how many of those entries the veto removed, their P&L, and what the freed cash bought instead
(arm-only entries dated 2022–23 and their P&L). Per entry-year realised for both arms.

**Re-entry cost, read per episode so a 2022 win is not bought with a slower recovery:** paired entries and P&L for
2003 (post dot-com Stage-1 → 2 turn), 2009 (post-GFC), 2020 (COVID V) and 2022–23 — the four windows where the index
leaves Stage 4. If the veto removes the 2009 / 2020 re-entry cohort's winners, that is the fat-tail tax
(`project_edge_is_the_fat_tail`) and the arm is not promotable even if 2022 clears. Also: number of screening weeks per
salt on which the veto fired while `trend` was Bullish/Neutral (the composite-vs-index disagreement weeks), from
`macro_trend.sexp` + the SPX weekly stage (the arm's `trade_audit.sexp` records the rejection reason where available).

## Cost / ops

~6.3 h per cell, one lane (single worker sits at 5.5–6.5 GB); ~19 h for the arm. Container-exclusive: no agent
dispatches while a cell runs (`container-capacity-scheduling.md` rule 1). Specs staged at `/tmp/veto-run/specs`
(outside any VCS tree), artifacts at `/tmp/sweeps/index-veto/` (bind-mounted), per-cell raw artifacts committed to
`results/` after each cell (`feedback_commit_raw_per_arm_artifacts`: never read a number from the chain log).

## Log

(cells append here as they finish)

- 2026-09-20 02:34 PT — **launched** (lane A, salts 0 → 1 → 2, one worker). Mechanism merged as #2863 (`5577d418a`,
  two commits: the flag + a rework pinning the fresh-candidate wiring after qc-behavioral proved M2/M3 mutations
  survived the suite); #2823 twin-detector guards merged alongside as #2862 (default-off, warehouse untouched). Pinned
  worktree `sweep-veto` @ `5577d418a`; build drift vs the null's `3a20f4987` is the list in §Arm plus #2862/#2863,
  both default-off. **Smoke** (same build, spec with `end_date 2000-04-28`, salt 0): exit 0, `params.sexp` reads
  `index_stage_veto_blocks_longs true`, 10 trades, +3.17 % — the flag resolves through `Overlay_validator` and the
  PIT schedule + `_v11pit` warehouse path works on this build. Chain script staged at `/tmp/veto-run/chain-veto.sh`
  (copy of the committed one), specs at `/tmp/veto-run/specs`, artifacts `/tmp/sweeps/index-veto/`, launch log
  `/tmp/veto-run/launch-A.log`. The warmup year (1999) alone costs ~18 min of weekly classification over 9,915
  symbols, which is where the 6.3 h/cell goes. Ops note: a `dune build` started through a harness-backgrounded
  `docker exec` hung in `futex_wait` at 0 % CPU for 34 min; killed and relaunched detached (`docker exec -d … nohup`)
  — build long things detached from the start.

- 2026-09-20 11:08 PT — **v1-index-veto, salt 0** (wall 30,789 s = 8h33m vs the null's 5h58m; `results/v1-index-veto-s0-v11-*`)
  vs the committed `a0-pit-null-s0-v11`. `params.sexp` reads `index_stage_veto_blocks_longs true`; V6 = 0 on both,
  `validator_diff -check V6` exit 0; V16 2 fallback exits (same CLE/ASPS quality flags as the null); `macro_trend.sexp`
  byte-identical to the null's (398 Bearish / 748 Bullish / 189 Neutral weeks — the composite is untouched, as designed).
  Level **457.0 → 344.7**, trades 732 → 703, Sharpe 0.482 → 0.443, **maxDD 40.6 → 33.5** (episode 2021-11-29 → 2024-08-05
  on the null becomes 2022-01-03 → 2023-10-27 on the arm), **Calmar 0.165 → 0.173**, **realised $3.85M → $2.77M
  (−$1.08M)**, end NAV $5.57M → $4.45M, open 5 → 6 names. **Fails the realised criterion, clears Calmar** at this salt.
  Exit mix stop_loss 495 → 483, laggard 221 → 206.
  Join (`symbol|entry_date`): **602 shared** (+$2.557M → +$2.553M, no drift), null-only 130 (+$1.29M), arm-only 101
  (+$0.22M). **Trade-for-trade identical 2000-01 → 2018-11**; first divergence MLNX 2018-11-17 (Q4-2018 correction),
  then CCOI 2020-03-21. Per entry-year: 2018 −$260k → −$245k; **2020 +$1.84M → +$1.32M**; 2021 −$212k → −$236k;
  **2022 −$818k → −$282k**; 2023 −$134k → −$252k; 2024 −$278k → −$155k; **2025 +$1.17M → +$27k**; 2026 −$330k → −$275k.
  - **2022 cohort (the mechanism read):** 19 null-only entries removed, net **−$485k** on the null (GETY −$118k, RGEN −$77k,
    ALTM −$61k, ADTN −$54k …; only BBSI +$92k and two small winners removed); 2022 goes −$818k → −$282k, the 2022-23
    window −$953k → −$534k. The veto did exactly what the dissection predicted, at this salt.
    *(Net restated 2026-09-21 under the uniform `symbol|entry_date` key — see §Correction note; the entry count is
    unchanged at 19, the net was first logged as −$524k.)*
  - **2020 re-entry episode** *(window corrected 2026-09-21; see §Correction note)*: on the fixed
    **2020-03-15 → 05-31** window — the same one used at salts 1–2 — the blocked re-entry cohort here is **12 null-only
    entries, +$563k**, the *largest* of the three salts. It is dominated by **ZS 05-29 (+$492k)** and LACO 05-27 (+$74k);
    the 03-21 → 04-29 sub-window alone (CCOI −$41k, CTXS +$30k, KR +$30k, GC +$22k, GIS +$24k, EGOV −$39k, GEAR −$29k,
    CPB −$17k, MRNA +$9k, MOH +$7k) nets ≈ −$3k. **The 2020 re-entry block costs real money at this salt too** — the
    earlier "the cohort was flat / monster lottery, not mechanism" read came from measuring salt 0 on the narrow
    sub-window. What remains after the cohort is genuine path divergence, and at this salt it runs the arm's way:
    Jun–Dec 2020 null-only is 10 entries +$869k (BBBY 07-01 +$518k, GME 09-14 +$326k) against arm-only 13 entries
    +$1.01M (APPS 06-13 +$498k, TTEC 08-04 +$463k, FCNCA 11-16 +$188k). So the 2020 entry-year gap (−$516k) is the
    re-entry tax, not the funding lottery (`project_funding_grid_monster_lottery`) it was first read as.
  - **2025 (−$1.15M) is ONE trade and not the veto:** ECHO 2025-08-26 (+$647k on the null) was screened by the arm at
    score 110 and skipped `Insufficient_cash` — the arm's book was fuller that week. 2003 / 2009 episodes: identical
    (the composite was already Bearish in every deep-bear Stage-4 week — see the proxy below), so no re-entry cost there.
  - **Where the veto can bite (proxy, not the classifier):** weekly SPX close below a falling 30-week SMA crossed with the
    run's composite trend. Deep bears: 2001 25 proxy-Stage-4 weeks / **0** not-Bearish, 2002 27 / 1, 2008 35 / 2 — the
    composite already blocked buys, the veto is redundant. Modern regime: 2018 17 / **12**, 2020 9 / 9, 2022 26 / **10**,
    2023 14 / **14**, 2025 9 / 8, 2026 7 / 7 — the disagreement weeks are all post-2017, which is why the two runs are
    identical for 18 years. The audit records no gate-rejection marker for the veto (0 hits) — a diagnostic gap.
  - **Read at one salt:** ex-ECHO the realised gap is ≈ −$430k, made of the 2020 entry-year gap (−$516k — mostly the
    blocked re-entry cohort, see above) and 2023 (−$118k) against the 2022 save (+$536k). The drawdown improvement is
    real (33.5 vs 40.6, shorter episode). Salts 1–2 decide whether the 2022 save is a property and whether the 2020
    re-entry tax reproduces.
  - **MTM (added 11:30 PT):** end NAV $5.57M → $4.45M (−$1.12M) is realised, not marks — unrealised on the open book is
    $0.92M (5 names, $4.12M market value) vs $0.86M (6 names, $4.26M). Year-end NAV diff: 2019 +$0.02M, **2020 −$1.02M**
    (the blocked re-entry cohort, then path divergence), 2021 −$0.53M, **2022 +$0.07M**, 2023 −$0.17M, 2024 −$0.01M, **2025 −$0.92M** (ECHO),
    2026 −$1.12M. **The maxDD improvement is half a lower-peak artifact:** both curves bottom at the same $3.54M on
    2023-10-27; the arm's % is smaller because its peak was $5.32M vs $5.94M (no ZS/BBBY/GME). The real protection is the
    2024 leg — 2024-08-05 the arm sits at $4.01M vs the null's $3.53M trough (+$0.48M), and from the 2022-01 peak to
    YE-2022 the arm gave back $0.97M vs $1.57M. So at this salt: 2022–24 capital protection is real (≈ +$0.5–0.6M at the
    trough), the level and peak are draws. Judge Calmar on the trough-to-peak decomposition at salts 1–2, not on the
    ratio alone.

## Runtime read (2026-09-20 12:40 PT) — where the 6–8.5 h/cell goes

`Panel_runner`'s end-of-run cache line, same `SNAPSHOT_CACHE_MB=1024` everywhere:

| cell | n_symbols | hits | misses | evictions | misses/symbol | misses/symbol/sim-year |
|---|---:|---:|---:|---:|---:|---:|
| dg-5y-2019 (2000-vintage wh, 6 sim-years) | 3,015 | 4.40M | 8.08M | 6.07M | 2,678 | 446 |
| dg-26y / arc26y (2000-vintage, 27 sim-years) | 3,015 | 18.4M / 17.1M | 36.8M / 36.6M | 35.6M / 35.4M | 12,205 / 12,132 | 452 / 449 |
| a0-pit-null s0 (_v11pit, 27) | 9,915 | 41.5M | 118.5M | 112.2M | 11,951 | 443 |
| v1-index-veto s0 (_v11pit, 27) | 9,915 | 41.4M | 118.5M | 112.2M | 11,951 | 443 |

- **The 1 GB decoded-panel LRU thrashes at every scale: 65–74 % miss rate, ~450 re-decodes per symbol per simulated
  year, evictions ≈ misses.** The streaming design does its job for the heap (anon stays 2.2–3.5 GB; nothing holds 27
  years) — but the cap is far below the weekly working set (n_symbols × the 130/520-week lookbacks), so nearly every
  weekly read is a re-decode from the mmap. Misses are **linear in years and linear in symbols** (3.3× symbols → 3.2×
  misses): this is the #2839 cost, and it is a cache-size problem, not an algorithmic one.
- **Null and arm are identical to four digits** (118.5M misses both). The arm's 43 % extra wall at salt 0 is therefore
  per-miss cost, not more work: whether a re-decode hits the VM page cache or the disk. Same mechanism explains the
  same-list 5y-vs-26y superlinearity (446 vs 452 misses/symbol/year — identical — yet 3.6 vs 5.6 min/year): a 6-year
  footprint stays page-cached, a 27-year footprint scrolls out of it. The 09-06 26y cells ran sequentially (no lane
  overlap), so contention is ruled out for that pair.
- **Lever (bit-identical by construction — a cache is a cache):** raise `SNAPSHOT_CACHE_MB` for PIT cells. The worker's
  anon heap is 2.2–3.5 GB on a 7.75 GB container, so 3–4 GB of cache is available with one worker. To test after this
  lane: the 4-month smoke spec at 1024 vs 3072 vs 4096, compare wall + the cache line; if misses collapse, make it the
  chain default and record it on #2839. Not changed mid-chain (the running script must not be edited; wall time is
  not a criterion).

**Correction (13:05 PT) — the MB cap is the wrong lever on a v2 warehouse.** `_v11pit` is columnar (`SNAPCOL1`, 19,198
files, 3.5 GB). For a v2 entry `Daily_panels` counts only the int32 date array plus a constant against the byte budget,
so the 1 GB `SNAPSHOT_CACHE_MB` never binds; what binds is the hard-coded `_max_open_mmap_handles = 256` in
`daily_panels.ml` (doc: "well under a typical 1024 fd ulimit"). Each weekly pass over 9,915 symbols cycles a 256-entry
LRU, so nearly every read is a miss = `openfile` + `fstat` + whole-file `map_file` + header parse, and every eviction
is `close` + munmap — 118M of each per cell. Neither cap is dynamic; the only statistics are the cumulative
hits/misses/evictions line at the end (no occupancy max/avg, no peak RSS in the chain scripts). Budget for lifting the
cap to ≥ n_symbols: the worker holds 269 fds against a 1,048,576 limit and 54,667 mappings against
`vm.max_map_count` 262,144 (one mapping per reader); heap per reader is the date array (~27 KB) plus a constant, so
~10k readers ≈ 0.3 GB — affordable, bit-identical by construction. Proposed on #2839: make the handle cap an env knob
(`SNAPSHOT_MAX_MMAP_HANDLES`, default 256 = unchanged), set it to 12,000 in the chain scripts, measure on the smoke.

- 2026-09-20 21:08 PT — **salt 1 LOST: killed by the chain's own `timeout 36000` guard** (`exit=124`, wall 36,015 s, no
  `actual.sexp`). Progress marker at the kill: 1,326 / 1,434 cycles (92.5 %), last completed date 2024-05-31, 629 round
  trips closed, equity $3.37M — ~45–60 min from the end. Not a crash and not contention (load ≈ 1.0, one worker; two
  hung `dune build` processes from the previous session were idle in `S`). Cause: the guard was sized off the null's
  6–7 h and the arm runs ~43 % slower than its null (s0 8h33m vs 5h58m); null s1 is itself the slowest salt (7h05m), so
  the arm's s1 projected to ~10h08m. Salt 2 auto-started on the same guard and was killed at 88 s; lane A closed.
  Decision (user, 21:15 PT): do not relaunch on the old guard — build the mmap-handle knob first (#2839:
  `SNAPSHOT_MAX_MMAP_HANDLES`, default 256), measure it on the 4-month smoke at 256 vs 12,000, then run salts 1 → 2 on
  the knob build with the cap ≥ n_symbols and `CELL_TIMEOUT` sized from the measured arm. Salt 0 stays on `5577d418a`;
  salts 1–2 will carry the knob build's SHA — bit-identical by construction (a cache is a cache; eviction changes when a
  file is re-opened, never what it returns) plus the smoke's md5 check, recorded here when they land. Also filed the
  weekly perf-review rule (`.claude/rules/perf-review-weekly.md`, #2881) off this loss.
- 2026-09-20 22:22 PT — **knob smoke (PR #2882 build, `v1-index-veto-smoke.sexp`, salt 0, `SNAPSHOT_CACHE_MB=1024`):**
  cap 256 → 27m23s, 5.64M misses (569 / symbol), 5.34M evictions; cap 12,000 → **6m15s**, 0.31M misses (31 / symbol,
  first touch), **0 evictions**; `actual.sexp` and `trades.csv` md5 identical (10 trades, +3.17 %). 4.4× on the
  4-month smoke with the same output byte-for-byte — the bit-identical claim is now measured, not just constructed.
  Lanes B+ run at cap 12,000 (`chain-veto.sh` default) once #2882 is on main and the pinned worktree is rebuilt.
- 2026-09-20 22:53 PT — **lane B launched** (salts 1 → 2, one worker) on pinned worktree `sweep-veto2` @ `477522b7c` (= main
  after #2882), `SNAPSHOT_MAX_MMAP_HANDLES=12000`, `CELL_TIMEOUT` 60,000 s, same staged spec / warehouse (9,364 entries)
  / null artifacts as lane A. Build drift vs salt 0's `5577d418a`: #2881 (docs), #2882 (the cache knob — smoke-verified
  byte-identical above). The worker's cache line confirms the cap (`max mmap handles = 12000`). Expected: each cell well
  under salt 0's 8h33m; the first cell's wall + `snapshot cache hits=…` line is the 26y measurement for #2839.

- 2026-09-21 03:12 PT — **v1-index-veto, salt 1** (lane B, knob build `477522b7c`, cap 12,000; **wall 15,523 s = 4h19m** vs the
  cap-256 attempt killed at 36,000 s with 7.5 % left; cache line `hits=153.8M misses=6.30M evictions=0` — the residual
  misses are the ~551 universe names absent from the 9,364-entry manifest, counted as misses on every read, not
  reopens; `results/v1-index-veto-s1-v11-*`) vs the committed `a0-pit-null-s1-v11`. `params.sexp` reads
  `index_stage_veto_blocks_longs true`; V6 = 0 both, `validator_diff -check V6` exit 0; V16 = 1 (CLE 2014
  force_liquidation, the null's flag); `macro_trend.sexp` md5 identical to salt 0's (composite untouched).
  Level **188.0 → 308.8**, trades 766 → 705, Sharpe 0.329 → 0.417, **maxDD 53.0 → 40.6**, **Calmar 0.077 → 0.135**,
  **realised $1.67M → $2.66M (+$0.99M)**, end NAV $2.88M → $4.09M, unrealised $0.41M → $0.60M. **Clears BOTH criteria at
  this salt** (salt 0: realised fails, Calmar clears). Exit mix stop_loss 530 → 482, laggard 223 → 211.
  Join (`symbol|entry_date`): **619 shared** (+$1.476M → +$1.566M), null-only 147 (+$0.20M), arm-only 86 (+$1.09M).
  **Trade-identical 2000 → 2018** again; first divergence 2019 (28 → 27 entries). Per entry-year: **2020 +$1.46M →
  +$0.71M (−$0.76M)**; 2021 −$172k → −$308k; **2022 −$828k → −$525k (+$303k)**; 2023 −$222k → −$48k (+$174k);
  **2024 −$795k → −$303k (+$492k)**; **2025 +$55k → +$612k (+$557k)**; 2026 −$405k → −$94k (+$311k).
  - **2022 cohort (the mechanism read, 2nd salt):** **17** null-only 2022 entries removed, net **−$357k** (count and net
    restated 2026-09-21 under the uniform `symbol|entry_date` key; first logged as 13), losers GETY −$109k, ALTM −$55k,
    ADTN −$50k, ESTA −$38k, NXE −$36k …, winners removed STLD +$46k, ISEE +$16k; the 2022–23 window −$1.05M → −$574k
    (+$477k). Same direction and similar size as salt 0 (+$419k on the window) — **the 2022 save is a property, not a draw.**
  - **2020 (the cost, 2nd salt):** null-only 2020 = 31 entries, **+$1.64M** — BBBY +$503k, ZS +$475k, GME +$304k, WSC +$271k,
    COHR +$154k; the arm's replacements TTEC +$454k, SNBR +$370k, AVGO +$181k. The blocked Mar-15 → May-31 re-entry
    cohort is 12 entries **+$466k** at this salt (ZS 05-29 inside it) vs **+$563k** at salt 0 on the same window
    (12 entries; the "≈ −$3k" first logged at salt 0 was the narrower 03-21 → 04-29 sub-window — corrected 2026-09-21,
    see §Correction note) — so the veto's 2020 re-entry block costs real money at both salts, not just
    path divergence. 2003 / 2009: identical both salts.
  - **2025 (+$557k) is ONE trade again, on the other side this time:** ECHO 2025-08-26 is **arm-only +$652k** here (at salt 0 it
    was null-only +$647k, skipped by the arm on `Insufficient_cash`). A lottery ticket that switches arms across salts;
    **ex-ECHO the realised gap is +$334k**, made of 2022–24 protection (+$0.97M) against the 2020 monsters (−$0.76M).
  - **MTM / maxDD decomposition:** null peak 2021-02-11 $5.52M → trough 2025-04-07 $2.59M (53.0 %); arm peak **2018-01-26
    $4.62M** → trough 2025-06-10 $2.74M (40.6 %). The arm never made the 2020–21 highs, so most of the ratio gain is a
    lower peak; the real protection is smaller — at the null's trough date the arm holds $2.77M vs $2.59M (**+$0.18M**),
    and the 2022-01 → YE-2022 give-back is $1.06M vs $1.49M. YE NAV diff: 2019 +$0.04M, **2020 −$1.23M**, 2021 −$0.94M,
    2022 −$0.54M, 2023 −$0.27M, 2024 +$0.09M, 2025 +$0.77M (ECHO), 2026 +$1.21M.
  - **Two-salt read:** 2022–24 capital protection reproduces (+$0.4–0.6M realised on the 2022–23 window, smaller give-back,
    higher NAV at the null's trough, both salts); the 2020 cost reproduces (−$0.52M entry-year at s0 around a +$0.56M
    blocked re-entry cohort, −$0.76M around a +$0.47M cohort at s1); the level/realised verdict is decided by monster tickets (ZS/BBBY/GME vs
    TTEC/SNBR, ECHO's side). Pre-registered rule needs realised AND Calmar at ≥ 2/3 salts: s0 = Calmar only, s1 = both.
    **Salt 2 decides** (running since 03:12 PT, ETA ~07:30). Whatever it says, the mechanism read is already: a 2022-style
    grind is where the veto earns, a 2020-style V-recovery is where it pays, and the fat-tail tax on the recovery is
    real at one salt of two.

- 2026-09-21 06:49 PT — **v1-index-veto, salt 2** (lane B, knob build; **wall 13,003 s = 3h37m**; cache `misses=6.30M evictions=0`;
  `results/v1-index-veto-s2-v11-*`) vs the committed `a0-pit-null-s2-v11`. `params.sexp` reads the flag true; V6 = 0 both,
  `validator_diff -check V6` exit 0; V16 = 2 (CLE 2014, ASPS 2017 — the null's flags); `macro_trend.sexp` md5 identical.
  Level **152.0 → 141.9**, trades 762 → 716, Sharpe 0.297 → 0.292, maxDD 51.3 → 46.2, Calmar 0.069 → 0.073,
  **realised $1.40M → $0.97M (−$0.43M) — FAILS**, end NAV $2.52M → $2.42M, unrealised $0.29M → $0.58M.
  Join: 632 shared (+$0.64M → +$0.93M), null-only 130 (**+$0.76M**), arm-only 84 (+$0.04M). Trade-identical 2000 → 2019
  (first divergence 2020). Per entry-year: **2020 +$1.58M → +$0.22M (−$1.35M)**; 2021 −$241k → −$129k; **2022 −$785k →
  −$300k (+$485k)**; 2023 −$319k → −$248k; 2024 −$319k → −$268k; 2025 +$27k → +$134k; 2026 −$230k → −$131k.
  - **2022 cohort (3rd salt):** **15** null-only 2022 entries removed, net **−$444k** (count and net restated 2026-09-21
    under the uniform `symbol|entry_date` key; first logged as 11, which was the stricter "symbol absent from the arm
    entirely" definition) — GETY −$89k, ALTM −$50k, ADTN −$41k, ESTA −$41k, BHRB −$40k, CCJ −$39k, FNB −$37k, AMBA −$31k;
    no real winners removed (QDEL +$5k only); 2022–23 window −$1.10M → −$0.55M (**+$556k**). Three for three.
  - **2020 (3rd salt):** null-only 2020 = 28 entries **+$1.66M** (BBWI +$460k, BBBY +$379k, ZS +$359k, SNBR +$325k, WIT +$191k);
    the arm's replacements TTEC +$332k, AVGO +$131k. Blocked Mar-15 → May-31 re-entry cohort: 13 entries **+$329k**
    (ZS inside it again). ECHO 2025 is in neither arm at this salt.
  - **MTM:** null peak 2021-11-09 $4.66M → trough 2025-04-07 $2.27M (51.3 %); arm peak **2018-09-20 $3.21M** → trough
    2025-04-07 **$1.73M** (46.2 %). The arm's dollar trough is $0.54M *below* the null's on the same day; the Calmar / maxDD
    "win" here is entirely the lower peak. YE NAV diff negative every year from 2020 (−$1.02M) to 2026 (−$0.10M).
    2022 give-back $0.69M vs $1.51M — the grind protection is real, it just protects a smaller book.

## Correction note (2026-09-21, from the qc-behavioral review of #2884 — `dev/reviews/index-stage-veto.md`)

Three bookkeeping corrections to the log above. **No cell was re-run**; every corrected figure is re-derived from the
per-salt `results/*-trades.csv` committed in this PR joined against the committed null
(`pit-universe-2026-09-14/step4/results/a0-pit-null-s{0,1,2}-v11-trades.csv`) on `symbol|entry_date` — zero duplicate
keys in any of the six files, so the join is exact. The verdict and its Rule-4 classification are unchanged; both
corrections **strengthen** the read.

1. **The 2020 blocked re-entry cohort is now measured on one window at all three salts.** Salt 0 was first logged on a
   narrower **2020-03-21 → 04-29** window (10 entries, ≈ −$3k) while salts 1–2 used **2020-03-15 → 05-31** (12 and 13
   entries), and the three were then quoted as a comparable triple. They were not comparable. The narrow window cannot
   be defended on mechanism grounds: `macro_trend.sexp` is md5-identical across all three salts, so the veto's firing
   weeks are salt-independent — 2020-05-29 is a veto week at every salt or at none, and ZS enters null-only at exactly
   that date at all three. On the common window salt 0 is **12 entries / +$563,394**, the *largest* of the three; the
   two entries the narrow window dropped are LACO 05-27 (+$74,122) and ZS 05-29 (+$492,371). Corrected triple:
   **+$0.56M / +$0.47M / +$0.33M**. Consequence for the read: the 2020 re-entry tax is a property at **3/3 salts**,
   symmetric with the 2022 grind save at 3/3 — not a salt-0 draw.
2. **2022 removed-entry counts restated under the uniform key.** 19 / 13 / 11 as first logged mixed two definitions;
   under `symbol|entry_date` throughout it is **19 / 17 / 15**, nets **−$484,629 / −$357,130 / −$444,311** (salt 0's
   net was first logged as −$524k). Salt 2's "11" was the stricter "symbol absent from the arm entirely" count; salt 1's
   "13" matched neither definition. Every *named* trade in all three lists, and the load-bearing 2022–23 window deltas
   (+$418k / +$477k / +$556k), reproduce exactly — this is a counting-key artifact, not a data error.
3. **The NAV peak / trough / give-back figures are not re-derivable from this PR.** They come from the chain's
   `equity_curve.csv`, which `chain-veto.sh` copies to the artifact dir but which was not committed into `results/` and
   is not recoverable without re-running a cell (the run machine is not this one). Treat every peak/trough/give-back
   number in the log as **asserted, not artifact-backed**, including the lower-peak argument that discounts the Calmar
   3/3 clear. The verdict does not rest on it: realised fails the conjunctive rule at 2/3 salts however Calmar is read.
   Future chains in this family should commit `*-equity_curve.csv` alongside `*-trades.csv`.

## Verdict (2026-09-21, pre-registered rule: realised AND Calmar better than the null at ≥ 2 of 3 salts)

| salt | level null → arm | realised null → arm | maxDD | Calmar | both? | wall (arm) |
|---|---|---|---|---|---|---|
| 0 | 457.0 → 344.7 | $3.85M → $2.77M (**fail**) | 40.6 → 33.5 | 0.165 → 0.173 (clear) | no | 8h33m (cap 256) |
| 1 | 188.0 → 308.8 | $1.67M → $2.66M (clear) | 53.0 → 40.6 | 0.077 → 0.135 (clear) | **yes** | 4h19m (cap 12k) |
| 2 | 152.0 → 141.9 | $1.40M → $0.97M (**fail**) | 51.3 → 46.2 | 0.069 → 0.073 (clear) | no | 3h37m (cap 12k) |

**REJECT-as-default, keep as an axis.** Realised clears 1/3; Calmar clears 3/3 but at salts 0 and 2 the ratio gain is a
lower-peak artifact (the arm never makes the 2020–21 highs; at salt 2 its dollar trough is $0.54M *below* the null's).
`index_stage_veto_blocks_longs` stays default-off. Not do-not-revive: the book is unambiguous that a Stage-4 primary
index suspends buying (§2.1, #2861), and the mechanism does exactly what it says.

**Why (the transferable read, 3/3 salts each):**
- **Where it earns — the 2022 grind.** The composite stayed Bullish for 25+ weeks of 2022 while SPX sat below a falling
  30-week MA; the veto removes 15–19 entries a year that lose −$0.36M to −$0.48M net, and the 2022–23 window improves +$0.42M /
  +$0.48M / +$0.56M. The 2022 give-back halves. This is the property, and it is exactly the PIT-drawdown episode that
  motivated the arm (`project_pit_drawdown_2021_25_macro_veto`).
- **Where it pays — the 2020 V-recovery.** The index is still Stage 4 for 9–12 weeks after the March-2020 low while the
  composite has already turned; on the fixed **2020-03-15 → 05-31** window the blocked re-entry cohort is worth
  **+$0.56M / +$0.47M / +$0.33M** (12 / 12 / 13 null-only entries; net of the arm-only substitutes bought in the same
  window, +$0.61M / +$0.49M / +$0.36M), and the path divergence that follows costs the arm the 2020 monsters
  (ZS, BBBY, GME, BBWI, SNBR: −$0.5M / −$0.76M / −$1.35M by entry-year). The 2020 payoff is the fat tail the whole edge
  lives on (`project_edge_is_the_fat_tail`); a gate that is late by a quarter at the bottom taxes it every time.
  **The two legs are symmetric at 3/3 salts** — the 2022 grind save reproduces at every salt and so does the 2020
  re-entry tax. The veto is not a mechanism that sometimes earns for free: it both earns and pays, every salt, which is
  what makes this a clean REJECT-as-default rather than a salt-dependent draw.
- **2001–02 and 2008 are inert** — the composite was already Bearish in every deep-bear Stage-4 week, so the veto never
  fires there (trade-identical 2000 → 2018/2019 at every salt). The disagreement weeks are all post-2017.
- **The level is a monster lottery on top of that** (ECHO 2025 on the null's side at s0, the arm's at s1, absent at s2).
  Never quote the salt-1 +121pp or the salt-0 −112pp as the mechanism.

**Forward guidance.** The veto is a *regime dial*, not a default: it trades 2020-style recovery upside for 2022-style
grind protection, one-for-one in dollars at these salts. It belongs in a drawdown-averse (investor) preset. A faster
re-admission is the obvious pairing, but **the cheap version of it is not book-faithful**: lifting the veto when the
index merely *closes above* a still-falling MA is settled against by tier 1 — `weinstein-book-reference.md` §2.1
("Resolved 2026-09-16"), the same entry this arm cites for its own faithfulness, says it is "not enough for the
industrials to temporarily pop above the MA … if the average continues pointing lower", and that one buys
aggressively only once "the levelled MA is penetrated on the upside". This is **not** an open book question. A faithful
faster-re-admission dial would therefore key off the MA *levelling* (slope crossing up through flat), not a price
cross, and would need a different formulation from the one sketched here. Not another single-lever screen on this base.

**Runtime (#2839):** the cap-256 arm cell was 8h33m (s0) and >10h (s1, killed); at cap 12,000 the same cells are 4h19m
and 3h37m — misses 118.5M → 6.3M, evictions 112M → 0. Chain default is now 12,000.
