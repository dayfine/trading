# Residual nondeterminism after #2279 — 2026-08-12

**PR #2279 fixed one source of backtest nondeterminism. There is at least one
more.** This note records the evidence, the discriminator that reproduces it,
and the prior art that names the likely class — so the next session starts from
a repro rather than from a surprise.

It also corrects the over-claim in that PR's body and in
`dev/notes/backtest-nondeterminism-2026-08-11.md`: "armed runs are now
reproducible" is wrong. What is true is narrower — the unseeded intraday-path
RNG was a real source, it is fixed, and it is not the only one.

## Evidence

Same binary (the #2279 branch), same spec, same env, back to back:

```
R1   total_return_pct 112.75516086084866    total_trades 241
R2   total_return_pct 112.66951221025134    total_trades 240
```

And a third observation from a two-scenario run of the *same* config under a
different name: 112.7 / 240 against an earlier 112.28323995525771 / 240.

## This is a different mechanism from the first one

The **trade count moves** (241 vs 240). The intraday-path RNG could only perturb
fill *prices* within a bar — every pre-fix probe at 302/6y held trades at exactly
259 across four runs while returns spread 0.774pp. A changed trade count is a
changed *decision*: an admission or ordering flip.

That matters for interpretation. Path noise perturbs magnitudes; ordering noise
changes which candidates get funded, which is a much bigger lever in a
capital-constrained run where the tiebreak at the cash boundary is alphabetical
(`project_screener_alphabetical_tiebreak`).

## The discriminator: TRADING_DATA_DIR

- Under `TRADING_DATA_DIR=<repo>/trading/test_data` (CI's committed bar data —
  what every workflow sets): **nondeterministic**, 3+ observations.
- Under this host's default `data/` warehouse: **deterministic** across four
  observations — 48.969233055332253 twice at 302 symbols / 6y, and
  51.900914377999626 twice at 500 symbols / 5y.

I cannot explain why the data directory discriminates, so this is recorded as an
observed, reproducible condition, not a mechanism. Two obvious hypotheses worth
testing first: the two trees differ in which symbols resolve (so a
missing-data/fallback path is entered only under one), and they differ in
directory size (so any unsorted `readdir`-style discovery would order differently).

## Prior art — the likely class

`order_generator.ml:18` documents a **G6 fix** for exactly this failure mode:

> order IDs are minted from scenario-time inputs (current_date + a per-call
> sequence index) so that two structurally identical simulations produce
> bit-identical IDs regardless of wall-clock or process forking. The IDs are
> hashtable keys in `Trading_orders.Manager.orders`; unstable IDs caused
> different bucket placement -> different `list_orders` iteration order in
> `Engine.process_orders` -> different fill order -> metric drift on
> long-horizon backtests.

`Manager.list_orders` folds a stdlib `Hashtbl` keyed by order id
(`manager.ml:81`), so **any** path still minting an id from the wall clock
reintroduces it. `Create_order.create_order` defaults `now_time` to
`Time_ns_unix.now ()` and `types.ml:30` stamps `updated_at` the same way, so the
ingredients are still present even though `order_generator` itself was fixed.

This is a hypothesis, not a diagnosis. It has not been traced.

## Repro recipe

~4 min a run:

```sh
docker exec trading-1-dev bash -c \
  "cd /workspaces/trading-1/trading && eval \$(opam env) && \
   TRADING_DATA_DIR=/workspaces/trading-1/trading/test_data \
   ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir /tmp/goldenarmed \
     --fixtures-root /workspaces/trading-1/trading/test_data/backtest_scenarios \
     --parallel 1 --no-emit-all-eligible"
```

with an armed-StopLimit spec in `/tmp/goldenarmed` (the ladder v2-core entry
stack on `universes/sp500.sexp`, 2019-2023). Run twice, compare `actual.sexp`.

Suggested first move: bisect the source by instrumenting order-id minting — dump
every id the run creates, diff the two dumps, and see whether the id *sequence*
differs or only the downstream fills do. That distinguishes "unstable ids" from
"stable ids, unstable iteration".

## Consequences

- **The armed-StopLimit golden is blocked again**, for a real reason this time:
  its bands are unpinnable while the regime it covers is nondeterministic. The
  spec is written and validated (it PASSes) but deliberately not landed. Land it
  the moment this is fixed — it is exactly the gate that would have caught both
  of these.
- **#2279 still stands.** It removes a proven source, goldens are bit-identical
  pre/post, and its tests pin a genuine contract. It is necessary, not
  sufficient.
- **The ladder-v4 read is unaffected.** The 278pp null measured from the sweep's
  duplicate cells 07/08 (`dev/notes/ladder-v4-read-2026-08-12.md`) is a
  measurement of the *pre-fix* build's total noise, whatever its sources. If
  anything, a second source makes that number more expected, not less.

## Method note

I claimed the fix was verified because two runs matched, twice, at two scales.
That was true and still insufficient: both verification pairs ran under the same
data dir, so the check had a blind spot exactly where the residual source lives.
A determinism check should vary the incidental environment (data dir, scenario
name, batch composition), not just repeat the identical invocation — otherwise
it confirms reproducibility of *one configuration* and gets read as
reproducibility of *the system*.
