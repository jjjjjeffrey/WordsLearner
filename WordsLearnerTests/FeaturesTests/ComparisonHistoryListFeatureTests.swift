//
//  ComparisonHistoryListFeatureTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/13/26.
//

import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import WordsLearner

@MainActor
struct ComparisonHistoryListFeatureTests {
    
    // MARK: - Helpers
    
    private func makeStore() -> TestStoreOf<ComparisonHistoryListFeature> {
        TestStore(initialState: ComparisonHistoryListFeature.State()) {
            ComparisonHistoryListFeature()
        } withDependencies: {
            try! $0.bootstrapDatabase(useTest: true)
        }
    }
    
    // MARK: - Initial State Tests
    
    @Test
    func initialState_defaultsAndLoadsSeedData() async throws {
        let store = makeStore()
        
        // Force the initial @Fetch load to run deterministically in tests.
        await store.send(.textChanged(""))
        await store.finish()
        
        #expect(store.state.searchText == "")
        #expect(store.state.showUnreadOnly == false)
        
        // Seed data in DatabaseConfiguration.swift inserts 15 ComparisonHistory rows.
        #expect(store.state.allComparisons.count == 15)
        #expect(store.state.filteredComparisons.count == 15)
        
        // Ordering should be descending by date (most recent first).
        #expect(store.state.filteredComparisons.first?.word1 == "affect")
        #expect(store.state.filteredComparisons.dropFirst().first?.word1 == "compliment")
    }
    
    // MARK: - comparisonTapped Action Tests
    
    @Test
    func comparisonTapped_marksReadAndSendsDelegate() async throws {
        let store = makeStore()
        
        await store.send(.textChanged(""))
        await store.finish()
        
        let tapped = store.state.filteredComparisons[0]
        #expect(tapped.word1 == "affect")
        #expect(tapped.isRead == false)
        
        await store.send(.comparisonTapped(tapped))
        await store.finish()
        await store.receive(.delegate(.comparisonSelected(tapped)))
        
        let updated = try #require(store.state.filteredComparisons.first(where: { $0.id == tapped.id }))
        #expect(updated.isRead == true)
    }
    
    // MARK: - deleteComparisons Action Tests
    
    @Test
    func deleteComparisons_singleIndex_deletesFromDatabase() async throws {
        let store = makeStore()
        
        await store.send(.textChanged(""))
        await store.finish()
        
        #expect(store.state.filteredComparisons.count == 15)
        let toDeleteId = store.state.filteredComparisons[0].id
        
        await store.send(.deleteComparisons(IndexSet(integer: 0)))
        await store.finish()
        
        #expect(store.state.filteredComparisons.count == 14)
        #expect(!store.state.filteredComparisons.contains(where: { $0.id == toDeleteId }))
        #expect(store.state.allComparisons.count == 14)
    }
    
    @Test
    func deleteComparisons_multipleIndices_deletesFromDatabase() async throws {
        let store = makeStore()
        
        await store.send(.textChanged(""))
        await store.finish()
        
        let ids = store.state.filteredComparisons.map(\.id)
        let toDelete = IndexSet([0, 1, 2, 3, 4, 5, 6])
        let deletedIds = [ids[0], ids[1], ids[2], ids[3], ids[4], ids[5], ids[6]]
        
        await store.send(.deleteComparisons(toDelete))
        await store.finish()
        
        #expect(store.state.filteredComparisons.count == 8)
        #expect(store.state.allComparisons.count == 8)
        #expect(!store.state.filteredComparisons.contains(where: { deletedIds.contains($0.id) }))
    }
    
    @Test
    func deleteComparisons_emptyIndexSet_noop() async throws {
        let store = makeStore()
        
        await store.send(.textChanged(""))
        await store.finish()
        
        let initialCount = store.state.filteredComparisons.count
        
        await store.send(.deleteComparisons(IndexSet()))
        await store.finish()
        
        #expect(store.state.filteredComparisons.count == initialCount)
        #expect(store.state.allComparisons.count == initialCount)
    }
    
    // MARK: - Clear All Tests
    
    @Test
    func clearAllButtonTapped_setsAlert() async throws {
        let store = makeStore()
        
        await store.send(.textChanged(""))
        await store.finish()
        
        await store.send(.clearAllButtonTapped) {
            $0.alert = AlertState {
                TextState("Clear All History?")
            } actions: {
                ButtonState(role: .destructive, action: .clearAllConfirmed) {
                    TextState("Clear All")
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            } message: {
                TextState("This will delete all comparison history. This action cannot be undone.")
            }
        }
    }
    
    @Test
    func clearAllConfirmed_deletesAllRows() async throws {
        let store = makeStore()
        
        await store.send(.textChanged(""))
        await store.finish()
        #expect(store.state.allComparisons.count == 15)
        
        await store.send(.clearAllButtonTapped) {
            $0.alert = AlertState {
                TextState("Clear All History?")
            } actions: {
                ButtonState(role: .destructive, action: .clearAllConfirmed) {
                    TextState("Clear All")
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            } message: {
                TextState("This will delete all comparison history. This action cannot be undone.")
            }
        }
        
        await store.send(.alert(.presented(.clearAllConfirmed))) {
            $0.alert = nil
        }
        await store.finish()
        
        #expect(store.state.allComparisons.isEmpty)
        #expect(store.state.filteredComparisons.isEmpty)
    }
    
    @Test
    func clearAllConfirmed_emptyDatabase_noop() async throws {
        let store = makeStore()
        
        await store.send(.textChanged(""))
        await store.finish()
        
        await store.send(.clearAllButtonTapped) {
            $0.alert = AlertState {
                TextState("Clear All History?")
            } actions: {
                ButtonState(role: .destructive, action: .clearAllConfirmed) {
                    TextState("Clear All")
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            } message: {
                TextState("This will delete all comparison history. This action cannot be undone.")
            }
        }
        await store.send(.alert(.presented(.clearAllConfirmed))) {
            $0.alert = nil
        }
        await store.finish()
        #expect(store.state.allComparisons.isEmpty)
    }
    
    // MARK: - Search Filtering Tests (textChanged)
    
    @Test
    func textChanged_filtersByWord1() async throws {
        let store = makeStore()
        
        await store.send(.textChanged("affect")) {
            $0.searchText = "affect"
        }
        await store.finish()
        
        #expect(store.state.filteredComparisons.count == 1)
        #expect(store.state.filteredComparisons.first?.word1 == "affect")
        #expect(store.state.allComparisons.count == 15)
    }
    
    @Test
    func textChanged_filtersByWord2() async throws {
        let store = makeStore()
        
        await store.send(.textChanged("effect")) {
            $0.searchText = "effect"
        }
        await store.finish()
        
        #expect(store.state.filteredComparisons.count == 1)
        #expect(store.state.filteredComparisons.first?.word1 == "affect")
        #expect(store.state.filteredComparisons.first?.word2 == "effect")
        #expect(store.state.allComparisons.count == 15)
    }
    
    @Test
    func textChanged_noMatches_returnsEmpty() async throws {
        let store = makeStore()
        
        await store.send(.textChanged("zzzz-does-not-exist")) {
            $0.searchText = "zzzz-does-not-exist"
        }
        await store.finish()
        
        #expect(store.state.filteredComparisons.isEmpty)
        #expect(store.state.allComparisons.count == 15)
    }
    
    @Test
    func textChanged_clearingSearch_restoresAllResults() async throws {
        let store = makeStore()
        
        await store.send(.textChanged("affect")) {
            $0.searchText = "affect"
        }
        await store.finish()
        #expect(store.state.filteredComparisons.count == 1)
        
        await store.send(.textChanged("")) {
            $0.searchText = ""
        }
        await store.finish()
        
        #expect(store.state.filteredComparisons.count == 15)
        #expect(store.state.allComparisons.count == 15)
    }
    
    // MARK: - Unread Filtering Tests (filterToggled)
    
    @Test
    func filterToggled_showsUnreadOnly_thenShowsAll() async throws {
        let store = makeStore()
        
        await store.send(.textChanged(""))
        await store.finish()
        
        await store.send(.filterToggled) {
            $0.showUnreadOnly = true
        }
        await store.finish()
        
        #expect(store.state.filteredComparisons.count == 8)
        #expect(store.state.filteredComparisons.allSatisfy { !$0.isRead })
        #expect(store.state.allComparisons.count == 15)
        
        await store.send(.filterToggled) {
            $0.showUnreadOnly = false
        }
        await store.finish()
        
        #expect(store.state.filteredComparisons.count == 15)
    }
    
    // MARK: - Combined Filtering Tests
    
    @Test
    func searchAndUnreadFilter_combined() async throws {
        let store = makeStore()
        
        // "infer" is seeded with isRead == true, so it should disappear under unread-only filter.
        await store.send(.textChanged("infer")) {
            $0.searchText = "infer"
        }
        await store.finish()
        #expect(store.state.filteredComparisons.count == 1)
        #expect(store.state.filteredComparisons.first?.word1 == "infer")
        #expect(store.state.filteredComparisons.first?.isRead == true)
        
        await store.send(.filterToggled) {
            $0.showUnreadOnly = true
        }
        await store.finish()
        
        #expect(store.state.filteredComparisons.isEmpty)
        #expect(store.state.allComparisons.count == 15)
        
        await store.send(.filterToggled) {
            $0.showUnreadOnly = false
        }
        await store.finish()
        
        #expect(store.state.filteredComparisons.count == 1)
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
        
        let store = makeStore()
        
        await store.send(.delegate(.comparisonSelected(comparison)))
    }
    
    // MARK: - Database Integration Tests
    
    @Test
    func allComparisons_isUnfiltered_evenWhenSearchAndUnreadApplied() async throws {
        let store = makeStore()
        
        await store.send(.textChanged("affect")) {
            $0.searchText = "affect"
        }
        await store.finish()
        #expect(store.state.filteredComparisons.count == 1)
        #expect(store.state.allComparisons.count == 15)
        
        await store.send(.filterToggled) {
            $0.showUnreadOnly = true
        }
        await store.finish()
        #expect(store.state.filteredComparisons.count == 1)
        #expect(store.state.allComparisons.count == 15)
    }
}

