#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/FoldBar.app/Contents/MacOS
xcrun clang -fobjc-arc -mmacosx-version-min=27.0 -c Sources/Bridge/VisibilityBridge.m -o build/VisibilityBridge.o
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx27.0 -import-objc-header Sources/Bridge/VisibilityBridge.h Sources/Core/*.swift Sources/App/*.swift build/VisibilityBridge.o -framework AppKit -framework SwiftUI -framework ApplicationServices -o build/FoldBar.app/Contents/MacOS/FoldBar
cp Resources/Info.plist build/FoldBar.app/Contents/Info.plist
codesign --force --sign - --identifier com.cmmuu.FoldBar build/FoldBar.app
codesign --verify --strict build/FoldBar.app
echo "Built: $(pwd)/build/FoldBar.app"
