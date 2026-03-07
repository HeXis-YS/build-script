#!/usr/bin/bash
export CGO_ENABLED=0
export GOGC=off
export GOMEMLIMIT=4GiB

if [ ! -d go/bin ]; then
    GO_LATEST=$(curl https://go.dev/dl/?mode=json | jq -r .[0].version)
    wget -qO- "https://go.dev/dl/${GO_LATEST}.linux-amd64.tar.gz" | tar -xzf-
fi
export PATH="$(pwd)/go/bin:$PATH"

if [ ! -d Xray-core/.git ]; then
    rm -rf Xray-core
    XRAY_TAG=$(curl -fsSL "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | jq -r ".tag_name")
    git clone -b $XRAY_TAG --depth 1 --single-branch https://github.com/XTLS/Xray-core
fi

pushd Xray-core

GCFLAGS="-l=4 -B"
LDFLAGS="-X github.com/xtls/xray-core/core.build=$(git rev-parse HEAD | cut -c 1-7) -s -w -buildid="

echo "Building Xray-core $tag"
for goamd64 in v2 v3
do
    export GOAMD64=${goamd64}
    GOOS=linux go build -o ../xray_linux_amd64_${goamd64} -trimpath -buildvcs=false -gcflags=all="$GCFLAGS" -ldflags="$LDFLAGS" ./main
    GOOS=windows go build -o ../xray_windows_amd64_${goamd64}.exe -trimpath -buildvcs=false -gcflags=all="$GCFLAGS" -ldflags="$LDFLAGS" ./main
done
popd
