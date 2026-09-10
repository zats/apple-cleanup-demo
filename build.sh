#!/bin/sh
set -eu
cd "$(dirname "$0")"
xcrun swiftc Cleanup.swift main.swift -o cleanup-image
