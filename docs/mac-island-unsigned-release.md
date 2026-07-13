# MemoryFlow Island unsigned release

MemoryFlow Island is distributed from the public `xixi131/MemoryFlow` repository without Developer ID signing or Apple notarization. The app bundle is ad-hoc signed after the Release build. Sparkle verifies downloaded updates with an EdDSA signature, while macOS still requires a one-time right-click **Open** or **Privacy & Security** approval for the first installation.

## Required secret

Add the exported Sparkle private seed to the repository Actions secret `SPARKLE_EDDSA_PRIVATE_KEY`. The release command derives the matching public key and injects it through `MEMORYFLOW_UPDATE_PUBLIC_ED_KEY`; the project value is only a development fallback. Never commit, log, attach, or pass the private seed as a command-line argument.

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

The command rejects non-`vX.Y.Z` tags, non-increasing marketing or build versions, missing key material, failed builds, invalid signatures, malformed archives, and incorrect GitHub URLs. It produces the app archive, SHA-256 checksum, release metadata, release notes, and signed `appcast.xml`. The checksum and metadata remain CI validation outputs rather than public release assets.

## GitHub Actions release

The `MemoryFlow Island Release` workflow supports:

- a stable release from a pushed `vX.Y.Z` tag;
- a manual draft candidate, which is the default for `workflow_dispatch`;
- a manual prerelease candidate for end-to-end update testing.

Manual runs require a concise user-facing release summary. The workflow does not publish raw commit history. It resolves the previous version and build from the latest stable signed appcast, enforces increasing versions, uploads the immutable app ZIP, and publishes the signed appcast last. Existing release tags are never overwritten.

Only the app ZIP and `appcast.xml` are uploaded by the workflow. GitHub automatically adds source-code ZIP and tarball links, so a public release normally shows four assets. Sparkle release notes are embedded in the signed appcast instead of being uploaded as another file.

The app feed is `https://github.com/xixi131/MemoryFlow/releases/latest/download/appcast.xml`, and each enclosure uses a tag-specific `https://github.com/xixi131/MemoryFlow/releases/download/...` URL. Manual draft assets are not visible to normal clients until the draft is published.

## First installation limitation

This pipeline intentionally has no Developer ID, notarization, staple, or Team ID step. Users download the ZIP from GitHub Releases, drag the app to Applications, and approve the first launch manually. Sparkle EdDSA protects update integrity but does not remove the initial Gatekeeper warning.
