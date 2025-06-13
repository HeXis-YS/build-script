#!/bin/bash
export CGO_ENABLED=0
# export GOEXPERIMENT=newinliner
export GOGC=off
export GOMEMLIMIT=4GiB

GO_LATEST=$(curl https://go.dev/dl/?mode=json | jq -r .[0].version)
wget -O go.tar.gz "https://go.dev/dl/${GO_LATEST}.linux-amd64.tar.gz"
tar -xf go.tar.gz
export PATH="$(pwd)/go/bin:$PATH"

git clone https://github.com/XTLS/Xray-core

pushd Xray-core
tag="$(git describe --abbrev=0 --tags)"
git checkout $tag

GCFLAGS="-B"
LDFLAGS="-X github.com/xtls/xray-core/core.build=$(git describe --tags) -s -w -buildid="

echo "Building Xray-core $tag"
for goamd64 in v2 v3
do
    export GOAMD64=${goamd64}
    GOOS=linux go build -o xray_linux_amd64_${goamd64} -trimpath -gcflags=all="$GCFLAGS" -ldflags="$LDFLAGS" ./main
    GOOS=windows go build -o xray_windows_amd64_${goamd64}.exe -trimpath -gcflags=all="$GCFLAGS" -ldflags="$LDFLAGS" ./main
done
popd
