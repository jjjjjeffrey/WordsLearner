---
name: wordslearner-testflight-dual-release
description: Archive and upload new iOS and macOS builds for the WordsLearner app to TestFlight, with project-specific Tuist generation, build-number bumping in Project.swift, macOS sandbox entitlement checks, asc/altool upload fallbacks, and commit-only-after-both-uploads-succeed gating.
---

# WordsLearner Dual TestFlight Release

Use this skill when releasing **WordsLearner** builds to TestFlight for **both iOS and macOS** in one run.

This is a project-specific wrapper around the generic `asc`/`xcodebuild` flows with the exact fixes and checks that were required for this repo.

## Scope

- Regenerate the Tuist workspace
- Resolve/build next build number
- Bump build number in `Project.swift`
- Archive/export iOS (`.ipa`)
- Archive/export macOS (`.pkg`)
- Upload both to TestFlight / App Store Connect
- Verify ASC sees the uploads
- Commit source changes only if both uploads succeed

## Project Facts (WordsLearner)

- Repo root: `.` (run from repo root)
- Workspace: `WordsLearner.xcworkspace`
- Scheme: `WordsLearner`
- ASC app id (Apple ID): `6758244943`
- Bundle id: `com.jeffrey.wordslearner`
- Build number source: `CURRENT_PROJECT_VERSION` in `Project.swift`
- Marketing version source: `MARKETING_VERSION` in `Project.swift`

## Required Preconditions

- `asc` authenticated (`asc auth status`)
- Xcode signing works for both iOS and macOS
- Tuist available (`tuist`)

ASC auth typically uses:

- key file in `~/.asc/AuthKey_<KEY_ID>.p8`
- issuer id from local secret file or env

If `asc auth login` is missing credentials, ask the user to provide `ASC_ISSUER_ID` (the `.p8` file does not contain it).

## Release Workflow

### 1) Regenerate the project (Tuist)

Run:

```bash
tuist install
tuist generate
```

Confirm `WordsLearner.xcworkspace` and scheme `WordsLearner` exist.

### 2) Determine next build number and bump `Project.swift`

Use ASC to inspect latest uploaded/processed builds for both platforms and choose the next build number (usually the max observed + 1):

```bash
asc builds latest --app 6758244943 --platform IOS --next --output json
asc builds latest --app 6758244943 --platform MAC_OS --next --output json
```

Update `CURRENT_PROJECT_VERSION` in `Project.swift`.

Important: this repo also needs explicit Info.plist mappings in `Project.swift` so exported artifacts carry the correct values:

- `CFBundleShortVersionString = $(MARKETING_VERSION)`
- `CFBundleVersion = $(CURRENT_PROJECT_VERSION)`

If these mappings are missing, add them before rebuilding.

### 3) Verify macOS sandbox entitlement exists

Before macOS upload, ensure `WordsLearner/WordsLearner.entitlements` includes:

- `com.apple.security.app-sandbox = true`

Without this, App Store Connect validation rejects the macOS package.

### 4) Archive + export iOS (`.ipa`)

Archive:

```bash
xcodebuild clean archive \
  -workspace WordsLearner.xcworkspace \
  -scheme WordsLearner \
  -configuration Release \
  -archivePath "$PWD/build/release/ios/WordsLearner-iOS.xcarchive" \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates
```

Export:

```bash
xcodebuild -exportArchive \
  -archivePath "$PWD/build/release/ios/WordsLearner-iOS.xcarchive" \
  -exportPath "$PWD/build/release/ios/export" \
  -exportOptionsPlist "$PWD/build/release/ios/ExportOptions.plist" \
  -allowProvisioningUpdates
```

Verify exported IPA metadata (must match the bumped build number):

```bash
tmp=$(mktemp -d)
unzip -qq "$PWD/build/release/ios/export/WordsLearner.ipa" -d "$tmp"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$tmp/Payload/WordsLearner.app/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$tmp/Payload/WordsLearner.app/Info.plist"
rm -rf "$tmp"
```

### 5) Upload iOS build

Preferred:

```bash
asc builds upload \
  --app 6758244943 \
  --ipa "$PWD/build/release/ios/export/WordsLearner.ipa" \
  --wait \
  --poll-interval 30s
```

Notes:

- `asc` may appear silent for a long time while waiting; poll before assuming failure.
- Confirm upload separately with:

```bash
asc builds latest --app 6758244943 --platform IOS --next --output json
```

Expect latest uploaded/processed build number to reflect the new build.

### 6) Archive + export macOS (`.pkg`)

Archive:

```bash
xcodebuild clean archive \
  -workspace WordsLearner.xcworkspace \
  -scheme WordsLearner \
  -configuration Release \
  -archivePath "$PWD/build/release/macos/WordsLearner-macOS.xcarchive" \
  -destination 'generic/platform=macOS' \
  -allowProvisioningUpdates
```

Export:

```bash
xcodebuild -exportArchive \
  -archivePath "$PWD/build/release/macos/WordsLearner-macOS.xcarchive" \
  -exportPath "$PWD/build/release/macos/export" \
  -exportOptionsPlist "$PWD/build/release/macos/ExportOptions.plist" \
  -allowProvisioningUpdates
```

### 7) Upload macOS build (use `altool` fallback if needed)

Attempt `asc` first if supported by the installed version.

Known issue in some `asc` versions:

- pkg upload uses UTI `com.apple.installer-package-archive`
- ASC expects `com.apple.pkg`
- result: validation/upload failure despite valid package

Fallback (recommended for this repo if `asc --pkg` fails):

```bash
xcrun altool --upload-app \
  -f "$PWD/build/release/macos/export/WordsLearner.pkg" \
  -t macos \
  --apiKey <KEY_ID> \
  --apiIssuer <ISSUER_ID> \
  --verbose
```

If `altool --upload-package` stalls on multipart checksum retries, use `--upload-app` for the `.pkg` instead.

Capture the delivery UUID and validate status:

```bash
xcrun altool --build-status --delivery-id <DELIVERY_UUID> \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID> --verbose
```

Expect `build-status = VALID`.

Also confirm via ASC:

```bash
asc builds latest --app 6758244943 --platform MAC_OS --next --output json
```

### 8) Final verification (both platforms)

Both of these should show the new build number as uploaded (and ideally processed):

```bash
asc builds latest --app 6758244943 --platform IOS --next --output json
asc builds latest --app 6758244943 --platform MAC_OS --next --output json
```

### 9) Commit only after both uploads succeed

Commit only source changes needed for the release (typically `Project.swift` and any required entitlement/plist fixes). Do not commit `build/` artifacts.

```bash
git status --short
git add Project.swift WordsLearner/WordsLearner.entitlements
git commit -m "Bump build to <N> for TestFlight uploads"
```

If one platform upload fails, do not commit. Fix and retry first.

## Troubleshooting (Project-Specific)

### Exported IPA has wrong `CFBundleVersion`

Symptom:

- `CURRENT_PROJECT_VERSION` changed in `Project.swift`, but IPA/xcarchive still shows old build number

Fix:

- Ensure `appInfoPlist` in `Project.swift` explicitly sets:
  - `CFBundleVersion` to `$(CURRENT_PROJECT_VERSION)`
  - `CFBundleShortVersionString` to `$(MARKETING_VERSION)`
- Regenerate with Tuist and rebuild

### macOS upload rejected for missing sandbox

Symptom:

- App Store Connect validation error for missing `com.apple.security.app-sandbox`

Fix:

- Add `com.apple.security.app-sandbox` to `WordsLearner/WordsLearner.entitlements`
- Re-archive and re-export macOS package

### `asc builds upload --wait` appears stuck

Actions:

- Check whether ASC already registered the build using `asc builds latest ... --next --output json`
- Wait longer if upload is likely complete but polling output is delayed
- Fall back to `altool` for transport if needed

## Output Expectations (for agent runs)

Report:

- chosen build number
- iOS archive/export paths
- macOS archive/export paths
- upload IDs / delivery UUIDs
- final ASC build-number verification for iOS + macOS
- whether a commit was created (and commit SHA)
