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
    @Test
    func canGenerateWithEmptyAndValidInputs() async {
        let store = TestStore(initialState: WordComparatorFeature.State()) {
            WordComparatorFeature()
        } withDependencies: {
            $0.apiKeyManager = .testValue
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.generateButtonTapped) {
            $0.path.append(.detail(
                ResponseDetailFeature.State(
                    word1: "word1",
                    word2: "word2",
                    sentence: "This is a sentence"
                )
            ))
        }
        
        await store.receive(\.clearInputFields) {
            $0.word1 = ""
            $0.word2 = ""
            $0.sentence = ""
        }
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
        }
        
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
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.recentComparisons(.delegate(.comparisonSelected(comparison)))) {
            $0.path.append(.detail(
                ResponseDetailFeature.State(
                    word1: "word1",
                    word2: "word2",
                    sentence: "This is a sentence",
                    streamingResponse: "Response text",
                    shouldStartStreaming: false
                )
            ))
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
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.historyListButtonTapped) {
            $0.path.append(.historyList(ComparisonHistoryListFeature.State()))
        }
        
        // Get the path ID from the state
        let pathId = store.state.path.ids.first!
        
        await store.send(.path(.element(id: pathId, action: .historyList(.delegate(.comparisonSelected(comparison)))))) {
            $0.path.append(.detail(
                ResponseDetailFeature.State(
                    word1: "word1",
                    word2: "word2",
                    sentence: "This is a sentence",
                    streamingResponse: "Response text",
                    shouldStartStreaming: false
                )
            ))
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
            try! $0.bootstrapDatabase(useTest: true)
        }
        await store.send(.backgroundTasksButtonTapped) {
            $0.path.append(.backgroundTasks(BackgroundTasksFeature.State()))
        }
        // Get the path ID from the state
        let pathId = store.state.path.ids.first!
        
        await store.send(.path(.element(id: pathId, action: .backgroundTasks(.delegate(.comparisonSelected(comparison)))))) {
            $0.path.append(.detail(
                ResponseDetailFeature.State(
                    word1: "word1",
                    word2: "word2",
                    sentence: "This is a sentence",
                    streamingResponse: "Response text",
                    shouldStartStreaming: false
                )
            ))
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
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
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.taskAddedSuccessfully)
    }
}




