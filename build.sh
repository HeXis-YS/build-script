#!/bin/bash
export PATH="$HOME/go/bin:$PATH"
export CGO_ENABLED=0
export GOEXPERIMENT=newinliner
export GOGC=off
export GOMEMLIMIT=4GiB

cd $HOME

git clone https://github.com/XTLS/Xray-core

pushd Xray-core
tag="$(git describe --abbrev=0 --tags)"
git checkout $tag

XGCFLAGS="-B"
XLDFLAGS="-X github.com/xtls/xray-core/core.build=$(git describe --tags) -s -w -buildid="

echo "Building Xray-core $tag"
for goamd64 in v2 v3
do
    export GOAMD64=${goamd64}
    GOOS=linux go build -o ../xray_linux_amd64_${goamd64} -trimpath -gcflags=all="$XGCFLAGS" -ldflags=all="$XLDFLAGS" ./main
    GOOS=windows go build -o ../xray_windows_amd64_${goamd64}.exe -trimpath -gcflags=all="$XGCFLAGS" -ldflags="$XLDFLAGS" ./main
done
popd
