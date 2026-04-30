# Release

Session Search releases are driven by pushes to `main`.

## Versioning

The deploy workflow runs `semantic-release` with the default conventional commit rules:

- `fix:` creates a patch release.
- `feat:` creates a minor release.
- breaking changes create a major release.
- non-release commits skip packaging because no tag points at the merge commit.

When a release is created, the workflow resolves the semantic-release tag, builds the macOS app with `MARKETING_VERSION` set to the tag without `v`, and sets `CURRENT_PROJECT_VERSION` to the GitHub Actions run number.

## Artifact

The release job signs, notarizes, staples, and zips `SessionSearch.app`, then verifies:

- `CFBundleShortVersionString` equals the semantic-release version.
- `CFBundleVersion` equals the workflow run number.

The verified zip is uploaded to the GitHub Release as:

```text
SessionSearch-vX.Y.Z.app.zip
```

## Sparkle Updates

Sparkle support is wired into the app and release workflow, but appcast generation is gated on these repository secrets:

- `SPARKLE_PUBLIC_ED_KEY`: base64 public EdDSA key embedded into the app.
- `SPARKLE_PRIVATE_ED_KEY`: matching private EdDSA key used by `generate_appcast`.

Generate the keys with Sparkle's `generate_keys` tool and store the public key in GitHub secrets. Export the private key only for CI signing, keep a backup outside the repository, and never commit it.

When both secrets are present, the deploy workflow generates and uploads `appcast.xml` to the same release. The app checks:

```text
https://github.com/neonwatty/session-search/releases/latest/download/appcast.xml
```

If the secrets are missing, the release still publishes the notarized zip and logs a notice that appcast generation was skipped.

## Recovery

If semantic-release succeeds but packaging fails, rerun the failed deploy workflow after fixing the cause. The upload step uses `--clobber`, so a rerun can replace the release zip.

If notarization fails, inspect the notary log in the workflow output. The workflow prints the submission id and fetches Apple's log for rejected submissions.

If Sparkle appcast generation fails, the release zip may already be uploaded. Fix the Sparkle key/tool issue and rerun the workflow so `appcast.xml` is regenerated for the same tag.
