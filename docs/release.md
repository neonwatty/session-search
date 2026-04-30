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

## Recovery

If semantic-release succeeds but packaging fails, rerun the failed deploy workflow after fixing the cause. The upload step uses `--clobber`, so a rerun can replace the release zip.

If notarization fails, inspect the notary log in the workflow output. The workflow prints the submission id and fetches Apple's log for rejected submissions.
