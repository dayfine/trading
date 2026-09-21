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
  - **2022 cohort (the mechanism read):** 19 null-only entries removed, net −$524k on the null (GETY −$118k, RGEN −$77k,
    ALTM −$61k, ADTN −$54k …; only BBSI +$92k and two small winners removed); 2022 goes −$818k → −$282k, the 2022-23
    window −$953k → −$534k. The veto did exactly what the dissection predicted, at this salt.
  - **2020 re-entry episode:** the veto removed 10 entries dated 03-21 → 04-29 (CCOI −$41k, CTXS +$30k, KR +$30k, GC +$22k,
    GIS +$24k, EGOV −$39k, GEAR −$29k, CPB −$17k, MRNA +$9k, MOH +$7k) — **net ≈ −$3k: the COVID re-entry cohort the veto
    blocks was flat**, not the monster cohort. The 2020 gap (−$516k) is path divergence after that: the null funded ZS
    05-29 (+$492k), BBBY 07-01 (+$518k), GME 09-14 (+$326k); the arm funded APPS 06-13 (+$498k), TTEC 08-04 (+$463k),
    FCNCA 11-16 (+$188k). Monster lottery, not mechanism (`project_funding_grid_monster_lottery`).
  - **2025 (−$1.15M) is ONE trade and not the veto:** ECHO 2025-08-26 (+$647k on the null) was screened by the arm at
    score 110 and skipped `Insufficient_cash` — the arm's book was fuller that week. 2003 / 2009 episodes: identical
    (the composite was already Bearish in every deep-bear Stage-4 week — see the proxy below), so no re-entry cost there.
  - **Where the veto can bite (proxy, not the classifier):** weekly SPX close below a falling 30-week SMA crossed with the
    run's composite trend. Deep bears: 2001 25 proxy-Stage-4 weeks / **0** not-Bearish, 2002 27 / 1, 2008 35 / 2 — the
    composite already blocked buys, the veto is redundant. Modern regime: 2018 17 / **12**, 2020 9 / 9, 2022 26 / **10**,
    2023 14 / **14**, 2025 9 / 8, 2026 7 / 7 — the disagreement weeks are all post-2017, which is why the two runs are
    identical for 18 years. The audit records no gate-rejection marker for the veto (0 hits) — a diagnostic gap.
  - **Read at one salt:** ex-ECHO the realised gap is ≈ −$430k, made of 2020 path divergence (−$516k) and 2023
    (−$118k) against the 2022 save (+$536k). The drawdown improvement is real (33.5 vs 40.6, shorter episode); the level
    loss is a funding lottery. Salts 1–2 decide whether the 2022 save is a property and the 2020/2025 losses are draws.
  - **MTM (added 11:30 PT):** end NAV $5.57M → $4.45M (−$1.12M) is realised, not marks — unrealised on the open book is
    $0.92M (5 names, $4.12M market value) vs $0.86M (6 names, $4.26M). Year-end NAV diff: 2019 +$0.02M, **2020 −$1.02M**
    (the monster funding lottery), 2021 −$0.53M, **2022 +$0.07M**, 2023 −$0.17M, 2024 −$0.01M, **2025 −$0.92M** (ECHO),
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
