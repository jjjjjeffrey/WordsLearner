//
//  RecentComparisonsFeatureTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/8/26.
//

import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import WordsLearner

@MainActor
struct RecentComparisonsFeatureTests {
    
    // MARK: - Initial State Tests
    @Test
    func initialState_defaults() async throws {
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.onAppear)
        #expect(store.state.recentComparisons.count == 10)
        #expect(store.state.searchText == "")
        #expect(store.state.isLoading == false)
    }
    
    // MARK: - comparisonTapped Action Tests
    
    @Test
    func comparisonTapped_marksReadAndSendsDelegate() async throws {
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        #expect(store.state.recentComparisons.count == 10)
        
        // Most recent should be the one with the later date
        let tapped = store.state.recentComparisons[0]
        #expect(tapped.isRead == false)
        await store.send(.comparisonTapped(tapped))
        await store.finish(timeout: 200)
        await store.receive(.delegate(.comparisonSelected(tapped)))
        #expect(store.state.recentComparisons[0].isRead == true)
        #expect(store.state.recentComparisons[1].isRead == false)
    }
    
    // MARK: - deleteComparisons Action Tests
    
    @Test
    func deleteComparisons_singleIndex_deletesFromDatabase() async throws {
        
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        #expect(store.state.recentComparisons.count == 10)
        
        let toDeleteId = store.state.recentComparisons[0].id
        await store.send(.deleteComparisons(IndexSet(integer: 0)))
        await store.finish()
        
        #expect(!store.state.recentComparisons.contains(where: { $0.id == toDeleteId }))
        #expect(store.state.recentComparisons.count == 10)
    }
    
    @Test
    func deleteComparisons_multipleIndices_deletesFromDatabase() async throws {
        
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        #expect(store.state.recentComparisons.count == 10)
        
        let ids = store.state.recentComparisons.map(\.id)
        let toDelete = IndexSet([0, 1, 2, 3, 4, 5, 6])
        let deletedIds = [ids[0], ids[1], ids[2], ids[3], ids[4], ids[5], ids[6]]
        
        await store.send(.deleteComparisons(toDelete))
        await store.finish()
        
        #expect(!store.state.recentComparisons.contains(where: { $0.id == deletedIds[0] }))
        #expect(!store.state.recentComparisons.contains(where: { $0.id == deletedIds[1] }))
        #expect(!store.state.recentComparisons.contains(where: { $0.id == deletedIds[2] }))
        #expect(!store.state.recentComparisons.contains(where: { $0.id == deletedIds[3] }))
        #expect(!store.state.recentComparisons.contains(where: { $0.id == deletedIds[4] }))
        #expect(!store.state.recentComparisons.contains(where: { $0.id == deletedIds[5] }))
        #expect(!store.state.recentComparisons.contains(where: { $0.id == deletedIds[6] }))
        #expect(store.state.recentComparisons.count == 8)
    }
    
    @Test
    func deleteComparisons_emptyIndexSet_noop() async throws {
        
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.onAppear)
        #expect(store.state.recentComparisons.count == 10)
        
        let initialCount = store.state.recentComparisons.count
        await store.send(.deleteComparisons(IndexSet()))
        await store.finish()
        
        #expect(store.state.recentComparisons.count == initialCount)
    }
    
    // MARK: - Clear All Tests
    
    @Test
    func clearAllButtonTapped_noStateChange() async throws {
        
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.onAppear)
        await store.send(.clearAllButtonTapped)
        #expect(store.state.searchText == "")
        #expect(store.state.isLoading == false)
    }
    
    @Test
    func clearAllConfirmed_deletesAllRows() async throws {
        
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.onAppear)
        #expect(store.state.recentComparisons.count == 10)
        
        await store.send(.clearAllConfirmed)
        await store.finish()
        
        #expect(store.state.recentComparisons.isEmpty)
    }
    
    @Test
    func clearAllConfirmed_emptyDatabase_noop() async throws {
        
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.onAppear)
        #expect(store.state.recentComparisons.count == 10)
        
        await store.send(.clearAllConfirmed)
        await store.finish()
        
        #expect(store.state.recentComparisons.isEmpty)
        
        await store.send(.clearAllConfirmed)
        await store.finish()
        
        #expect(store.state.recentComparisons.isEmpty)
    }
    
    // MARK: - Binding Action Tests
    
    @Test
    func binding_searchText() async throws {
        
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.onAppear)
        await store.send(\.binding.searchText, "hello") {
            $0.searchText = "hello"
        }
    }
    
    @Test
    func binding_isLoading() async throws {
        
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.onAppear)
        await store.send(\.binding.isLoading, true) {
            $0.isLoading = true
        }
    }
    
    // MARK: - Delegate Action Tests
    
    @Test
    func delegateAction_noStateChange() async throws {
        
        let comparison = ComparisonHistory(
            id: UUID(),
            word1: "w1",
            word2: "w2",
            sentence: "s",
            response: "r",
            date: Date(),
            isRead: false
        )
        
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.onAppear)
        await store.send(.delegate(.comparisonSelected(comparison)))
    }
    
    // MARK: - Database Integration Tests
    
    @Test
    func fetchAll_respectsOrdering_descByDate() async throws {
        
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.onAppear)
        #expect(store.state.recentComparisons.count == 10)
        
        #expect(store.state.recentComparisons[0].word1 == "affect")
        #expect(store.state.recentComparisons[1].word1 == "compliment")
    }
    
    @Test
    func fetchAll_respectsLimit_10() async throws {
        
        let store = TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
        
        await store.send(.onAppear)
        #expect(store.state.recentComparisons.count == 10)
        
        // Verify we got the 10 most recent by date (i.e. 14 down to 5).
        let words = store.state.recentComparisons.map(\.word1)
        #expect(words.first == "affect")
        #expect(words.last == "fewer")
    }
}

