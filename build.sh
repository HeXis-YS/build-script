#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/tmp/build-script"
OUT_DIR="$ROOT_DIR/out";
DIST_DIR="$ROOT_DIR/dist";
GOHOME="$ROOT_DIR/.go";
GOPATH="$ROOT_DIR/.gopath"

pack() {
  local format=$1
  local filename=$DIST_DIR/$2.tar
  pushd $OUT_DIR
  case "$format" in
    tgz)
      tar -cf $filename *
      gzip -9 $filename
      ;;
    zip)
      zip -9 $filename *
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
  curl_get "https://go.dev/dl/${GO_LATEST_VERSION}.linux-amd64.tar.gz" | tar -xzf- -C "$GOHOME" --strip-components=1
  export PATH="$GOHOME/bin:$PATH" GOROOT="$GOHOME" GOPATH="$GOPATH"
  go version
  go_flags
  GO_READY="true"
}

check_update() {
  local repo=$1
  local name=$2
  local UPDATE_AVAILABLE="false"
  case "$name" in
    frp)
      UPDATE_AVAILABLE=$GO_UPDATE_AVAILABLE
      ;;
  esac
  local LATEST_VERSION=$(get_latest_release_api $repo | jq -r ".tag_name")
  if [[ $UPDATE_AVAILABLE == "false" ]]; then
    local CURRENT_VERSION=$(jq -r ".$name.version" $ROOT_DIR/version.json)
    if [[ $CURRENT_VERSION == $LATEST_VERSION ]]; then
      return
    fi
  fi
  update_version $name $LATEST_VERSION
  git clone --branch $LATEST_VERSION --depth 1 --single-branch --no-tags https://github.com/$repo.git $name
  echo "$LATEST_VERSION"
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

GO_READY="false"
GO_UPDATE_AVAILABLE="false"
GO_LATEST_VERSION=$(curl_get https://go.dev/dl/?mode=json | jq -r ".[0].version")
GO_CURRENT_VERSION=$(jq -r ".go.version" $ROOT_DIR/version.json)
if [[ $GO_CURRENT_VERSION != $GO_LATEST_VERSION ]]; then
  GO_UPDATE_AVAILABLE="true"
  update_version go $GO_LATEST_VERSION
fi

update_frp
