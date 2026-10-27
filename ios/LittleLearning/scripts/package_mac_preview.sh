#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
swift build
app_path="$PWD/build/千臻乐园.app"
mkdir -p build
stage_root="$(mktemp -d "$PWD/build/.preview.XXXXXX")"
stage_app="$stage_root/千臻乐园.app"
mkdir -p "$stage_app/Contents/MacOS" "$stage_app/Contents/Resources"
bin_path="$(swift build --show-bin-path)"
cp "$bin_path/LittleLearning" "$stage_app/Contents/MacOS/LittleLearning"
# Bundle.module requires the Swift Package resource bundle in the app.
cp -R "$bin_path/LittleLearning_LittleLearning.bundle" "$stage_app/Contents/Resources/"
cp -R Sources/WebGames "$stage_app/Contents/Resources/WebGames"
cp -R Sources/Configuration "$stage_app/Contents/Resources/Configuration"
cp Assets.xcassets/AppIcon.appiconset/AppIcon.png "$stage_app/Contents/Resources/AppIcon.png"
/usr/libexec/PlistBuddy -c 'Clear dict' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string LittleLearning' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string com.example.littlelearning.preview' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleName string 千臻乐园' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 2.5.0' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity dict' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSLocalNetworkUsageDescription string 连接家中NAS同步积分和兑换。' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 14.0' "$stage_app/Contents/Info.plist"
codesign --force --sign - "$stage_app"
codesign --verify --deep --strict "$stage_app"
# Replace the bundle as a unit, rather than overwriting a running executable inode.
if [[ -d "$app_path" ]]; then mv "$app_path" "$stage_root/previous.app"; fi
mv "$stage_app" "$app_path"
rm -rf "$stage_root"
echo "$app_path"
