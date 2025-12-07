#!/usr/bin/env bash
set -euo pipefail

echo "Building BitcoinBar..."
./Scripts/package_app.sh release

echo ""
echo "✅ Build complete: BitcoinBar.app"
echo ""
echo "To run: open BitcoinBar.app"
