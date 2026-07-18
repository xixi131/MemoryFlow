#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

REMOTE="origin"
VERSION_INPUT=""
COMMIT_MESSAGE=""
NOTES=()
ASSUME_YES=false
DRY_RUN=false
SKIP_CHECKS=false
WAIT_FOR_CI=false
MAX_FILE_BYTES=$((50 * 1024 * 1024))
NOTES_OUTPUT=""
ORIGINAL_INDEX_TREE=""
INDEX_MUTATED=false

cleanup() {
  local exit_code=$?
  [[ -z "$NOTES_OUTPUT" ]] || rm -f "$NOTES_OUTPUT"
  if $INDEX_MUTATED && [[ -n "$ORIGINAL_INDEX_TREE" ]]; then
    git read-tree "$ORIGINAL_INDEX_TREE" >/dev/null 2>&1 || true
  fi
  return $exit_code
}

trap cleanup EXIT

usage() {
  cat <<'USAGE'
Usage: ./publish.sh [options]

Interactive default:
  ./publish.sh

Options:
  --version VERSION     Release version: patch, minor, major, X.Y.Z, or vX.Y.Z
  --notes TEXT          Add a release-note bullet; may be repeated
  --message TEXT        Git commit message (default: release: vX.Y.Z)
  --remote NAME         Git remote to push (default: origin)
  --yes                 Do not ask for final confirmation
  --wait                Wait for tag-triggered GitHub Actions runs (requires gh)
  --skip-checks         Skip local syntax and release-contract checks
  --dry-run             Validate and show the plan without staging or changing Git
  --help                Show this help

Examples:
  ./publish.sh
  ./publish.sh --version patch --notes "修复 Todo 页面布局" --yes
  ./publish.sh --version v1.1.0 --wait
USAGE
}

fail() {
  print -u2 -- "publish: $*"
  exit 1
}

info() {
  print -- "publish: $*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command is unavailable: $1"
}

confirm() {
  local prompt="$1"
  $ASSUME_YES && return 0
  [[ -t 0 ]] || fail "$prompt (rerun interactively or pass --yes)"
  local answer=""
  read "answer?$prompt [y/N] "
  [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]]
}

while (( $# > 0 )); do
  case "$1" in
    --version) VERSION_INPUT="${2:-}"; shift 2 ;;
    --notes) NOTES+=("${2:-}"); shift 2 ;;
    --message) COMMIT_MESSAGE="${2:-}"; shift 2 ;;
    --remote) REMOTE="${2:-}"; shift 2 ;;
    --yes) ASSUME_YES=true; shift ;;
    --wait) WAIT_FOR_CI=true; shift ;;
    --skip-checks) SKIP_CHECKS=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

require_command git
require_command ruby

[[ -d .git ]] || fail "run this script from the MemoryFlow Git checkout"
git remote get-url "$REMOTE" >/dev/null 2>&1 || fail "Git remote does not exist: $REMOTE"
[[ -z "$(git rev-parse -q --verify MERGE_HEAD 2>/dev/null || true)" ]] || fail "finish or abort the current merge first"
[[ ! -d .git/rebase-merge && ! -d .git/rebase-apply ]] || fail "finish or abort the current rebase first"
[[ ! -f .git/CHERRY_PICK_HEAD ]] || fail "finish or abort the current cherry-pick first"

BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
[[ -n "$BRANCH" ]] || fail "detached HEAD cannot be published"

info "fetching $REMOTE and release tags"
git fetch "$REMOTE" --tags --prune

REMOTE_BRANCH="refs/remotes/${REMOTE}/${BRANCH}"
if git show-ref --verify --quiet "$REMOTE_BRANCH"; then
  git merge-base --is-ancestor "$REMOTE_BRANCH" HEAD || fail "local branch is behind or diverged from ${REMOTE}/${BRANCH}; synchronize it before publishing"
else
  info "remote branch ${REMOTE}/${BRANCH} does not exist and will be created"
fi

LATEST_TAG="$(git tag --list 'v[0-9]*' --sort=-version:refname | /usr/bin/grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)"
LATEST_TAG="${LATEST_TAG:-v0.0.0}"

WORKTREE_HAS_CHANGES=false
[[ -n "$(git status --porcelain=v1 --untracked-files=normal)" ]] && WORKTREE_HAS_CHANGES=true
RESUME_TAG=""
REMOTE_STABLE_TAGS="$(git ls-remote --tags --refs "$REMOTE" 'refs/tags/v*' | awk '{sub("refs/tags/", "", $2); print $2}' | /usr/bin/grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)"
UNPUBLISHED_TAGS=()
for candidate in ${(f)"$(git tag --list 'v[0-9]*' --sort=-version:refname | /usr/bin/grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)"}; do
  if ! print -r -- "$REMOTE_STABLE_TAGS" | /usr/bin/grep -Fxq "$candidate"; then
    UNPUBLISHED_TAGS+=("$candidate")
    if ! $WORKTREE_HAS_CHANGES && [[ "$(git rev-list -n 1 "$candidate")" == "$(git rev-parse HEAD)" && -z "$RESUME_TAG" ]]; then
      RESUME_TAG="$candidate"
    fi
  fi
done

if (( ${#UNPUBLISHED_TAGS[@]} > 0 )) && [[ -z "$RESUME_TAG" ]]; then
  fail "local release tag(s) are not on $REMOTE: ${UNPUBLISHED_TAGS[*]}; publish or delete them before creating another release"
fi

next_version() {
  ruby -e '
    match = ARGV.fetch(0).match(/\Av(\d+)\.(\d+)\.(\d+)\z/) or abort "invalid current tag"
    major, minor, patch = match.captures.map(&:to_i)
    case ARGV.fetch(1)
    when "major" then major += 1; minor = 0; patch = 0
    when "minor" then minor += 1; patch = 0
    when "patch" then patch += 1
    else abort "invalid bump"
    end
    puts "v#{major}.#{minor}.#{patch}"
  ' "$LATEST_TAG" "$1"
}

if [[ -n "$RESUME_TAG" && -z "$VERSION_INPUT" ]]; then
  TAG="$RESUME_TAG"
  info "resuming unpublished local tag $TAG"
else
  if [[ -z "$VERSION_INPUT" ]]; then
    DEFAULT_TAG="$(next_version patch)"
    if [[ -t 0 ]]; then
      read "VERSION_INPUT?Release version [${DEFAULT_TAG}]: "
    fi
    VERSION_INPUT="${VERSION_INPUT:-$DEFAULT_TAG}"
  fi
  case "$VERSION_INPUT" in
    patch|minor|major) TAG="$(next_version "$VERSION_INPUT")" ;;
    [0-9]*.[0-9]*.[0-9]*) TAG="v${VERSION_INPUT}" ;;
    v*) TAG="$VERSION_INPUT" ;;
    *) fail "version must be patch, minor, major, X.Y.Z, or vX.Y.Z" ;;
  esac
fi

[[ "$TAG" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]] || fail "release tag must match vX.Y.Z: $TAG"

if [[ "$TAG" != "$RESUME_TAG" ]]; then
  ruby -rrubygems -e '
    current = Gem::Version.new(ARGV.fetch(0).delete_prefix("v"))
    latest = Gem::Version.new(ARGV.fetch(1).delete_prefix("v"))
    abort "release version must be greater than #{latest}" unless current > latest
  ' "$TAG" "$LATEST_TAG"
  git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null && fail "local tag already exists: $TAG"
  git ls-remote --exit-code --tags "$REMOTE" "refs/tags/${TAG}" >/dev/null 2>&1 && fail "remote tag already exists: $TAG"
fi

RELEASE_NOTES_FILE="$SCRIPT_DIR/RELEASE_NOTES.md"
EXTRACTOR="$SCRIPT_DIR/mac-island/release/extract_release_notes.rb"
[[ -f "$RELEASE_NOTES_FILE" ]] || fail "missing RELEASE_NOTES.md"
[[ -f "$EXTRACTOR" ]] || fail "missing release-note extractor"

has_release_section() {
  /usr/bin/grep -Eq "^##[[:space:]]+${TAG}$" "$RELEASE_NOTES_FILE"
}

if [[ "$TAG" != "$RESUME_TAG" ]] && ! has_release_section; then
  if (( ${#NOTES[@]} == 0 )); then
    [[ -t 0 ]] || fail "RELEASE_NOTES.md has no ${TAG} section; pass one or more --notes values"
    info "enter release-note bullets for $TAG; submit an empty line to finish"
    while true; do
      note=""
      read "note?- " || true
      [[ -n "$note" ]] || break
      NOTES+=("$note")
    done
  fi
  (( ${#NOTES[@]} > 0 )) || fail "at least one release note is required for $TAG"
  if ! $DRY_RUN; then
    NOTES_PAYLOAD="$(printf '%s\n' "${NOTES[@]}")" ruby - "$TAG" "$RELEASE_NOTES_FILE" <<'RUBY'
tag, path = ARGV
notes = ENV.fetch("NOTES_PAYLOAD").lines.map(&:strip).reject(&:empty?)
abort "release notes cannot be empty" if notes.empty?
content = File.read(path)
section = "## #{tag}\n\n" + notes.map { |note| "- #{note.sub(/\A-\s*/, '')}" }.join("\n") + "\n\n"
marker = content.index(/^## v\d+\.\d+\.\d+\s*$/)
updated = marker ? content.dup.insert(marker, section) : "#{content.rstrip}\n\n#{section}"
File.write(path, updated)
RUBY
  else
    info "dry run would add a $TAG section to RELEASE_NOTES.md"
  fi
fi

if ! $DRY_RUN; then
  NOTES_OUTPUT="$(mktemp /tmp/memoryflow-release-notes.XXXXXX)"
  ruby "$EXTRACTOR" --tag "$TAG" --input "$RELEASE_NOTES_FILE" --output "$NOTES_OUTPUT"
  [[ -s "$NOTES_OUTPUT" ]] || fail "release-note extraction produced an empty file"
fi

if ! $SKIP_CHECKS; then
  info "running release preflight checks"
  zsh -n "$SCRIPT_DIR/mac-island/release.sh"
  ruby -c "$EXTRACTOR" >/dev/null
  [[ -f "$SCRIPT_DIR/.github/workflows/mac-island-release.yml" ]] || fail "macOS release workflow is missing"
  /usr/bin/grep -Fq 'tags:' "$SCRIPT_DIR/.github/workflows/mac-island-release.yml" || fail "macOS workflow is not configured for tag pushes"
fi

if $DRY_RUN; then
  info "dry-run plan: branch=$BRANCH tag=$TAG remote=$REMOTE"
  info "no files were staged, committed, tagged, or pushed"
  exit 0
fi

if [[ "$TAG" != "$RESUME_TAG" ]]; then
  info "staging repository changes"
  ORIGINAL_INDEX_TREE="$(git write-tree)"
  INDEX_MUTATED=true
  git add -A
  git diff --cached --check

  STAGED_PATHS="$(git diff --cached --name-only --diff-filter=ACMR)"
  [[ -n "$STAGED_PATHS" ]] || fail "there are no changes to commit; use an explicit existing commit/tag recovery flow instead"

  SENSITIVE_PATHS="$(print -r -- "$STAGED_PATHS" | /usr/bin/grep -Ei '(^|/)\.env($|\.)|(^|/)(xcuserdata|DerivedData)(/|$)|\.xcuserstate$|\.(p12|pfx|pem|key|mobileprovision)$|(^|/)(id_rsa|id_ed25519)$' || true)"
  [[ -z "$SENSITIVE_PATHS" ]] || fail "refusing to commit sensitive or machine-local paths:\n${SENSITIVE_PATHS}"

  OVERSIZED_PATHS=""
  while IFS= read -r staged_path; do
    [[ -n "$staged_path" && -f "$staged_path" && ! -L "$staged_path" ]] || continue
    file_size="$(stat -f '%z' "$staged_path")"
    if (( file_size > MAX_FILE_BYTES )); then
      OVERSIZED_PATHS+="${staged_path} (${file_size} bytes)\n"
    fi
  done <<< "$STAGED_PATHS"
  [[ -z "$OVERSIZED_PATHS" ]] || fail "refusing to commit files larger than 50 MiB:\n${OVERSIZED_PATHS}"

  git diff --quiet || fail "unstaged tracked changes remain after git add -A"
  COMMIT_MESSAGE="${COMMIT_MESSAGE:-release: ${TAG}}"

  print -- ""
  info "release summary"
  print -- "  branch:  $BRANCH"
  print -- "  remote:  $REMOTE"
  print -- "  tag:     $TAG"
  print -- "  commit:  $COMMIT_MESSAGE"
  print -- "  files:   $(git diff --cached --name-only | wc -l | tr -d ' ')"
  git diff --cached --stat
  print -- ""
  confirm "Commit, tag, and push this release?" || fail "cancelled; changes remain staged"

  git commit -m "$COMMIT_MESSAGE"
  INDEX_MUTATED=false
  git tag -a "$TAG" -m "MemoryFlow $TAG"
else
  info "the release commit and local tag already exist; only the atomic push will be retried"
  confirm "Push branch $BRANCH and tag $TAG to $REMOTE?" || fail "cancelled"
fi

info "atomically pushing branch and release tag"
git push --atomic "$REMOTE" "HEAD:refs/heads/${BRANCH}" "refs/tags/${TAG}:refs/tags/${TAG}"

REMOTE_URL="$(git remote get-url "$REMOTE")"
WEB_URL="${REMOTE_URL%.git}"
WEB_URL="${WEB_URL#git@github.com:}"
[[ "$WEB_URL" == http* ]] || WEB_URL="https://github.com/${WEB_URL}"
info "pushed $TAG; CI/CD release has been triggered"
info "Actions: ${WEB_URL}/actions"

if $WAIT_FOR_CI; then
  require_command gh
  gh auth status >/dev/null 2>&1 || fail "gh is not authenticated; the push succeeded but CI cannot be watched"
  info "waiting for GitHub Actions to register runs for commit $(git rev-parse --short HEAD)"
  RUN_IDS=()
  for attempt in {1..12}; do
    RUN_OUTPUT="$(gh run list --repo "${WEB_URL#https://github.com/}" --commit "$(git rev-parse HEAD)" --event push --limit 10 --json databaseId --jq '.[].databaseId')"
    RUN_IDS=(${(f)RUN_OUTPUT})
    (( ${#RUN_IDS[@]} > 0 )) && break
    sleep 5
  done
  (( ${#RUN_IDS[@]} > 0 )) || fail "push succeeded, but no GitHub Actions run appeared within 60 seconds"
  for run_id in "${RUN_IDS[@]}"; do
    gh run watch "$run_id" --repo "${WEB_URL#https://github.com/}" --exit-status
  done
fi

print -- ""
info "release handoff complete: $TAG"
