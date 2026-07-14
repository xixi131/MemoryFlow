#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_PATH="$SCRIPT_DIR/MemoryFlowIsland.xcodeproj"
SCHEME="MemoryFlowIsland"
REPOSITORY="${GITHUB_REPOSITORY:-xixi131/MemoryFlow}"
TAG=""
BUILD_VERSION=""
PREVIOUS_VERSION=""
PREVIOUS_BUILD=""
PRIVATE_KEY_FILE=""
OUTPUT_DIR=""
DERIVED_DATA="${MEMORYFLOW_DERIVED_DATA:-/tmp/memoryflow-phase7-cicd-derived}"
RELEASE_NOTES_FILE="$PROJECT_ROOT/RELEASE_NOTES.md"
PHASED_ROLLOUT_INTERVAL="86400"
DELTA_ARCHIVES_DIR=""
MAXIMUM_DELTAS="3"

usage() {
  cat <<'USAGE'
Usage: ./mac-island/release.sh --tag vX.Y.Z --build-number N --private-key-file PATH [options]

Required:
  --tag TAG                     Stable v-prefixed semantic version, for example v1.1.0
  --build-number NUMBER         Monotonically increasing positive CFBundleVersion
  --private-key-file PATH       Sparkle EdDSA private seed file (never committed)

Options:
  --previous-version VERSION    Previous marketing version; auto-detected from stable Git tags
  --previous-build-number N     Previous build number; defaults to 0 for the first release
  --output-dir PATH             Output directory (default: /tmp/memoryflow-release-TAG)
  --derived-data PATH           Xcode DerivedData directory
  --delta-archives-dir PATH     Directory of prior full Sparkle ZIP archives to delta from
  --maximum-deltas N            Positive maximum prior versions to delta from (default: 3)
  --phased-rollout-seconds N    Sparkle phased rollout interval (default: 86400)
  --repository OWNER/REPO       GitHub release target (default: xixi131/MemoryFlow)
  --help                        Show this help
USAGE
}

fail() {
  print -u2 -- "release: $*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command is unavailable: $1"
}

while (( $# > 0 )); do
  case "$1" in
    --tag) TAG="${2:-}"; shift 2 ;;
    --build-number) BUILD_VERSION="${2:-}"; shift 2 ;;
    --previous-version) PREVIOUS_VERSION="${2:-}"; shift 2 ;;
    --previous-build-number) PREVIOUS_BUILD="${2:-}"; shift 2 ;;
    --private-key-file) PRIVATE_KEY_FILE="${2:-}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
    --derived-data) DERIVED_DATA="${2:-}"; shift 2 ;;
    --delta-archives-dir) DELTA_ARCHIVES_DIR="${2:-}"; shift 2 ;;
    --maximum-deltas) MAXIMUM_DELTAS="${2:-}"; shift 2 ;;
    --phased-rollout-seconds) PHASED_ROLLOUT_INTERVAL="${2:-}"; shift 2 ;;
    --repository) REPOSITORY="${2:-}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

for command_name in codesign ditto git hdiutil plutil ruby shasum stat swift xcodebuild; do
  require_command "$command_name"
done

[[ "$TAG" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]] || fail "tag must match vX.Y.Z"
MARKETING_VERSION="${TAG#v}"
[[ "$BUILD_VERSION" =~ '^[1-9][0-9]*$' ]] || fail "build number must be a positive integer"
[[ "$REPOSITORY" =~ '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' ]] || fail "repository must be OWNER/REPO"
[[ "$PHASED_ROLLOUT_INTERVAL" =~ '^[1-9][0-9]*$' ]] || fail "phased rollout interval must be positive"
[[ "$MAXIMUM_DELTAS" =~ '^[1-9][0-9]*$' ]] || fail "maximum deltas must be a positive integer"
[[ -f "$PRIVATE_KEY_FILE" && -s "$PRIVATE_KEY_FILE" ]] || fail "Sparkle EdDSA private key file is missing or empty"
[[ -f "$RELEASE_NOTES_FILE" ]] || fail "release notes file does not exist: $RELEASE_NOTES_FILE"
[[ -z "$DELTA_ARCHIVES_DIR" || -d "$DELTA_ARCHIVES_DIR" ]] || fail "delta archives directory does not exist: $DELTA_ARCHIVES_DIR"

PUBLIC_ED_KEY="$(swift -e '
  import CryptoKit
  import Foundation
  do {
    let encoded = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let seed = Data(base64Encoded: encoded) else { throw CocoaError(.fileReadCorruptFile) }
    let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
    print(privateKey.publicKey.rawRepresentation.base64EncodedString())
  } catch {
    FileHandle.standardError.write(Data("Invalid Sparkle EdDSA private seed\n".utf8))
    exit(1)
  }
' "$PRIVATE_KEY_FILE")" || fail "Sparkle EdDSA private key is not a valid base64-encoded 32-byte seed"
[[ -n "$PUBLIC_ED_KEY" ]] || fail "could not derive the Sparkle public key"

PREVIOUS_TAG=""
if [[ -z "$PREVIOUS_VERSION" ]]; then
  PREVIOUS_TAG="$(git -C "$PROJECT_ROOT" tag --list 'v[0-9]*' --sort=-version:refname | /usr/bin/grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | /usr/bin/grep -v "^${TAG}$" | head -n 1 || true)"
  PREVIOUS_VERSION="${PREVIOUS_TAG#v}"
fi
PREVIOUS_VERSION="${PREVIOUS_VERSION:-0.0.0}"
if [[ -z "$PREVIOUS_BUILD" && -n "$PREVIOUS_TAG" ]]; then
  PREVIOUS_BUILD="$(git -C "$PROJECT_ROOT" show "${PREVIOUS_TAG}:mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj" 2>/dev/null | awk '/CURRENT_PROJECT_VERSION = [0-9]+;/{gsub(";", "", $3); print $3; exit}' || true)"
  [[ -n "$PREVIOUS_BUILD" ]] || fail "could not determine the build for $PREVIOUS_TAG; pass --previous-build-number"
fi
PREVIOUS_BUILD="${PREVIOUS_BUILD:-0}"
[[ "$PREVIOUS_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || fail "previous version must match X.Y.Z"
[[ "$PREVIOUS_BUILD" =~ '^[0-9]+$' ]] || fail "previous build number must be a non-negative integer"

ruby -rrubygems -e '
  current = Gem::Version.new(ARGV.fetch(0))
  previous = Gem::Version.new(ARGV.fetch(1))
  abort("marketing version #{current} must be greater than #{previous}") unless current > previous
' "$MARKETING_VERSION" "$PREVIOUS_VERSION" || fail "marketing version is not monotonic"
(( BUILD_VERSION > PREVIOUS_BUILD )) || fail "build number $BUILD_VERSION must be greater than $PREVIOUS_BUILD"

OUTPUT_DIR="${OUTPUT_DIR:-/tmp/memoryflow-release-${TAG}}"
[[ "$OUTPUT_DIR" == /tmp/memoryflow-* ]] || fail "output directory must be under /tmp and start with memoryflow-"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

FEED_URL="https://github.com/${REPOSITORY}/releases/latest/download/appcast.xml"

print -- "Building MemoryFlow Island ${MARKETING_VERSION} (${BUILD_VERSION})..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_VERSION" \
  MEMORYFLOW_UPDATE_FEED_URL="$FEED_URL" \
  MEMORYFLOW_UPDATE_PUBLIC_ED_KEY="$PUBLIC_ED_KEY" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

BUILT_APP="$DERIVED_DATA/Build/Products/Release/MemoryFlowIsland.app"
[[ -d "$BUILT_APP/Contents" ]] || fail "build did not produce MemoryFlowIsland.app"
STAGED_APP="$OUTPUT_DIR/MemoryFlowIsland.app"
ditto "$BUILT_APP" "$STAGED_APP"
# Sparkle's delta generator requires standard readable bundle permissions.
find "$STAGED_APP" -type d -exec chmod 755 {} +
find "$STAGED_APP" -type f -perm -u+x -exec chmod 755 {} +
find "$STAGED_APP" -type f ! -perm -u+x -exec chmod 644 {} +
codesign --force --deep --sign - "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"

ACTUAL_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$STAGED_APP/Contents/Info.plist")"
ACTUAL_BUILD="$(plutil -extract CFBundleVersion raw -o - "$STAGED_APP/Contents/Info.plist")"
MINIMUM_MACOS="$(plutil -extract LSMinimumSystemVersion raw -o - "$STAGED_APP/Contents/Info.plist")"
ACTUAL_FEED_URL="$(plutil -extract SUFeedURL raw -o - "$STAGED_APP/Contents/Info.plist")"
ACTUAL_PUBLIC_ED_KEY="$(plutil -extract SUPublicEDKey raw -o - "$STAGED_APP/Contents/Info.plist")"
[[ "$ACTUAL_VERSION" == "$MARKETING_VERSION" ]] || fail "built marketing version is $ACTUAL_VERSION"
[[ "$ACTUAL_BUILD" == "$BUILD_VERSION" ]] || fail "built build version is $ACTUAL_BUILD"
[[ "$ACTUAL_FEED_URL" == "$FEED_URL" ]] || fail "built feed URL is not the GitHub latest-release URL"
[[ "$ACTUAL_PUBLIC_ED_KEY" == "$PUBLIC_ED_KEY" ]] || fail "built public key does not match the signing key"

SIGN_UPDATE="$(find "$DERIVED_DATA/SourcePackages/artifacts" -type f -path '*/Sparkle/bin/sign_update' -perm -111 -print -quit 2>/dev/null || true)"
[[ -x "$SIGN_UPDATE" ]] || fail "Sparkle sign_update was not resolved under DerivedData"
GENERATE_APPCAST="$(find "$DERIVED_DATA/SourcePackages/artifacts" -type f -path '*/Sparkle/bin/generate_appcast' -perm -111 -print -quit 2>/dev/null || true)"
[[ -x "$GENERATE_APPCAST" ]] || fail "Sparkle generate_appcast was not resolved under DerivedData"

ARCHIVE_NAME="MemoryFlowIsland-${MARKETING_VERSION}.zip"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"
ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" "$ARCHIVE_PATH"
ARCHIVE_LENGTH="$(stat -f '%z' "$ARCHIVE_PATH")"
ARCHIVE_SHA256="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
print -- "${ARCHIVE_SHA256}  ${ARCHIVE_NAME}" > "$OUTPUT_DIR/${ARCHIVE_NAME}.sha256"
ARCHIVE_SIGNATURE="$($SIGN_UPDATE --ed-key-file "$PRIVATE_KEY_FILE" -p "$ARCHIVE_PATH")"
[[ -n "$ARCHIVE_SIGNATURE" ]] || fail "Sparkle did not produce an archive signature"
$SIGN_UPDATE --verify --ed-key-file "$PRIVATE_KEY_FILE" "$ARCHIVE_PATH" "$ARCHIVE_SIGNATURE" >/dev/null

EXPANDED_DIR="$(mktemp -d /tmp/memoryflow-release-expand.XXXXXX)"
DMG_STAGING_DIR="$(mktemp -d /tmp/memoryflow-release-dmg.XXXXXX)"
DMG_MOUNT_DIR="$(mktemp -d /tmp/memoryflow-release-mount.XXXXXX)"
DMG_ATTACHED=false
cleanup_release_temporary_files() {
  if [[ "$DMG_ATTACHED" == true ]]; then
    hdiutil detach "$DMG_MOUNT_DIR" -quiet >/dev/null 2>&1 || hdiutil detach "$DMG_MOUNT_DIR" -force -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$EXPANDED_DIR" "$DMG_STAGING_DIR" "$DMG_MOUNT_DIR"
}
trap cleanup_release_temporary_files EXIT
ditto -x -k "$ARCHIVE_PATH" "$EXPANDED_DIR"
[[ -d "$EXPANDED_DIR/MemoryFlowIsland.app/Contents" ]] || fail "archive does not expand to an app bundle"

DMG_NAME="MemoryFlowIsland-${MARKETING_VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
ditto "$STAGED_APP" "$DMG_STAGING_DIR/MemoryFlowIsland.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
hdiutil create \
  -volname "MemoryFlow Island" \
  -srcfolder "$DMG_STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH" >/dev/null
hdiutil verify "$DMG_PATH" >/dev/null
hdiutil attach \
  -readonly \
  -nobrowse \
  -mountpoint "$DMG_MOUNT_DIR" \
  "$DMG_PATH" >/dev/null
DMG_ATTACHED=true
[[ -d "$DMG_MOUNT_DIR/MemoryFlowIsland.app/Contents" ]] || fail "DMG does not contain the app bundle"
[[ -L "$DMG_MOUNT_DIR/Applications" && "$(readlink "$DMG_MOUNT_DIR/Applications")" == "/Applications" ]] || fail "DMG does not contain the Applications shortcut"
hdiutil detach "$DMG_MOUNT_DIR" -quiet >/dev/null
DMG_ATTACHED=false
DMG_LENGTH="$(stat -f '%z' "$DMG_PATH")"
DMG_SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
print -- "${DMG_SHA256}  ${DMG_NAME}" > "$OUTPUT_DIR/${DMG_NAME}.sha256"

RELEASE_NOTES_MD="$OUTPUT_DIR/release-notes.md"
ruby "$SCRIPT_DIR/release/extract_release_notes.rb" \
  --tag "$TAG" \
  --input "$RELEASE_NOTES_FILE" \
  --output "$RELEASE_NOTES_MD"
ruby -rcgi -e 'body = CGI.escapeHTML(File.read(ARGV[0])); File.write(ARGV[1], "<pre>#{body}</pre>\n")' \
  "$RELEASE_NOTES_MD" "$OUTPUT_DIR/release-notes.html"

APPCAST_PATH="$OUTPUT_DIR/appcast.xml"
ARCHIVE_URL_PREFIX="https://github.com/${REPOSITORY}/releases/download/${TAG}/"
SPARKLE_ARCHIVES_DIR="$OUTPUT_DIR/sparkle-archives"
mkdir -p "$SPARKLE_ARCHIVES_DIR"
if [[ -n "$DELTA_ARCHIVES_DIR" ]]; then
  for prior_archive in "$DELTA_ARCHIVES_DIR"/*.zip(N); do
    cp "$prior_archive" "$SPARKLE_ARCHIVES_DIR/"
  done
fi
cp "$ARCHIVE_PATH" "$SPARKLE_ARCHIVES_DIR/"
cp "$OUTPUT_DIR/release-notes.html" "$SPARKLE_ARCHIVES_DIR/${ARCHIVE_NAME%.zip}.html"

"$GENERATE_APPCAST" \
  --ed-key-file "$PRIVATE_KEY_FILE" \
  --versions "$BUILD_VERSION" \
  --maximum-deltas "$MAXIMUM_DELTAS" \
  --delta-compression lzfse \
  --download-url-prefix "$ARCHIVE_URL_PREFIX" \
  --phased-rollout-interval "$PHASED_ROLLOUT_INTERVAL" \
  --embed-release-notes \
  -o "$APPCAST_PATH" \
  "$SPARKLE_ARCHIVES_DIR"

for delta_archive in "$SPARKLE_ARCHIVES_DIR"/*.delta(N); do
  cp "$delta_archive" "$OUTPUT_DIR/"
done

$SIGN_UPDATE --ed-key-file "$PRIVATE_KEY_FILE" "$APPCAST_PATH" >/dev/null
$SIGN_UPDATE --verify --ed-key-file "$PRIVATE_KEY_FILE" "$APPCAST_PATH" >/dev/null

ruby -rjson -e '
  metadata = {
    tag: "v#{ARGV.fetch(1)}",
    marketing_version: ARGV.fetch(1),
    build_version: Integer(ARGV.fetch(2), 10),
    minimum_macos: ARGV.fetch(3),
    archive: ARGV.fetch(4),
    archive_length: Integer(ARGV.fetch(5), 10),
    archive_sha256: ARGV.fetch(6),
    installation_image: ARGV.fetch(7),
    installation_image_length: Integer(ARGV.fetch(8), 10),
    installation_image_sha256: ARGV.fetch(9),
    maximum_deltas: Integer(ARGV.fetch(10), 10)
  }
  File.write(ARGV.fetch(0), JSON.pretty_generate(metadata) + "\n")
' "$OUTPUT_DIR/release-metadata.json" "$MARKETING_VERSION" "$BUILD_VERSION" "$MINIMUM_MACOS" "$ARCHIVE_NAME" "$ARCHIVE_LENGTH" "$ARCHIVE_SHA256" "$DMG_NAME" "$DMG_LENGTH" "$DMG_SHA256" "$MAXIMUM_DELTAS"

/usr/bin/grep -Fq "${ARCHIVE_URL_PREFIX}${ARCHIVE_NAME}" "$APPCAST_PATH" || fail "appcast archive URL contract is invalid"
/usr/bin/grep -Fq 'sparkle:edSignature=' "$APPCAST_PATH" || fail "appcast is missing the archive signature"

rm -rf "$STAGED_APP"
print -- "Release candidate ready: $OUTPUT_DIR"
print -- "Sparkle archive: $ARCHIVE_NAME ($ARCHIVE_LENGTH bytes)"
print -- "Installer image: $DMG_NAME ($DMG_LENGTH bytes)"
print -- "Feed: $FEED_URL"
