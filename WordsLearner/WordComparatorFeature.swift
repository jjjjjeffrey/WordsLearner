//
//  WordComparatorFeature.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/18/25.
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct WordComparatorFeature {
    
    @Reducer
    enum Destination {
        case detail(ResponseDetailFeature)
        case settings(SettingsFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        var word1: String = ""
        var word2: String = ""
        var sentence: String = ""
        var recentComparisons: [ComparisonHistory] = []
        var hasValidAPIKey: Bool = false
        
        @Presents var destination: Destination.State?
        
        var canGenerate: Bool {
            !word1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !word2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case generateButtonTapped
        case settingsButtonTapped
        case loadRecentComparison(UUID)
        case destination(PresentationAction<Destination.Action>)
        case recentComparisonsLoaded([ComparisonHistory])
        case apiKeyStatusChanged(Bool)
        case deleteComparisons(IndexSet)
    }
    
    @Dependency(\.apiKeyManager) var apiKeyManager
    @Dependency(\.database) var database
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.hasValidAPIKey = apiKeyManager.hasValidAPIKey()
                return .run { send in
                    // Load recent comparisons from database
                    let comparisons = try await loadRecentComparisons()
                    await send(.recentComparisonsLoaded(comparisons))
                    
                    // Optional: Migrate from UserDefaults on first launch
                    #if DEBUG
                    // You can manually trigger migration if needed
                    // try? database.migrateFromUserDefaults()
                    #endif
                }
                
            case .settingsButtonTapped:
                state.destination = .settings(SettingsFeature.State())
                return .none
                
            case .generateButtonTapped:
                guard state.canGenerate && state.hasValidAPIKey else { return .none }
                
                state.destination = .detail(
                    ResponseDetailFeature.State(
                        word1: state.word1,
                        word2: state.word2,
                        sentence: state.sentence
                    )
                )
                return .none
                
            case let .loadRecentComparison(id):
                guard let comparison = state.recentComparisons.first(where: { $0.id == id })
                else { return .none }
                
                state.word1 = comparison.word1
                state.word2 = comparison.word2
                state.sentence = comparison.sentence
                state.destination = .detail(
                    ResponseDetailFeature.State(
                        word1: comparison.word1,
                        word2: comparison.word2,
                        sentence: comparison.sentence,
                        streamingResponse: comparison.response,
                        shouldStartStreaming: false
                    )
                )
                return .none
                
            case let .recentComparisonsLoaded(comparisons):
                state.recentComparisons = comparisons
                return .none
                
            case let .apiKeyStatusChanged(hasKey):
                state.hasValidAPIKey = hasKey
                return .none
                
            case let .deleteComparisons(indexSet):
                return .run { [comparisons = state.recentComparisons] send in
                    try await deleteComparisons(at: indexSet, from: comparisons)
                    let updatedComparisons = try await loadRecentComparisons()
                    await send(.recentComparisonsLoaded(updatedComparisons))
                }
                
            case let .destination(.presented(.detail(.delegate(.comparisonCompleted(comparison))))):
                // Save to database
                return .run { send in
                    try await saveComparison(comparison)
                    let comparisons = try await loadRecentComparisons()
                    await send(.recentComparisonsLoaded(comparisons))
                }
                
            case .destination(.presented(.settings(.delegate(.apiKeyChanged)))):
                state.hasValidAPIKey = apiKeyManager.hasValidAPIKey()
                return .none
                
            case .destination:
                return .none
                
            case .binding:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    // MARK: - Database Operations
    
    private func loadRecentComparisons() async throws -> [ComparisonHistory] {
        try await database.read { db in
            try ComparisonHistory
                .order { $0.date.desc() }
                .limit(10)
                .fetchAll(db)
        }
    }
    
    private func saveComparison(_ comparison: ComparisonHistory) async throws {
        try await database.write { db in
            try ComparisonHistory.insert {
                ComparisonHistory.Draft(
                    id: comparison.id,
                    word1: comparison.word1,
                    word2: comparison.word2,
                    sentence: comparison.sentence,
                    response: comparison.response,
                    date: comparison.date
                )
            }
            .execute(db)
        }
    }
    
    private func deleteComparisons(at indexSet: IndexSet, from comparisons: [ComparisonHistory]) async throws {
        try await database.write { db in
            let ids = indexSet.map { comparisons[$0].id }
            try ComparisonHistory
                .where { $0.id.in(ids) }
                .delete()
                .execute(db)
        }
    }
}

extension WordComparatorFeature.Destination.State: Equatable {}
