#!/bin/bash
set -euo pipefail
cd ~; L=~/aud/setup; mkdir -p $L
exec > >(tee -a $L/setup.log) 2>&1
date -Is; id
curl -sSfL -o elan.tgz https://github.com/leanprover/elan/releases/latest/download/elan-x86_64-unknown-linux-gnu.tar.gz
sha256sum elan.tgz; tar xzf elan.tgz; ./elan-init -y --default-toolchain leanprover/lean4:v4.34.1 --no-modify-path
export PATH=~/.elan/bin:$PATH
elan --version; lean --version; lake --version; sha256sum $(lean --print-prefix)/bin/lean
gcc -O2 -Wall -o ~/bin/restrict-af-unix ~/tools/restrict_af_unix.c
cd ~/tools; rm -rf landrun comparator nanoda_lib
git clone -q https://github.com/Zouuup/landrun && (cd landrun && git checkout -q 811cfff51ceaf3d9843708aa6d22e9b84ccac8b4 && GOPATH=~/go GOCACHE=~/.cache/go GOPROXY=https://proxy.golang.org,direct go build -o ~/bin/landrun ./cmd/landrun)
git clone -q https://github.com/leanprover/comparator && cd comparator && git checkout -q d03acab154d269c06e60e4de7e4cc85deebff94b
echo 'leanprover/lean4:v4.34.1' > lean-toolchain; git diff > ~/aud/setup/tool-patch-comparator-toolchain.diff
lake build lean4export comparator
cp .lake/build/bin/comparator ~/bin/; cp $(find .lake -path '*lean4export*/.lake/build/bin/lean4export' | head -1) ~/bin/lean4export
git -C .lake/packages/lean4export rev-parse HEAD
cd ~/tools; git clone -q https://github.com/ammkrn/nanoda_lib && cd nanoda_lib && git checkout -q 3a24072 && git rev-parse HEAD && CARGO_HOME=~/.cargo cargo build --release 2>&1 | tail -3
cp target/release/nanoda_bin ~/bin/
sha256sum ~/bin/*
echo SETUP_OK $(date -Is)
