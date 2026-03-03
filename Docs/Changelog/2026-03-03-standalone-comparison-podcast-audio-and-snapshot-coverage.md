# Changelog: Standalone Comparison Podcast Audio + Exhaustive Snapshot Coverage

Date: 2026-03-03

## Summary

This changelog records the standalone comparison-audio implementation (independent from multimodal lessons), including podcast transcript generation, audio generation/persistence, TCA navigation fixes, schema migration updates, and exhaustive unit/snapshot test coverage on macOS and iOS.

## Feature Scope Implemented

### 1. Standalone comparison podcast/audio pipeline

- Added isolated comparison audio services (not coupled to `MultimodalLessons*` feature state/UI):
  - `WordsLearner/Services/ComparisonPodcastTranscriptClient.swift`
  - `WordsLearner/Services/ComparisonAudioGeneratorClient.swift`
  - `WordsLearner/Services/ComparisonAudioServiceClient.swift`
  - `WordsLearner/Services/ComparisonNarrationFormatterClient.swift`
  - `WordsLearner/Services/ComparisonAudioAssetStoreClient.swift`
- Added shared ElevenLabs generator extraction for reuse:
  - `WordsLearner/Services/ElevenLabsAudioGeneratorClient.swift`
  - `WordsLearner/Services/MultimodalAudioGeneratorClient.swift`
- Added settings/API key wiring so ElevenLabs key configuration is shared cleanly:
  - `WordsLearner/Features/SettingsFeature.swift`
  - `WordsLearner/Features/SettingsView.swift`
  - `WordsLearner/Services/APIKeyManager.swift`
  - `WordsLearner/Services/AIServiceClient.swift`

### 2. Comparison history schema + persistence

- Extended comparison history audio/transcript metadata fields and persistence behavior:
  - `audioRelativePath`
  - `audioDurationSeconds`
  - `audioGeneratedAt`
  - `audioVoiceID`
  - `audioModel`
  - `audioFileExtension`
  - `audioData`
  - `podcastTranscript`
- Added/updated migrations and DB handling:
  - `WordsLearner/Database/ComparisonHistory.swift`
  - `WordsLearner/Database/DatabaseConfiguration.swift`
  - `WordsLearner/Database/BackgroundTaskManager.swift`

### 3. Response detail TCA + UI behavior

- Expanded `ResponseDetailFeature` with dedicated audio/transcript state/actions/effects:
  - comparison ID attachment
  - generate transcript+audio integration
  - progress tracking + status message
  - error handling
  - replay/pause integration
- Updated `ResponseDetailView`:
  - audio card (generate/generating/play/pause/regenerate)
  - integrated progress UI
  - transcript display
  - markdown display gating when transcript/audio exists
  - markdown open action
- Files:
  - `WordsLearner/Features/ResponseDetailFeature.swift`
  - `WordsLearner/Features/ResponseDetailView.swift`

### 4. Independent markdown detail page + navigation fix

- Added dedicated markdown detail domain and view:
  - `WordsLearner/Features/MarkdownDetailFeature.swift`
  - `WordsLearner/Features/MarkdownDetailView.swift`
- Integrated push-style navigation and fixed repeated open/back/open flow bugs by making navigation state-driven and stable in TCA.
- Files:
  - `WordsLearner/Features/WordComparatorFeature.swift`
  - `WordsLearner/Features/WordComparatorMainView.swift`

### 5. Comparison save contract update

- Updated comparison save API to return inserted comparison ID so audio/transcript can be attached post-save:
  - `WordsLearner/Services/ComparisonGenerationService.swift`

## Test and Snapshot Coverage

### 6. Added/expanded unit tests for feature/service changes

- Added service tests:
  - `WordsLearnerTests/ComparisonAudioServiceTests.swift`
- Expanded feature tests:
  - `WordsLearnerTests/FeaturesTests/ResponseDetailFeatureTests.swift`
  - `WordsLearnerTests/FeaturesTests/WordComparatorFeatureTests.swift`
  - `WordsLearnerTests/FeaturesTests/SettingsFeatureTests.swift`
  - `WordsLearnerTests/DependencyPreviewIntegrationTests.swift`

### 7. Added exhaustive snapshot suites for changed/new views

- Added snapshot suites:
  - `WordsLearnerTests/ResponseDetailViewTests.swift`
  - `WordsLearnerTests/MarkdownDetailViewTests.swift`
  - `WordsLearnerTests/SettingsViewTests.swift`
- Added/updated snapshot baselines for all relevant statuses under:
  - `WordsLearnerTests/__Snapshots__/ResponseDetailViewTests/`
  - `WordsLearnerTests/__Snapshots__/MarkdownDetailViewTests/`
  - `WordsLearnerTests/__Snapshots__/SettingsViewTests/`

### 8. Platform-specific snapshot stability fix

- Added Debug-only entitlements file and project wiring to avoid macOS test-host sandbox write restrictions during snapshot generation:
  - `WordsLearner/WordsLearner.Debug.entitlements`
  - `Project.swift`
- Fixed macOS `SettingsViewTests` snapshot background rendering and regenerated affected macOS baselines.
- Improved macOS visibility in `responseDetailViewGeneratingAudioProgress` snapshot and refreshed corresponding macOS baseline.

## Verification Outcome

### 9. Full test validation

- Full `WordsLearnerTests` suite passed on:
  - macOS destination (`platform=macOS`)
  - iPhone 12 Pro simulator on iOS 26.2 (`id=D7B80675-822C-4968-8168-EA9247B3EA64`)

