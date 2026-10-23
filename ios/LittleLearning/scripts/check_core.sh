#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
swiftc Core/*.swift Checks/*.swift -o build/core-checks
build/core-checks
