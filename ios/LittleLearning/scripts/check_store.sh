#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
swiftc Core/*.swift Sources/UsageStore.swift Sources/CollectionStore.swift Sources/StudyStore.swift Sources/FunStore.swift Checks/StoreChecks/*.swift -o build/store-checks
build/store-checks
