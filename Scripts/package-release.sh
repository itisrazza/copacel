#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF' >&2
Usage: Scripts/package-release.sh <path-to-Copacel.xcarchive> [output-directory]

Signs the Copacel.app inside the given .xcarchive with your local Developer ID
Application certificate, then packages it as a drag-to-Applications DMG.

  <path-to-Copacel.xcarchive>  Archive produced by `xcodebuild archive`, or downloaded
                                and unzipped from the "Release archive" GitHub Actions
                                workflow (runs on push to a release/v* branch).
  [output-directory]           Defaults to ./dist
EOF
    exit 1
}

[[ $# -ge 1 ]] || usage

archive_path=$1
output_dir=${2:-dist}
signing_identity="Developer ID Application: Rares Nistor (APDU9LKPK3)"
volume_name="Copacel"

app_path="$archive_path/Products/Applications/Copacel.app"
[[ -d "$app_path" ]] || { echo "error: Copacel.app not found at $app_path" >&2; exit 1; }

if ! security find-identity -v -p codesigning | grep -qF "$signing_identity"; then
    echo "error: signing identity not found in keychain: $signing_identity" >&2
    echo "Run 'security find-identity -v -p codesigning' to see what's available." >&2
    exit 1
fi

mkdir -p "$output_dir"
signed_app="$output_dir/Copacel.app"
rm -rf "$signed_app"
cp -R "$app_path" "$signed_app"

echo "Signing $signed_app…"
# --deep is normally discouraged in favour of signing inside-out yourself, but the archive
# arrives completely unsigned (CI builds with CODE_SIGNING_ALLOWED=NO) and this app has no
# embedded frameworks or helper bundles, so a single deep sign is both correct and simplest.
codesign --force --deep --timestamp --sign "$signing_identity" "$signed_app"

echo "Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$signed_app"
spctl --assess --type execute --verbose=2 "$signed_app" \
    || echo "note: Gatekeeper assessment failed — expected pre-notarization, first launch elsewhere needs right-click > Open."

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$signed_app/Contents/Info.plist")
dmg_path="$output_dir/Copacel-$version.dmg"

staging_dir=$(mktemp -d)
trap 'rm -rf "$staging_dir"' EXIT

cp -R "$signed_app" "$staging_dir/"
ln -s /Applications "$staging_dir/Applications"

rm -f "$dmg_path"
echo "Building $dmg_path…"
hdiutil create -volname "$volume_name" -srcfolder "$staging_dir" -ov -format UDZO "$dmg_path"

echo
echo "Done: $dmg_path"
echo "Not notarized — first launch on another Mac still needs a right-click > Open."
echo
echo "To publish:"
echo "  gh release create \"v$version\" \"$dmg_path\" --title \"Copacel $version\" --generate-notes"
