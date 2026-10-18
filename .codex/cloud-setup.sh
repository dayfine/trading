#!/bin/sh
# Codex cloud environment setup script (DRAFT, unverified; spike per dev/plans/delegation-lanes-2026-10-18.md).
#
# Paste into the environment's "Setup script" box at chatgpt.com/codex → Environments (base image: universal).
# It mirrors the `ci` stage of .devcontainer/Dockerfile; keep the two in step. Setup runs with internet; the
# agent phase does not, so every dependency installs here. Codex caches the finished container for ~12 h.
# Success criteria for the spike: setup completes, then
#   cd trading && eval $(opam env) && dune build @fmt && dune build && dune runtest trading/orders
set -eu
REPO=$(pwd)   # Codex runs setup from the repo root
sudo apt-get update
sudo apt-get install -y opam pkg-config build-essential curl libssl-dev libffi-dev libopenblas-dev liblapack-dev \
  liblapacke-dev libplplot-dev plplot-driver-cairo autoconf automake libtool time jq shellcheck
# TA-Lib 0.6.4 from source (no AVX-512: owl and ta-lib must run on generic x86-64)
cd /tmp
curl -fsSL https://github.com/ta-lib/ta-lib/releases/download/v0.6.4/ta-lib-0.6.4-src.tar.gz -o ta-lib.tar.gz
tar xzf ta-lib.tar.gz && cd ta-lib-0.6.4
./configure --prefix=/usr CFLAGS="-O2 -mtune=generic -march=x86-64-v2" && make -j"$(nproc)" && sudo make install
cd "$REPO"
opam init --disable-sandboxing --bare --yes
opam switch create 5.3.0+flambda --packages=ocaml-variants.5.3.0+options,ocaml-option-flambda --yes
eval "$(opam env --switch=5.3.0+flambda)"
export OWL_CFLAGS="-g -O3 -march=x86-64-v2 -mtune=generic -mfpmath=sse -msse2 -funroll-loops -fno-math-errno -fno-rounding-math -fno-signaling-nans -fexcess-precision=fast -DSFMT_MEXP=19937 -fno-strict-aliasing"
opam install --yes async async_ssl async_unix base bos cohttp-async core core_unix csv ctypes ctypes-foreign fpath \
  ounit2 plplot.5.12.0 owl.1.2 owl-plplot.1.1 ppx_deriving ppx_jane ppx_let sexplib sexp_pretty uri yojson memtrace \
  ocamlformat.0.29.0
find trading -name '*.opam' ! -path '*/_build/*' -exec dirname {} \; | sort -u | while read -r d; do
  opam install "$d" --deps-only --with-test --yes || true
done
echo 'eval "$(opam env --switch=5.3.0+flambda)"' >> "$HOME/.bashrc"
