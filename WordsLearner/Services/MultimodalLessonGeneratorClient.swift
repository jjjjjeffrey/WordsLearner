//
//  MultimodalLessonGeneratorClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation
import SQLiteData

enum MultimodalGenerationProgress: Equatable, Sendable {
    case planning(UUID)
    case generatingFrame(lessonID: UUID, step: Int, totalSteps: Int, frameIndex: Int)
    case completed(UUID)
}

@DependencyClient
struct MultimodalLessonGeneratorClient: Sendable {
    var generateLesson: @Sendable (
        _ word1: String,
        _ word2: String,
        _ sentence: String?,
        _ onProgress: @Sendable (MultimodalGenerationProgress) async -> Void
    ) async throws -> UUID
}

extension MultimodalLessonGeneratorClient: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date.now) var now
        @Dependency(\.multimodalStoryboardPlanner) var planner
        @Dependency(\.multimodalImageGenerator) var imageGenerator
        @Dependency(\.multimodalAudioGenerator) var audioGenerator
        @Dependency(\.multimodalAssetStore) var assets
        @Dependency(\.uuid) var uuid

        return Self(
            generateLesson: { word1, word2, sentence, onProgress in
                let lessonID = uuid()
                try await database.write { db in
                    try MultimodalLesson.insert {
                        MultimodalLesson.Draft(
                            id: lessonID,
                            word1: word1,
                            word2: word2,
                            userSentence: sentence ?? "",
                            status: MultimodalLesson.Status.generating.rawValue,
                            storyboardJSON: "",
                            stylePreset: "cinematic_storyboard_16_9_v2",
                            voicePreset: "elevenlabs_default_v1",
                            imageModel: "google/gemini-3.1-flash-image-preview",
                            audioModel: "eleven_multilingual_v2",
                            generatorVersion: "v2.1",
                            claritySelfRating: nil,
                            lessonDurationSeconds: nil,
                            errorMessage: nil,
                            createdAt: now,
                            updatedAt: now,
                            completedAt: nil
                        )
                    }
                    .execute(db)
                }

                do {
                    await onProgress(.planning(lessonID))
                    let plan = try await planner.plan(word1, word2, sentence)
                    let storyboardData = try JSONEncoder().encode(plan)
                    let storyboardJSON = String(data: storyboardData, encoding: .utf8) ?? ""

                    try await database.write { db in
                        try MultimodalLesson
                            .where { $0.id == lessonID }
                            .update {
                                $0.storyboardJSON = storyboardJSON
                                $0.updatedAt = now
                            }
                            .execute(db)
                    }

                    let flattened = flattenStoryFrames(plan)
                    let totalSteps = flattened.count + 1
                    var step = 0
                    var storyAnchorImages: [String: Data] = [:]
                    for item in flattened {
                        step += 1
                        await onProgress(.generatingFrame(lessonID: lessonID, step: step, totalSteps: totalSteps, frameIndex: item.frameIndex))
                        let referenceImages = storyAnchorImages[item.storyID].map { [$0] } ?? []
                        let imageData = try await imageGenerator.generateImage(item.imagePrompt, referenceImages)
                        if storyAnchorImages[item.storyID] == nil {
                            // Lock the story's visual identity from the first generated frame.
                            storyAnchorImages[item.storyID] = imageData
                        }
                        let audioData = try await audioGenerator.generateAudio(item.narrationText)
                        let imagePath = try assets.writeImage(imageData, lessonID, item.frameIndex)
                        let audioPath = try assets.writeAudio(audioData, lessonID, item.frameIndex)

                        try await database.write { db in
                            try MultimodalLessonFrame.insert {
                                MultimodalLessonFrame.Draft(
                                    id: uuid(),
                                    lessonID: lessonID,
                                    frameIndex: item.frameIndex,
                                    frameRole: item.frameRole,
                                    title: item.title,
                                    caption: item.caption,
                                    narrationText: item.narrationText,
                                    imagePrompt: item.imagePrompt,
                                    imageRelativePath: imagePath,
                                    audioRelativePath: audioPath,
                                    audioDurationSeconds: nil,
                                    checkPrompt: item.checkPrompt,
                                    expectedAnswer: item.expectedAnswer,
                                    createdAt: now,
                                    updatedAt: now
                                )
                            }
                            .execute(db)
                        }
                    }

                    let conclusionFrame = makeConclusionFrame(plan: plan, word1: word1, word2: word2)
                    step += 1
                    await onProgress(.generatingFrame(lessonID: lessonID, step: step, totalSteps: totalSteps, frameIndex: conclusionFrame.frameIndex))
                    let conclusionImageData = try await imageGenerator.generateImage(conclusionFrame.imagePrompt, [])
                    let conclusionAudioData = try await audioGenerator.generateAudio(conclusionFrame.narrationText)
                    let conclusionImagePath = try assets.writeImage(conclusionImageData, lessonID, conclusionFrame.frameIndex)
                    let conclusionAudioPath = try assets.writeAudio(conclusionAudioData, lessonID, conclusionFrame.frameIndex)

                    try await database.write { db in
                        try MultimodalLessonFrame.insert {
                            MultimodalLessonFrame.Draft(
                                id: uuid(),
                                lessonID: lessonID,
                                frameIndex: conclusionFrame.frameIndex,
                                frameRole: conclusionFrame.frameRole,
                                title: conclusionFrame.title,
                                caption: conclusionFrame.caption,
                                narrationText: conclusionFrame.narrationText,
                                imagePrompt: conclusionFrame.imagePrompt,
                                imageRelativePath: conclusionImagePath,
                                audioRelativePath: conclusionAudioPath,
                                audioDurationSeconds: nil,
                                checkPrompt: conclusionFrame.checkPrompt,
                                expectedAnswer: conclusionFrame.expectedAnswer,
                                createdAt: now,
                                updatedAt: now
                            )
                        }
                        .execute(db)
                    }

                    try await database.write { db in
                        try MultimodalLesson
                            .where { $0.id == lessonID }
                            .update {
                                $0.status = MultimodalLesson.Status.ready.rawValue
                                $0.updatedAt = now
                                $0.completedAt = now
                            }
                            .execute(db)
                    }
                    await onProgress(.completed(lessonID))
                    return lessonID
                } catch {
                    try? await database.write { db in
                        try MultimodalLesson
                            .where { $0.id == lessonID }
                            .update {
                                $0.status = MultimodalLesson.Status.failed.rawValue
                                $0.errorMessage = error.localizedDescription
                                $0.updatedAt = now
                            }
                            .execute(db)
                    }
                    throw error
                }
            }
        )
    }

    static var previewValue: Self {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date.now) var now
        @Dependency(\.uuid) var uuid
        return Self(
            generateLesson: { word1, word2, sentence, onProgress in
                let lessonID = uuid()
                try await database.write { db in
                    try MultimodalLesson.insert {
                        MultimodalLesson.Draft(
                            id: lessonID,
                            word1: word1,
                            word2: word2,
                            userSentence: sentence ?? "",
                            status: MultimodalLesson.Status.ready.rawValue,
                            storyboardJSON: "{}",
                            stylePreset: "preview_cinematic_16_9",
                            voicePreset: "preview",
                            imageModel: "preview",
                            audioModel: "preview",
                            generatorVersion: "v2.1",
                            claritySelfRating: nil,
                            lessonDurationSeconds: nil,
                            errorMessage: nil,
                            createdAt: now,
                            updatedAt: now,
                            completedAt: now
                        )
                    }
                    .execute(db)

                    let previewFrames: [(index: Int, role: String, title: String)] = [
                        (0, "story_a:setup", "Story A · Setup"),
                        (1, "story_a:conflict", "Story A · Conflict"),
                        (2, "story_a:outcome", "Story A · Outcome"),
                        (3, "story_a:language_lock_in", "Story A · Language Lock-In"),
                        (4, "story_b:setup", "Story B · Setup"),
                        (5, "story_b:conflict", "Story B · Conflict"),
                        (6, "story_b:outcome", "Story B · Outcome"),
                        (7, "story_b:language_lock_in", "Story B · Language Lock-In"),
                        (8, "final_conclusion", "Final Verdict")
                    ]

                    for frame in previewFrames {
                        try MultimodalLessonFrame.insert {
                            MultimodalLessonFrame.Draft(
                                id: uuid(),
                                lessonID: lessonID,
                                frameIndex: frame.index,
                                frameRole: frame.role,
                                title: frame.title,
                                caption: "Preview caption",
                                narrationText: "Preview narration",
                                imagePrompt: "preview",
                                imageRelativePath: "",
                                audioRelativePath: "",
                                audioDurationSeconds: nil,
                                checkPrompt: nil,
                                expectedAnswer: nil,
                                createdAt: now,
                                updatedAt: now
                            )
                        }
                        .execute(db)
                    }
                }
                await onProgress(.planning(lessonID))
                await onProgress(.generatingFrame(lessonID: lessonID, step: 1, totalSteps: 9, frameIndex: 0))
                await onProgress(.generatingFrame(lessonID: lessonID, step: 9, totalSteps: 9, frameIndex: 8))
                await onProgress(.completed(lessonID))
                return lessonID
            }
        )
    }

    static var testValue: Self {
        previewValue
    }
}

private struct PlannedFrameAsset: Sendable {
    let storyID: String
    let frameIndex: Int
    let frameRole: String
    let storyTitle: String
    let roleName: String
    let focusWord: String
    let title: String
    let caption: String
    let narrationText: String
    let imagePrompt: String
    let checkPrompt: String?
    let expectedAnswer: String?
}

private func flattenStoryFrames(_ plan: StoryboardPlan) -> [PlannedFrameAsset] {
    plan.stories
        .flatMap { story in
            story.frames.map { frame in
                PlannedFrameAsset(
                    storyID: story.storyID,
                    frameIndex: frame.globalIndex,
                    frameRole: "\(story.storyID):\(frame.role)",
                    storyTitle: story.title,
                    roleName: frame.role,
                    focusWord: story.focusWord,
                    title: frame.title,
                    caption: frame.caption,
                    narrationText: frame.narrationText,
                    imagePrompt: buildStoryFrameImagePrompt(
                        storyID: story.storyID,
                        storyTitle: story.title,
                        storyMeaningSummary: story.meaningSummary,
                        focusWord: story.focusWord,
                        storyFrames: story.frames,
                        frame: frame
                    ),
                    checkPrompt: frame.checkPrompt,
                    expectedAnswer: frame.expectedAnswer
                )
            }
        }
        .sorted { $0.frameIndex < $1.frameIndex }
}

private func makeConclusionFrame(plan: StoryboardPlan, word1: String, word2: String) -> PlannedFrameAsset {
    let conclusionIndex = (plan.stories
        .flatMap(\.frames)
        .map(\.globalIndex)
        .max() ?? -1) + 1

    let verdictText = switch plan.finalConclusion.verdict {
    case .yes: "Interchangeable"
    case .no: "Not Interchangeable"
    case .depends: "Depends on Context"
    }

    return PlannedFrameAsset(
        storyID: "final_conclusion",
        frameIndex: conclusionIndex,
        frameRole: "final_conclusion",
        storyTitle: "Final Conclusion",
        roleName: "final_conclusion",
        focusWord: "\(word1) vs \(word2)",
        title: "Final Verdict: \(word1) vs \(word2)",
        caption: "\(verdictText): \(plan.finalConclusion.recommendedUsage)",
        narrationText: plan.finalConclusion.narrationText,
        imagePrompt: buildConclusionImagePrompt(
            word1: word1,
            word2: word2,
            conclusion: plan.finalConclusion
        ),
        checkPrompt: "Can \(word1) and \(word2) be interchanged in the sentence?",
        expectedAnswer: plan.finalConclusion.verdict.rawValue
    )
}

private func buildStoryFrameImagePrompt(
    storyID: String,
    storyTitle: String,
    storyMeaningSummary: String,
    focusWord: String,
    storyFrames: [StoryboardFramePlan],
    frame: StoryboardFramePlan
) -> String {
    let framePosition = frame.indexInStory + 1
    let storyArc = buildStoryArcSummary(storyFrames)
    let continuityChecklist = buildContinuityChecklist(storyFrames: storyFrames, frame: frame)

    return """
    Draw one storyboard frame that matches this exact lesson scene.

    Story context:
    - Story ID: \(storyID)
    - Story title: \(storyTitle)
    - Meaning focus: \(storyMeaningSummary)
    - Focus word: \(focusWord)
    - This is frame \(framePosition) of \(max(storyFrames.count, 1)) in the same story.

    Full story arc (must stay logically consistent across frames):
    \(storyArc)

    Frame context:
    - Global index: \(frame.globalIndex)
    - Role: \(humanizeFrameRole(frame.role))
    - Title: \(frame.title)
    - Caption: \(frame.caption)
    - Narration to depict exactly: \(frame.narrationText)

    Visual grounding rules:
    - Show a single concrete moment from this frame, not a generic concept.
    - The people, setting, and action must directly reflect the narration.
    - Keep visual continuity with the same story's characters and environment.
    - Keep story details consistent with the full arc above.
    - Continuity details to preserve in this frame:
    \(continuityChecklist)
    - Emphasize the cause/result in this frame role: \(humanizeFrameRole(frame.role)).
    - Use the planner visual note if compatible: \(frame.imagePrompt)
    """
}

private func buildStoryArcSummary(_ storyFrames: [StoryboardFramePlan]) -> String {
    let lines = storyFrames
        .sorted { $0.indexInStory < $1.indexInStory }
        .map { storyFrame in
            let step = storyFrame.indexInStory + 1
            return "- Frame \(step) (\(humanizeFrameRole(storyFrame.role))): \(storyFrame.narrationText)"
        }
    return lines.joined(separator: "\n")
}

private func buildContinuityChecklist(
    storyFrames: [StoryboardFramePlan],
    frame: StoryboardFramePlan
) -> String {
    let ordered = storyFrames.sorted { $0.indexInStory < $1.indexInStory }
    let visibleSoFar = ordered.filter { $0.indexInStory <= frame.indexInStory }
    let upcoming = ordered.filter { $0.indexInStory > frame.indexInStory }

    var lines: [String] = []
    if !visibleSoFar.isEmpty {
        lines.append("- Already happened in this story:")
        lines.append(contentsOf: visibleSoFar.map { storyFrame in
            let step = storyFrame.indexInStory + 1
            return "  - Frame \(step): \(storyFrame.narrationText)"
        })
    }
    if !upcoming.isEmpty {
        lines.append("- Will happen in later frames (do not contradict):")
        lines.append(contentsOf: upcoming.map { storyFrame in
            let step = storyFrame.indexInStory + 1
            return "  - Frame \(step): \(storyFrame.narrationText)"
        })
    }
    return lines.joined(separator: "\n")
}

private func buildConclusionImagePrompt(
    word1: String,
    word2: String,
    conclusion: StoryboardFinalConclusionPlan
) -> String {
    """
    Draw one final storyboard conclusion frame for this vocabulary lesson.

    Lesson comparison:
    - Word 1: \(word1)
    - Word 2: \(word2)
    - Verdict: \(conclusion.verdict.rawValue)
    - Verdict reason: \(conclusion.verdictReason)
    - Recommended usage: \(conclusion.recommendedUsage)
    - Tone difference: \(conclusion.toneDifferenceNote)
    - User sentence: \(conclusion.sentenceFromUser)
    - Narration to depict exactly: \(conclusion.narrationText)

    Visual grounding rules:
    - Show a clear closing scene that communicates the verdict decision.
    - Use concrete characters and context from lesson world, not abstract icons only.
    - Visually communicate the recommendation for sentence usage.
    - Use the planner visual note if compatible: \(conclusion.imagePrompt)
    """
}

private func humanizeFrameRole(_ role: String) -> String {
    switch role {
    case "setup":
        return "setup"
    case "conflict":
        return "conflict"
    case "outcome":
        return "outcome"
    case "language_lock_in":
        return "language lock-in"
    case "final_conclusion":
        return "final conclusion"
    default:
        return role.replacingOccurrences(of: "_", with: " ")
    }
}

extension DependencyValues {
    var multimodalLessonGenerator: MultimodalLessonGeneratorClient {
        get { self[MultimodalLessonGeneratorClient.self] }
        set { self[MultimodalLessonGeneratorClient.self] = newValue }
    }
}
