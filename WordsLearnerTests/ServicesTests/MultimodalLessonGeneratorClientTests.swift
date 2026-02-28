//
//  MultimodalLessonGeneratorClientTests.swift
//  WordsLearnerTests
//

import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import WordsLearner

@MainActor
struct MultimodalLessonGeneratorClientTests {
    private final class LockedBox<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Value

        init(_ value: Value) {
            self.value = value
        }

        func withValue<R>(_ body: (inout Value) -> R) -> R {
            lock.lock()
            defer { lock.unlock() }
            return body(&value)
        }

        func snapshot() -> Value where Value: Sendable {
            withValue { $0 }
        }
    }

    private struct ImageCall: Sendable {
        let prompt: String
        let referenceCount: Int
    }

    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func generateLesson_success_persistsFramesProgressAndStoryAnchors() async throws {
        let imageCalls = LockedBox<[ImageCall]>([])
        let progressEvents = LockedBox<[MultimodalGenerationProgress]>([])
        let uuidSequence = LockedBox([
            UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!, // lesson id
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1")!,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2")!,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3")!,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb4")!,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb5")!,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb6")!,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb7")!,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb8")!,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb9")!,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbba0")!
        ])

        let result = try await withDependencies {
            try! $0.bootstrapDatabase(useTest: true)
            $0.date.now = baseDate
            $0.uuid = .init {
                uuidSequence.withValue { sequence in
                    sequence.removeFirst()
                }
            }
            $0.multimodalStoryboardPlanner = .init(
                plan: { word1, word2, sentence in
                    makePlan(word1: word1, word2: word2, sentence: sentence ?? "")
                }
            )
            $0.multimodalImageGenerator = .init(
                generateImage: { prompt, references in
                    imageCalls.withValue { calls in
                        calls.append(ImageCall(prompt: prompt, referenceCount: references.count))
                    }
                    return Data("img".utf8)
                }
            )
            $0.multimodalAudioGenerator = .init(
                generateAudio: { _ in Data("audio".utf8) }
            )
            $0.multimodalAssetStore = .init(
                lessonDirectory: { lessonID in
                    URL(fileURLWithPath: "/tmp/\(lessonID.uuidString)", isDirectory: true)
                },
                writeImage: { _, lessonID, frameIndex in
                    "MultimodalLessons/\(lessonID.uuidString)/frame-\(frameIndex).png"
                },
                writeAudio: { _, lessonID, frameIndex in
                    "MultimodalLessons/\(lessonID.uuidString)/frame-\(frameIndex).mp3"
                },
                resolve: { URL(fileURLWithPath: "/tmp/\($0)") }
            )
        } operation: {
            @Dependency(\.defaultDatabase) var database
            let lessonID = try await MultimodalLessonGeneratorClient.liveValue.generateLesson(
                "affect",
                "effect",
                "The policy affects the final effect."
            ) { progress in
                progressEvents.withValue { $0.append(progress) }
            }

            let lesson = try await database.read { db in
                try MultimodalLesson.where { $0.id == lessonID }.fetchOne(db)
            }
            let frames = try await database.read { db in
                try MultimodalLessonFrame
                    .where { $0.lessonID == lessonID }
                    .order { $0.frameIndex.asc() }
                    .fetchAll(db)
            }
            return (lessonID, lesson, frames)
        }

        let lesson = try #require(result.1)
        #expect(lesson.lessonStatus == .ready)
        #expect(lesson.generatorVersion == "v2.1")
        #expect(lesson.completedAt != nil)

        let frames = result.2
        #expect(frames.count == 9)
        #expect(frames.map(\.frameIndex) == Array(0...8))
        #expect(frames.last?.frameRole == "final_conclusion")

        let calls = imageCalls.snapshot()
        #expect(calls.count == 9)
        #expect(calls.map(\.referenceCount) == [0, 1, 1, 1, 0, 1, 1, 1, 0])
        #expect(calls[1].prompt.contains("Full story arc"))
        #expect(calls[1].prompt.contains("Will happen in later frames (do not contradict):"))
        #expect(calls[8].prompt.contains("final storyboard conclusion frame"))

        let progress = progressEvents.snapshot()
        #expect(progress.count == 11)
        #expect(progress.first == .planning(result.0))
        #expect(progress.last == .completed(result.0))
        #expect(progress.dropFirst().dropLast().allSatisfy {
            if case let .generatingFrame(_, _, totalSteps, _) = $0 {
                return totalSteps == 9
            }
            return false
        })
    }

    @Test
    func generateLesson_failure_setsLessonFailedAndStoresError() async throws {
        let fixedLessonID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let uuidSequence = LockedBox([
            fixedLessonID,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1")!
        ])
        let progressEvents = LockedBox<[MultimodalGenerationProgress]>([])

        let result = try await withDependencies {
            try! $0.bootstrapDatabase(useTest: true)
            $0.date.now = baseDate
            $0.uuid = .init {
                uuidSequence.withValue { sequence in
                    sequence.removeFirst()
                }
            }
            $0.multimodalStoryboardPlanner = .init(
                plan: { word1, word2, sentence in
                    makePlan(word1: word1, word2: word2, sentence: sentence ?? "")
                }
            )
            $0.multimodalImageGenerator = .init(
                generateImage: { _, _ in
                    struct StubFailure: Error, LocalizedError {
                        var errorDescription: String? { "image generation failed" }
                    }
                    throw StubFailure()
                }
            )
            $0.multimodalAudioGenerator = .init(
                generateAudio: { _ in Data("audio".utf8) }
            )
            $0.multimodalAssetStore = .init(
                lessonDirectory: { _ in URL(fileURLWithPath: "/tmp", isDirectory: true) },
                writeImage: { _, _, _ in "" },
                writeAudio: { _, _, _ in "" },
                resolve: { URL(fileURLWithPath: "/tmp/\($0)") }
            )
        } operation: {
            @Dependency(\.defaultDatabase) var database
            do {
                _ = try await MultimodalLessonGeneratorClient.liveValue.generateLesson(
                    "affect",
                    "effect",
                    nil
                ) { progress in
                    progressEvents.withValue { $0.append(progress) }
                }
                Issue.record("Expected multimodal generation to fail.")
            } catch {}

            let lesson = try await database.read { db in
                try MultimodalLesson.where { $0.id == fixedLessonID }.fetchOne(db)
            }
            let frames = try await database.read { db in
                try MultimodalLessonFrame
                    .where { $0.lessonID == fixedLessonID }
                    .fetchAll(db)
            }
            return (lesson, frames)
        }

        let lesson = try #require(result.0)
        #expect(lesson.lessonStatus == .failed)
        #expect(lesson.errorMessage == "image generation failed")
        #expect(result.1.isEmpty)

        let progress = progressEvents.snapshot()
        #expect(progress.count == 2)
        #expect(progress.first == .planning(fixedLessonID))
        #expect({
            if case .generatingFrame(lessonID: fixedLessonID, step: 1, totalSteps: 9, frameIndex: 0) = progress.last {
                return true
            }
            return false
        }())
    }
}

private func makePlan(word1: String, word2: String, sentence: String) -> StoryboardPlan {
    StoryboardPlan(
        schemaVersion: "v2.0",
        lessonObjective: "Teach usage differences.",
        styleConsistency: "Story-first, certainty-first multimodal lesson with concrete mini-stories.",
        stories: [
            StoryboardStoryPlan(
                storyID: "story_a",
                focusWord: word1,
                title: "\(word1) story",
                meaningSummary: "Use \(word1) in context A.",
                frames: [
                    StoryboardFramePlan(indexInStory: 0, globalIndex: 0, role: "setup", targetWord: word1, title: "Setup", caption: "Setup caption", narrationText: "A student starts in class.", imagePrompt: "Classroom setup", checkPrompt: nil, expectedAnswer: nil),
                    StoryboardFramePlan(indexInStory: 1, globalIndex: 1, role: "conflict", targetWord: word1, title: "Conflict", caption: "Conflict caption", narrationText: "The wrong word sounds strange here.", imagePrompt: "Classroom conflict", checkPrompt: nil, expectedAnswer: nil),
                    StoryboardFramePlan(indexInStory: 2, globalIndex: 2, role: "outcome", targetWord: word1, title: "Outcome", caption: "Outcome caption", narrationText: "The result confirms the intended meaning.", imagePrompt: "Classroom outcome", checkPrompt: nil, expectedAnswer: nil),
                    StoryboardFramePlan(indexInStory: 3, globalIndex: 3, role: "language_lock_in", targetWord: word1, title: "Lock-In", caption: "Lock-in caption", narrationText: "In this story, \(word1) is the natural choice.", imagePrompt: "Classroom lock-in", checkPrompt: "Which fits?", expectedAnswer: word1)
                ]
            ),
            StoryboardStoryPlan(
                storyID: "story_b",
                focusWord: word2,
                title: "\(word2) story",
                meaningSummary: "Use \(word2) in context B.",
                frames: [
                    StoryboardFramePlan(indexInStory: 0, globalIndex: 4, role: "setup", targetWord: word2, title: "Setup", caption: "Setup caption", narrationText: "A worker starts in an office.", imagePrompt: "Office setup", checkPrompt: nil, expectedAnswer: nil),
                    StoryboardFramePlan(indexInStory: 1, globalIndex: 5, role: "conflict", targetWord: word2, title: "Conflict", caption: "Conflict caption", narrationText: "Now only the second word sounds natural.", imagePrompt: "Office conflict", checkPrompt: nil, expectedAnswer: nil),
                    StoryboardFramePlan(indexInStory: 2, globalIndex: 6, role: "outcome", targetWord: word2, title: "Outcome", caption: "Outcome caption", narrationText: "The outcome highlights the contrast.", imagePrompt: "Office outcome", checkPrompt: nil, expectedAnswer: nil),
                    StoryboardFramePlan(indexInStory: 3, globalIndex: 7, role: "language_lock_in", targetWord: word2, title: "Lock-In", caption: "Lock-in caption", narrationText: "In this story, \(word2) is the right word.", imagePrompt: "Office lock-in", checkPrompt: "Which fits?", expectedAnswer: word2)
                ]
            )
        ],
        finalConclusion: StoryboardFinalConclusionPlan(
            verdict: .depends,
            verdictReason: "Context decides the choice.",
            sentenceFromUser: sentence,
            recommendedUsage: "Choose by intent.",
            toneDifferenceNote: "Tone differs by context.",
            narrationText: "Final verdict: it depends on context.",
            imagePrompt: "Final summary image"
        )
    )
}

