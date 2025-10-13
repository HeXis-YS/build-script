#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/tmp/build-script"
OUT_DIR="$ROOT_DIR/out";
DIST_DIR="$ROOT_DIR/dist";
GOHOME="$ROOT_DIR/.go";
GOPATH="$ROOT_DIR/.gopath"

pack() {
  local format=$1
  local filename=$DIST_DIR/$2
  pushd $OUT_DIR
  case "$format" in
    tgz)
      tar -cf $filename.tar *
      gzip -9 $filename.tar
      ;;
    zip)
      zip -9 $filename.zip *
      ;;
  esac
  rm -rf *
  popd
}

curl_get() { curl -fsSL "$1"; }

get_latest_release_version() { curl_get "https://api.github.com/repos/$1/releases/latest" | jq -r ".tag_name"; }

update_version() {
  echo $(jq ".$1.revision |=. +1 | .$1.version = "\""$2"\" $DIST_DIR/version.json) > $DIST_DIR/version.json
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
    frp | xray_core)
      UPDATE_AVAILABLE=$GO_UPDATE_AVAILABLE
      ;;
  esac
  local LATEST_VERSION=$(get_latest_release_version $repo)
  if [[ $UPDATE_AVAILABLE == "false" ]]; then
    local CURRENT_VERSION=$(jq -r ".$name.version" $DIST_DIR/version.json)
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
    suffix=".exe"
    pack_format="zip"
    if [[ "$goos" == "linux" ]]; then
      progs+=("frps")
      suffix=""
      pack_format="tgz"

      GOOS=$goos GOARCH=arm64 GOARM64=v9.0,lse,crypto go build $GOFLAGS -gcflags=all="$GOGCFLAGS" -ldflags="$GOLDFLAGS" -o $OUT_DIR/frpc_arm64_v9.0 ./cmd/frpc
    fi
    for goamd64 in "v2" "v3"; do
      for prog in ${progs[@]}; do
        GOOS=$goos GOARCH=amd64 GOAMD64=$goamd64 go build $GOFLAGS -gcflags=all="$GOGCFLAGS" -ldflags="$GOLDFLAGS" -o $OUT_DIR/${prog}_amd64_$goamd64$suffix ./cmd/$prog
      done
    done
    pack $pack_format frp_$goos
  done
  popd
}

update_xray_core() {
  local LATEST_VERSION=$(check_update XTLS/Xray-core xray_core)
  if [[ -z $LATEST_VERSION ]]; then
    return
  fi
  install_go
  pushd xray_core
  for goos in "linux" "windows"; do
    suffix=".exe"
    pack_format="zip"
    if [[ "$goos" == "linux" ]]; then
      suffix=""
      pack_format="tgz"
    fi
    for goamd64 in "v2" "v3"; do
      GOOS=$goos GOARCH=amd64 GOAMD64=$goamd64 go build $GOFLAGS -gcflags=all="$GOGCFLAGS" -ldflags="-X github.com/xtls/xray-core/core.build=$LATEST_VERSION $GOLDFLAGS" -o $OUT_DIR/xray_amd64_$goamd64$suffix ./main
    done
    pack $pack_format xray_core_$goos
  done
  popd
}

update_rclone() {
  if [[ -z $(check_update rclone/rclone rclone) ]]; then
    return
  fi
  install_go
  pushd rclone
  GOOS=linux GOARCH=amd64 GOAMD64=v2 go build $GOFLAGS -gcflags=all="$GOGCFLAGS" -ldflags="-X github.com/rclone/rclone/fs.Version='$(cat VERSION) $GOLDFLAGS" -o $OUT_DIR/rclone_amd64_v2 .
  pack tgz rclone_linux
  popd
}

sudo rm -rf "$ROOT_DIR"
mkdir -p "$OUT_DIR" "$DIST_DIR" "$GOPATH" "$GOHOME"
pushd "$ROOT_DIR"

curl_get "https://github.com/HeXis-YS/build-script/releases/latest/download/version.json" > $DIST_DIR/version.json

GO_READY="false"
GO_UPDATE_AVAILABLE="false"
GO_LATEST_VERSION=$(curl_get "https://go.dev/dl/?mode=json" | jq -r ".[0].version")
GO_CURRENT_VERSION=$(jq -r ".go.version" $DIST_DIR/version.json)
if [[ $GO_CURRENT_VERSION != $GO_LATEST_VERSION ]]; then
  GO_UPDATE_AVAILABLE="true"
  update_version go $GO_LATEST_VERSION
fi

update_frp
update_xray_core
