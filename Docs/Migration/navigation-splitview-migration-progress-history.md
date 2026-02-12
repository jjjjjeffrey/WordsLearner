# NavigationSplitView Migration Progress History

Last updated: 2026-02-13
Scope: WordsLearner navigation architecture migration to a unified `NavigationSplitView` model for macOS and iOS, aligned with TCA state management.

## Summary
The app navigation has been migrated to use `NavigationSplitView` across macOS and iOS with reducer-driven state transitions. Major regressions discovered during migration (detail hydration, iOS compact re-navigation, repeated generation behavior on macOS) were fixed and covered by tests.

## Progress Timeline

### Phase 1: Reference + direction setup
- Reviewed `Examples/NavigationSplitView-TCA-Example-main` and extracted applicable patterns for sidebar/content/detail composition.
- Decided to unify both platforms under one split view architecture while preserving compact iOS behavior.

### Phase 2: Split view unification
- Moved main navigation into split view columns (sidebar/content/detail).
- Kept feature composition in TCA parent reducer (`WordComparatorFeature`) with optional child states for history/background/detail.

### Phase 3: Stored detail hydration fix
- Fixed issue where selecting history/background items sometimes showed `No Response Yet` despite existing stored response.
- Added reducer action path to hydrate markdown rendering for stored responses.

### Phase 4: iOS compact navigation fixes
- Fixed initial iOS compact push behavior when selecting list items.
- Fixed back-then-reselect behavior (cannot re-enter detail after returning to list).
- Introduced reducer-owned presentation signaling (`detailPresentationToken`) to drive compact transitions in a TCA-native way.

### Phase 5: TCA conformance cleanup
- Removed view-derived identity workaround from `WordComparatorMainView`.
- Kept navigation signaling in reducer state and actions (`detailDismissed`, presentation token increment on detail presentation).

### Phase 6: macOS repeated generation regression
- Fixed regression where first generate streamed correctly, but subsequent generates showed header update with `No Response Yet`.
- Root cause: relying on detail view `onAppear` to start streaming in a persistent split view detail pane.
- Fix: parent reducer now explicitly sends `.detail(.startStreaming)` on each generate; detail `onAppear` made idempotent.

## Tests Added/Adjusted
- Added regression test for iOS back-then-reselect detail flow:
  - `WordComparatorFeatureTests.historySelectionAfterDetailDismissShowsNewDetail`
- Added regression test for repeated generation streaming restart:
  - `WordComparatorFeatureTests.generateButtonTappedTwiceStartsStreamingBothTimes`
- Updated existing tests to match reducer-driven streaming/presentation behavior and idempotent detail startup.

## Current Status
- Migration objective for unified split navigation is complete.
- Known migration regressions addressed with targeted tests.
- Remaining warnings in test output are pre-existing Swift concurrency warnings in test code and not migration blockers.

## Follow-up Recommendations
- Optional: reduce/resolve Swift 6 concurrency warnings in tests (`@Sendable`/actor isolation issues).
- Optional: add a UI-level iOS compact navigation integration test if automation coverage is expanded in future.
