#!/bin/sh
# r2_bars.sh -- move the private bar store to and from a Cloudflare R2 bucket
# (issue #3476).
#
# EODHD terms allow storing the data for private use and forbid sharing it, so
# the bucket must stay private (no public access, no r2.dev URL) and nothing
# here ever writes bar data into the repo. Only the hash manifest
# (data_manifest.sh) is committed; `pull --manifest` checks a download
# against it.
#
# Usage:
#   r2_bars.sh push --data-dir DIR [--name NAME] [--force]
#   r2_bars.sh pull --dest DIR [--name NAME] [--manifest FILE]
#   r2_bars.sh ls
#
# push: packs DIR into one .tar.gz (in $TMPDIR, never in the repo), records
#   its sha256, and uploads both as bars/<NAME>.tar.gz and
#   bars/<NAME>.tar.gz.sha256. NAME defaults to data-<UTC date>. Refuses to
#   overwrite an existing object unless --force. One PUT carries the archive,
#   so it must be under R2's 5 GiB single-upload limit (checked; R2_MAX_BYTES
#   overrides the limit).
# pull: downloads bars/<NAME>.tar.gz (NAME defaults to the newest by key),
#   checks its sha256, and unpacks into DEST, which must be empty or absent.
#   With --manifest FILE, rebuilds a manifest of DEST at FILE's cutoff and
#   compares roots; a mismatch exits 1 and lists the symbols.
# ls: lists the archives in the bucket with their sizes.
#
# Credentials: R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT
# (https://<account-id>.r2.cloudflarestorage.com) and R2_BUCKET. Any that are
# unset are read from $R2_ENV, default ~/.config/trading/r2.env (KEY=value
# lines; keep it chmod 600 and outside the repo). The key pair reaches curl
# on stdin (-K -), never on the command line, and is never printed.
#
# Needs curl >= 7.75 (--aws-sigv4), tar, gzip, and sha256sum or shasum.
#
# Testing: R2_LOCAL_STORE=DIR replaces the network with a plain directory, so
# trading/devtools/checks/r2_bars_test.sh runs the whole flow offline.

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PREFIX=bars
# R2's single PUT limit is 5 GiB; stay a little under it. R2_MAX_BYTES
# overrides it (the test sets a tiny limit to reach the check).
MAX_BYTES=${R2_MAX_BYTES:-5300000000}

_die() {
  printf 'r2_bars: %s\n' "$*" >&2
  exit 2
}

_usage() {
  cat >&2 <<'EOF'
usage: r2_bars.sh push --data-dir DIR [--name NAME] [--force]
       r2_bars.sh pull --dest DIR [--name NAME] [--manifest FILE]
       r2_bars.sh ls
EOF
  exit 2
}

_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Reads one KEY=value from the env file without sourcing it, so the file can
# never run code. Quotes around the value are dropped.
_env_value() {
  sed -n "s/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}$1=//p" "$2" \
    | tail -1 | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/"
}

_load_credentials() {
  [ -n "${R2_LOCAL_STORE:-}" ] && return 0
  env_file=${R2_ENV:-$HOME/.config/trading/r2.env}
  for var in R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ENDPOINT R2_BUCKET; do
    eval "cur=\${$var:-}"
    if [ -z "$cur" ] && [ -f "$env_file" ]; then
      cur=$(_env_value "$var" "$env_file")
      eval "$var=\$cur"
    fi
    [ -n "$cur" ] || _die "$var is not set (and not in $env_file)"
  done
  R2_ENDPOINT=${R2_ENDPOINT%/}
  curl --help all 2>/dev/null | grep -q -- '--aws-sigv4' \
    || _die "curl lacks --aws-sigv4 (need curl >= 7.75)"
}

# _curl ARGS... : signed request; the key pair goes to curl on stdin.
_curl() {
  printf 'user = "%s:%s"\n' "$R2_ACCESS_KEY_ID" "$R2_SECRET_ACCESS_KEY" \
    | curl -K - -sS --aws-sigv4 'aws:amz:auto:s3' \
      -H 'x-amz-content-sha256: UNSIGNED-PAYLOAD' "$@"
}

_url() { printf '%s/%s/%s' "$R2_ENDPOINT" "$R2_BUCKET" "$1"; }

# Transport: three verbs over object keys, or a local directory under test.
_exists() {
  if [ -n "${R2_LOCAL_STORE:-}" ]; then
    [ -f "$R2_LOCAL_STORE/$1" ]
  else
    code=$(_curl -I -o /dev/null -w '%{http_code}' "$(_url "$1")") || return 1
    [ "$code" = 200 ]
  fi
}

_put() {
  if [ -n "${R2_LOCAL_STORE:-}" ]; then
    mkdir -p "$(dirname "$R2_LOCAL_STORE/$2")" && cp "$1" "$R2_LOCAL_STORE/$2"
  else
    _curl -f -T "$1" "$(_url "$2")" -o /dev/null
  fi
}

_get() {
  if [ -n "${R2_LOCAL_STORE:-}" ]; then
    cp "$R2_LOCAL_STORE/$1" "$2"
  else
    _curl -f -o "$2" "$(_url "$1")"
  fi
}

# Prints "<key> <bytes>" for every archive, sorted by key.
_list_unsorted() {
  if [ -n "${R2_LOCAL_STORE:-}" ]; then
    [ -d "$R2_LOCAL_STORE/$PREFIX" ] || return 0
    for f in "$R2_LOCAL_STORE/$PREFIX"/*.tar.gz; do
      [ -f "$f" ] || continue
      printf '%s/%s %s\n' "$PREFIX" "$(basename "$f")" "$(wc -c <"$f" | tr -d ' ')"
    done
  else
    # Fetch first so a failed request is an error, not an empty listing.
    # One request returns up to 1,000 keys; there is no paging.
    xml=$(_curl -f "$(_url '')?list-type=2&prefix=$PREFIX/") || _die "cannot list the bucket"
    printf '%s\n' "$xml" \
      | tr '<' '\n' \
      | sed -n -e 's/^Key>\(.*\)$/K \1/p' -e 's/^Size>\(.*\)$/S \1/p' \
      | awk '$1=="K"{k=$2} $1=="S" && k ~ /\.tar\.gz$/ {print k, $2}'
  fi
}

# A failed listing exits 2 here; it never reads as an empty bucket.
_list() {
  listing=$(_list_unsorted) || exit 2
  [ -z "$listing" ] || printf '%s\n' "$listing" | LC_ALL=C sort
}

_push() {
  data_dir='' name="data-$(date -u +%Y%m%d)" force=0
  while [ $# -gt 0 ]; do
    case $1 in
      --data-dir) [ $# -ge 2 ] || _usage; data_dir=$2; shift 2 ;;
      --name) [ $# -ge 2 ] || _usage; name=$2; shift 2 ;;
      --force) force=1; shift ;;
      *) _usage ;;
    esac
  done
  [ -n "$data_dir" ] || _usage
  [ -d "$data_dir" ] || _die "no such directory: $data_dir"
  _load_credentials
  key="$PREFIX/$name.tar.gz"
  if [ "$force" = 0 ] && _exists "$key"; then
    _die "$key already exists (use --force to replace it)"
  fi
  work=$(mktemp -d "${TMPDIR:-/tmp}/r2_bars.XXXXXX")
  trap 'rm -rf "$work"' EXIT
  printf 'r2_bars: packing %s\n' "$data_dir" >&2
  # COPYFILE_DISABLE keeps macOS tar from adding ._ AppleDouble files.
  COPYFILE_DISABLE=1 tar -C "$data_dir" -czf "$work/a.tar.gz" .
  bytes=$(wc -c <"$work/a.tar.gz" | tr -d ' ')
  [ "$bytes" -lt "$MAX_BYTES" ] || _die "archive is $bytes bytes, over the single-upload limit"
  _sha256 "$work/a.tar.gz" >"$work/a.sha256"
  printf 'r2_bars: uploading %s (%s bytes)\n' "$key" "$bytes" >&2
  _put "$work/a.tar.gz" "$key"
  _put "$work/a.sha256" "$key.sha256"
  printf '%s %s sha256=%s\n' "$key" "$bytes" "$(cat "$work/a.sha256")"
}

_pull() {
  dest='' name='' manifest=''
  while [ $# -gt 0 ]; do
    case $1 in
      --dest) [ $# -ge 2 ] || _usage; dest=$2; shift 2 ;;
      --name) [ $# -ge 2 ] || _usage; name=$2; shift 2 ;;
      --manifest) [ $# -ge 2 ] || _usage; manifest=$2; shift 2 ;;
      *) _usage ;;
    esac
  done
  [ -n "$dest" ] || _usage
  if [ -d "$dest" ] && [ -n "$(ls -A "$dest")" ]; then
    _die "destination is not empty: $dest"
  fi
  if [ -n "$manifest" ]; then
    [ -f "$manifest" ] || _die "no such manifest: $manifest"
    cutoff=$(sed -n 's/^# cutoff:* *\([0-9-]*\).*/\1/p' "$manifest" | head -1)
    [ -n "$cutoff" ] || _die "no cutoff line in $manifest"
  fi
  _load_credentials
  if [ -n "$name" ]; then
    key="$PREFIX/$name.tar.gz"
  else
    listing=$(_list) || exit 2
    key=$(printf '%s\n' "$listing" | tail -1 | cut -d' ' -f1)
    [ -n "$key" ] || _die "no archives in the bucket"
  fi
  work=$(mktemp -d "${TMPDIR:-/tmp}/r2_bars.XXXXXX")
  trap 'rm -rf "$work"' EXIT
  printf 'r2_bars: downloading %s\n' "$key" >&2
  _get "$key.sha256" "$work/a.sha256" || _die "cannot fetch $key.sha256"
  _get "$key" "$work/a.tar.gz" || _die "cannot fetch $key"
  want=$(tr -d ' \n' <"$work/a.sha256")
  got=$(_sha256 "$work/a.tar.gz")
  [ "$want" = "$got" ] || _die "sha256 mismatch for $key: want $want, got $got"
  mkdir -p "$dest"
  tar -C "$dest" -xzf "$work/a.tar.gz"
  printf '%s sha256=%s -> %s\n' "$key" "$got" "$dest"
  if [ -n "$manifest" ]; then
    sh "$SCRIPT_DIR/data_manifest.sh" build --data-dir "$dest" --cutoff "$cutoff" \
      --out "$work/pulled.manifest"
    sh "$SCRIPT_DIR/data_manifest.sh" compare "$manifest" "$work/pulled.manifest"
  fi
}

[ $# -ge 1 ] || _usage
cmd=$1
shift
case $cmd in
  push) _push "$@" ;;
  pull) _pull "$@" ;;
  ls) _load_credentials; _list ;;
  *) _usage ;;
esac
