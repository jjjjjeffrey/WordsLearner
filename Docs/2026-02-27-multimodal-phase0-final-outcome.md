# Multimodal Phase 0 Final Outcome

Date: 2026-02-27
Status: Completed
Decision: Proceed with `google/gemini-2.5-flash-image` (image) + ElevenLabs TTS (audio) for V1.

## Executive Summary
Phase 0 feasibility is complete.

Validated working stack:
- Image generation: ZenMux Vertex API + `google/gemini-2.5-flash-image`
- Audio narration: ElevenLabs TTS (`eleven_multilingual_v2`)

Not validated / blocked in current provider setup:
- `openai/gpt-image-1.5` on ZenMux (OpenAI-style image endpoint and Vertex API route both failed in this environment)
- `inclusionai/ming-flash-omni-2.0` audio on ZenMux (no working documented TTS route found in this spike)

## Evidence and Run History

### Run 1
Report: `/Users/jeffrey/Git/WordsLearner/Docs/2026-02-26-multimodal-phase0-spike-report-run1.md`
- Result: Fail
- Cause: Cloudflare edge block (`403`, `error code: 1010`) on script default request fingerprint.

### Run 2 (docs-compliant image path)
Report: `/Users/jeffrey/Git/WordsLearner/Docs/2026-02-26-multimodal-phase0-spike-report-run2-docs-compliant.md`
- Result: Partial pass
- Image: success via ZenMux Vertex endpoint
- Audio: failed (`404`) on probed Vertex audio path.

### Run 3 (ElevenLabs integration path check)
Report: `/Users/jeffrey/Git/WordsLearner/Docs/2026-02-27-multimodal-phase0-spike-report-run3-elevenlabs-audio.md`
- Result: Integration path validated, auth failed
- ElevenLabs response: `401 invalid_api_key` (expected with non-ElevenLabs key).

### Run 4 (success)
Report: `/Users/jeffrey/Git/WordsLearner/Docs/2026-02-27-multimodal-phase0-spike-report-run4-success.md`
- Result: Pass
- Image: `200` success, output saved
- Audio: `200` success, output saved
- `overall_pass_candidate: true`

### Run 5 (`openai/gpt-image-1.5` re-test)
Report: `/Users/jeffrey/Git/WordsLearner/Docs/2026-02-27-multimodal-phase0-spike-report-run5-gpt-image-1_5-openai-path.md`
- Result: Fail for image model target
- ZenMux OpenAI-style image route returned `500 {"message":"missing csrf token"}`.

## Additional SDK Verification
Using the official `google-genai` SDK with ZenMux Vertex base:
- `generate_images(model="openai/gpt-image-1.5")` -> `404 model_not_supported`
- `generate_content(... response_modalities=["TEXT","IMAGE"])`:
  - `openai/gpt-image-1.5` -> `404 model_not_supported`
  - `google/gemini-2.5-flash-image` -> success

Conclusion: `openai/gpt-image-1.5` is not currently usable through the tested ZenMux Vertex API surface.

## Final Outcome Against Phase 0 Criteria
1. Usable image output: Pass (with Gemini path)
2. Playable speech audio output: Pass (with ElevenLabs path)
3. Latency acceptable for V1 foreground use: Pass in spike baseline
   - Image ~9-11s
   - Audio ~3-5s
4. Response parsing stable enough: Pass
5. Quality baseline suitable for V1: Pass for technical feasibility gate

## Final Implementation Input (for Phase 1+)
Use this provider split in implementation:
- Storyboard planning: existing text model path (ZenMux chat route)
- Image generation: ZenMux Vertex image route with `google/gemini-2.5-flash-image`
- Audio generation: ElevenLabs TTS (`eleven_multilingual_v2`, configurable voice ID)

Retain model/provider abstraction in service interfaces so `openai/gpt-image-1.5` can be swapped in later if provider support changes.

