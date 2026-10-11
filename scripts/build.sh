#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
foldbar_build_dir="${1:-build}"
mkdir -p "$foldbar_build_dir/FoldBar.app/Contents/MacOS"
xcrun clang -fobjc-arc -mmacosx-version-min=27.0 -c Sources/Bridge/VisibilityBridge.m -o "$foldbar_build_dir/VisibilityBridge.o"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx27.0 -import-objc-header Sources/Bridge/VisibilityBridge.h Sources/Core/*.swift Sources/App/*.swift "$foldbar_build_dir/VisibilityBridge.o" -framework AppKit -framework SwiftUI -framework ApplicationServices -o "$foldbar_build_dir/FoldBar.app/Contents/MacOS/FoldBar"
mkdir -p "$foldbar_build_dir/FoldBar.app/Contents/Resources"
cp -R Resources/*.lproj "$foldbar_build_dir/FoldBar.app/Contents/Resources/"
cp Resources/FoldBar.png "$foldbar_build_dir/FoldBar.app/Contents/Resources/"
bash scripts/build-icon.sh "$foldbar_build_dir"
cp Resources/Info.plist "$foldbar_build_dir/FoldBar.app/Contents/Info.plist"
foldbar_sign_identity="${FOLDBAR_SIGN_IDENTITY:--}"
if [[ "$foldbar_sign_identity" == "-" ]]; then
  codesign --force --sign - --identifier com.cmmuu.FoldBar "$foldbar_build_dir/FoldBar.app"
else
  codesign --force --options runtime --timestamp --sign "$foldbar_sign_identity" --identifier com.cmmuu.FoldBar "$foldbar_build_dir/FoldBar.app"
fi
codesign --verify --strict "$foldbar_build_dir/FoldBar.app"
echo "Built: $(pwd)/$foldbar_build_dir/FoldBar.app"
