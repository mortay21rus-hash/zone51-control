#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
destination="${1:-$project_root/dist}"
mkdir -p "$destination"
destination="$(cd "$destination" && pwd)"
swift build --package-path "$project_root" -c release --arch arm64
binary_dir="$(swift build --package-path "$project_root" -c release --arch arm64 --show-bin-path)"
application="$destination/Zone51 Control.app"
mkdir -p "$application/Contents/MacOS" "$application/Contents/Resources"
cp "$binary_dir/Zone51Control" "$application/Contents/MacOS/Zone51Control"
cp "$binary_dir/zone51-tool" "$application/Contents/MacOS/zone51-tool"
ditto "$binary_dir/Zone51Control_Zone51Core.bundle" "$application/Contents/Resources/Zone51Control_Zone51Core.bundle"
xcrun swift "$project_root/scripts/Icon.swift" "$project_root/.build/AppIcon.iconset"
iconutil -c icns "$project_root/.build/AppIcon.iconset" -o "$application/Contents/Resources/AppIcon.icns"
python3 - "$application/Contents/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'wb') as output:
    plistlib.dump({
        'CFBundleIdentifier':'io.github.mortay21rus-hash.Zone51Control',
        'CFBundleExecutable':'Zone51Control',
        'CFBundleName':'Zone51 Control',
        'CFBundleDisplayName':'Zone51 Control',
        'CFBundlePackageType':'APPL',
        'CFBundleShortVersionString':'1.0.1',
        'CFBundleVersion':'2',
        'CFBundleIconFile':'AppIcon',
        'LSMinimumSystemVersion':'14.0',
        'LSApplicationCategoryType':'public.app-category.utilities',
        'NSHighResolutionCapable':True,
        'NSPrincipalClass':'NSApplication'
    },output)
PY
codesign --force --sign - --timestamp=none "$application/Contents/MacOS/zone51-tool"
codesign --force --sign - --timestamp=none "$application"
codesign --verify --deep --strict "$application"
file "$application/Contents/MacOS/Zone51Control"
echo "$application"
