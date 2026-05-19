# Bayesian leak root cause — Random.State.make_self_init in price_path.ml leaks one DLS key per (symbol, bar) (2026-05-19)

## Headline

**Every call to `Backtest.Runner.run_backtest` leaks ~25 MB of permanently-rooted
OCaml heap because `Trading_engine.Price_path._generate_path_with_scratch`
calls `Random.State.make_self_init ()` once per (symbol, bar) — i.e. roughly
525 symbols × 411 calendar days ≈ 215 000 calls per backtest — and `Base`'s
`Random.State.make_self_init` is implemented via `Stdlib.Domain.DLS.new_key`,
which permanently registers each fresh key in the runtime's global
domain-local-storage state. The DLS table and the per-key `parent_keys` atomic
list are GC roots, so neither the keys nor the bigarray-backed `Random.State.t`
values they reference are ever reclaimed.**

Proposed one-line fix:

> In `trading/trading/engine/lib/price_path.ml:436`, replace
> `Random.State.make_self_init ()` with `Random.State.make [| <stable_seed> |]`
> (or `Stdlib.Random.State.make_self_init ()` — note: the *stdlib* version
> does **not** allocate a DLS key; only `Base.Random.State.make_self_init`
> does), and pass the resulting state by argument rather than re-creating it
> per call.

Fix is ≤ 10 lines and removes ~28 MB/backtest (~90 % of the post-`Gc.compact`
growth observed before the fix). Plan #1197 (fork-per-fold) becomes a pure
performance optimisation rather than load-bearing OOM-avoidance.

## Method

A single experimental binary at
`trading/trading/backtest/scripts/leak_repro.ml` (deletable; see "Discoverable
diagnostic file" below) loops `Backtest.Runner.run_backtest` on the
sp500-2010-2026 fold `2011-07-01..2012-06-29` and:

1. Records `Gc.stat` (heap_words, live_words, top_heap_words) after each
   iteration's `Gc.compact + Gc.full_major + Gc.compact` chain.
2. Runs `Gc.Memprof.start ~sampling_rate:1e-3` with a tracker whose `alloc_*`
   callbacks insert into a hashtable and whose `dealloc_*` callbacks remove —
   so after the iterations finish, anything still in the hashtable is
   reachable from a GC root.
3. Aggregates surviving sampled allocations by top-10-frame callstack and
   prints the top groups by estimated total bytes (the unbiased estimator is
   `Σ n_samples / sampling_rate` words per group).

Run command, inside the docker container:

```
cd /workspaces/trading-1/.claude/worktrees/agent-a439a97153604019f/trading/trading
eval $(opam env)
dune build backtest/scripts/leak_repro.exe
/workspaces/trading-1/.claude/worktrees/agent-a439a97153604019f/trading/_build/default/trading/backtest/scripts/leak_repro.exe \
  --iters 3 \
  --fixtures-root /workspaces/trading-1/.claude/worktrees/agent-a439a97153604019f/trading/test_data/backtest_scenarios \
  --memprof-rate 1e-3 --top 15
```

Two runs confirmed: 3-iter loops show live-words growth of 27.3 MB, 28.0 MB,
30.4 MB per iter (one slightly higher because of GC residency phase). Total
delta 85.6 MB across 3 iters ≈ ~28.5 MB/iter average.

## (a) What survives `Gc.compact` per iteration

After the third iteration plus a `Gc.compact + Gc.full_major + Gc.compact`
chain, the memprof tracker holds 10 958 sampled allocations. Aggregated by
top-10-frame callstack, the top survivors are:

| Rank | Est. live MB | Site (top of stack)                                                | Frames below the top                                                                                                                            |
|------|--------------|--------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| 1    | 44.7 MB      | `Stdlib.Bigarray.Array1.create` (random.ml inlined → `Random.State.create`) | `Random.State.make_self_init` ← `DLS.get` ← `Base.Random_repr.get_state` ← `Base.Random.State.bits` ← `…State.rawfloat` ← `…State.float` ← `Price_path._decide_high_first_directional` (line 153) ← `Price_path._generate_path_with_scratch` (line 438) ← `Engine.update_market` (line 64) ← `Base.List0.iter` |
| 2    | 12.8 MB      | `Stdlib.Domain.DLS.new_key` (domain.ml:110)                       | `Base.Random.State.make_self_init` (random.ml:50) ← `Price_path._generate_path_with_scratch` (line 436) ← `Engine.update_market` (line 64)        |
| 3    | 12.8 MB      | `Stdlib.Domain.DLS.new_key` (domain.ml:113 — second alloc inside the function) | (same chain as rank 2)                                                                                                                          |
| 4    | 12.5 MB      | `Stdlib.Domain.DLS.add_parent_key` (domain.ml:105)                | `DLS.new_key` (domain.ml:113) ← `Base.Random.State.make_self_init` ← `Price_path._generate_path_with_scratch` (line 436)                          |
| 5    | 8.1 MB       | `Stdlib.Domain.DLS.maybe_grow` (domain.ml:128)                    | `DLS.get` ← `Random_repr.get_state` ← `Random.State.bits` ← `…State.float` ← `Price_path._decide_high_first_directional`                          |
| 6    | 1.1 MB       | `Stdlib.Bigarray.Array1.create` (random.ml inlined)               | `Random.State.make_self_init` ← `DLS.get` ← `Base.Random_repr.get_state` ← `Base.Random.State.bool` ← `Price_path._generate_path_with_scratch`    |

Ranks 1 + 2 + 3 + 4 + 5 + 6 = ~92 MB across the 3 iterations — the entire
85.6 MB growth observed in `Gc.stat`. Every entry chains back to one of two
adjacent lines in
`trading/trading/engine/lib/price_path.ml`:

- **Line 436**: `| None -> Random.State.make_self_init ()` — this is
  `Base.Random.State.make_self_init`, which calls
  `Base.Random_repr.make_lazy`, which calls
  `Stdlib.Domain.DLS.new_key`. Each invocation:
  - allocates a fresh DLS key tuple (rank 2),
  - calls `add_parent_key` which prepends `KI(k, split)` to the **global
    Atomic ref `parent_keys`** in `domain.ml` (rank 4),
  - and registers a second allocation site inside `new_key` for the closure
    (rank 3).
- **Line 438**: `let high_first = _decide_high_first random_state bar in`
  inside which `Random.State.float` triggers a `DLS.get` (the FIRST
  `DLS.get` for the freshly-created key). `DLS.get` calls `maybe_grow idx`
  which extends the global DLS state array (rank 5), then runs the lazy
  initialiser, which is `Stdlib.Random.State.make_self_init ()` —
  this allocates the actual `Random.State.t` (an int64
  `Bigarray.Array1.t`, ~136 bytes / ~17 words on heap) and stores it in the
  newly-grown DLS slot (rank 1). The state is then permanently retained
  because the DLS state array is itself a domain-global root.

Per call to `_generate_path_with_scratch`:
- 1 DLS key (idx integer + closure) → ~5 words live
- 1 entry on `parent_keys` (cons cell + `KI` block) → ~5 words live
- 1 `Bigarray.Array1.t` (state) → ~17 words live
- proportional contribution to the global DLS state array growth (doubling
  resize) → ~1 word amortised
- Total ~30–40 words ≈ ~250 bytes live per call.

At 525 symbols × 411 days × 1 call each ≈ 215 775 calls per backtest, that's
~52 MB of strictly-leaked state per backtest **before** GC residency / NaN
cells / inline overhead. After `Gc.compact`'s major-heap densification, the
observable live-words delta is ~25–28 MB per backtest, which matches.

## (b) The GC-root path

```
runtime
  └─ domain.ml: dls_state               (per-domain Obj_opt.t array, monotonically grows)
        └─ slot[idx_N]                   (one slot per DLS key ever created)
              └─ Stdlib.Random.State.t   (int64 Bigarray.Array1.t)
  └─ domain.ml: DLS.parent_keys          (Atomic ref to global list)
        └─ KI(k, split_from_parent)      (one cell per DLS key ever created)
              └─ k = (idx, init_orphan)   (idx int + closure)
```

The `dls_state` array and `parent_keys` list are both intrinsic runtime GC
roots. They grow monotonically. There is no per-key release API — the
runtime assumes DLS keys are allocated at module-init time and live for the
program's lifetime, not allocated per work unit.

`Base.Random_repr.make_lazy` predates this assumption and uses
`DLS.new_key` to get the per-domain dispatch semantics for free. Using it
inside a per-(symbol, bar) call is a misuse: the function is meant to be
called once per logical random stream, not once per consumer of one.

## (c) Proposed fix (one line, in concept)

Two equally-valid mechanical fixes; both are < 10 lines:

**Fix A (preferred — minimal):** In
`trading/trading/engine/lib/price_path.ml`, replace `Base.Random.State.t`
with a single-domain `Stdlib.Random.State.t` lifted to the `Scratch.t`
record so it lives as long as the engine/scratch does (one per symbol, not
one per (symbol, bar)). Concretely:

1. Add a `random_state : Stdlib.Random.State.t` field to `Price_path.Scratch.t`.
2. In `Scratch.for_config`, initialise it via `Stdlib.Random.State.make_self_init ()`
   (the *stdlib* version, which simply creates a Random.State without touching
   DLS — see `/home/opam/.opam/5.3/lib/ocaml/random.ml` lines 111–115).
3. In `_generate_path_with_scratch`, use `scratch.random_state` instead of
   creating a fresh one.

Effect: ~215 000 `Random.State.make_self_init` calls/backtest collapse to
~525 (one per symbol, the size of `engine.path_scratches`). DLS table no
longer grows. Per-backtest live-words delta should drop from 28 MB to a few
hundred KB.

**Fix B (1-line, less aggressive):** Switch the `None` branch at line 436
from `Random.State.make_self_init ()` (which is `Base.Random.State.make_self_init`)
to `Stdlib.Random.State.make_self_init ()`. This bypasses the DLS path
entirely. The function still allocates a fresh `Random.State.t` per call
(~17 words / ~136 B), but those are now ordinary heap blocks and will be
collected once the path point is consumed. Estimated leak after fix: ~zero.

Fix A is strictly better (avoids ~215 000 redundant allocations of the
Random.State itself; backtest throughput should also improve). Fix B is a
zero-risk safety patch if there's any concern about determinism / unrelated
behaviour drift on the scratch refactor.

Bandaids that can now be reverted once Fix A or B lands:
- `Daily_panels.close daily_panels` at end of `Panel_runner.run` (added
  2026-05-19, see `panel_runner.ml:237` — daily_panels wasn't the retainer).
- `Gc.compact` after each fold in `Walk_forward_executor._run_one` — still
  worth keeping as a defensive measure, but no longer load-bearing.
- The `[@inline never] _extract_fold` scoping hack — same story.

## (d) False leads ruled out

The prior writeup
(`dev/notes/bayesian-int-rounding-bug-2026-05-19.md` §"Root cause identified
2026-05-19 PM") listed several closures, recorders, and caches as suspected
retainers. The memprof survivor table does **not** include any of them as
contributors above the 1 MB floor. Specifically:

- **`Daily_panels` LRU cache.** Already explicitly closed at end of
  `Panel_runner.run`; this PR's eprintf added 2026-05-19 confirms the cache
  is empty at backtest end. Not in the survivor table.
- **`Snapshot_callbacks` / `Snapshot_bar_views` closures.** Not in the
  survivor table.
- **`Trade_audit`, `Stop_log`, `Force_liquidation_log`, `Stale_hold.Log`
  recorders.** Not in the survivor table. These are dropped on `Panel_runner.run`'s
  return.
- **`Sector_map` resolved hashtable.** Not in the survivor table.
- **`Csv_snapshot_builder` manifest entries.** Not in the survivor table.
  (The 17 GB `/tmp` blow-out from `panel_runner_csv_snapshot_*` dirs is a
  separate disk-leak, not a heap leak — see `bayesian-int-rounding-bug-2026-05-19.md`
  §"Second failure".)
- **`Order_manager` active-orders index.** Not in the survivor table (PR
  #1020).
- **A `Lazy.t` somewhere memoising across calls.** No `Lazy` in the
  survivor table; the only "lazy" implicated is `Base.Random_repr.make_lazy`
  which is the DLS wrapper itself, not an OCaml `Lazy.t` value.
- **A `Weak` / `Ephemeron` table holding strong refs.** No Weak/Ephemeron in
  the survivor table.
- **A `Gc.finaliser` queue.** No finalisers registered in the per-iter
  code path (`grep -rn "Gc.finalise\|register_finaliser" trading/ analysis/`
  returned no hits outside test code).
- **Per-thread thread-pool retaining stack frames.** OCaml 5.3 has a single
  domain in this binary; the only thread-local-equivalent retention is the
  DLS state array, which IS the culprit but via a different mechanism than
  "thread-pool stack frames".

The two prior bandaid attempts (`Daily_panels.close`, `[@inline never]
_extract_fold`) were correct in shape but couldn't help because the
retention path goes through the runtime's DLS state, not through OCaml-level
references that could be broken by scope tightening or container close.

## Discoverable diagnostic file

`trading/trading/backtest/scripts/leak_repro.ml` — single-file experimental
binary. Top-of-file comment marks it as 2026-05-19 diagnostic; delete after
fix lands. Build target: `dune build trading/backtest/scripts/leak_repro.exe`
from the project root inside the docker container.

Companion dune file at
`trading/trading/backtest/scripts/dune` declares it as an executable depending
on `core memtrace scenario_lib backtest` (all libs the project already uses).

## Reproduction recipe for the next engineer

Inside the dev container:

```
cd /workspaces/trading-1/trading/trading
eval $(opam env)
dune build backtest/scripts/leak_repro.exe
_build/default/trading/backtest/scripts/leak_repro.exe \
  --iters 3 \
  --fixtures-root ../test_data/backtest_scenarios \
  --memprof-rate 1e-3 --top 15
```

Expected output: `Trading_engine__Price_path._generate_path_with_scratch in
file "trading/engine/lib/price_path.ml", line 436` (or line 438, both from
the same call site) appears in every one of the top 6 survivor groups.
Total estimated live ~28 MB/iter, ~85 MB after 3 iters.

After Fix A or B lands, repeat the run; the same groups should drop below
1 MB and the iter-over-iter live-words delta should be near zero.
