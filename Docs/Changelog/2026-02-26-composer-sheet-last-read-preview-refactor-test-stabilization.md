# Changelog: Composer Sheet, Last-Read Restore, Dependency Preview Refactor, and Test Stabilization

Date: 2026-02-26

## Summary

This changelog records a multi-step redesign and stabilization effort around the Word Comparator experience, preview/debug dependency behavior, and snapshot/unit test reliability across iOS and macOS.

## Product / UX Changes

### 1. Composer moved from sidebar to sheet

- Removed `Composer` from the sidebar navigation.
- Sidebar now focuses on:
  - `History`
  - `Background Tasks`
- Added a toolbar-driven `New Comparison` entry point.
- Composer is presented as a sheet instead of a sidebar destination.
- `RecentComparisonsView` was removed from the composer flow.

### 2. Default landing screen changed

- `History` is now the default sidebar selection / landing content.
- Composer no longer appears by default on launch.

### 3. Last-read comparison restore

- Added persistence for the last comparison the user opened.
- On app launch / feature appear:
  - app opens `History`
  - restores and displays the last-read comparison detail if it still exists
- Missing/deleted records are handled safely (cleared persistence, no crash).

### 4. iOS toolbar visibility fixes

- `New Comparison` button now appears correctly on iOS.
- Toolbar placement was adjusted so the button is attached to visible iOS navigation columns instead of only the split-view root.

## Feature / Architecture Refactors

### 5. Composer sheet extraction

- Extracted composer sheet UI into a dedicated view:
  - `WordComparatorComposerSheetView`
- `WordComparatorMainView` now presents the extracted view in `.sheet(...)`.

### 6. Removed `RecentComparisons`

- Deleted `RecentComparisonsFeature` and `RecentComparisonsView`.
- Removed associated state/actions/scopes/tests/snapshots.
- Regenerated the project with `tuist generate`.

## Dependency / Debug / Preview Refactors

### 7. Preview value support for background task manager

- Added `previewValue` to `BackgroundTaskManagerClient`.
- Enabled debug usage safely after DB bootstrap.

### 8. Simplified debug configuration model

- Reworked dependency composition so debug behavior is easier to reason about.
- Debug now primarily overrides `aiService = .previewValue`, while composed clients remain consistent.
- `comparisonGenerator` and `backgroundTaskManager` behavior now follows the underlying AI preview dependency more naturally.

### 9. `AIServiceClient` / `ComparisonGenerationServiceClient` refactor

- Added `AIServiceClient.previewValue`.
- Consolidated preview fixture/source-of-truth output in `AIServiceClient`.
- Moved preview fixture string (`streamString`) ownership to `AIServiceClient` and reused it from generator/test paths.

### 10. Preview generation persistence behavior fixed

- `ComparisonGenerationServiceClient.previewValue` now persists generated comparisons to `ComparisonHistory` (using the real DB with preview AI output).

### 11. `BackgroundTaskManagerClient.previewValue` composition fixed

- `BackgroundTaskManagerClient.previewValue` now composes through `ComparisonGenerationServiceClient.previewValue` (instead of a disconnected no-op path), making preview/debug flows consistent.

## Error Investigation / Runtime Debugging Notes

### 12. DNS failure diagnosis during generation

- Investigated generation failure logs (`NSURLErrorDomain -1003`).
- Determined issue was DNS hostname resolution failure (likely VPN/DNS/proxy/environment-related), not model/generation logic.
- Verified endpoint/host configuration and identified likely network path cause.

## Testing and Snapshot Coverage Expansion

### 13. Expanded unit/integration test coverage

- Added/updated tests for:
  - composer sheet presentation
  - last-read restore behavior
  - invalid last-read cleanup
  - sheet generate/background-generate flows
  - preview dependency composition and persistence behavior

### 14. Composer sheet snapshots added

- Added dedicated snapshot coverage for composer sheet content on:
  - macOS
  - iPhone 12 Pro (iOS 26.2, light/dark)

### 15. `WordComparatorMainView` iOS snapshot harness fix

- Switched iOS snapshots to `UIHostingController`-based `UIViewController` snapshots so UIKit navigation chrome is included.
- Added snapshot waiting / key-window drawing to improve nav bar rendering reliability.

### 16. Navigation bar snapshot fixes for list views

- Updated `BackgroundTasksViewTests` and `ComparisonHistoryListViewTests` iOS snapshots to use a pushed `UINavigationController` context.
- Ensured snapshots look like real in-stack navigation (with back icon).
- Explicitly set back button display mode to `.minimal` (chevron icon only).
- Added parent-context `+` toolbar button in snapshot harness to match real app navigation bars.

### 17. Snapshot stabilization strategy refinement

- Determined the most reliable fix for spinner-related snapshot flakiness is deterministic fixture data (not view-specific test rendering branches).
- Updated `BackgroundTasksViewTests` seeded fixture to avoid `.generating` rows (uses non-animated statuses instead).
- Reverted temporary test-only rendering branch in `BackgroundTaskRow`.

## Snapshot Baseline Maintenance

### 18. Snapshot baselines updated across platforms

- Updated multiple iOS/macOS reference snapshots during the redesign and nav/sheet changes, including:
  - `WordComparatorMainViewTests`
  - `WordComparatorComposerSheetViewTests`
  - `BackgroundTasksViewTests`
  - `ComparisonHistoryListViewTests`
  - `ResponseDetailViewTests`
- Removed obsolete `RecentComparisonsViewTests` snapshots after feature removal.

### 19. macOS snapshot regeneration workaround

- Regenerating a missing macOS snapshot file via direct recording encountered a permission error when creating a brand-new file.
- Workaround used:
  - create/restore placeholder file first
  - record/capture generated snapshot
  - copy generated file from test temp output into repo snapshot directory
- Final macOS `BackgroundTasksViewTests` snapshots were verified successfully.

## Test Verification Results (Completed)

- Full macOS suite passed after major changes (multiple times during the work).
- Full iOS suite on `iPhone 12 Pro / iOS 26.2` passed after snapshot updates.
- Targeted suites repeatedly verified after snapshot harness changes:
  - `WordComparatorMainViewTests`
  - `BackgroundTasksViewTests`
  - `ComparisonHistoryListViewTests`
- Final targeted verification for `BackgroundTasksViewTests` passed on macOS after seeded snapshot stabilization and baseline refresh.

## Notes for Future Work

- If additional spinner-related snapshots become flaky elsewhere, prefer:
  1. deterministic fixture states
  2. test-specific snapshot harness adjustments
  3. only then test-time rendering overrides
- The current navigation snapshot harness pattern (pushed `UINavigationController` + parent toolbar simulation) should be reused for iOS leaf views that are normally rendered inside `WordComparatorMainView`.

