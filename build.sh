#!/bin/bash
export PATH="$HOME/go/bin:$PATH"
export CGO_ENABLED=0
# export GOEXPERIMENT=newinliner
export GOGC=off
export GOMEMLIMIT=4GiB

cd $HOME

git clone https://github.com/fatedier/frp -b master

pushd frp
tag="$(git describe --abbrev=0 --tags)"
git checkout $tag

GCFLAGS="-B"
LDFLAGS="-s -w -buildid="

echo "Building frp $tag"
for goamd64 in v2 v3
do
    export GOAMD64=${goamd64}
    GOOS=linux go build -o ../frps_linux_amd64_${goamd64} -trimpath -gcflags=all="$GCFLAGS" -ldflags="$LDFLAGS" ./cmd/frps
    GOOS=linux go build -o ../frpc_linux_amd64_${goamd64} -trimpath -gcflags=all="$GCFLAGS" -ldflags="$LDFLAGS" ./cmd/frpc
    GOOS=windows go build -o ../frpc_windows_amd64_${goamd64}.exe -trimpath -gcflags=all="$GCFLAGS" -ldflags="$LDFLAGS" ./cmd/frpc
done
popd
