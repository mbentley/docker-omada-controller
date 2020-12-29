#!/usr/bin/env bash

set -e

IMAGE="mbentley/omada-controller"
TAG=${TAG:-latest}
DOCKERFILE=${DOCKERFILE:-Dockerfile}

usage() {
  echo "usage: $0 [ amd64 | arm64 | armv7l ]" 2>&1
  exit 1
}

case "$1" in
amd64|"")
  BUILD_ARGS=()
  ;;
arm64)
  BUILD_ARGS=(
    --build-arg ARCH="$1"
  )
  TAG=${TAG}-${1}
  ;;
armv7l)
  BUILD_ARGS=(
    --build-arg ARCH="$1"
    --build-arg BASE=ubuntu:16.04
  )
  TAG=${TAG}-${1}
  ;;
*)
  usage
  ;;
esac

docker build -f "${DOCKERFILE}" "${BUILD_ARGS[@]}" -t "${IMAGE}:${TAG}" .