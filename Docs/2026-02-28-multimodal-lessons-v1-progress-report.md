# Multimodal Lessons V1 Progress Report
Date: 2026-02-28
Branch: `codex/multimodal-lessons-v1`

## Summary
Core V1 multimodal lesson flow is implemented end-to-end:
- generation pipeline works
- lessons persist to DB
- history list and detail column are integrated
- image/audio playback is available in lesson detail
- 16:9 image enforcement strategy is applied

The main remaining gap is output quality consistency of generated storyboard/narration.

## Completed Work

### 1. Data & Migration
- Added multimodal schema:
  - `WordsLearner/Database/MultimodalLesson.swift`
  - `WordsLearner/Database/MultimodalLessonFrame.swift`
- Added DB migration and indexes:
  - `WordsLearner/Database/DatabaseConfiguration.swift`

### 2. Service Layer
- Added planner client:
  - `WordsLearner/Services/MultimodalStoryboardPlannerClient.swift`
- Added image client:
  - `WordsLearner/Services/MultimodalImageGeneratorClient.swift`
- Added audio client:
  - `WordsLearner/Services/MultimodalAudioGeneratorClient.swift`
- Added local asset storage client:
  - `WordsLearner/Services/MultimodalAssetStoreClient.swift`
- Added orchestrator:
  - `WordsLearner/Services/MultimodalLessonGeneratorClient.swift`

### 3. Key Management & Settings
- ElevenLabs key support added to API key manager:
  - `WordsLearner/Services/APIKeyManager.swift`
  - `WordsLearner/Services/AIServiceClient.swift` (`APIKeyManagerClient` extended)
- Settings UI and reducer now support managing AIHubMix + ElevenLabs keys:
  - `WordsLearner/Features/SettingsFeature.swift`
  - `WordsLearner/Features/SettingsView.swift`
- Fixed parent refresh bug by delegating key changes on ElevenLabs save/clear.

### 4. UI & Navigation
- Added multimodal history feature and view:
  - `WordsLearner/Features/MultimodalLessonsFeature.swift`
  - `WordsLearner/Features/MultimodalLessonsView.swift`
- Added dedicated detail column lesson player:
  - `WordsLearner/Features/MultimodalLessonDetailView.swift`
- Integrated into root navigation:
  - `WordsLearner/Features/WordComparatorFeature.swift`
  - `WordsLearner/Features/WordComparatorMainView.swift`
- Added multimodal generation button in existing composer:
  - `WordsLearner/Features/WordComparatorComposerSheetView.swift`

### 5. Playback UX
- Detail view now shows one frame at a time.
- Next-button navigation implemented.
- Play-all auto-advances to next frame when current narration finishes.
- Narration text placed under image and typography improved for readability.

### 6. Prompt/Model Refinement
- Storyboard prompt refined around certainty-first methodology and contrast progression.
- Image generation switched to `google/gemini-3.1-flash-image-preview`.
- 16:9 strategy in app:
  - request aspect ratio in config
  - validate generated dimensions
  - retry with stricter prompt constraints

### 7. Tooling Script
- Added standalone verification script for ZenMux 16:9 image generation:
  - `Scripts/zenmux_generate_16x9_image.py`

### 8. Tests
- Updated and expanded tests for settings and root feature flows:
  - `WordsLearnerTests/FeaturesTests/SettingsFeatureTests.swift`
  - `WordsLearnerTests/FeaturesTests/WordComparatorFeatureTests.swift`
- Targeted suites run successfully during implementation iterations.

## Known Issues / Remaining Work
1. Storyboard/narration quality still varies by word pair and can be generic.
2. Need quality gates before accepting generated lesson content.
3. Need broader evaluation matrix to measure teaching clarity consistency.

## Recommended Next Iteration
1. Implement prompt quality-gate validation and selective regeneration.
2. Build a curated 20+ word-pair benchmark set and score outputs.
3. Tune frame-level constraints for non-interchangeable and overlap scenes.
