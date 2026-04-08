# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Environment

- Development environment runs in Docker
- All commands must be executed inside Docker container:
  `docker exec <container-name> bash -c 'cd /workspaces/trading-1/trading && eval \$(opam env) && <command>'`
- OCaml codebase built with Dune build system
- Uses Core library extensively for standard data structures and utilities

### Essential Commands

- **Build entire project**: `dune build`
- **Run all tests**: `dune runtest`
- **Run specific test directory**: `dune runtest <path>` (e.g., `dune runtest trading/orders/test/`)
- **Format code**: `dune fmt`
- **Build and test together**: `dune build && dune runtest`

## Architecture Overview

The codebase is organized into two main areas:

### Core Trading System (`trading/trading/`)

- **Base Types** (`trading/base/lib/types.mli`): Fundamental trading types (symbol, price, quantity, side, order_type, position)
- **Orders** (`trading/orders/`): Order management system with factory patterns, validation, and lifecycle management
- **Portfolio** (`trading/portfolio/`): Portfolio tracking and management with exposed value type (fields directly accessible via `portfolio.current_cash`, `portfolio.positions`, etc.)
- **Simulation** (`trading/simulation/`): Trading simulation engine
- **Engine** (`trading/engine/`): Core trading engine (currently scaffolded)

### Analysis Framework (`analysis/`)

- **Data Sources** (`analysis/data/sources/`): External data providers (EOD HD API integration)
- **Data Storage** (`analysis/data/storage/`): CSV storage with metadata tracking
- **Data Types** (`analysis/data/types/`): Market data structures (Daily_price with OHLCV data)
- **Technical Indicators** (`analysis/technical/indicators/`): EMA, time period conversion, and indicator framework
- **Scripts** (`analysis/scripts/`): Analysis workflows and utilities

## Weinstein Trading System — Design Documentation

The project is building a semi-automated trading system based on Stan Weinstein's stage analysis methodology. All design documentation lives in `docs/design/`. **Read these docs before making changes to understand the system goals, component boundaries, and technical decisions.**

### Start here (read in this order):

1. **System Design** (`docs/design/weinstein-trading-system-v2.md`): What we're building, how it's used (weekly workflow, mid-week adjustments, backtesting, tuning), the core abstraction (live and simulation share the same pipeline), component map, config surface, milestones (M1–M7), and build phases.

2. **Codebase Assessment** (`docs/design/codebase-assessment.md`): How the Weinstein system maps onto the existing codebase — what we reuse (orders, portfolio, engine, simulation, strategy interface, EODHD client), what we extend, what we build new. **Read this to understand which existing modules to touch and which to leave alone.**

### Engineering design docs (one per subsystem):

3. **Data Layer** (`docs/design/eng-design-1-data-layer.md`): EODHD client extensions, DATA_SOURCE abstraction (live/historical/synthetic), cache design, storage format decisions, idempotency, performance.

4. **Screener / Analysis** (`docs/design/eng-design-2-screener-analysis.md`): Stage classifier, macro analyzer, sector analyzer, relative strength, volume confirmation, resistance mapping, breakout detection, and the screener cascade filter. All analysis modules are pure functions. All thresholds configurable.

5. **Portfolio / Orders / Stops** (`docs/design/eng-design-3-portfolio-stops.md`): Weinstein trailing stop state machine, portfolio risk management (position sizing, exposure limits, sector concentration), trading state persistence, order generation. **Key decision: don't modify existing Portfolio/Orders/Position modules — build alongside them.**

6. **Simulation / Tuning** (`docs/design/eng-design-4-simulation-tuning.md`): Weekly simulation mode (extend existing simulator with strategy_cadence), Weinstein strategy module (implements existing STRATEGY interface), parameter tuner with walk-forward validation.

### Domain reference:

7. **Weinstein Book Reference** (`docs/design/weinstein-book-reference.md`): Detailed notes from Stan Weinstein's book — stage definitions, buy/sell criteria, stop-loss rules, macro indicators, sector analysis, short-selling rules. **Use this as the domain reference when implementing analysis logic — it contains the specific rules to encode so you don't need to re-read the book.**

### Key principles from the design docs:

- **Same pipeline for live and simulation.** The DATA_SOURCE interface is the seam — live calls EODHD, historical replays from cache, synthetic generates programmatically. Analysis and screening code is identical in both modes.
- **All parameters in config, never hardcoded.** Every threshold, weight, lookback period, and limit is configurable. This enables backtesting and tuning.
- **Prefer building alongside existing modules** (Portfolio, Orders, Engine, Position) rather than modifying them. When a well-scoped refactor to an existing module is clearly beneficial (e.g., adding a shared type to the canonical location), feature agents should **propose it as a decision item** for human or review-agent approval rather than executing it directly. This prevents unintended cross-module changes from being silently bundled into feature PRs.
- **Every analysis function is pure.** Same input → same output. No hidden state. Essential for reproducible backtests.
- **The Weinstein strategy implements the existing `STRATEGY` module type.** Integration point is `on_market_close` — the strategy receives market data, looks at positions, returns transitions.

## Development

### Development Workflow

Use Test driven development to develop iteratively

1. Write an interface / skeleton of the new symbols (types, functions, and
   modules)
   - They should build ok (`dune build`)
   - Document everything non-trivial / not self-explanatory with comments
2. Write tests for the desired behaviors, which at first mostly (if not all) fail
   - Using OUnit2 or Alcotest
3. Update implementation to make tests pass (while builds too)
   - `dune build && dune runtest`
4. Once a working solution is done, self-review and criticize the code just
   written
5. Do another round of updates for style, abstraction, and corner cases
   - Again, code should build, add new test cases as needed, and make all tests
     pass
   - Focus on human readability and understandability
     - Is it clear what the code is doing?
     - Is the code too repetitive / not properly abstracted?
     - Is the name confusing?
     - Is a given file / module / function / records too big for human to read?
       - Does a record contain more than 7–9 fields?
       - Does a function contain more than 5–7 parameters?
       - Does a module contain more than 3–5 methods?
       - Does a function contain more than 25 lines (recommended) or 50 lines (hard limit)?
6. At the end, format the code using `dune fmt`
7. Make a commit using `jj describe -m "..."` by summarizing a concise commit
   message. This repo uses **jj (Jujutsu)** as the VCS — always use `jj`
   commands, never bare `git` commands for committing, branching, or pushing.

### VCS & PR Workflow

This repo uses **jj (Jujutsu)** as the VCS in colocated mode (`.jj/` and `.git/` coexist). Always use `jj` commands — never bare `git` for committing, branching, or pushing.

#### Key jj commands

```bash
jj status                          # what changed in working copy
jj diff                            # full diff of working copy
jj log -n 10                       # recent history
jj describe -m "message"           # set commit message on current @
jj new -m "message"                # create new child commit
jj new main@origin                 # create new commit off main (start a feature)
jj bookmark create <name> -r @     # create bookmark at current commit
jj bookmark set <name> -r @        # move bookmark to current commit
jj git push -b <name>              # push a bookmark to origin
jj git fetch                       # fetch from origin
jj rebase -b <bookmark> -d <dest>  # rebase a bookmark onto a destination
jj squash --from <rev> --into <rev> --message "..." # squash commits
```

jj auto-snapshots the working copy into `@` continuously — no `git add` needed.

#### Branch conventions

- Feature branches: `feat/<feature-name>` (e.g. `feat/screener`)
- Module sub-bookmarks: `feat/<feature>/<module>` (e.g. `screener/sma`) — one per module commit, used by `jst` for stacked PRs
- Always branch from `main@origin`, never from another feature branch

#### Creating and submitting PRs with jst

PRs are created using `jst` (stacked PR tool), which reads the module-level bookmarks and creates one PR per module, each targeting the one below it:

```bash
GH_TOKEN=$(echo "protocol=https\nhost=github.com" | git credential fill | grep ^password | cut -d= -f2)
GH_TOKEN=$GH_TOKEN jst submit feat/<your-feature>
```

Re-run `jst submit` after each session to update existing PRs. The full workflow is documented in `dev/agent-feature-workflow.md`.

For non-feature branches (e.g. harness work), use the URL printed by `jj git push`:
```
remote: Create a pull request for '<branch>' on GitHub by visiting:
remote:      https://github.com/dayfine/trading/pull/new/<branch>
```

#### Review feedback workflow

When the user gives feedback on a PR, add the changes as a **second commit on top** of the original — do not amend. This lets the reviewer see exactly what changed in response to their feedback.

1. `jj edit <bookmark>` — land on the commit under review
2. `jj new -m "Apply review: <short description>"` — creates an empty child commit; the bookmark still points to the original
3. Make the changes, then `dune build && dune runtest` and `dune fmt`
4. `jj bookmark set <bookmark> -r @` — advance the bookmark to the new tip
5. `jj git push -b <bookmark>`

Descendant commits in the stack rebase automatically. The PR will contain two commits; GitHub lets the reviewer diff each one independently.

### Write new code incrementally

Make one small change at a time.

- For source code changes, write one (pair of) file (`.ml` and `.mli`) at a
  time, and make sure they build. Then add tests for them, and make sure
  the tests pass
- Make comments for symbols in `.mli` and complex implementations in `.ml`
- When done with the module file, only then add new module files
- Though the whole sequence can be planned out at the beginning

Minimize changes to existing code. They are all working

- Feel free to verify by running builds and tests for the entire project
  first, and bail out if failures are encountered

If the initial prompt is expected to result in a really large change (> 1000
lines), plan it out beforehand and make multiple commits, each no more than
500–1000 lines (including tests).

For large modules (e.g. a module with many sub-modules or a complex pipeline),
implement iteratively step by step:

- Break the module into logical sub-units (e.g. types → core logic → integration)
- Implement and commit each sub-unit before moving to the next
- Each commit / PR should remain small and self-contained (< 500 lines)
- A sub-unit is done when it builds, has tests, and tests pass
- Plan the full sequence upfront, but execute one step at a time

### Debugging Tips

- For compilation errors with published packages, inspect opam/build to check
  exported symbols
- Use WebSearch to identify similar issues and solutions
- Check dune-package files for actual module structure when modules seem missing
