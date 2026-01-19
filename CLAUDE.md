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

## Code Patterns

### Type Definitions

- Extensive use of variant types for domain modeling (side, order_type, order_status)
- Records with `[@@deriving show, eq]` for core data structures, which can be used for test assertions
- Modules expose both `.ml` and `.mli` files with comprehensive documentation

### Error Handling

- Result types for validation: `type validation_result = (order_params, validation_error list) result`
- Custom error types per domain area
- Status module in `base/status/` for common result patterns

### Validation Patterns

Use **pure functional validation** with applicative composition:

```ocaml
(* Each validation returns Ok () or Error status *)
let _validate_symbol symbol =
  if symbol = "" then Error (invalid_argument_error "Symbol cannot be empty")
  else Ok ()

let _validate_quantity quantity =
  if quantity <= 0.0 then
    Error (invalid_argument_error (Printf.sprintf "Quantity must be positive: %.2f" quantity))
  else Ok ()

(* Compose validations with combine_status_list *)
let create_something params =
  let validations = [
    _validate_symbol params.symbol;
    _validate_quantity params.quantity;
  ] in
  match combine_status_list validations with
  | Ok () -> Result.Ok { ... }
  | Error err -> Result.Error err
```

**Prefer this over imperative patterns:**
- Avoid mutable refs for error collection
- Each validation is independently testable
- All errors are collected and returned together
- Uses Status module's `combine_status_list` for composition

### OCaml Idioms and Best Practices

**Pattern Matching:**
- Use exhaustive matching on variant types
- Prefer `Hashtbl.find` (returns `Option.t`) over `Hashtbl.find_exn`
- Use `filter_map` when filtering and mapping in one pass
- Keep pattern matches clean with inline expressions where appropriate

**Monadic Composition:**
```ocaml
(* Use let%bind for Result chaining *)
let process portfolio trade =
  let%bind new_cash = _check_sufficient_cash portfolio cash_change in
  let%bind () = _update_position_with_trade new_positions trade in
  return { portfolio with current_cash = new_cash; ... }
```

**Helper Functions:**
- Prefix internal helpers with underscore: `_validate_symbol`, `_calculate_cost`
- Keep functions small and focused (< 25 lines preferred)
- Name functions clearly to indicate their purpose
- Extract complex logic into named helper functions

**Avoid Magic Numbers:**
- Semantic zeros (0.0 for "no P&L") are acceptable
- Parameterize tolerances with defaults: `?(epsilon = 1e-9)`
- Extract named constants for domain-specific values

### Test Patterns

**Use the Matchers Library** (`base/matchers/`):

```ocaml
open Matchers

(* Assert on Result types with fluent matchers *)
assert_that result
  (is_ok_and_holds (fun value ->
       assert_that value (float_equal expected)))

(* Assert errors *)
assert_that result is_error

(* Extract values from Ok results in test setup *)
let portfolio =
  match create_portfolio ~cash:10000.0 with
  | Ok p -> p
  | Error err -> failwith ("Failed to create: " ^ Status.show err)

(* Float comparisons with epsilon tolerance *)
assert_that actual (float_equal 10.5)
assert_that actual (float_equal ~epsilon:1e-6 expected)

(* Accessing portfolio fields directly *)
assert_that portfolio.current_cash (float_equal 10000.0)
let position = Hashtbl.find portfolio.positions "AAPL" in
assert_that position (is_some_and (fun pos -> ...))
```

**Matcher Composition Patterns:**

The matchers library supports declarative, composable assertions. Follow these patterns for consistency:

1. **Use type annotations instead of explicit comparison functions:**
   ```ocaml
   (* GOOD: Type annotation enables structural equality *)
   assert_that result
     (is_some_and (equal_to ({ price = 100.0; quantity = 10 } : order)))

   (* AVOID: Unnecessary explicit comparison parameter *)
   assert_that result
     (is_some_and (equal_to ~cmp:equal_order { price = 100.0; quantity = 10 }))
   ```

2. **Inline expected values instead of intermediate variables:**
   ```ocaml
   (* GOOD: Clear and concise *)
   assert_that result
     (is_some_and (equal_to ({ price = 100.0; fraction = 0.5 } : fill_result)))

   (* AVOID: Unnecessary variable binding *)
   let expected = { price = 100.0; fraction = 0.5 } in
   assert_that result (is_some_and (equal_to expected))
   ```

3. **Use `elements_are` for comprehensive list validation:**

   Prefer `equal_to` on whole records when possible:

   ```ocaml
   (* GOOD: Validates entire list structure with position-specific assertions *)
   assert_that path
     (elements_are [
       equal_to ({ time = 0.0; price = 100.0 } : path_point);
       equal_to ({ time = 0.5; price = 105.0 } : path_point);
       equal_to ({ time = 1.0; price = 110.0 } : path_point);
     ])

   (* AVOID: Manual element-by-element checking *)
   match path with
   | [p1; p2; p3] ->
       assert_that p1 (equal_to { time = 0.0; price = 100.0 });
       assert_that p2 (equal_to { time = 0.5; price = 105.0 });
       assert_that p3 (equal_to { time = 1.0; price = 110.0 })
   | _ -> assert_failure "Expected 3 elements"
   ```

   Prefer `elements_are` over `size_is` + extraction, even when you can't
   use `equal_to` (e.g., records with dynamic fields like IDs/timestamps):

   ```ocaml
   (* GOOD: elements_are groups assertions per element *)
   assert_that result.trades
     (elements_are [
       (fun trade ->
         assert_that trade.symbol (equal_to "AAPL");
         assert_that trade.side (equal_to Buy));
     ])

   (* AVOID: size_is + extraction scatters related assertions *)
   assert_that result.trades (size_is 1);
   let trade = List.hd_exn result.trades in
   assert_that trade.symbol (equal_to "AAPL");
   assert_that trade.side (equal_to Buy)
   ```

   For hierarchical structures, use nested `elements_are` so assertion
   structure mirrors data structure:

   ```ocaml
   (* GOOD: Nested structure shows parent-child relationships *)
   assert_that steps
     (elements_are [
       (fun step -> assert_that step.trades (size_is 0));
       (fun step ->
         assert_that step.trades
           (elements_are [
             (fun t -> assert_that t.side (equal_to Buy));
           ]));
     ])

   (* AVOID: Flat assertions lose hierarchical relationship *)
   assert_that steps (size_is 2);
   let step1 = List.nth_exn steps 0 in
   assert_that step1.trades (size_is 0);
   let step2 = List.nth_exn steps 1 in
   assert_that step2.trades (size_is 1);
   let trade = List.hd_exn step2.trades in
   assert_that trade.side (equal_to Buy)
   ```

4. **Use `field` matcher to extract and assert on record fields:**
   ```ocaml
   (* GOOD: Extract specific field and apply matcher *)
   assert_that result
     (is_some_and (field (fun fill -> fill.price) (float_equal 95.0)))

   (* GOOD: Can chain with other matchers *)
   assert_that portfolio
     (field (fun p -> p.current_cash) (float_equal 10000.0))

   (* AVOID: Pattern matching for simple field access *)
   match result with
   | Some fill -> assert_that fill.price (float_equal 95.0)
   | None -> assert_failure "Expected Some"
   ```

5. **Use `is_some_and` for Option unwrapping:**
   ```ocaml
   (* GOOD: Declarative Option handling *)
   assert_that result is_some_and (equal_to expected_value)
   assert_that result is_none

   (* AVOID: Manual pattern matching *)
   match result with
   | Some value -> assert_that value (equal_to expected_value)
   | None -> assert_failure "Expected Some"
   ```

6. **Compose matchers for complex assertions:**
   ```ocaml
   (* Combining multiple matchers *)
   assert_that order_result
     (is_ok_and_holds (fun order ->
       assert_that order (field (fun o -> o.status) (equal_to Filled))))

   (* Nested composition for deep structures *)
   assert_that portfolio
     (field (fun p -> Hashtbl.find p.positions "AAPL")
            (is_some_and (field (fun pos -> pos.quantity) (float_equal 100.0))))
   ```

**Key Principles:**
- Prefer declarative matchers over imperative pattern matching
- Use type annotations to enable structural equality
- Inline values for clarity and conciseness
- Compose matchers for complex assertions
- Let the matcher library handle common patterns (Option, Result, list validation)

**Test Data Builders:**
- Keep simple record constructors inline in test files
- Don't create unnecessary helper modules for trivial builders
- Use optional parameters with defaults for flexibility:

```ocaml
let make_trade ~id ~order_id ~symbol ~side ~quantity ~price ?(commission = 0.0) () =
  { id; order_id; symbol; side; quantity; price; commission; timestamp = Time_ns_unix.now () }
```

**Domain-Specific Helpers:**
- Build on top of matchers for domain logic:

```ocaml
let apply_trades_exn portfolio trades ~error_msg =
  match apply_trades portfolio trades with
  | Ok value -> value
  | Error err -> OUnit2.assert_failure (error_msg ^ ": " ^ Status.show err)
```

**General Principles:**
- General-purpose utilities belong in general modules (matchers)
- Domain-specific logic stays in test files
- Prefer simplicity over abstraction for test code
- Make test intent clear through descriptive messages

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

- For compilation errors with published packages, inspect opam/build to check
  exported symbols
- Use WebSearch to identify similar issues and solutions
- Check dune-package files for actual module structure when modules seem missing
