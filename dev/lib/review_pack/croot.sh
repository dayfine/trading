#!/bin/sh
# croot.sh -- the container path of a host repo checkout (#3262, from #3214). The container bind-mounts ONE
# host directory at MOUNT (/workspaces/trading-1); a jj workspace or git worktree under it sits at
# MOUNT/<its path below the mount source>. A fixed MOUNT would build and run the PARENT checkout's binaries
# and write to the parent's paths, and the audit came out silently empty (rebaseline-v12, 2026-10-09).
#
# croot_for SRC REPO MOUNT  -> MOUNT/<REPO below SRC>; fails (exit 1) when REPO is not under SRC
# mount_source CONTAINER MOUNT -> the host directory the container mounts at MOUNT ("" when unknown)
croot_for() {
  case "$2" in
    "$1") printf '%s' "$3" ;;
    "$1"/*) printf '%s%s' "$3" "${2#"$1"}" ;;
    *) return 1 ;;
  esac
}
mount_source() {
  docker inspect "$1" --format "{{range .Mounts}}{{if eq .Destination \"$2\"}}{{.Source}}{{end}}{{end}}" 2>/dev/null || true
}
