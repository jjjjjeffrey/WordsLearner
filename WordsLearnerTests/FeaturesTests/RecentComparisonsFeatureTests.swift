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
@Suite(
    .dependency(\.date.now, Date(timeIntervalSince1970: 1_234_567_890))
)
struct RecentComparisonsFeatureTests {
    
    // MARK: - Helpers
    
    private let seedBaseDate = Date(timeIntervalSince1970: 1_700_000_000)
    
    private func seedComparisonHistories(in db: Database) throws {
        let now = seedBaseDate
        try db.seed {
            ComparisonHistory.Draft(
                word1: "character",
                word2: "characteristic",
                sentence: "The character of this wine is unique.",
                response: "Test response...",
                date: now.addingTimeInterval(-3600),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "affect",
                word2: "effect",
                sentence: "How does this affect the result?",
                response: "Another test response...",
                date: now,
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "emigrate",
                word2: "immigrate",
                sentence: "Many people emigrate to find better opportunities.",
                response: "A migrated test response...",
                date: now.addingTimeInterval(-7200),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "infer",
                word2: "imply",
                sentence: "What do you infer from her words?",
                response: "Implied answer test...",
                date: now.addingTimeInterval(-10800),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "stationary",
                word2: "stationery",
                sentence: "The bike remained stationary.",
                response: "More comparison data...",
                date: now.addingTimeInterval(-14400),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "compliment",
                word2: "complement",
                sentence: "She gave me a sincere compliment on my presentation.",
                response: "Used 'compliment' for praise; 'complement' means completes/ pairs well.",
                date: now.addingTimeInterval(-1800),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "principal",
                word2: "principle",
                sentence: "The principal announced a new school policy today.",
                response: "'Principal' is a person or main thing; 'principle' is a rule or belief.",
                date: now.addingTimeInterval(-5400),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "its",
                word2: "it's",
                sentence: "The company updated its privacy policy last week.",
                response: "'Its' is possessive; 'it's' means 'it is' or 'it has'.",
                date: now.addingTimeInterval(-9000),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "then",
                word2: "than",
                sentence: "Finish your tasks, then we can go for coffee.",
                response: "'Then' relates to time/sequence; 'than' is used for comparisons.",
                date: now.addingTimeInterval(-12600),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "fewer",
                word2: "less",
                sentence: "This checkout line has fewer people than the other one.",
                response: "Use 'fewer' for countable items; 'less' for uncountable amounts.",
                date: now.addingTimeInterval(-16200),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "discreet",
                word2: "discrete",
                sentence: "Please be discreet about the surprise party plans.",
                response: "'Discreet' = careful/private; 'discrete' = separate/distinct.",
                date: now.addingTimeInterval(-19800),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "ensure",
                word2: "insure",
                sentence: "Double-check the settings to ensure the backup completes successfully.",
                response: "'Ensure' = make certain; 'insure' = provide insurance; 'assure' = reassure someone.",
                date: now.addingTimeInterval(-23400),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "lay",
                word2: "lie",
                sentence: "I need to lie down for a few minutes.",
                response: "'Lie' = recline (no object); 'lay' = place something (needs an object).",
                date: now.addingTimeInterval(-27000),
                isRead: true
            )
            ComparisonHistory.Draft(
                word1: "allude",
                word2: "elude",
                sentence: "He alluded to a bigger announcement coming next month.",
                response: "'Allude' = refer indirectly; 'elude' = evade/escape or be difficult to remember.",
                date: now.addingTimeInterval(-30600),
                isRead: false
            )
            ComparisonHistory.Draft(
                word1: "council",
                word2: "counsel",
                sentence: "The city council voted on the new zoning proposal.",
                response: "'Council' = a governing group; 'counsel' = advice or a lawyer.",
                date: now.addingTimeInterval(-34200),
                isRead: true
            )
        }
    }
    
    private func makeStore(
        seed: ((Database) throws -> Void)? = nil
    ) -> TestStoreOf<RecentComparisonsFeature> {
        TestStore(initialState: RecentComparisonsFeature.State()) {
            RecentComparisonsFeature()
        } withDependencies: {
            let seed = seed ?? seedComparisonHistories(in:)
            try! $0.bootstrapDatabase(useTest: true, seed: seed)
        }
    }
    
    // MARK: - Initial State Tests
    @Test
    func initialState_defaults() async throws {
        let store = makeStore()
        
        await store.send(.onAppear)
        #expect(store.state.recentComparisons.count == 10)
        #expect(store.state.searchText == "")
        #expect(store.state.isLoading == false)
    }
    
    // MARK: - comparisonTapped Action Tests
    
    @Test
    func comparisonTapped_marksReadAndSendsDelegate() async throws {
        @Dependency(\.date.now) var now
        let store = makeStore(seed: { db in
            try db.seed {
                ComparisonHistory(
                    id: UUID(),
                    word1: "accept",
                    word2: "except",
                    sentence: "I accept all terms except the final clause.",
                    response: "Use 'accept' for receive/agree, 'except' for excluding.",
                    date: now,
                    isRead: false
                )
                ComparisonHistory(
                    id: UUID(),
                    word1: "affect",
                    word2: "effect",
                    sentence: "How does this affect the final effect?",
                    response: "'Affect' is usually a verb; 'effect' is usually a noun.",
                    date: now.addingTimeInterval(-3600),
                    isRead: false
                )
            }
        })
        
        #expect(store.state.recentComparisons.count == 2)
        
        // Most recent should be the one with the later date
        let tapped = store.state.recentComparisons[0]
        #expect(tapped.isRead == false)
        await store.send(.comparisonTapped(tapped))
        await store.finish()
        await store.receive(.delegate(.comparisonSelected(tapped)))
        #expect(store.state.recentComparisons[0].isRead == true)
        #expect(store.state.recentComparisons[1].isRead == false)
    }
    
    // MARK: - deleteComparisons Action Tests
    
    @Test
    func deleteComparisons_singleIndex_deletesFromDatabase() async throws {
        
        let store = makeStore()
        
        #expect(store.state.recentComparisons.count == 10)
        
        let toDeleteId = store.state.recentComparisons[0].id
        await store.send(.deleteComparisons(IndexSet(integer: 0)))
        await store.finish()
        
        #expect(!store.state.recentComparisons.contains(where: { $0.id == toDeleteId }))
        #expect(store.state.recentComparisons.count == 10)
    }
    
    @Test
    func deleteComparisons_multipleIndices_deletesFromDatabase() async throws {
        
        let store = makeStore()
        
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
        
        let store = makeStore()
        
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
        
        let store = makeStore()
        
        await store.send(.onAppear)
        await store.send(.clearAllButtonTapped)
        #expect(store.state.searchText == "")
        #expect(store.state.isLoading == false)
    }
    
    @Test
    func clearAllConfirmed_deletesAllRows() async throws {
        
        let store = makeStore()
        
        await store.send(.onAppear)
        #expect(store.state.recentComparisons.count == 10)
        
        await store.send(.clearAllConfirmed)
        await store.finish()
        
        #expect(store.state.recentComparisons.isEmpty)
    }
    
    @Test
    func clearAllConfirmed_emptyDatabase_noop() async throws {
        
        let store = makeStore()
        
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
        
        let store = makeStore()
        
        await store.send(.onAppear)
        await store.send(\.binding.searchText, "hello") {
            $0.searchText = "hello"
        }
    }
    
    @Test
    func binding_isLoading() async throws {
        
        let store = makeStore()
        
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
        
        let store = makeStore()
        
        await store.send(.onAppear)
        await store.send(.delegate(.comparisonSelected(comparison)))
    }
    
    // MARK: - Database Integration Tests
    
    @Test
    func fetchAll_respectsOrdering_descByDate() async throws {
        
        let store = makeStore()
        
        await store.send(.onAppear)
        #expect(store.state.recentComparisons.count == 10)
        
        #expect(store.state.recentComparisons[0].word1 == "affect")
        #expect(store.state.recentComparisons[1].word1 == "compliment")
    }
    
    @Test
    func fetchAll_respectsLimit_10() async throws {
        
        let store = makeStore()
        
        await store.send(.onAppear)
        #expect(store.state.recentComparisons.count == 10)
        
        // Verify we got the 10 most recent by date (i.e. 14 down to 5).
        let words = store.state.recentComparisons.map(\.word1)
        #expect(words.first == "affect")
        #expect(words.last == "fewer")
    }
}
