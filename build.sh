#!/usr/bin/bash
export CGO_ENABLED=0
export GOGC=off
export GOMEMLIMIT=4GiB

if [ ! -d go/bin ]; then
    GO_LATEST=$(curl https://go.dev/dl/?mode=json | jq -r .[0].version)
    wget -O go.tar.gz "https://go.dev/dl/${GO_LATEST}.linux-amd64.tar.gz"
    tar -xf go.tar.gz
fi

export PATH="$(pwd)/go/bin:$PATH"

if [ ! -d frp/.git ]; then
    rm -rf frp
    git clone https://github.com/fatedier/frp -b master
fi

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
