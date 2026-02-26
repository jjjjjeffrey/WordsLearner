# Changelog: Remove History Import/Export and Verify Cross-Platform Tests

Date: 2026-02-26

## Summary

This changelog records the removal of the macOS comparison history import/export feature and the follow-up regression verification on both macOS and iOS (iPhone 12 Pro, iOS 26.x).

## Product / UX Changes

### 1. Removed macOS history import/export buttons

- Removed the two sidebar toolbar buttons in the macOS history view:
  - `Import` (`square.and.arrow.down`)
  - `Export` (`square.and.arrow.up`)
- The macOS history toolbar now retains only the remaining actions (filter / clear all).

## Feature / Architecture Changes

### 2. Removed import/export reducer state and actions

- Deleted macOS-only import/export state from `ComparisonHistoryListFeature.State`.
- Removed import/export actions and reducer branches from `ComparisonHistoryListFeature`.
- Removed import/export completion alert flows related to file import/export.

### 3. Removed file importer/exporter UI wiring

- Deleted `fileImporter` / `fileExporter` presentation from `ComparisonHistoryListView`.
- Removed related bindings and helper handlers for importer/exporter completion.

### 4. Removed transfer/document helper types

- Deleted `ComparisonHistoryTransfer.swift`, including:
  - `ComparisonHistoryExportRecord`
  - `ComparisonHistoryExportDocument`

## Project / Build Maintenance

### 5. Regenerated Tuist project after source deletion

- Regenerated the project with `tuist generate` to remove the stale file reference to `ComparisonHistoryTransfer.swift` from `WordsLearner.xcodeproj`.

## Test Verification Results (Completed)

### 6. Full unit test suite passed on macOS

- Ran:
  - `xcodebuild test -workspace WordsLearner.xcworkspace -scheme WordsLearner -destination 'platform=macOS'`
- Result:
  - `98 tests` in `13 suites` passed

### 7. Full unit test suite passed on iOS Simulator (iPhone 12 Pro, iOS 26.2)

- Ran on `iPhone 12 Pro` simulator (`iOS 26.2`):
  - `xcodebuild test -workspace WordsLearner.xcworkspace -scheme WordsLearner -destination 'platform=iOS Simulator,id=D7B80675-822C-4968-8168-EA9247B3EA64'`
- Result:
  - `98 tests` in `13 suites` passed

## Notes

- iOS test logs included UIKit warnings about unbalanced appearance transition calls, but no test failures were caused by these warnings.
- A direct app build check initially failed due to a stale Xcode project file reference after deleting `ComparisonHistoryTransfer.swift`; this was resolved by regenerating the Tuist project.
