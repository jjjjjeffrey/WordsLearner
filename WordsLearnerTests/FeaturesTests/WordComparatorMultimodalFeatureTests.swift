//
//  WordComparatorMultimodalFeatureTests.swift
//  WordsLearnerTests
//

import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import WordsLearner

@MainActor
struct WordComparatorMultimodalFeatureTests {
    private let seedBaseDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func seedBackgroundTasks(in db: Database) throws {
        let now = seedBaseDate
        try db.seed {
            BackgroundTask.Draft(
                id: UUID(),
                word1: "accept",
                word2: "except",
                sentence: "I accept all terms.",
                status: BackgroundTask.Status.pending.rawValue,
                response: "",
                error: nil,
                createdAt: now,
                updatedAt: now
            )
        }
    }

    @Test
    func generateMultimodalButtonTapped_startsGeneratingState() async throws {
        let fixedLessonID = UUID(uuidString: "15aa1fbf-2c1d-4ef3-b9f6-b3cc29f98dbb")!
        let store = TestStore(initialState: WordComparatorFeature.State(
            word1: "affect",
            word2: "effect",
            sentence: "The policy affects outcomes.",
            hasValidAPIKey: true,
            hasValidElevenLabsAPIKey: true,
            isComposerSheetPresented: true
        )) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            $0.multimodalLessonGenerator = .init(
                generateLesson: { _, _, _, _ in
                    fixedLessonID
                }
            )
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }

        await store.send(.generateMultimodalButtonTapped) {
            $0.isGeneratingMultimodalLesson = true
            $0.activeMultimodalLessonID = nil
            $0.multimodalGenerationStatusText = "Starting multimodal lesson..."
            $0.multimodalGenerationStep = 0
            $0.multimodalGenerationTotalSteps = 0
            $0.isComposerSheetPresented = false
            $0.sidebarSelection = .multimodalLessons
            $0.multimodalLessons = MultimodalLessonsFeature.State()
            $0.historyList = nil
            $0.backgroundTasks = nil
        }
        await store.receive(\.multimodalLessonGenerated) {
            $0.isGeneratingMultimodalLesson = false
            $0.activeMultimodalLessonID = nil
            $0.multimodalGenerationStatusText = nil
            $0.multimodalGenerationStep = 0
            $0.multimodalGenerationTotalSteps = 0
            $0.sidebarSelection = .multimodalLessons
            $0.multimodalLessons = MultimodalLessonsFeature.State()
            $0.historyList = nil
            $0.backgroundTasks = nil
        }
        await store.receive(\.multimodalLessons.lessonTapped) {
            $0.multimodalLessons?.selectedLessonID = fixedLessonID
        }
        await store.receive(\.clearInputFields) {
            $0.word1 = ""
            $0.word2 = ""
            $0.sentence = ""
        }
        await store.receive(\.multimodalLessons.selectedFramesLoaded)
    }

    @Test
    func multimodalPlanningProgress_setsStatusAndRoutesToLesson() async throws {
        let lessonID = UUID()
        let store = TestStore(initialState: WordComparatorFeature.State(
            sidebarSelection: .multimodalLessons,
            multimodalLessons: MultimodalLessonsFeature.State()
        )) {
            WordComparatorFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }

        await store.send(.multimodalGenerationProgressUpdated(.planning(lessonID))) {
            $0.activeMultimodalLessonID = lessonID
            $0.multimodalGenerationStatusText = "Planning storyboard..."
            $0.multimodalGenerationStep = 0
            $0.multimodalGenerationTotalSteps = 0
        }
        await store.receive(\.multimodalLessons.lessonTapped) {
            $0.multimodalLessons?.selectedLessonID = lessonID
        }
        await store.receive(\.multimodalLessons.selectedFramesLoaded)
    }

    @Test
    func multimodalFrameProgress_updatesStepAndFraction() async throws {
        let lessonID = UUID()
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }

        await store.send(.multimodalGenerationProgressUpdated(
            .generatingFrame(lessonID: lessonID, step: 3, totalSteps: 9, frameIndex: 2)
        )) {
            $0.activeMultimodalLessonID = lessonID
            $0.multimodalGenerationStep = 3
            $0.multimodalGenerationTotalSteps = 9
            $0.multimodalGenerationStatusText = "Generating scene 3/9..."
        }
        #expect(store.state.multimodalGenerationProgressFraction == (3.0 / 9.0))
        #expect(store.state.multimodalGenerationStepText == "3/9")
    }

    @Test
    func multimodalCompletedProgress_setsFinalizingText() async throws {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }

        await store.send(.multimodalGenerationProgressUpdated(.completed(UUID()))) {
            $0.multimodalGenerationStatusText = "Finalizing lesson..."
        }
    }

    @Test
    func multimodalLessonGenerated_resetsStateAndNavigatesToDetail() async throws {
        let lessonID = UUID()
        let store = TestStore(initialState: WordComparatorFeature.State(
            isGeneratingMultimodalLesson: true,
            activeMultimodalLessonID: UUID(),
            multimodalGenerationStatusText: "Generating...",
            multimodalGenerationStep: 4,
            multimodalGenerationTotalSteps: 9
        )) {
            WordComparatorFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }

        await store.send(.multimodalLessonGenerated(lessonID)) {
            $0.isGeneratingMultimodalLesson = false
            $0.activeMultimodalLessonID = nil
            $0.multimodalGenerationStatusText = nil
            $0.multimodalGenerationStep = 0
            $0.multimodalGenerationTotalSteps = 0
            $0.sidebarSelection = .multimodalLessons
            $0.multimodalLessons = MultimodalLessonsFeature.State()
            $0.historyList = nil
            $0.backgroundTasks = nil
        }
        await store.receive(\.multimodalLessons.lessonTapped) {
            $0.multimodalLessons?.selectedLessonID = lessonID
        }
        await store.receive(\.multimodalLessons.selectedFramesLoaded)
    }

    @Test
    func multimodalLessonGenerationFailed_resetsStateAndShowsAlert() async throws {
        let store = TestStore(initialState: WordComparatorFeature.State(
            isGeneratingMultimodalLesson: true,
            activeMultimodalLessonID: UUID(),
            multimodalGenerationStatusText: "Generating...",
            multimodalGenerationStep: 2,
            multimodalGenerationTotalSteps: 9
        )) {
            WordComparatorFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }

        await store.send(.multimodalLessonGenerationFailed("boom")) {
            $0.isGeneratingMultimodalLesson = false
            $0.activeMultimodalLessonID = nil
            $0.multimodalGenerationStatusText = nil
            $0.multimodalGenerationStep = 0
            $0.multimodalGenerationTotalSteps = 0
            $0.alert = AlertState {
                TextState("Multimodal Generation Failed")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("OK")
                }
            } message: {
                TextState("boom")
            }
        }
    }
}
