#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/tmp/build-script"
OUT_DIR="$ROOT_DIR/out";
DIST_DIR="$ROOT_DIR/dist";
GOHOME="$ROOT_DIR/.go";
GOPATH="$ROOT_DIR/.gopath"

GO_READY="false"

pack() {
  pushd $OUT_DIR
  case "$1" in
    tgz)
      tar -cf $DIST_DIR/$2.tar *
      gzip -9 $DIST_DIR/$2.tar
      ;;
    zip)
      zip -9 $DIST_DIR/$2.zip *
      ;;
  esac
  rm -rf *
  popd
}

curl_get() { curl -fsSL "$1"; }

get_latest_release_api() { curl_get "https://api.github.com/repos/$1/releases/latest"; }

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
  local LATEST_VERSION=$(get_latest_release_api $1 | jq -r ".tag_name")
  local CURRENT_VERSION=$(jq -r ".$2.version" $ROOT_DIR/version.json)
  if [[ $CURRENT_VERSION != $LATEST_VERSION ]]; then
    update_version $2 $LATEST_VERSION
    git clone --branch $LATEST_VERSION --depth 1 --single-branch --no-tags https://github.com/$1.git $2
    echo "$LATEST_VERSION"
  fi
}

update_frp() {
  if [[ -z $(check_update fatedier/frp frp) ]]; then
    return
  fi
  install_go
  pushd frp
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
        GOOS=$goos GOARCH=amd64 GOAMD64=$goamd64 go build $GOFLAGS -gcflags=all="$GOGCFLAGS" -ldflags="$GOLDFLAGS" -o $OUT_DIR/${prog}_amd64_$goamd64$suffix ./cmd/$prog
      done
    done
    if [[ "$goos" == "linux" ]]; then
      pack tgz frp_linux
    else
      pack zip frp_windows
    fi
  done
  popd
}


sudo rm -rf "$ROOT_DIR"
mkdir -p "$OUT_DIR" "$DIST_DIR" "$GOPATH" "$GOHOME"
pushd "$ROOT_DIR"

get_latest_release_api "HeXis-YS/build-script" | jq -r ".body" > $ROOT_DIR/version.json

update_frp
