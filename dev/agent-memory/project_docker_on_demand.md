---
name: project-docker-on-demand
description: "Local dev container is on-demand (USER 11-16): stopped when idle so Docker Desktop frees ~5 GB; scripts start it via ensure_container.sh"
metadata:
  node_type: memory
  type: project
  originSessionId: 249246cf-fc3d-457f-8536-5d3b905a45a5
  modified: 2026-11-17T04:09:03.739Z
---

User decision 2026-11-16 ~20:15 PT ("sure" to option 1), reversing the same day's "Docker stays up": the local `trading-1-dev` container runs only when something builds.

**Why:** 16 GB host was swapping 13 GB (swap files ate ~9 GB of disk, load avg ~50 on 10 cores) while the Docker VM held 5.2 GB with the container idle for 7 days (358 MB in use). Cloud runs backtests and CI runs tests, so local Docker is only needed for agent `dune build`/`fmt`, QC mutation probes and the Saturday weekly picks.

**How to apply:**
- Container stopped 11-16 ~20:12 PT. Merged #3663 (4f8c446c7): `dev/lib/ensure_container.sh` (starts Docker Desktop + container, called by `run-in-env.sh`, `docker_dune.sh` and the work scripts; agents call it before their first `docker exec`), `dev/lib/container_idle_stop.sh` (stops only when idle). Every docker call is bounded by `dev/lib/bounded_call.sh` (SIGKILL watchdog; the Go docker CLI ignores SIGALRM, so `perl alarm; exec docker` does NOT work). Follow-ups: `run-in-env.sh` probe and `docker_dune.sh` polling are still unbounded; a cold Docker Desktop start whose `docker info` blocks > 30 s is a hard FAIL, not a retry.
- After a build/QC wave and at session end, run `container_idle_stop.sh`. Observers (`wait_for.sh proc`, `where_is_work.sh`) must treat a stopped container as idle, never start it.
- Alternatives not taken: a native opam switch on the host (ocamlformat skew, owl BLAS on arm64; see [[project_ocamlformat_version_skew]], [[project_owl_sigill_image_rebuild]]), or all build work in the cloud.
