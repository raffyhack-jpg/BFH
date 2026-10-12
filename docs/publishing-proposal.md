# Proposed private IPA publishing job

This proposal is documentation only. It is not installed as an active workflow.

The job would be started manually through GitHub Actions. It would validate
original skeletal playback, run the simulation checks, build an unsigned ARM64
IPA, and attach that IPA to a prerelease in the private raffyhack-jpg/BFH repository.
It would not trigger on pushes or pull requests. Repository write permission
would be limited to this publishing job; ordinary build jobs keep read access.

The exact requested permission is `contents: write` for that job. GitHub grants
that scope for repository contents and releases, so it is broader than a
release-only permission. The job uses the temporary GitHub Actions token;
no personal token is requested or stored. Checkout does not persist credentials.

Automatic approval review rejected the earlier proposal and requires explicit
approval before this permission change is activated. No release has been uploaded
through this proposal. It is intended to avoid the full Actions artifact quota.

```yaml
name: Publish unsigned iPhone prototype
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  publish:
    runs-on: macos-15
    timeout-minutes: 20
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - name: Validate original character assets
        run: bash scripts/check_animation.sh
      - name: Build and test
        run: bash scripts/build_unsigned.sh
      - name: Attach IPA to private prerelease
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          tag="prototype-${GITHUB_SHA:0:12}"
          gh release create "$tag" build/PocketFront-unsigned.ipa \
            --target "$GITHUB_SHA" --prerelease \
            --title "iPhone prototype ${GITHUB_SHA:0:12}" \
            --notes "Unsigned ARM64 iPhone prototype. SceneKit import, game-core checks and Xcode build passed. Requires device signing. Original faction models use original weighted skeletal animation. Original maps, weapons and full gameplay fidelity remain unfinished."
```
