#!/bin/sh
# Build the PIT snapshot warehouse /tmp/snap_top4000_pit_v13pit from the pit-v13 true-dollar-volume lists (top-4000
# union, ~14.2k names; supports the universe-depth experiment). A wrapper: the recipe, phases and guards are those of
# dev/scripts/build_pit_warehouse_v12.sh (read its header), run with VERSION=v13 TOPN=4000. pit-v13/quarantine.txt
# (DNGFF HLAN MDFI SYNI: absurd avg_dollar_volume) is excluded from the union and expected-absent in `verify`.
#
# The union is ~1.4x v12's, so a chunk of the default 4 would peak above the 4 GB of a cloud session: use CHUNKS=6
# (~2.4k names per chunk, as in v11) or more. The handle cap default is raised past the expected manifest size.
#
# Cloud session, no docker (docs/howtos/claude_cloud_sessions.md, "Building a PIT warehouse in a session"):
#   CONTAINER=none CHUNKS=6 sh dev/scripts/build_pit_warehouse_v13.sh all
# Local container: RUN_TREE=/workspaces/trading-1/<pinned tree> CHUNKS=6 sh dev/scripts/build_pit_warehouse_v13.sh all
# POSIX sh. Never run by tests: the full build takes hours.
VERSION=v13
TOPN=4000
CHUNKS=${CHUNKS:-6}
SNAPSHOT_MAX_MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-16000}
export VERSION TOPN CHUNKS SNAPSHOT_MAX_MMAP_HANDLES
exec sh "$(dirname "$0")/build_pit_warehouse_v12.sh" "$@"
