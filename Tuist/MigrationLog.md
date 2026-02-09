# Tuist Migration Log

## Scope
Migrate `WordsLearner` from hand-edited Xcode project workflow to Tuist-generated project/workspace while keeping iOS + macOS behavior and tests stable.

## Baseline (Before Migration)
- 2026-02-09: `xcodebuild build -project WordsLearner.xcodeproj -scheme WordsLearner -configuration Debug -destination "generic/platform=iOS Simulator" -derivedDataPath DerivedDataBaseline`
- Result: build succeeded.

## Tuist Setup
- 2026-02-09: Installed Tuist `4.141.0` at `/Users/zengdaqian/.local/share/mise/installs/tuist/4.141.0/bin/tuist`.
- 2026-02-09: `tuist install` initially failed because `Tuist/Package.swift` had no tools-version header.
- Fix: added `// swift-tools-version: 6.2` at the top of `Tuist/Package.swift`.
- 2026-02-09: `tuist install` and `tuist generate --no-open` then succeeded.

## Migration Decisions
- Kept app `Info.plist` as `.extendingDefault` in `Project.swift` to preserve existing app keys (`UIBackgroundModes`, launch/orientation, etc.).
- Added explicit macOS post-build script to copy/sign SwiftPM frameworks for app runtime packaging consistency.
- Kept test target dependency graph minimal and explicit to avoid duplicate runtime symbols in host-app + test-bundle execution.

## Issues Encountered And Fixes

### 1) Runtime duplicate symbol/class crash in tests
- Symptom:
  `objc[...] Class _TtC22ComposableArchitecture6Logger is implemented in both ...WordsLearner.debug.dylib and ...WordsLearnerTests.xctest...`
- Why it happened:
  after migration, test linkage allowed duplicate availability of TCA/runtime symbols between host app and test bundle.
- Fix:
  reduced direct test target linkage to avoid re-linking products already available transitively from `WordsLearner`, and kept host-based unit test settings (`TEST_HOST` / `BUNDLE_LOADER`) aligned in Tuist settings.
- Result:
  crash disappeared for the affected test runs.

### 2) iOS 26.2 simulator crash in `ResponseDetailFeatureTests.testShareButtonTapped`
- Symptom:
  uncaught `NSInvalidArgumentException` from `ShareSheet` / `UIActivityViewController` path on iPhone 12 Pro iOS 26.2.
- Why it happened:
  reducer called `PlatformShareService.share` directly, so test execution invoked real system share UI.
- Fix:
  introduced dependency-injected share client (`platformShare`) with live implementation and no-op test value; reducer now uses dependency; test overrides and asserts generated share text.
- Result:
  no share-sheet crash in tests, deterministic test behavior.

### 3) `ComparisonHistoryListFeatureTests.clearAllConfirmed_deletesAllRows` state mismatch
- Symptom:
  expected `alert == nil`, actual state still contained clear-all confirmation alert.
- Why it happened:
  timing/order around transient alert dismissal differed after migration/runtime changes, exposing an implicit assumption in test flow.
- Fix:
  explicitly clear alert when handling `.alert(.presented(.clearAllConfirmed))`:
  `state.alert = nil` before delete effect.
- Result:
  test became stable and matched expected state transitions again.

### 4) Git noise from generated/irrelevant files
- Symptom:
  generated artifacts and project files appeared in git unexpectedly.
- Fix:
  consolidated ignore rules and moved to Tuist-first source of truth; added explicit ignore for `.xcodeproj` and removed tracked `WordsLearner.xcodeproj` from index.

## Final Validation

### iOS (Tuist workspace)
- 2026-02-10:
  `xcodebuild test -workspace WordsLearner.xcworkspace -scheme WordsLearner -destination 'id=875B07E5-0CC0-4BB2-AAB6-D06E0042641C' -derivedDataPath DerivedDataIPhone12Pro262Retry`
- Result: **101 passed, 0 failed**.

### macOS (Tuist workspace)
- 2026-02-10:
  `xcodebuild test -workspace WordsLearner.xcworkspace -scheme WordsLearner -destination 'platform=macOS,arch=arm64' -derivedDataPath DerivedDataMigrationCloseout`
- Result: **101 passed, 0 failed**.

## Closeout
- Tuist migration is functionally complete.
- Build and test verification succeeded on both iOS simulator and macOS.
- Remaining source of truth is Tuist manifests (`Project.swift`, `Tuist.swift`, `Tuist/Package.swift`).
