#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc Shared/Cleanup.swift macOS/main.swift -o build/cleanup-image \
    -Xlinker -undefined -Xlinker dynamic_lookup
