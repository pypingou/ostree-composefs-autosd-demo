#!/usr/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR"

set -xe

# Check prerequisites
if ! command -v aib &> /dev/null; then
    echo "Error: aib (Automotive Image Builder) not found"
    exit 1
fi

arch=$(arch)

aib --verbose \
  build \
  --distro autosd10 \
  --target qemu \
  --build-dir=_build \
  developer.aib.yml \
  "localhost/developer" \
  "developer.$arch.img"
