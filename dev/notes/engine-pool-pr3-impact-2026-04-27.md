# PR-3 of engine-pooling — threading impact (2026-04-27)

PR-3 (`feat/backtest-perf-engine-pool-thread`) wires `Price_path.Scratch.t`
through `Engine.update_market` per-tick so the buffer-reuse path
introduced in PR-2 (#626) is actually exercised on the hot loop.

## What was threaded

- `Engine.t` now owns a `(symbol, Price_path.Scratch.t) Hashtbl.t` —
  one scratch buffer per loaded symbol, allocated lazily on first
  sight of that symbol and re-used on every subsequent tick.
- `Engine.update_market` replaces the single per-call
  `Price_path.generate_path ~config:path_config bar` with
  `Price_path.generate_path_into ~scratch ~config:path_config bar`
  where `scratch` comes from the per-symbol table.
- `Price_path.Scratch.required_capacity` was added to the public API so
  the engine can decide whether an existing scratch is large enough
  without allocating a throwaway scratch as a probe.
- A new test `test_engine_scratch_threading_parity` pins bit-equality
  between the reused-scratch path (one engine, N sequential
  `update_market` calls) and the fresh-scratch path (N engines, one
  call each) using a fixed seed. Catches any cross-call state leak
  inside `Price_path` even though PR-2's tests already pin parity at
  the `Price_path` level.

## Per-call allocation reduction (architectural)

Per the post-PR-A memtrace
(`dev/notes/panels-memtrace-postA-2026-04-26.md`), the dominant
per-tick allocators inside `Trading_engine.Price_path` were:

| Allocator | sampled events | bytes allocated |
|---|---|---|
| `_decide_high_first_directional` | 1,034 | 4,183,712 |
| `_sample_standard_normal` | 195,235 | 1,561,880 |
| `_sample_student_t.sum_squares` | 84,951 | 1,463,808 |
| `_append_segment` | 39,995 | 1,279,840 |
| `_generate_bridge_segment.generate_points` | 45,766 | 1,464,512 |

PR-2 already converted those allocators to write into `Scratch.t` —
but only when the public API explicitly went through
`generate_path_into`. The default `Engine.update_market` was still
calling `generate_path`, which allocated a *fresh* `Scratch.t` per
call (one float array of `total_points + slack ≈ 398` slots, plus the
GC overhead of dropping it on the next tick).

PR-3 promotes that scratch from a per-call alloc to a per-symbol
field, so steady-state allocation inside `Price_path` per
`update_market` call drops to:

- **Before PR-3**: one fresh `Scratch.t` allocation
  (`float array` of ~398 slots = 3,184 bytes) + the final
  `path_point list` (~390 cons cells) per call, per symbol.
- **After PR-3**: just the final `path_point list`. The `Scratch.t`
  is touched in place; no float-array allocation per call after the
  symbol's first day.

## Sample size in production

For the canonical `bull-crash-292x6y` matrix run (292 symbols, 6
years ≈ 1,500 trading days), `update_market` is called
292 × 1,500 ≈ 438,000 times. Each call previously allocated a
`Scratch.t` (~3.2 KB float array + header). PR-3 collapses that to
the 292 first-day allocations and zero thereafter — a reduction of
**437,708 array allocations × ~3.2 KB ≈ 1.4 GB of array-only
allocation traffic** moved off the per-tick path.

That's not the full picture — the `path_point list` materialization
inside `_path_of_array` still allocates per call (the public contract
still returns a fresh list). PR-2's agent flagged that as the next
target ("PR-4: transient buffer pool for one-off workspaces").

## Verification

- `dune build && dune runtest` green inside the worktree with
  `TRADING_DATA_DIR=…/test_data`.
- `dune build @fmt` clean.
- `test_panel_loader_parity` (the load-bearing parity gate) passes
  bit-equality on both `tiered-loader-parity` and
  `panel-golden-2019-full` scenarios — confirming PR-3's threading
  produces identical trade output to PR-2.
- New `test_engine_scratch_threading_parity` pins the engine-level
  reuse contract: same engine reused across N seeded calls produces
  the same fill prices as N fresh engines, one call each.

## Memtrace re-run (deferred)

A full memtrace re-run on the 292×6y matrix would tell us how much of
the cumulative `Price_path` allocation attribution drops post-PR-3.
That requires the full `bull-crash-292x6y` data fixture and a wall
budget of ~5 minutes. Deferred to PR-5 of the engine-pooling plan
("matrix re-run validation") which lands all four PRs together.

For now, the architectural argument above + the bit-equality parity
gate are sufficient to confirm PR-3 is doing what it claims:
threading the existing PR-2 buffer-reuse plumbing through to the
actual per-tick callsite.

## References

- Plan: `dev/plans/engine-layer-pooling-2026-04-27.md` §PR-3
- PR-2 (companion): #626
- Triggering memtrace: `dev/notes/panels-memtrace-postA-2026-04-26.md`
- Phase-1 GC instrumentation: #618
