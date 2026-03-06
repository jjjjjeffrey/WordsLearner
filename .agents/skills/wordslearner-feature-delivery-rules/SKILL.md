---
name: wordslearner-feature-delivery-rules
description: Use when adding or refactoring WordsLearner features that touch TCA state, navigation, AI/media generation, persistence, migrations, or snapshot coverage. Encodes project-specific rules learned from the standalone comparison podcast audio rollout.
---

# WordsLearner Feature Delivery Rules

Use this skill when building a new feature in **WordsLearner** that changes:

- TCA reducer state/actions/effects
- navigation or child-feature composition
- persisted models or database migrations
- AI-generated text/audio/media workflows
- snapshot-tested SwiftUI screens

This skill is project-specific. It captures what went wrong, what had to be corrected, and what should be treated as non-negotiable for future work.

## Core Rule

Design the feature around its real product artifact and lifecycle first, then make TCA state, persistence, and UI reflect that model directly.

If the real artifact is unclear, the architecture will drift.

## Non-Negotiable Rules

### 1. Isolate feature domains first

- Do not couple a new feature to an existing feature just because some infrastructure is reusable.
- Reuse shared clients and storage helpers only when they are truly cross-feature.
- Do not reuse another feature's reducer state, navigation state, or UI assumptions.

Good pattern:

- extract shared API-key access
- extract shared ElevenLabs client
- keep feature-specific reducers and views separate

Bad pattern:

- comparison feature depending on `MultimodalLessons*` state or flow

### 2. Decide persistence before polishing UI

For any generated artifact, decide early:

- what gets stored
- where it is stored
- how it is reopened
- how it survives app relaunch
- how it behaves for old rows
- whether it should sync

If the artifact is part of history, treat reopen/replay/restore as first-class requirements, not follow-up work.

### 3. Navigation must be explicit TCA state

- If a destination can be opened, dismissed, reopened, or restored, it must exist as explicit child state.
- Prefer dedicated child features over embedding navigation behavior in a large parent view.
- If `ifLet` is involved, child actions must only arrive while child state exists.

Do not solve navigation bugs with view-local workarounds if the real issue is reducer modeling.

### 4. Generated-content features are state machines

Model these states explicitly when relevant:

- idle
- unavailable
- generating
- partial success
- success
- retryable failure
- persisted/restored

For AI/media features, the UI must expose:

- why an action is disabled
- current progress
- current phase/status text
- retry path
- restored state after relaunch

### 5. Re-center the screen around the primary artifact

- When a new artifact becomes the user's main output, the screen should change to reflect that.
- Secondary artifacts should remain accessible, but not dominate the detail view.

Example from this repo:

- once podcast transcript/audio existed, raw markdown should no longer be the default primary content in comparison detail

### 6. Migrations are part of feature completion

Any change to `ComparisonHistory` or other persisted models is incomplete until:

- a migration exists
- null/default behavior is safe for pre-migration rows
- history screens work with old and new data
- tests cover restored/persisted state

Do not treat schema work as an implementation detail.

### 7. macOS must be treated as its own platform

- Do not assume macOS behaves like iOS for sandboxing, file access, networking, audio, or snapshot rendering.
- Snapshot recording may require Debug-only entitlements changes for the test host.
- Visual states may need macOS-specific rendering adjustments to make the intended UI visible in snapshots.

If a feature touches storage, networking, media, or snapshots, validate macOS explicitly.

### 8. View-local imperative state must track artifact identity

- If a SwiftUI view can display different persisted artifacts over time, do not let `@State`, `@StateObject`, players, timers, delegates, or controller wrappers silently outlive the artifact they operate on.
- When artifact identity changes, either reset the view-local object immediately or verify that its loaded resource still matches current feature state before resuming/reusing it.
- This applies especially to media playback, background tasks, streaming handles, and any wrapper around framework objects that keep internal mutable state.

Do not assume TCA state replacement is enough if the actual side-effectful object lives in the view layer.

### 9. Compact and full-content surfaces must be intentionally split

- If a screen has a primary interactive artifact plus long-form supporting content, keep the primary card focused and move the long-form content into an explicit destination.
- Do not leave duplicate passive cards on the detail screen once a full transcript/detail view exists.
- Decide early which content remains inline for fast interaction and which content belongs behind "View Full ..." navigation.

Good pattern:

- audio card shows playback actions, progress, and previous/current/next turns
- full transcript opens in a dedicated destination
- compact analysis section opens a dedicated markdown detail once audio becomes primary

Bad pattern:

- primary card plus a second passive card that repeats the same artifact in longer form

### 10. Cross-platform control density must be validated explicitly

- Do not assume the same button labels, hit areas, or control layouts fit both macOS and iPhone-sized screens.
- Validate iPhone-width layouts before finalizing any control row that mixes buttons with status text.
- For this repo's snapshot/manual validation default, use `iPhone 12 Pro` on `iOS 26.2` unless the feature explicitly requires another device.
- When compact iOS controls become icon-only, add explicit accessibility labels.

Good pattern:

- macOS keeps icon-plus-text controls where width is available
- iOS uses icon-only controls when labels would wrap or distort the row

Bad pattern:

- shipping a single control style that looks fine on macOS but wraps or compresses on iPhone

### 11. Media integrations require simulator and device validation separately

- Treat simulator and real-device checks as different layers of validation.
- Use simulator for layout, local playback, and reducer/view wiring.
- Use real devices for Lock Screen, Control Center, remote commands, and background-media UX.

Do not conclude a media integration is broken solely because the simulator does not expose system media controls.

### 12. Generated workspaces must be regenerated when adding app sources

- If a new source file is added to the app or tests, run `tuist generate` before trusting missing-type build failures.
- Prefer ruling out stale generated projects early instead of debugging false compile errors.

## Implementation Checklist

When adding a new WordsLearner feature, check these in order:

1. Define the primary artifact and user-visible lifecycle.
2. Decide persistence/storage/sync expectations before UI refinement.
3. Create dedicated reducer state/actions for the feature.
4. Model navigation as child state if the destination has meaningful behavior.
5. Reset or re-key any view-local imperative object when the displayed artifact identity can change.
6. Keep reusable infra separate from feature-specific logic.
7. Add migrations and old-row compatibility if persistence changes.
8. Add reducer tests for guards, success, failure, and restored state.
9. Add snapshot coverage for every meaningful UI status.
10. Manually test cross-item transitions for media/controller features: open A, start, pause or interrupt, switch to B, start again, and confirm the active resource belongs to B.
11. Run tests on both macOS and iOS before considering the feature complete.
12. For cross-platform UI, verify that control density and button labels work on iPhone-sized layouts, not just macOS.
13. Default iOS snapshot and manual UI validation to `iPhone 12 Pro` on `iOS 26.2` unless another target is required.
14. For media features, validate device-only behaviors separately from simulator-only checks.
15. Regenerate the Tuist workspace immediately after adding new app/test files.

## Testing Requirements

For non-trivial feature work, aim for all of the following:

- reducer tests for happy path
- reducer tests for guarded no-op paths
- reducer tests for failure paths
- service tests for persistence/update semantics
- snapshot tests for each major screen state
- snapshot tests for compact and full-content destinations when the UI intentionally splits them
- manual validation for restore/reopen behavior when history is involved

If a view has multiple user-visible states, snapshot all of them. Do not stop at the default state.

## Anti-Patterns

Avoid these patterns in this repo:

- piggybacking on another feature's state machine
- pushing persistence decisions until after UI is done
- storing navigation only in local SwiftUI state when the flow matters
- adding new DB columns without old-row validation
- relying on local files when the product expectation is history replay or sync
- assuming one successful open/close cycle means navigation is modeled correctly
- updating snapshots without understanding platform-specific rendering differences

## Completion Standard

A WordsLearner feature is not done when the happy path works once.

It is done when:

- the domain boundary is clean
- persistence and reopen behavior are coherent
- navigation is correct in TCA terms
- old data is safe
- macOS and iOS are both validated
- tests cover the real statuses the user can hit
