#!/bin/sh
# Build the PIT snapshot warehouse /tmp/snap_top4000_pit_v13pit from the pit-v13 true-dollar-volume lists (top-4000
# union, 13,747 names; supports the universe-depth experiment). A wrapper: the recipe, phases and guards are those of
# dev/scripts/build_pit_warehouse_v12.sh (read its header), run with VERSION=v13 TOPN=4000. pit-v13/quarantine.txt
# (DNGFF HLAN MDFI SYNI: absurd avg_dollar_volume) is excluded from the union and expected-absent in `verify`.
#
# The union is ~1.4x v12's, so a chunk of the default 4 (3.4k names) would peak well above 5 GB: use CHUNKS=6
# (~2.3k names per chunk, v11 peaked 5-6 GB at 2.5k; CHUNKS=8 for a 5 GB session VM) or more. The handle cap default is raised past the expected manifest size.
#
# Cloud session: the session's trading-1-dev container (checkout mounted at /workspaces/trading-1), see
# docs/howtos/claude_cloud_sessions.md "Building a PIT warehouse in a session" for the CONTAINER, RUN_TREE, HOST_ROOT, CSV, OUT, WORK
# values. CONTAINER=none (no docker) only on a host with the CI image's runtime libraries (libta-lib.so.0).
# Local container: RUN_TREE=/workspaces/trading-1/<pinned tree> CHUNKS=6 sh dev/scripts/build_pit_warehouse_v13.sh all
# POSIX sh. Never run by tests: the full build takes hours.
VERSION=v13
TOPN=4000
CHUNKS=${CHUNKS:-6}
SNAPSHOT_MAX_MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-16000}
export VERSION TOPN CHUNKS SNAPSHOT_MAX_MMAP_HANDLES
exec sh "$(dirname "$0")/build_pit_warehouse_v12.sh" "$@"
