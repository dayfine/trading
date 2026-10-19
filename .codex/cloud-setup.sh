#!/bin/sh
# Run from the repository root during setup, then again at task startup.
set -eu
repo=$(pwd -P)
if [ ! -f "$repo/.codex/dune-workspace.cloud" ]; then
  echo 'Run cloud setup from the repository root containing .codex/dune-workspace.cloud.' >&2
  exit 1
fi
setup_dir=${TRADING_CLOUD_SETUP_DIR:-/workspace/.trading-cloud}
image=trading-cloud-ci:2026-10-18
source_image=ghcr.io/dayfine/trading-ci@sha256:9bd613007268f458ad935126c53b1d76368374f3032807b174908bdb3bba28e5
# Always use the managed local daemon; preserve registry credentials and proxies.
unset DOCKER_HOST DOCKER_CONTEXT DOCKER_TLS DOCKER_TLS_VERIFY DOCKER_CERT_PATH
docker() { command docker --host=unix:///var/run/docker.sock "$@"; }
docker info >/dev/null
mkdir -p "$setup_dir"
if ! docker image inspect "$image" >/dev/null 2>&1; then
  archive=go-containerregistry_Linux_x86_64.tar.gz
  release=https://github.com/google/go-containerregistry/releases/download/v0.20.3
  curl -fsSL "$release/$archive" -o "$setup_dir/$archive"
  curl -fsSL "$release/checksums.txt" -o "$setup_dir/checksums.txt"
  (
    cd "$setup_dir"
    awk -v name="$archive" '$2 == name' checksums.txt > archive.sha256
    test -s archive.sha256
    sha256sum -c archive.sha256
    tar xzf "$archive" crane
  )
  # Export flattens layers before import: a layered pull exhausts vfs disk.
  trap 'rm -f "$setup_dir/ci-flat.tar"' 0
  trap 'exit 1' HUP INT TERM
  "$setup_dir/crane" export "$source_image" "$setup_dir/ci-flat.tar"
  docker import "$setup_dir/ci-flat.tar" "$image"
  rm -f "$setup_dir/ci-flat.tar"
  trap - 0 HUP INT TERM
fi
if ! docker container inspect trading-1-dev >/dev/null 2>&1; then
  docker run -d --name trading-1-dev --user "$(id -u):$(id -g)" \
    -e OPAMROOT=/home/opam/.opam -e OPAMSWITCH=5.3.0+flambda \
    -e TRADING_DATA_DIR=/workspaces/trading-1/trading/test_data \
    -v "$repo:/workspaces/trading-1" \
    -w /workspaces/trading-1/trading "$image" /usr/bin/tail -f /dev/null
else
  mounted_repo=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/workspaces/trading-1"}}{{.Source}}{{end}}{{end}}' trading-1-dev)
  if [ "$mounted_repo" != "$repo" ]; then
    echo "Existing trading-1-dev mounts $mounted_repo; run startup from that repository root." >&2
    exit 1
  fi
  docker start trading-1-dev >/dev/null
fi
# Drop unused base-image caches, retaining the active flambda switch.
docker exec trading-1-dev bash -c 'set -eu; if opam switch list --short | grep -Fxq 5.3; then opam switch remove 5.3 --yes; fi; rm -rf /home/opam/opam-repository'
docker cp "$repo/.codex/dune-workspace.cloud" trading-1-dev:/tmp/trading-cloud-workspace
docker exec trading-1-dev bash -c 'set -eu; eval "$(opam env)"; ocamlc -version; ocamlformat --version; dune --version'
