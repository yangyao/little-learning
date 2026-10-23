#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
swiftc Core/*.swift Checks/OpticsChecks/QRCodeImageChecks.swift -o build/sync-image-checks
build/sync-image-checks
