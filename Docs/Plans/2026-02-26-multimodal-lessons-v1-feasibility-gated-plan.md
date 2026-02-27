# V1 Multimodal Lessons with Model Feasibility Gate (OpenAI Images + Ming Audio)

## Summary
Implement the new storyboard-based multimodal lesson feature as a separate sidebar section, but gate all app integration behind a short feasibility phase that validates the selected models and provider path in the real environment.

Chosen V1 model targets (to validate first):
- Image generation: `openai/gpt-image-1.5`
- Audio generation: `inclusionai/ming-flash-omni-2.0`

Rationale:
- `gpt-image-1.5` appears available in current OpenAI docs and third-party gateways.
- `ming-flash-omni-2.0` is a strong multimodal candidate, but provider/API behavior for text-to-audio generation via your actual backend is not yet proven and must be empirically tested before feature integration.

References:
- [OpenAI GPT Image 1.5 model page](https://platform.openai.com/docs/models/gpt-image-1.5)
- [OpenAI image generation guide](https://platform.openai.com/docs/guides/images/image-generation)
- [ZenMux OpenAI-compatible chat API docs](https://docs.zenmux.ai/api/openai/create-chat-completion.html)
- [ZenMux image generation docs](https://zenmux.ai/docs/guide/advanced/image-generation.html)
- [Ming-flash-omni-2.0 Hugging Face model page](https://huggingface.co/inclusionAI/Ming-flash-omni-2.0)

## Key Change to Previous Plan
Add a mandatory `Phase 0: Provider/Model Feasibility Spike` before any DB schema, reducers, or UI implementation. The rest of the multimodal feature proceeds only if Phase 0 passes.

## Phase 0 — Feasibility Spike (Mandatory Gate)

### Goal
Prove that image and audio generation work well enough through your actual provider path (likely ZenMux/AIHubMix-style setup) for the planned 4-frame lesson flow.

### Deliverables
1. A standalone local spike script (not app-integrated) that:
   - Generates 1 image with `openai/gpt-image-1.5`
   - Generates 1 audio narration with `inclusionai/ming-flash-omni-2.0`
   - Saves outputs locally for manual review
   - Prints latency and response shape metadata
2. A short spike report in `Docs/` with:
   - Exact request formats that worked
   - Response payload formats
   - Content-type/file formats
   - Typical latency
   - Failures and retries needed
   - Decision: pass/fail for V1

### Pass/Fail Criteria
Pass only if all are true:
1. Image generation returns a usable image file (`png`, `jpeg`, or base64-decodable payload) for a storyboard-style prompt.
2. Audio generation returns a playable speech output (not only text/transcript).
3. End-to-end latency is acceptable for V1 foreground use:
   - Target: <= 10s per image and <= 10s per audio segment on average in your environment
   - Hard stop: if total estimated 4-frame generation exceeds ~90s consistently
4. API responses are stable enough to parse deterministically.
5. Content quality is good enough for “simple educational illustration” + “simple English narration”.

### Phase 0 Test Matrix
Run at least these cases:
1. Image prompt: simple concrete scene (`word1_only`)
2. Image prompt: contrast scene (`non_interchangeable`)
3. Audio prompt: short narration (1 sentence)
4. Audio prompt: longer narration (3-4 simple sentences)
5. Audio prompt with punctuation and quoted words
6. Retry behavior on one intentionally malformed request (to inspect error schema)

### Technical Unknowns to Resolve in Phase 0
1. Does your provider expose `gpt-image-1.5` through an image endpoint or via chat/responses-compatible API?
2. Does `inclusionai/ming-flash-omni-2.0` produce audio output through your provider in a non-streaming request?
3. What output format is returned for audio (base64 blob, URL, multipart, chunked stream)?
4. Can you control voice/speed enough for simple English narration consistency?
5. Are there policy/content filters that reject neutral educational prompts unexpectedly?

### If Phase 0 Fails
Use this fallback sequence:
1. Keep `gpt-image-1.5` if image passes.
2. Replace audio model with a provider-supported TTS model for V1.
3. Keep storyboard architecture unchanged.
4. Do not block the feature on Ming specifically if only the provider integration fails.

## Phase 1 — App Architecture and Data Model (Only After Phase 0 Pass)

### Scope
- Separate multimodal feature
- New sidebar section
- Foreground-only generation
- 4-frame lesson
- Filesystem cache + DB metadata
- Auto-play segment-based player
- Optional user sentence validation at end
- Completion time + self-rated clarity metrics

### Public API / Interface / Type Additions
Add these new types and dependency clients:

1. Domain schema types (`Codable`)
- `StoryboardPlan`
- `StoryboardFramePlan`
- `StoryboardMicroCheck`
- `StoryboardSentenceValidationTemplate`

2. Service dependency clients
- `StoryboardPlannerClient`
- `LessonImageGeneratorClient` (configured for `openai/gpt-image-1.5`)
- `LessonAudioGeneratorClient` (configured for `inclusionai/ming-flash-omni-2.0`, pending Phase 0)
- `MultimodalAssetStoreClient`
- `MultimodalLessonGeneratorClient` (orchestrator)
- `MultimodalMetricsClient`

3. TCA features
- `MultimodalLessonListFeature`
- `MultimodalLessonComposerFeature`
- `MultimodalLessonGenerationFeature`
- `MultimodalLessonPlayerFeature`
- `MultimodalSentenceValidationFeature`

4. SQLiteData models
- `MultimodalLesson`
- `MultimodalLessonFrame`
- `MultimodalLessonAttempt` (recommended)

## Phase 2 — Storage and Migrations

### SQLiteData Tables
Implement separate multimodal tables (do not modify `ComparisonHistory` for V1).

`MultimodalLesson`
- `id`
- `word1`
- `word2`
- `userSentence`
- `status` (`generating`, `ready`, `failed`)
- `storyboardJSON`
- `stylePreset`
- `voicePreset`
- `imageModel` (persist exact model name, e.g. `openai/gpt-image-1.5`)
- `audioModel` (persist exact model name, e.g. `inclusionai/ming-flash-omni-2.0`)
- `generatorVersion`
- `claritySelfRating`
- `lessonDurationSeconds`
- `errorMessage`
- `createdAt`
- `updatedAt`
- `completedAt`

`MultimodalLessonFrame`
- `id`
- `lessonID`
- `frameIndex`
- `frameRole`
- `title`
- `caption`
- `narrationText`
- `imagePrompt`
- `imageRelativePath`
- `audioRelativePath`
- `audioDurationSeconds`
- `checkPrompt`
- `expectedAnswer`
- `createdAt`
- `updatedAt`

`MultimodalLessonAttempt` (recommended)
- `id`
- `lessonID`
- `startedAt`
- `finishedAt`
- `completionState`
- `claritySelfRating`

### Filesystem Cache
Store assets under app support:
- `.../MultimodalLessons/<lesson-id>/frame-0.png`
- `.../MultimodalLessons/<lesson-id>/frame-0.m4a`

DB stores relative paths only.

### SyncEngine
Do not add multimodal tables to `SyncEngine` in V1 because assets are local-only.

## Phase 3 — Service Implementation (Point-Free Style)

### `StoryboardPlannerClient`
- Input: `word1`, `word2`, optional `sentence`, style preset, voice preset
- Output: strict `StoryboardPlan`
- Enforce exactly 4 roles:
  - `word1_only`
  - `word2_only`
  - `overlap`
  - `non_interchangeable`
- Include style consistency token in every frame prompt

### `LessonImageGeneratorClient`
- Concrete implementation targets `openai/gpt-image-1.5`
- Accepts image prompt + style preset
- Returns raw image bytes + MIME type metadata
- Handles provider response variants (`b64_json`, URL, binary payload)
- No streaming required in V1

### `LessonAudioGeneratorClient`
- Concrete implementation targets `inclusionai/ming-flash-omni-2.0` only if Phase 0 pass
- Accepts narration text + voice preset
- Returns audio bytes + MIME type + duration (if available)
- If duration unavailable, compute duration after file write in app layer or leave nil
- Handle provider-specific audio response shape discovered in Phase 0

### `MultimodalLessonGeneratorClient` (orchestrator)
Pipeline:
1. Create lesson row (`generating`)
2. Generate storyboard plan
3. Validate plan
4. Generate each frame’s image+audio (serial in V1)
5. Persist files
6. Persist frame metadata
7. Mark lesson `ready`
8. On any error:
   - delete partial assets for that lesson
   - mark lesson `failed`

All-or-nothing is enforced here.

## Phase 4 — TCA Feature Integration

### Root Navigation Changes
In `WordComparatorFeature` / `WordComparatorMainView`:
- Add sidebar item `.multimodalLessons`
- Add content/detail handling for multimodal list + player/generation
- Keep text comparison flow unchanged

### New Feature Flow
1. `MultimodalLessonListFeature`
   - list/search/select/delete/retry failed
   - open composer
2. `MultimodalLessonComposerFeature`
   - required: `word1`, `word2`
   - optional: `sentence`
   - starts foreground generation
3. `MultimodalLessonGenerationFeature`
   - progress state
   - cancel/retry
   - transitions to player only on full success
4. `MultimodalLessonPlayerFeature`
   - auto-play guided sequence
   - frame progression by segment completion
   - manual controls
   - micro-checks
   - completion timing + self-rating
5. `MultimodalSentenceValidationFeature`
   - only shown if sentence exists
   - can use text LLM path independently from audio/image models

## Phase 5 — UX Behavior (Decision-Complete)
- V1 uses `simple educational illustrations`
- V1 uses `simple English narration`
- V1 uses `single voice`
- V1 uses `auto-play` by default
- V1 uses `segment-based sync` (one audio segment per frame)
- V1 does not include pronunciation shadowing
- V1 is `all-or-nothing`
- V1 stores multimodal lesson history separately
- V1 is foreground-only

## Test Plan

### Phase 0 Spike Validation (manual + script assertions)
1. Assert image bytes non-empty and decodable
2. Assert audio bytes non-empty and playable container signature
3. Assert response parsing works for actual provider payloads
4. Record latency for 3 runs each image/audio

### Reducer Tests (`TestStore`)
1. Composer validation with optional sentence
2. Generation success transitions to player
3. Generation failure marks lesson failed
4. Cancel generation path
5. Player auto-play and segment advancement
6. Completion records duration + self-rating
7. Sentence validation only when sentence present
8. List select/delete/retry failed lesson

### Service Tests
1. Storyboard JSON strict validation
2. Orchestrator all-or-nothing cleanup on frame 2 failure
3. Asset store path generation and deletion
4. Image/audio clients parse mocked payload shapes discovered in Phase 0

### Migration Tests
1. New multimodal tables migrate successfully on fresh DB
2. Existing DB migrates forward without affecting current text history
3. Deleting lesson removes frame rows and local assets

### Snapshot Tests
1. Multimodal list empty and populated
2. Composer ready/invalid states
3. Generation progress/failure states
4. Player frame screen and completion screen (iOS + macOS)

## Acceptance Criteria
1. A feasibility spike proves `openai/gpt-image-1.5` image generation works via your provider path.
2. A feasibility spike proves `inclusionai/ming-flash-omni-2.0` returns usable audio via your provider path, or the plan falls back to a substitute audio model before app integration starts.
3. User can create and replay a 4-frame multimodal lesson from a new sidebar section.
4. Existing text comparison features remain unchanged and passing.

## Assumptions and Defaults
- This plan assumes model availability as of February 26, 2026; provider support must be verified in Phase 0.
- `gpt-image-1.5` is the intended image model and is expected to work through a compatible image endpoint.
- `inclusionai/ming-flash-omni-2.0` is preferred for audio, but only if provider API returns stable audio output in practice.
- Multimodal features remain local-only for asset storage in V1.
- No background generation queue for multimodal V1.

