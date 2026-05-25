# TestFlight Automation

The `TestFlight` GitHub Actions workflow builds ColorFlow, exports an IPA, and uses Fastlane to upload it to TestFlight.

## Repeatable Release Command

Use the release helper from the repo root:

```sh
Scripts/release_testflight.sh \
  --variant-name "Gouache TestFlight build" \
  --release-notes "Latest iPad UI build."
```

The helper:

1. verifies `gh` is authenticated,
2. pushes the current branch to `origin`,
3. triggers `.github/workflows/testflight.yml` with the supplied notes,
4. watches the run until success or failure.

Set `PUSH=0` or pass `--no-push` if the branch is already pushed. Set `WATCH=0` or pass `--no-watch` to trigger the workflow without waiting.

## Required GitHub Secrets

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_P8_BASE64`

`ASC_KEY_P8_BASE64` is the base64-encoded App Store Connect API key:

```sh
base64 -i AuthKey_YOURKEYID.p8 | pbcopy
```

## Optional Tester Groups

Set `TESTFLIGHT_GROUPS` as a GitHub repository variable or secret to automatically distribute processed builds to external TestFlight groups.

Use a comma-separated list matching the group names in App Store Connect:

```text
Internal QA, Beta Testers
```

When this value is present, Fastlane waits for Apple processing, applies the changelog, distributes to those groups, and notifies external testers. When it is absent, Fastlane uploads the build and applies the changelog without external group distribution.

## Changelog

The workflow generates the TestFlight changelog from the latest commit message and appends the short commit SHA plus GitHub run number.

Manual runs are available from GitHub Actions under the `TestFlight` workflow.

## Local Verification Before Triggering

Run these before starting a TestFlight upload when touching app code:

```sh
./dev gen
./dev test
```

The workflow also runs `./dev gen` and `./dev test` before archiving.

## Current Process Notes

- The workflow archives without code signing, then uses the App Store Connect API key during `xcodebuild -exportArchive` to create the signed IPA.
- The Fastlane lane only uploads and distributes the exported IPA. Build, signing, export, tests, and changelog generation stay in GitHub Actions.
- Automatic external distribution requires `TESTFLIGHT_GROUPS` to match group names in App Store Connect.
- Local triggering requires a valid GitHub CLI login. If `gh auth status` reports an invalid token, run `gh auth login -h github.com`.
