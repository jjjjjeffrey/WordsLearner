# Multimodal Lesson V2 Implementation Report (2026-02-28)

## Scope
This report summarizes the full V2 refinement work for multimodal lessons, including:
- story-style lesson generation aligned to comparison methodology,
- generation progress UX in UI,
- image relevance fixes,
- intra-story visual cohesion fixes,
- and detail-consistency fixes across storyboard frames.

## Product Goals
- Teach word comparison through concrete story pairs (4 frames per story) plus a final conclusion frame.
- Provide narration audio for each frame and the final conclusion.
- Let users understand whether words are interchangeable in their sentence context.
- Remove long blind waits by showing generation progress.
- Ensure generated visuals are relevant and consistent with story meaning and frame-by-frame details.

## What We Implemented

### 1) Story-First Multimodal Generation Pipeline
- The multimodal generation flow now builds lessons from planned storyboards and writes frames progressively.
- Final structure: 2 stories x 4 frames + 1 final conclusion frame.
- Generator version updated to `v2.1`.

Key files:
- `WordsLearner/Services/MultimodalStoryboardPlannerClient.swift`
- `WordsLearner/Services/MultimodalLessonGeneratorClient.swift`

### 2) Progress Events and UI Feedback
- Added structured generation progress events:
  - planning
  - generating frame (step/total)
  - completed
- Wired progress through feature state and UI.
- Added visible progress in:
  - sidebar badge/spinner,
  - composer sheet status + progress bar,
  - multimodal history top banner + active row progress,
  - generating-state copy in lesson detail.

Key files:
- `WordsLearner/Services/MultimodalLessonGeneratorClient.swift`
- `WordsLearner/Features/WordComparatorFeature.swift`
- `WordsLearner/Features/WordComparatorMainView.swift`
- `WordsLearner/Features/WordComparatorComposerSheetView.swift`
- `WordsLearner/Features/MultimodalLessonsView.swift`
- `WordsLearner/Features/MultimodalLessonDetailView.swift`

### 3) Image Relevance (Scene Grounding)
Problem:
- Images were sometimes unrelated to frame narration.

Fix:
- Strengthened per-frame prompt construction with richer story+frame grounding.
- Strengthened image model wrapper prompt constraints for scene fidelity.
- Added strict retry constraints to discourage unrelated imagery.

Key files:
- `WordsLearner/Services/MultimodalLessonGeneratorClient.swift`
- `WordsLearner/Services/MultimodalImageGeneratorClient.swift`

### 4) Intra-Story Cohesion (Character/Environment Continuity)
Problem:
- Within the same story, frames sometimes changed characters/environments.

Fix:
- Added reference-image conditioning in image generation API.
- After generating the first frame of each story, store it as story anchor.
- For later frames in the same story, attach the story anchor image as reference.
- Added continuity requirements (same identity/outfit/environment/style).

Key files:
- `WordsLearner/Services/MultimodalImageGeneratorClient.swift`
- `WordsLearner/Services/MultimodalLessonGeneratorClient.swift`

### 5) Story Detail Consistency Across Frames
Problem:
- Some details drifted (example: sketch story where final paper content contradicted prior setup).

Fix:
- Each frame prompt now includes the full story arc (all 4 frame narrations).
- Each frame prompt now includes a continuity checklist:
  - what already happened (must remain true),
  - what will happen later (must not be contradicted).
- Kept current frame as the explicit target moment.

Key file:
- `WordsLearner/Services/MultimodalLessonGeneratorClient.swift`

### 6) Detail View Navigation Improvement
- Added `Previous` button in frame viewer navigation to complement `Next`.
- Supports looping behavior and preserves playback stop behavior when navigating.

Key file:
- `WordsLearner/Features/MultimodalLessonDetailView.swift`

## Problems Fixed (Summary)
1. No visible generation progress while waiting.
2. Irrelevant frame images not matching narration/story.
3. Character/environment style drift across frames in one story.
4. Detail-level logical drift across frames (object/state inconsistency).
5. Missing backward navigation in frame detail viewer.

## Validation
Focused regression tests repeatedly executed during implementation:
- `xcodebuild test -workspace WordsLearner.xcworkspace -scheme WordsLearner -destination 'platform=macOS' -only-testing:WordsLearnerTests/SettingsFeatureTests -only-testing:WordsLearnerTests/WordComparatorFeatureTests`

Latest result for final code state:
- `TEST SUCCEEDED`

## Notes for Future Iteration
- If detail drift remains in edge cases, extend reference conditioning from 1 anchor image to:
  - anchor frame + immediate previous frame,
  - and optionally a lightweight state summary extracted from prior frames.
- If generation latency becomes an issue, add finer-grained milestone progress messages (planning, image model request, audio generation, persistence).

