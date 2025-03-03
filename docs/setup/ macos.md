# Setup on Mac OS

## 1. Get Brew

Hi

## 2. Install Opam


```sh
RUN sudo apt update && \
sudo apt install pkg-config libssl-dev vim -y && \
opam install . --deps-only --with-test && \
opam update && \
opam install ocaml-lsp-server odoc ocamlformat utop dune --yes --unlock-base && \
# Install the project dependencies
# For async_ssl
sudo apt-get install libffi-dev && \
opam install trading/analysis/data_sources/eodhd/
```
