# AGENTS.md

## Cursor Cloud specific instructions

### Overview

This is an OCaml 5.3 algorithmic trading simulation and backtesting system. All development happens inside the `trading-1-dev` Docker container. There is no web UI, database, or external service required for building and testing.

### Running commands

All build/test/format commands must run inside the Docker container:

```bash
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && <command>'
```

See `CLAUDE.md` for the full list of essential commands (`dune build`, `dune runtest`, `dune fmt`, etc.).

### Starting the container

If the container is not running, start it with:

```bash
docker start trading-1-dev
```

If it does not exist (e.g., after a fresh VM snapshot), rebuild and start:

```bash
docker build -t trading-1-dev -f /tmp/Dockerfile.trading /workspace
docker run -d --name trading-1-dev -v /workspace:/workspaces/trading-1 -w /workspaces/trading-1/trading trading-1-dev tail -f /dev/null
```

The update script handles image building and container creation automatically.

### Known issues

- **`segmentation_test` floating-point failure**: The test `test_complex_segmentation` in `analysis/technical/trend/test/` fails due to minor floating-point precision differences across platforms (differences in ~10th decimal place). This is a pre-existing issue, not caused by code changes.

- **opam `async_unix` recompile bug with fuse-overlayfs**: When installing dev tools (ocaml-lsp-server, ocamlformat, utop, odoc) via `opam install` in a Docker image built on fuse-overlayfs, the `async_unix` package fails to recompile with "File exists" errors. The workaround is to skip dev tools in the Docker image build, then install them inside the running container after clearing the stale library directory (`rm -rf ~/.opam/5.3/lib/async_unix/*`). The update script handles this automatically.

### Project structure

Refer to `CLAUDE.md` for architecture details, code patterns, test patterns, and the development workflow (TDD, incremental changes, etc.).
