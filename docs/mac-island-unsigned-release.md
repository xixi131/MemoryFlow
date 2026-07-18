# MemoryFlow Island unsigned release

MemoryFlow Island is distributed from the public `xixi131/MemoryFlow` repository without Developer ID signing or Apple notarization. The app bundle is ad-hoc signed after the Release build. Sparkle verifies downloaded updates with an EdDSA signature, while macOS still requires a one-time right-click **Open** or **Privacy & Security** approval for the first installation.

## Required secret

Add the exported Sparkle private seed to the repository Actions secret `SPARKLE_EDDSA_PRIVATE_KEY`. The release command derives the matching public key and injects it through `MEMORYFLOW_UPDATE_PUBLIC_ED_KEY`; the project value is only a development fallback. Never commit, log, attach, or pass the private seed as a command-line argument.

## Release notes

`RELEASE_NOTES.md` is the fixed, single source for user-facing update text. Before publishing `vX.Y.Z`, add a non-empty `## vX.Y.Z` section. The shared release command extracts only that section, adds the unsigned-installation notice, and uses the result for both the GitHub Release body and the Sparkle appcast. A missing or empty matching section fails the release before publication.

## Local release candidate

Use the same command that GitHub Actions invokes. Keep the private key and output outside the repository:

```bash
./mac-island/release.sh \
  --tag v1.1.0 \
  --build-number 10 \
  --previous-version 1.0.9 \
  --previous-build-number 9 \
  --private-key-file /tmp/memoryflow-sparkle-private-key \
  --derived-data /tmp/memoryflow-phase7-cicd-derived \
  --output-dir /tmp/memoryflow-phase7-release
```

The command rejects non-`vX.Y.Z` tags, non-increasing marketing or build versions, missing key material, failed builds, invalid signatures, malformed archives, invalid disk images, and incorrect GitHub URLs. It produces a DMG for first installation, a ZIP for Sparkle full updates, SHA-256 checksums, release metadata, release notes, and signed `appcast.xml`. The DMG contains `MemoryFlowIsland.app` and an Applications shortcut. The checksums and metadata remain CI validation outputs rather than public release assets.

## GitHub Actions release

The `MemoryFlow Island Release` workflow supports:

- a stable release from a pushed `vX.Y.Z` tag;
- a manual draft candidate, which is the default for `workflow_dispatch`;
- a manual prerelease candidate for end-to-end update testing.

Both tag and manual runs read the matching user-facing section from `RELEASE_NOTES.md`; the workflow does not publish raw commit history. It resolves the previous version and build from the latest stable signed appcast, enforces increasing versions, uploads the immutable DMG and app ZIP, and publishes the signed appcast last. The macOS workflow can update the release description if the Windows workflow creates the shared GitHub Release concurrently, but it never replaces an uploaded release asset.

## One-command publish

For normal development releases, run this once from the repository root:

```bash
./publish.sh
```

The script fetches the remote branch and tags, rejects an unsafe or diverged Git state, selects the next semantic version, collects release-note bullets when the matching section is missing, stages all repository changes, blocks machine-local, secret-like, and oversized files, validates the release contract, creates the commit and annotated tag, and atomically pushes both. The tag push triggers the Windows and macOS release workflows. If the network push fails after the local commit and tag are created, running the script again resumes that unpublished tag instead of creating another version.

Use `./publish.sh --dry-run` to inspect the calculated version without changing Git. Automated callers can use repeated `--notes`, an explicit `--version`, and `--yes`; `--wait` also watches the resulting GitHub Actions runs when GitHub CLI is installed and authenticated.

For the normal no-browser release flow, update the release notes and code, then run:

```bash
git add RELEASE_NOTES.md <changed-files>
git commit -m "release: v1.1.0"
git tag -a v1.1.0 -m "MemoryFlow Island v1.1.0"
git push origin HEAD --follow-tags
```

Every release uploads `MemoryFlowIsland-X.Y.Z.dmg` for first installation, the complete `MemoryFlowIsland-X.Y.Z.zip` for Sparkle updates, and `appcast.xml`. When up to three prior stable-release ZIPs are available, the workflow also uploads Sparkle-generated `.delta` files for faster upgrades from those versions. The complete ZIP remains Sparkle's fallback whenever a user's version has no delta or a delta fails verification. GitHub automatically adds source-code ZIP and tarball links. Sparkle release notes are embedded in the signed appcast instead of being uploaded as another file.

The app feed is `https://github.com/xixi131/MemoryFlow/releases/latest/download/appcast.xml`, and each enclosure uses a tag-specific `https://github.com/xixi131/MemoryFlow/releases/download/...` URL. Manual draft assets are not visible to normal clients until the draft is published.

## First installation limitation

This pipeline intentionally has no Developer ID, notarization, staple, or Team ID step. Users download the DMG from GitHub Releases, drag the app onto the Applications shortcut, eject the disk image, and approve the first launch manually. Sparkle EdDSA protects update integrity but does not remove the initial Gatekeeper warning.
