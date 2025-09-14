## Dev Environment

- Note that the development environment is in `docker`
- Code is in Ocaml, built with `dune`
- Run all commands (in docker) in the `trading` directory, e.g.
  - `dune build`
  - `dune runtest`

## Development

### Overall flow

Use Test driven development to develop iteratively

1. Write an interface / skeleton of the new symbols (types, functions, and
   modules)
   - They should build ok (`dune build`)
   - Document everything non-trivial / not self-explanatory with comments
1. Write tests for the desired behviors, which at first mostly (if not all) fail
   - `dune runtest`
1. Update implementatoin to make test passes (while builds too)
   - `dune build && dune runtest`
1. Once a working solution is done, self-review and critize the code just
   written
1. Do another round of updates for style, abstraction, and corner cases
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
1. At the end, format the code using `dune fmt`
1. Make a commit using `git commit -m "..."` by summarizing a concise commit
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
