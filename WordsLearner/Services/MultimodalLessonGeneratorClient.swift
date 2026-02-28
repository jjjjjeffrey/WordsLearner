//
//  MultimodalLessonGeneratorClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation
import SQLiteData

enum MultimodalGenerationProgress: Equatable, Sendable {
    case planning
    case generatingFrame(Int)
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
                            stylePreset: "cinematic_storyboard_16_9_v1",
                            voicePreset: "elevenlabs_default_v1",
                            imageModel: "google/gemini-3.1-flash-image-preview",
                            audioModel: "eleven_multilingual_v2",
                            generatorVersion: "v1.1",
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
                    await onProgress(.planning)
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

                    for frame in plan.frames.sorted(by: { $0.index < $1.index }) {
                        await onProgress(.generatingFrame(frame.index))
                        let imageData = try await imageGenerator.generateImage(frame.imagePrompt)
                        let audioData = try await audioGenerator.generateAudio(frame.narrationText)
                        let imagePath = try assets.writeImage(imageData, lessonID, frame.index)
                        let audioPath = try assets.writeAudio(audioData, lessonID, frame.index)

                        try await database.write { db in
                            try MultimodalLessonFrame.insert {
                                MultimodalLessonFrame.Draft(
                                    id: uuid(),
                                    lessonID: lessonID,
                                    frameIndex: frame.index,
                                    frameRole: frame.role,
                                    title: frame.title,
                                    caption: frame.caption,
                                    narrationText: frame.narrationText,
                                    imagePrompt: frame.imagePrompt,
                                    imageRelativePath: imagePath,
                                    audioRelativePath: audioPath,
                                    audioDurationSeconds: nil,
                                    checkPrompt: frame.checkPrompt,
                                    expectedAnswer: frame.expectedAnswer,
                                    createdAt: now,
                                    updatedAt: now
                                )
                            }
                            .execute(db)
                        }
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
                            generatorVersion: "v1.1",
                            claritySelfRating: nil,
                            lessonDurationSeconds: nil,
                            errorMessage: nil,
                            createdAt: now,
                            updatedAt: now,
                            completedAt: now
                        )
                    }
                    .execute(db)
                }
                await onProgress(.planning)
                await onProgress(.generatingFrame(0))
                await onProgress(.completed(lessonID))
                return lessonID
            }
        )
    }

    static var testValue: Self {
        previewValue
    }
}

extension DependencyValues {
    var multimodalLessonGenerator: MultimodalLessonGeneratorClient {
        get { self[MultimodalLessonGeneratorClient.self] }
        set { self[MultimodalLessonGeneratorClient.self] = newValue }
    }
}
