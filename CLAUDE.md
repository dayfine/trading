# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Environment

- Development environment runs in Docker
- All commands must be executed inside Docker container: `docker exec <container-name> bash -c "cd /workspaces/trading-1/trading && eval \$(opam env) && <command>"`
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
- **Portfolio** (`trading/portfolio/`): Portfolio tracking and management
- **Simulation** (`trading/simulation/`): Trading simulation engine
- **Engine** (`trading/engine/`): Core trading engine (currently scaffolded)

### Analysis Framework (`analysis/`)

- **Data Sources** (`analysis/data/sources/`): External data providers (EOD HD API integration)
- **Data Storage** (`analysis/data/storage/`): CSV storage with metadata tracking
- **Data Types** (`analysis/data/types/`): Market data structures (Daily_price with OHLCV data)
- **Technical Indicators** (`analysis/technical/indicators/`): EMA, time period conversion, and indicator framework
- **Scripts** (`analysis/scripts/`): Analysis workflows and utilities

## Code Patterns

### Type Definitions

- Extensive use of variant types for domain modeling (side, order_type, order_status)
- Records with `[@@deriving show, eq]` for core data structures, which can be used for test assertions
- Modules expose both `.ml` and `.mli` files with comprehensive documentation

### Error Handling

- Result types for validation: `type validation_result = (order_params, validation_error list) result`
- Custom error types per domain area
- Status module in `base/status/` for common result patterns

## Development

### Development Workflow

Use Test driven development to develop iteratively

1. Write an interface / skeleton of the new symbols (types, functions, and
   modules)
   - They should build ok (`dune build`)
   - Document everything non-trivial / not self-explanatory with comments
2. Write tests for the desired behviors, which at first mostly (if not all) fail
   - Using OUnit2 or Aloctest
3. Update implementatoin to make test passes (while builds too)
   - `dune build && dune runtest`
4. Once a working solution is done, self-review and critize the code just
   written
5. Do another round of updates for style, abstraction, and corner cases
   - Again, code should build, add new test cases as needed, and make all tests
     pass
   - Focus on human readability and understandability
     - Is it clear what the code is doing?
     - Is the code too repetitive / not properly abstracted?
     - Is the name confusing?
     - Is a given file / module / function / records too big for human to read?
       - Does a record contains more than 7~9 fields?
       - Does a function contains more than 5-7 parameters?
       - Does a module contains more than 3-5 methods?
       - Does a function contains more than a page (~35 lines) of code?
6. At the end, format the code using `dune fmt`
7. Make a commit using `git commit -m "..."` by summarizing a concise commit
   message

### Write new code incrementally

Make one small changes at a time.

- For source code changes, write one (pair of) file (`.ml` and `.mli`) at a
  time, and make sure they build. Then add tests for them, and make sure
  the tests pass
- Make comments for symbols in `.mli` and complex implementions in `.ml`
- When done with the module file, only then add new module files
- Though the whole sequence can be planned out at the beginning

Minimize changes to existing code. They are all working

- Feel free to verify by running builds and tests for the entire project
  first, and bail out if failures are encountered

If the initial prompt is expected to result in a really large change (> 1000
lines), plan it out beforehand and make multiple commits, each no more than
500-1000 lines (includig tests).

### Debugging Tips

- For compilation errors with published packages, inspect opam/build to check exported symbols
- Use WebSearch to identify similar issues and solutions
- Check dune-package files for actual module structure when modules seem missing
