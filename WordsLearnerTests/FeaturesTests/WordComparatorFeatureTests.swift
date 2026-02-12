//
//  WordComparatorFeatureTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 11/18/25.
//

import Foundation
import ComposableArchitecture
import Testing
import DependenciesTestSupport
import SQLiteData

@testable import WordsLearner

@MainActor
struct WordComparatorFeatureTests {
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
    func canGenerateWithEmptyAndValidInputs() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        #expect(store.state.canGenerate == false)
        #expect(store.state.pendingTasksCount == 1)
        
        await store.send(\.binding.word1, "word1") {
            $0.word1 = "word1"
        }
        
        #expect(store.state.canGenerate == false)
        
        await store.send(\.binding.word2, "word2") {
            $0.word2 = "word2"
        }
        
        #expect(store.state.canGenerate == false)
        
        await store.send(\.binding.sentence, "This is a sentence") {
            $0.sentence = "This is a sentence"
        }
        
        #expect(store.state.canGenerate == true)
    }
    
    @Test
    func canGenerateWithWhitespaceOnlyInputs() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(\.binding.word1, "   ") {
            $0.word1 = "   "
        }
        
        #expect(store.state.canGenerate == false)
        
        await store.send(\.binding.word2, "\n\t") {
            $0.word2 = "\n\t"
        }
        
        #expect(store.state.canGenerate == false)
        
        await store.send(\.binding.sentence, "  \n  ") {
            $0.sentence = "  \n  "
        }
        
        #expect(store.state.canGenerate == false)
    }
    
    // MARK: - Navigation Actions Tests
    
    @Test
    func onAppear() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.onAppear) {
            $0.hasValidAPIKey = true
        }
    }
    
    @Test
    func onAppearWithoutValidAPIKey() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testNoValidAPIKeyValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.onAppear)
        
        #expect(store.state.hasValidAPIKey == false)
    }
    
    @Test
    func onAppearWithValidAPIKey() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.onAppear) {
            $0.hasValidAPIKey = true
        }
    }
    
    // MARK: - Input Actions Tests
    
    @Test
    func clearInputFields() async {
        let store = TestStore(initialState: WordComparatorFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "sentence"
        )) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.clearInputFields) {
            $0.word1 = ""
            $0.word2 = ""
            $0.sentence = ""
        }
    }
    
    // MARK: - Generation Actions Tests
    
    @Test
    func generateButtonTappedWithValidInputs() async {
        let store = TestStore(initialState: WordComparatorFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            hasValidAPIKey: true
        )) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            $0.comparisonGenerator = .init(
                generateComparison: { _, _, _ in AsyncThrowingStream { _ in } },
                saveToHistory: { @Sendable _, _, _, _ async throws in }
            )
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.generateButtonTapped) {
            $0.detail = ResponseDetailFeature.State(
                word1: "word1",
                word2: "word2",
                sentence: "This is a sentence"
            )
            $0.detailPresentationToken = 1
        }
        
        await store.receive(\.clearInputFields) {
            $0.word1 = ""
            $0.word2 = ""
            $0.sentence = ""
        }

        await store.receive(\.detail.startStreaming) {
            $0.detail?.isStreaming = true
            $0.detail?.shouldStartStreaming = false
        }

        await store.skipInFlightEffects()
    }
    
    @Test
    func generateButtonTappedTwiceStartsStreamingBothTimes() async {
        let store = TestStore(initialState: WordComparatorFeature.State(
            word1: "accept",
            word2: "except",
            sentence: "I accept all terms except this one.",
            hasValidAPIKey: true
        )) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            $0.comparisonGenerator = .init(
                generateComparison: { _, _, _ in AsyncThrowingStream { _ in } },
                saveToHistory: { @Sendable _, _, _, _ async throws in }
            )
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }

        await store.send(.generateButtonTapped) {
            $0.detail = ResponseDetailFeature.State(
                word1: "accept",
                word2: "except",
                sentence: "I accept all terms except this one."
            )
            $0.detailPresentationToken = 1
        }
        await store.receive(\.clearInputFields) {
            $0.word1 = ""
            $0.word2 = ""
            $0.sentence = ""
        }
        await store.receive(\.detail.startStreaming) {
            $0.detail?.isStreaming = true
            $0.detail?.shouldStartStreaming = false
        }

        await store.send(\.binding.word1, "affect") {
            $0.word1 = "affect"
        }
        await store.send(\.binding.word2, "effect") {
            $0.word2 = "effect"
        }
        await store.send(\.binding.sentence, "The policy will affect the final effect.") {
            $0.sentence = "The policy will affect the final effect."
        }

        await store.send(.generateButtonTapped) {
            $0.detail = ResponseDetailFeature.State(
                word1: "affect",
                word2: "effect",
                sentence: "The policy will affect the final effect."
            )
            $0.detailPresentationToken = 2
        }
        await store.receive(\.clearInputFields) {
            $0.word1 = ""
            $0.word2 = ""
            $0.sentence = ""
        }
        await store.receive(\.detail.startStreaming) {
            $0.detail?.isStreaming = true
            $0.detail?.shouldStartStreaming = false
        }

        await store.skipInFlightEffects()
    }

    @Test
    func generateButtonTappedWithoutAPIKey() async {
        let store = TestStore(initialState: WordComparatorFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            hasValidAPIKey: false
        )) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.generateButtonTapped)
    }
    
    @Test
    func generateButtonTappedWithInvalidInputs() async {
        let store = TestStore(initialState: WordComparatorFeature.State(
            word1: "",
            word2: "word2",
            sentence: "sentence",
            hasValidAPIKey: true
        )) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.generateButtonTapped)
    }
    
    @Test
    func generateInBackgroundButtonTappedWithValidInputs() async {
        let store = TestStore(initialState: WordComparatorFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            hasValidAPIKey: true
        )) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.generateInBackgroundButtonTapped)
        await store.receive(\.taskAddedSuccessfully)
        await store.receive(\.clearInputFields) {
            $0.word1 = ""
            $0.word2 = ""
            $0.sentence = ""
        }
    }
    
    @Test
    func generateInBackgroundButtonTappedWithoutAPIKey() async {
        let store = TestStore(initialState: WordComparatorFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            hasValidAPIKey: false
        )) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.generateInBackgroundButtonTapped)
    }
    
    @Test
    func generateInBackgroundButtonTappedWithInvalidInputs() async {
        let store = TestStore(initialState: WordComparatorFeature.State(
            word1: "",
            word2: "word2",
            sentence: "sentence",
            hasValidAPIKey: true
        )) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.generateInBackgroundButtonTapped)
    }
    
    @Test
    func generateInBackgroundButtonTappedWithError() async {
        struct TaskError: Error {}
        
        let store = TestStore(initialState: WordComparatorFeature.State(
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            hasValidAPIKey: true
        )) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in throw TaskError() }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.generateInBackgroundButtonTapped)
        // Error is caught and printed, no action is sent
    }
    
    // MARK: - Delegate Actions Tests
    
    @Test
    func settingsDelegateApiKeyChanged() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        store.exhaustivity = .off
        
        await store.send(.settingsButtonTapped) {
            $0.settings = SettingsFeature.State()
        }
        
        await store.send(.settings(.presented(.delegate(.apiKeyChanged)))) {
            $0.hasValidAPIKey = true
        }
    }
    
    @Test
    func recentComparisonsDelegateComparisonSelected() async {
        let comparison = ComparisonHistory(
            id: UUID(),
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            response: "Response text",
            date: Date(),
            isRead: false
        )
        
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        store.exhaustivity = .off
        
        await store.send(.recentComparisons(.delegate(.comparisonSelected(comparison)))) {
            $0.detail = ResponseDetailFeature.State(
                word1: "word1",
                word2: "word2",
                sentence: "This is a sentence",
                streamingResponse: "Response text",
                shouldStartStreaming: false
            )
            $0.detailPresentationToken = 1
        }
    }
    
    @Test
    func pathHistoryListDelegateComparisonSelected() async {
        let comparison = ComparisonHistory(
            id: UUID(),
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            response: "Response text",
            date: Date(),
            isRead: false
        )
        
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        store.exhaustivity = .off
        
        await store.send(.historyListButtonTapped) {
            $0.sidebarSelection = .history
            $0.historyList = ComparisonHistoryListFeature.State()
        }

        await store.send(.historyList(.delegate(.comparisonSelected(comparison)))) {
            $0.detail = ResponseDetailFeature.State(
                word1: "word1",
                word2: "word2",
                sentence: "This is a sentence",
                streamingResponse: "Response text",
                shouldStartStreaming: false
            )
            $0.detailPresentationToken = 1
        }
    }
    
    @Test
    func pathBackgroundTasksDelegateComparisonSelected() async {
        let comparison = ComparisonHistory(
            id: UUID(),
            word1: "word1",
            word2: "word2",
            sentence: "This is a sentence",
            response: "Response text",
            date: Date(),
            isRead: false
        )
        
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        store.exhaustivity = .off
        await store.send(.backgroundTasksButtonTapped) {
            $0.sidebarSelection = .backgroundTasks
            $0.backgroundTasks = BackgroundTasksFeature.State()
        }

        await store.send(.backgroundTasks(.delegate(.comparisonSelected(comparison)))) {
            $0.detail = ResponseDetailFeature.State(
                word1: "word1",
                word2: "word2",
                sentence: "This is a sentence",
                streamingResponse: "Response text",
                shouldStartStreaming: false
            )
            $0.detailPresentationToken = 1
        }
    }

    @Test
    func historySelectionAfterDetailDismissShowsNewDetail() async {
        let first = ComparisonHistory(
            id: UUID(),
            word1: "accept",
            word2: "except",
            sentence: "I accept all terms except this one.",
            response: "First response",
            date: Date(),
            isRead: false
        )
        let second = ComparisonHistory(
            id: UUID(),
            word1: "affect",
            word2: "effect",
            sentence: "The policy will affect the final effect.",
            response: "Second response",
            date: Date().addingTimeInterval(1),
            isRead: false
        )

        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        store.exhaustivity = .off

        await store.send(.historyListButtonTapped) {
            $0.sidebarSelection = .history
            $0.historyList = ComparisonHistoryListFeature.State()
        }

        await store.send(.historyList(.delegate(.comparisonSelected(first)))) {
            $0.detail = ResponseDetailFeature.State(
                word1: first.word1,
                word2: first.word2,
                sentence: first.sentence,
                streamingResponse: first.response,
                shouldStartStreaming: false
            )
            $0.detailPresentationToken = 1
        }

        await store.send(.detailDismissed) {
            $0.detail = nil
        }

        await store.send(.historyList(.delegate(.comparisonSelected(second)))) {
            $0.detail = ResponseDetailFeature.State(
                word1: second.word1,
                word2: second.word2,
                sentence: second.sentence,
                streamingResponse: second.response,
                shouldStartStreaming: false
            )
            $0.detailPresentationToken = 2
        }
    }
    
    // MARK: - Binding Actions Tests
    
    @Test
    func bindingWord1() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(\.binding.word1, "test word1") {
            $0.word1 = "test word1"
        }
    }
    
    @Test
    func bindingWord2() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(\.binding.word2, "test word2") {
            $0.word2 = "test word2"
        }
    }
    
    @Test
    func bindingSentence() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(\.binding.sentence, "This is a test sentence") {
            $0.sentence = "This is a test sentence"
        }
    }
    
    @Test
    func bindingMultipleFields() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(\.binding.word1, "word1") {
            $0.word1 = "word1"
        }
        await store.send(\.binding.word2, "word2") {
            $0.word2 = "word2"
        }
        await store.send(\.binding.sentence, "sentence") {
            $0.sentence = "sentence"
        }
        
        #expect(store.state.canGenerate == true)
    }
    
    // MARK: - Task Added Successfully Test
    
    @Test
    func taskAddedSuccessfully() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.backgroundTaskManager.addTask = { _, _, _ in }
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true, seed: seedBackgroundTasks(in:))
        }
        
        await store.send(.taskAddedSuccessfully)
    }
}
