//
//  MultimodalLessonsFeatureTests.swift
//  WordsLearnerTests
//

import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import WordsLearner

@MainActor
struct MultimodalLessonsFeatureTests {
    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func seedLessons(in db: Database) throws {
        let readyID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let generatingID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let failedID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let frameID0 = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa0")!
        let frameID1 = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1")!
        let frameID2 = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2")!
        try db.seed {
            MultimodalLesson(
                id: readyID,
                word1: "affect",
                word2: "effect",
                userSentence: "The policy will affect the effect.",
                status: MultimodalLesson.Status.ready.rawValue,
                storyboardJSON: "{}",
                stylePreset: "cinematic_storyboard_16_9_v2",
                voicePreset: "elevenlabs_default_v1",
                imageModel: "google/gemini-3.1-flash-image-preview",
                audioModel: "eleven_multilingual_v2",
                generatorVersion: "v2.1",
                claritySelfRating: nil,
                lessonDurationSeconds: nil,
                errorMessage: nil,
                createdAt: baseDate.addingTimeInterval(-100),
                updatedAt: baseDate.addingTimeInterval(-90),
                completedAt: baseDate.addingTimeInterval(-90)
            )
            MultimodalLesson(
                id: generatingID,
                word1: "adapt",
                word2: "adopt",
                userSentence: "Teams adapt and adopt tools.",
                status: MultimodalLesson.Status.generating.rawValue,
                storyboardJSON: "{}",
                stylePreset: "cinematic_storyboard_16_9_v2",
                voicePreset: "elevenlabs_default_v1",
                imageModel: "google/gemini-3.1-flash-image-preview",
                audioModel: "eleven_multilingual_v2",
                generatorVersion: "v2.1",
                claritySelfRating: nil,
                lessonDurationSeconds: nil,
                errorMessage: nil,
                createdAt: baseDate.addingTimeInterval(-50),
                updatedAt: baseDate.addingTimeInterval(-40),
                completedAt: nil
            )
            MultimodalLesson(
                id: failedID,
                word1: "character",
                word2: "characteristic",
                userSentence: "Her character has one characteristic.",
                status: MultimodalLesson.Status.failed.rawValue,
                storyboardJSON: "{}",
                stylePreset: "cinematic_storyboard_16_9_v2",
                voicePreset: "elevenlabs_default_v1",
                imageModel: "google/gemini-3.1-flash-image-preview",
                audioModel: "eleven_multilingual_v2",
                generatorVersion: "v2.1",
                claritySelfRating: nil,
                lessonDurationSeconds: nil,
                errorMessage: "Audio failed",
                createdAt: baseDate,
                updatedAt: baseDate,
                completedAt: nil
            )

            // Intentionally insert unsorted frame indexes; reducer should load sorted.
            MultimodalLessonFrame(
                id: frameID2,
                lessonID: readyID,
                frameIndex: 2,
                frameRole: "story_a:outcome",
                title: "Outcome",
                caption: "",
                narrationText: "Outcome",
                imagePrompt: "prompt",
                imageRelativePath: "img2",
                audioRelativePath: "aud2",
                audioDurationSeconds: nil,
                checkPrompt: nil,
                expectedAnswer: nil,
                createdAt: baseDate,
                updatedAt: baseDate
            )
            MultimodalLessonFrame(
                id: frameID0,
                lessonID: readyID,
                frameIndex: 0,
                frameRole: "story_a:setup",
                title: "Setup",
                caption: "",
                narrationText: "Setup",
                imagePrompt: "prompt",
                imageRelativePath: "img0",
                audioRelativePath: "aud0",
                audioDurationSeconds: nil,
                checkPrompt: nil,
                expectedAnswer: nil,
                createdAt: baseDate,
                updatedAt: baseDate
            )
            MultimodalLessonFrame(
                id: frameID1,
                lessonID: readyID,
                frameIndex: 1,
                frameRole: "story_a:conflict",
                title: "Conflict",
                caption: "",
                narrationText: "Conflict",
                imagePrompt: "prompt",
                imageRelativePath: "img1",
                audioRelativePath: "aud1",
                audioDurationSeconds: nil,
                checkPrompt: nil,
                expectedAnswer: nil,
                createdAt: baseDate,
                updatedAt: baseDate
            )
        }
    }

    private func makeStore() -> TestStoreOf<MultimodalLessonsFeature> {
        TestStore(initialState: MultimodalLessonsFeature.State()) {
            MultimodalLessonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true, seed: seedLessons(in:))
        }
    }

    @Test
    func initialFetch_loadsLessonsAndSortsByDateDescending() async throws {
        let store = makeStore()
        await store.send(.textChanged(""))
        await store.finish()

        #expect(store.state.lessons.count == 3)
        #expect(store.state.filteredLessons.count == 3)
        #expect(store.state.filteredLessons.first?.lessonStatus == .failed)
    }

    @Test
    func lessonTapped_loadsFramesSortedByFrameIndex() async throws {
        let store = makeStore()
        await store.send(.textChanged(""))
        await store.finish()
        let readyLesson = try #require(store.state.lessons.first(where: { $0.lessonStatus == .ready }))

        await store.send(.lessonTapped(readyLesson.id)) {
            $0.selectedLessonID = readyLesson.id
        }
        await store.receive(\.selectedFramesLoaded) {
            $0.selectedFrames = [
                MultimodalLessonFrame(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa0")!,
                    lessonID: readyLesson.id,
                    frameIndex: 0,
                    frameRole: "story_a:setup",
                    title: "Setup",
                    caption: "",
                    narrationText: "Setup",
                    imagePrompt: "prompt",
                    imageRelativePath: "img0",
                    audioRelativePath: "aud0",
                    audioDurationSeconds: nil,
                    checkPrompt: nil,
                    expectedAnswer: nil,
                    createdAt: baseDate,
                    updatedAt: baseDate
                ),
                MultimodalLessonFrame(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1")!,
                    lessonID: readyLesson.id,
                    frameIndex: 1,
                    frameRole: "story_a:conflict",
                    title: "Conflict",
                    caption: "",
                    narrationText: "Conflict",
                    imagePrompt: "prompt",
                    imageRelativePath: "img1",
                    audioRelativePath: "aud1",
                    audioDurationSeconds: nil,
                    checkPrompt: nil,
                    expectedAnswer: nil,
                    createdAt: baseDate,
                    updatedAt: baseDate
                ),
                MultimodalLessonFrame(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2")!,
                    lessonID: readyLesson.id,
                    frameIndex: 2,
                    frameRole: "story_a:outcome",
                    title: "Outcome",
                    caption: "",
                    narrationText: "Outcome",
                    imagePrompt: "prompt",
                    imageRelativePath: "img2",
                    audioRelativePath: "aud2",
                    audioDurationSeconds: nil,
                    checkPrompt: nil,
                    expectedAnswer: nil,
                    createdAt: baseDate,
                    updatedAt: baseDate
                )
            ]
        }
        #expect(store.state.selectedLessonID == readyLesson.id)
        #expect(store.state.selectedFrames.map(\.frameIndex) == [0, 1, 2])
    }

    @Test
    func filterToggled_showsOnlyFailedLessons() async throws {
        let store = makeStore()
        await store.send(.textChanged(""))
        await store.finish()

        await store.send(.filterToggled) {
            $0.showFailedOnly = true
        }

        #expect(store.state.filteredLessons.count == 1)
        #expect(store.state.filteredLessons.first?.lessonStatus == .failed)
    }

    @Test
    func textChanged_filtersByWordOrSentence() async throws {
        let store = makeStore()
        await store.send(.textChanged("adapt")) {
            $0.searchText = "adapt"
        }
        await store.finish()
        #expect(store.state.filteredLessons.count == 1)
        #expect(store.state.filteredLessons.first?.word1 == "adapt")
    }

    @Test
    func deleteLessons_deletesLessonAndAssociatedFrames() async throws {
        let store = makeStore()
        await store.send(.textChanged(""))
        await store.finish()

        let readyIndex = try #require(store.state.filteredLessons.firstIndex(where: { $0.lessonStatus == .ready }))
        await store.send(.deleteLessons(IndexSet(integer: readyIndex)))
        await store.finish()

        #expect(!store.state.lessons.contains(where: { $0.lessonStatus == .ready }))
    }

    @Test
    func clearAllConfirmed_deletesAllLessonsAndFrames() async throws {
        let store = makeStore()
        await store.send(.textChanged(""))
        await store.finish()
        #expect(store.state.lessons.count == 3)

        await store.send(.clearAllButtonTapped) {
            $0.alert = AlertState {
                TextState("Clear All Multimodal History?")
            } actions: {
                ButtonState(role: .destructive, action: .clearAllConfirmed) {
                    TextState("Clear All")
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            } message: {
                TextState("This will delete all multimodal lessons. This action cannot be undone.")
            }
        }

        await store.send(.alert(.presented(.clearAllConfirmed))) {
            $0.alert = nil
        }
        await store.finish()

        #expect(store.state.lessons.isEmpty)
        #expect(store.state.filteredLessons.isEmpty)
    }
}
