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
RELEASE_NOTES_FILE=""
PHASED_ROLLOUT_INTERVAL="86400"

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
  --release-notes PATH          Markdown release notes input
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
    --release-notes) RELEASE_NOTES_FILE="${2:-}"; shift 2 ;;
    --phased-rollout-seconds) PHASED_ROLLOUT_INTERVAL="${2:-}"; shift 2 ;;
    --repository) REPOSITORY="${2:-}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

for command_name in codesign ditto git plutil ruby shasum stat swift xcodebuild; do
  require_command "$command_name"
done

[[ "$TAG" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]] || fail "tag must match vX.Y.Z"
MARKETING_VERSION="${TAG#v}"
[[ "$BUILD_VERSION" =~ '^[1-9][0-9]*$' ]] || fail "build number must be a positive integer"
[[ "$REPOSITORY" =~ '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' ]] || fail "repository must be OWNER/REPO"
[[ "$PHASED_ROLLOUT_INTERVAL" =~ '^[1-9][0-9]*$' ]] || fail "phased rollout interval must be positive"
[[ -f "$PRIVATE_KEY_FILE" && -s "$PRIVATE_KEY_FILE" ]] || fail "Sparkle EdDSA private key file is missing or empty"
[[ -z "$RELEASE_NOTES_FILE" || -f "$RELEASE_NOTES_FILE" ]] || fail "release notes file does not exist"

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
trap 'rm -rf "$EXPANDED_DIR"' EXIT
ditto -x -k "$ARCHIVE_PATH" "$EXPANDED_DIR"
[[ -d "$EXPANDED_DIR/MemoryFlowIsland.app/Contents" ]] || fail "archive does not expand to an app bundle"

RELEASE_NOTES_MD="$OUTPUT_DIR/release-notes.md"
if [[ -n "$RELEASE_NOTES_FILE" ]]; then
  cp "$RELEASE_NOTES_FILE" "$RELEASE_NOTES_MD"
else
  {
    print -- "# MemoryFlow Island ${MARKETING_VERSION}"
    print -- ""
    print -- "Unsigned open-source release. On first launch, use right-click Open or approve the app in Privacy and Security."
    print -- ""
    print -- "## Changes"
    git -C "$PROJECT_ROOT" log --no-merges --pretty='- %s' -20
  } > "$RELEASE_NOTES_MD"
fi
ruby -rcgi -e 'body = CGI.escapeHTML(File.read(ARGV[0])); File.write(ARGV[1], "<pre>#{body}</pre>\n")' \
  "$RELEASE_NOTES_MD" "$OUTPUT_DIR/release-notes.html"

ARCHIVE_URL="https://github.com/${REPOSITORY}/releases/download/${TAG}/${ARCHIVE_NAME}"
RELEASE_PAGE_URL="https://github.com/${REPOSITORY}/releases/tag/${TAG}"
RELEASE_NOTES_URL="https://github.com/${REPOSITORY}/releases/download/${TAG}/release-notes.html"
APPCAST_PATH="$OUTPUT_DIR/appcast.xml"
APPCAST_PATH="$APPCAST_PATH" \
ARCHIVE_NAME="$ARCHIVE_NAME" \
ARCHIVE_URL="$ARCHIVE_URL" \
ARCHIVE_LENGTH="$ARCHIVE_LENGTH" \
ARCHIVE_SIGNATURE="$ARCHIVE_SIGNATURE" \
ARCHIVE_SHA256="$ARCHIVE_SHA256" \
BUILD_VERSION="$BUILD_VERSION" \
MARKETING_VERSION="$MARKETING_VERSION" \
MINIMUM_MACOS="$MINIMUM_MACOS" \
PHASED_ROLLOUT_INTERVAL="$PHASED_ROLLOUT_INTERVAL" \
PUBLICATION_DATE="$(date -R)" \
RELEASE_NOTES_URL="$RELEASE_NOTES_URL" \
RELEASE_PAGE_URL="$RELEASE_PAGE_URL" \
REPOSITORY="$REPOSITORY" \
METADATA_PATH="$OUTPUT_DIR/release-metadata.json" \
ruby "$SCRIPT_DIR/release/generate_appcast.rb"

$SIGN_UPDATE --ed-key-file "$PRIVATE_KEY_FILE" "$APPCAST_PATH" >/dev/null
$SIGN_UPDATE --verify --ed-key-file "$PRIVATE_KEY_FILE" "$APPCAST_PATH" >/dev/null
/usr/bin/grep -Fq "$ARCHIVE_URL" "$APPCAST_PATH" || fail "appcast archive URL contract is invalid"
/usr/bin/grep -Fq 'sparkle:edSignature=' "$APPCAST_PATH" || fail "appcast is missing the archive signature"

rm -rf "$STAGED_APP"
print -- "Release candidate ready: $OUTPUT_DIR"
print -- "Archive: $ARCHIVE_NAME ($ARCHIVE_LENGTH bytes)"
print -- "Feed: $FEED_URL"
