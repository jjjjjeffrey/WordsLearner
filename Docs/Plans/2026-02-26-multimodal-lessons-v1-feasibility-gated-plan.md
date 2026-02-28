# V1 Multimodal Lessons Plan (Refined After Implementation)

Last refined: 2026-02-28

## 1. Objective
Build a production-ready V1 multimodal lesson flow that helps learners gain clarity between two confusing words using:
- vivid storyboard images
- short narration audio per frame
- detail playback UI with frame-by-frame progression

Primary learning goal from methodology: reduce uncertainty and increase usage certainty in real contexts.

## 2. Current Status Snapshot

### Completed
1. Phase 0 feasibility spike and model/provider validation completed; report documented.
2. SQLite schema and migrations for multimodal lessons/frames implemented.
3. Multimodal generation pipeline implemented (planner -> image -> audio -> assets -> DB).
4. Sidebar multimodal history list integrated into app navigation.
5. Multimodal detail column implemented with:
   - single-frame view
   - next-frame navigation
   - per-frame play/pause
   - play-all auto advance
   - narration text under image
6. Settings/API key management fixed:
   - ElevenLabs key moved to APIKeyManager
   - UI support to save/clear ElevenLabs key
   - parent state refresh fix after key changes
7. Image generation refined to enforce video-like layout:
   - request aspect ratio 16:9
   - validate generated ratio
   - retry with stricter prompt if needed
8. Prompt refinement for storyboard quality:
   - certainty-first framing
   - specific-doubt removal
   - connected mini-story and contrast progression

### In Progress / Needs Improvement
1. LLM output quality for storyboard/narration is still inconsistent for some word pairs.
2. Need stronger prompt tuning and objective quality checks for lesson usefulness.
3. Need final acceptance calibration for “clarity gained” with representative test word pairs.

## 3. Architecture (Implemented)

### Persistence
- `MultimodalLesson`
- `MultimodalLessonFrame`
- Migration in `DatabaseConfiguration` to create tables + indexes.

### Service Layer
- `MultimodalStoryboardPlannerClient`
- `MultimodalImageGeneratorClient`
- `MultimodalAudioGeneratorClient`
- `MultimodalAssetStoreClient`
- `MultimodalLessonGeneratorClient`

### Feature Layer
- `MultimodalLessonsFeature`
- `MultimodalLessonsView` (history/list/search/filter/delete)
- `MultimodalLessonDetailView` (detail-column playback)

### Root Integration
- Sidebar item: Multimodal History
- Composer entry point: `Generate Multimodal` button in existing comparator composer
- Detail column routes to multimodal lesson detail when multimodal section is active

## 4. Model/Provider Decisions (Current)

Image:
- Runtime target: `google/gemini-3.1-flash-image-preview`
- Provider path: ZenMux Vertex endpoint
- 16:9 strategy: API config request + output ratio validation + retry

Audio:
- Runtime target: ElevenLabs TTS API
- Key source: `APIKeyManager` only (user-managed via Settings)

## 5. Remaining Work Plan (Next)

### Phase A — Output Quality Hardening (Next Priority)
1. Prompt iteration loop for storyboard planner:
   - tighten role intent constraints
   - improve overlap/non-interchangeable clarity
   - reduce generic narration
2. Add deterministic quality checks before persisting lesson:
   - ensure each frame meaningfully distinguishes target usage
   - detect repeated/near-duplicate captions/narrations
3. Build evaluation set (at least 20 word pairs) and manually score:
   - clarity
   - vividness
   - correctness
   - non-interchangeability teaching value
4. Add fallback regeneration for failed quality checks.

### Phase B — UX Polish
1. Improve frame controls (previous/next indicators, keyboard shortcuts on macOS).
2. Add optional narration speed/voice setting.
3. Improve failed lesson recovery and retry flows from list UI.

### Phase C — Reliability & Tests
1. Expand service tests for parsing/provider variants and retry behavior.
2. Add reducer tests for multimodal detail play-all progression.
3. Add UI snapshot coverage for multimodal history/detail states.

## 6. Acceptance Criteria for “V1 Ready”
1. For representative word pairs, generated lessons consistently provide clear distinction and correct usage contexts.
2. 16:9 image output is reliable enough for storyboard presentation.
3. Audio narration playback is stable frame-by-frame and in play-all mode.
4. User can configure both required API keys from Settings without app restart.
5. Existing word comparison flow remains stable and passing tests.

## 7. Risks
1. Provider/model response drift may affect 16:9 behavior or payload parsing.
2. Prompt-only quality control may still allow weak lessons on edge-case word pairs.
3. Audio/image generation latency may degrade user experience for long runs.

## 8. Tracking Documents
- Feasibility outcome: `Docs/2026-02-27-multimodal-phase0-final-outcome.md`
- This refined plan: `Docs/Plans/2026-02-26-multimodal-lessons-v1-feasibility-gated-plan.md`
- Progress report: `Docs/2026-02-28-multimodal-lessons-v1-progress-report.md`
