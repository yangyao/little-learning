#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
swift build
app_path="$PWD/build/游戏抽屉.app"
mkdir -p build
stage_root="$(mktemp -d "$PWD/build/.preview.XXXXXX")"
stage_app="$stage_root/游戏抽屉.app"
mkdir -p "$stage_app/Contents/MacOS" "$stage_app/Contents/Resources"
cp "$(swift build --show-bin-path)/LittleLearning" "$stage_app/Contents/MacOS/LittleLearning"
cp -R Sources/WebGames "$stage_app/Contents/Resources/WebGames"
cp Assets.xcassets/AppIcon.appiconset/AppIcon.png "$stage_app/Contents/Resources/AppIcon.png"
/usr/libexec/PlistBuddy -c 'Clear dict' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string LittleLearning' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string com.example.littlelearning.preview' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleName string 游戏抽屉' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 2.1' "$stage_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 14.0' "$stage_app/Contents/Info.plist"
codesign --force --sign - "$stage_app"
codesign --verify --deep --strict "$stage_app"
# Replace the bundle as a unit, rather than overwriting a running executable inode.
if [[ -d "$app_path" ]]; then mv "$app_path" "$stage_root/previous.app"; fi
mv "$stage_app" "$app_path"
rm -rf "$stage_root"
echo "$app_path"
