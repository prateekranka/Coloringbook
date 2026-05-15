# TestFlight Automation

The `TestFlight` GitHub Actions workflow builds ColorFlow, exports an IPA, and uses Fastlane to upload it to TestFlight.

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
