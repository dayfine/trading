# Mechanical migrations applied to archived experiment specs

Specs under `dev/experiments/` are the reproducible record of a study: the
verdict in a `results.md` only means something if the config that produced it can
be re-run. That makes them **provenance**, so they are not edited casually — but
it also means they must stay **runnable**, and a spec naming a config key that no
longer exists fails validation loudly (`Overlay_validator`, the #1051 hazard).

When a config field is renamed or split, both goals are met by a **mechanical,
exactly behaviour-preserving** rewrite plus an entry here recording the mapping,
so the original text is reconstructible from this file alone.

A rewrite belongs here only if it is exactly behaviour-preserving. Anything that
changes what a spec *does* is not a migration — it is a different experiment, and
it gets its own directory.

---

## 2026-08-16 — `entry_order_ttl_weeks` split into two fields (PR #2349)

One field armed two mechanisms — the book-supported weekly re-screen cancel
(§4.7 / §7) and an invented clock backstop — and returned `[]` at `0` without
consulting the re-screen predicate at all, so the faithful half was unreachable
without the invented one. It became:

```
enable_entry_ticket_rescreen : bool [@sexp.default false]
entry_order_max_rest_weeks   : int  [@sexp.default 0]   (* 0 = unbounded *)
```

**Mapping applied** (the same one PR #2349 applied to the 24 committed ladder-v4
specs under `trading/test_data/`):

| before | after |
|---|---|
| `((entry_order_ttl_weeks 0))` | `((enable_entry_ticket_rescreen false))` + `((entry_order_max_rest_weeks 0))` |
| `((entry_order_ttl_weeks N))`, `N > 0` | `((enable_entry_ticket_rescreen true))` + `((entry_order_max_rest_weeks N))` |

**Files touched** — 40 specs, all previously un-runnable against a post-#2349
binary, none read by any build or test:

| directory | specs | occurrences |
|---|---:|---|
| `ladder-v4-small-deterministic-2026-08-12/specs` | 24 | 13 × `0`, 9 × `4`, 2 × `8` |
| `ladder-v4-grid-2026-08-15/specs` | 8 | 4 × `0`, 4 × `4` |
| `candidate-universe-payoff-2026-08-13` | 3 | 3 × `0` |
| `entry-anchor-diagnostic-2026-08-15/specs` | 3 | 3 × `0` |
| `nearfloor-302-6y-2026-08-13/specs` | 2 | 2 × `0` |

(40 files, 40 occurrences: 25 × `0`, 13 × `4`, 2 × `8`.)

**Not touched**, deliberately:

- `trading/dev/backtest/scenarios-*/**/params.sexp` — these are run **outputs**,
  a record of what a binary actually ran. Rewriting them would be falsifying
  evidence, and nothing re-runs them.
- `trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp`
  — the only hit is inside a `;;` comment block, and it is describing history
  correctly.

**Caveat that the migration does not remove.** These specs are runnable again,
but re-running an archived study against today's binary does not reproduce its
recorded numbers — every mechanism merged since then applies. To reproduce a
result, pin the worktree at the commit the study names, where the pre-split field
still exists and no migration is needed.
