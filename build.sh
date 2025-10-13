#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/tmp/build-script"
DIST_DIR="$ROOT_DIR/dist";
GOHOME="$ROOT_DIR/.go";
GOPATH="$ROOT_DIR/.gopath"
sudo rm -rf "$ROOT_DIR"
mkdir -p "$DIST_DIR" "$GOPATH" "$GOHOME"
pushd "$ROOT_DIR"

GO_READY="false"

curl_get() { curl -fsSL "$1"; }

get_latest_release() { curl_get "https://api.github.com/repos/$1/releases/latest"; }

get_latest_version() { get_latest_release $1 | jq -r ".tag_name"; }

FORCE_REBUILD=${FORCE_REBUILD:-"false"}

get_latest_release "HeXis-YS/build-script" | jq -r ".body" > $ROOT_DIR/version.json

update_version() {
  echo $(jq ".$1.revision |=. +1 | .$1.version = "\""$2"\" $ROOT_DIR/version.json) > $ROOT_DIR/version.json
}

go_flags() {
  export GOGC=off \
    GOMEMLIMIT=4GiB \
    CGO_ENABLED=0 \
    GOEXPERIMENT=greenteagc \
    GOGCFLAGS="-l=4 -B" \
    GOLDFLAGS="-s -w -buildid=" \
    GOFLAGS="-trimpath -buildvcs=false"
}

install_go() {
  if [[ "$GO_READY" == "true" ]]; then
    return
  fi
  local GO_LATEST_VERSION=$(curl_get https://go.dev/dl/?mode=json | jq -r ".[0].version")
  curl_get "https://go.dev/dl/${GO_LATEST_VERSION}.linux-amd64.tar.gz" | tar -xzf- -C "$GOHOME" --strip-components=1
  export PATH="$GOHOME/bin:$PATH" GOROOT="$GOHOME" GOPATH="$GOPATH"
  go version
  go_flags
  GO_READY="true"
}

check_update() {
  local LATEST_VERSION=$(get_latest_version $1)
  local CURRENT_VERSION=$(jq -r ".$2.version" $ROOT_DIR/version.json)
  if [[ $CURRENT_VERSION != $LATEST_VERSION ]]; then
    git clone --branch $LATEST_VERSION --depth 1 --single-branch --no-tags https://github.com/$1.git $2
    update_version $2 $LATEST_VERSION
    echo "$LATEST_VERSION"
  fi
}

update_frp() {
  local LATEST_VERSION=$(check_update fatedier/frp frp)
  if [[ -z $LATEST_VERSION ]]; then
    return
  fi
  pushd frp
  install_go
  mkdir out
  for goos in "linux" "windows"; do
    progs=("frpc")
    suffix=""
    if [[ "$goos" == "linux" ]]; then
      progs+=("frps")
    else
      suffix=".exe"
    fi
    for goamd64 in "v2" "v3"; do
      for prog in ${progs[@]}; do
        GOOS=$goos GOARCH=amd64 GOAMD64=$goamd64 go build $GOFLAGS -gcflags=all="$GOGCFLAGS" -ldflags="$GOLDFLAGS" -o out/${prog}_amd64_$goamd64$suffix ./cmd/$prog
      done
    done
    pushd out
    if [[ "$goos" == "linux" ]]; then
      tar -cf $DIST_DIR/frp_linux.tar *
      gzip -9 $DIST_DIR/frp_linux.tar
    else
      zip -9 $DIST_DIR/frp_windows.zip *
    fi
    rm -rf *
    popd
  done
  popd
}

update_frp