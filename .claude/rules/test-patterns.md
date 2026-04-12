---
description: Test patterns using the Matchers library (base/matchers/)
globs: ["**/test/*.ml"]
---

## Core Rule: One `assert_that` per Value

Each value under test gets **one** `assert_that` call. Compose multiple checks into the matcher tree using `all_of`, `field`, `elements_are`, etc. — never nest a second `assert_that` inside a matcher callback.

```ocaml
(* GOOD: single assert_that, multiple checks via all_of + field *)
assert_that order_result
  (is_ok_and_holds
    (all_of [
      field (fun o -> o.status) (equal_to Filled);
      field (fun o -> o.price) (float_equal 100.0);
    ]))

(* AVOID: nested assert_that inside matcher callback *)
assert_that order_result
  (is_ok_and_holds (fun order ->
    assert_that order.status (equal_to Filled);
    assert_that order.price (float_equal 100.0)))
```

When checking multiple aspects of the same value, compose them into one `assert_that`:

```ocaml
(* GOOD: one assert on portfolio, checks composed via all_of + field *)
assert_that portfolio
  (all_of [
    field (fun p -> p.current_cash) (float_equal 9000.0);
    field (fun p -> Hashtbl.length p.positions) (equal_to 1);
  ])
```

## Use the Matchers Library (`base/matchers/`)

```ocaml
open Matchers

(* Assert on Result types with fluent matchers *)
assert_that result (is_ok_and_holds (float_equal expected))

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
assert_that (Hashtbl.find portfolio.positions "AAPL")
  (is_some_and (field (fun pos -> pos.quantity) (float_equal 10.0)))
```

## Matcher Composition Patterns

1. **Use type annotations instead of explicit comparison functions:**
   ```ocaml
   (* GOOD *)
   assert_that result
     (is_some_and (equal_to ({ price = 100.0; quantity = 10 } : order)))

   (* AVOID: Unnecessary explicit comparison parameter *)
   assert_that result
     (is_some_and (equal_to ~cmp:equal_order { price = 100.0; quantity = 10 }))
   ```

2. **Inline expected values instead of intermediate variables:**
   ```ocaml
   (* GOOD *)
   assert_that result
     (is_some_and (equal_to ({ price = 100.0; fraction = 0.5 } : fill_result)))

   (* AVOID *)
   let expected = { price = 100.0; fraction = 0.5 } in
   assert_that result (is_some_and (equal_to expected))
   ```

3. **Use `elements_are` for list validation — prefer it over `size_is` + extraction:**
   ```ocaml
   (* GOOD: whole-record equality *)
   assert_that path
     (elements_are [
       equal_to ({ time = 0.0; price = 100.0 } : path_point);
       equal_to ({ time = 0.5; price = 105.0 } : path_point);
     ])

   (* GOOD: per-element matchers using all_of + field *)
   assert_that result.trades
     (elements_are [
       all_of [
         field (fun t -> t.symbol) (equal_to "AAPL");
         field (fun t -> t.side) (equal_to Buy);
       ];
     ])

   (* GOOD: nested elements_are mirrors data structure *)
   assert_that steps
     (elements_are [
       field (fun step -> step.trades) (size_is 0);
       field (fun step -> step.trades)
         (elements_are [
           field (fun t -> t.side) (equal_to Buy);
         ]);
     ])
   ```

4. **Use `field` to extract and assert on record fields:**
   ```ocaml
   (* GOOD *)
   assert_that result
     (is_some_and (field (fun fill -> fill.price) (float_equal 95.0)))

   (* GOOD: multiple fields *)
   assert_that order_result
     (is_ok_and_holds
       (all_of
          [
            field (fun o -> o.status) (equal_to Filled);
            field (fun o -> o.price) (float_equal 100.0);
          ]))

   (* AVOID: nested assert_that inside callbacks — breaks declarative style *)
   assert_that order_result
     (is_ok_and_holds (fun order ->
       assert_that order.status (equal_to Filled)))
   ```

5. **Use `is_some_and` / `is_none` for Option unwrapping:**
   ```ocaml
   assert_that result (is_some_and (equal_to expected_value))
   assert_that result is_none
   ```

6. **Use `gt`/`ge`/`lt`/`le`/`is_between` with `Int_ord`/`Float_ord` for numeric comparisons:**
   ```ocaml
   assert_that result.count (gt (module Int_ord) 0)
   assert_that price (ge (module Float_ord) min_price)

   (* GOOD: is_between for range checks *)
   assert_that result.confidence
     (is_between (module Float_ord) ~low:0.0 ~high:1.0)

   (* AVOID: all_of [ ge ...; le ... ] for ranges — use is_between *)
   assert_that price
     (all_of [ ge (module Float_ord) 100.0; le (module Float_ord) 200.0 ])

   (* AVOID: assert_bool with Float.(...) *)
   assert_bool "price > 0" Float.(price > 0.0)
   ```

7. **Use `matching` to assert a variant case:**
   ```ocaml
   (* GOOD *)
   assert_that result.stage
     (matching ~msg:"Expected Stage2"
        (function Stage2 x -> Some x | _ -> None)
        (field (fun s -> s.weeks_advancing) (gt (module Int_ord) 0)))

   (* AVOID: manual match with assert_failure *)
   (match result.stage with
   | Stage2 x -> assert_that x.weeks_advancing (gt (module Int_ord) 0)
   | _ -> assert_failure "Expected Stage2")
   ```

**Key Principles:**
- **One `assert_that` per value** — never nest `assert_that` inside a matcher callback; use `field`, `all_of`, `elements_are` to compose checks
- Use type annotations to enable structural equality
- Inline values for clarity; prefer `elements_are` over `size_is` + extraction

## Test Data Builders

- Keep simple record constructors inline in test files
- Don't create unnecessary helper modules for trivial builders
- Use optional parameters with defaults for flexibility:

```ocaml
let make_trade ~id ~order_id ~symbol ~side ~quantity ~price ?(commission = 0.0) () =
  { id; order_id; symbol; side; quantity; price; commission; timestamp = Time_ns_unix.now () }
```

**Domain-Specific Helpers** — build on top of matchers:
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
