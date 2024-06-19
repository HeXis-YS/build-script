#!/bin/bash
export CGO_ENABLED=0
export GOAMD64=v3
export GOEXPERIMENT=newinliner
export GOGC=off
export GOMEMLIMIT=4GiB
export GO_GCFLAGS="-B"
export GO_LDFLAGS="-s -w"


git clone https://github.com/HeXis-YS/go --depth=1
pushd go/src
./make.bash
popd
rm -rf go/.git
