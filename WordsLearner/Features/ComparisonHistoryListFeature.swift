//
//  ComparisonHistoryListFeature.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/21/25.
//

import ComposableArchitecture
import Foundation
import SQLiteData
import SwiftUI

@Reducer
struct ComparisonHistoryListFeature {
    @ObservableState
    struct State {
        @ObservationStateIgnored
        @Fetch(ComparisonsFetchKeyRequest(), animation: .default)
        var comparisons = ComparisonsFetchKeyRequest.Value()
        
        var searchText: String = ""
        var showUnreadOnly: Bool = false
        
        var filteredComparisons: [ComparisonHistory] {
            comparisons.comparisons
        }
        
        var allComparisons: [ComparisonHistory] {
            comparisons.allComparisons
        }
        
        @Presents var alert: AlertState<Action.Alert>?
    }
    
    enum Action {
        case comparisonTapped(ComparisonHistory)
        case deleteComparisons(IndexSet)
        case clearAllButtonTapped
        case textChanged(String)
        case filterToggled
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)
        
        enum Alert: Equatable {
            case clearAllConfirmed
        }
        
        enum Delegate: Equatable {
            case comparisonSelected(ComparisonHistory)
        }
    }
    
    @Dependency(\.defaultDatabase) var database
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .comparisonTapped(comparison):
                return .run { send in
                    await withErrorReporting {
                        try await database.write { db in
                            try ComparisonHistory
                                .where { $0.id == comparison.id }
                                .update { $0.isRead = true }
                                .execute(db)
                        }
                    }
                    await send(.delegate(.comparisonSelected(comparison)))
                }
            case let .deleteComparisons(indexSet):
                let comparisons = state.filteredComparisons
                return .run { send in
                    await withErrorReporting {
                        try await database.write { db in
                            let ids = indexSet.map { comparisons[$0].id }
                            try ComparisonHistory
                                .where { $0.id.in(ids) }
                                .delete()
                                .execute(db)
                        }
                    }
                }
                
            case .clearAllButtonTapped:
                state.alert = AlertState {
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
                return .none
                
            case .alert(.presented(.clearAllConfirmed)):
                return .run { send in
                    await withErrorReporting {
                        try await database.write { db in
                            try ComparisonHistory.delete().execute(db)
                        }
                    }
                }
            case let .textChanged(text):
                state.searchText = text
                return loadComparisons(state)
            case .filterToggled:
                state.showUnreadOnly.toggle()
                return loadComparisons(state)
            case .delegate:
                return .none
                
            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
    
    private func loadComparisons(_ state: State) -> Effect<Action> {
        return .run { [
            comparisons = state.$comparisons,
            showUnreadOnly = state.showUnreadOnly,
            searchText = state.searchText
        ] send in
            await loadComparisons(comparisons, showUnreadOnly: showUnreadOnly, searchText: searchText)
        }
    }
    
    private func loadComparisons(
        _ fetch: Fetch<ComparisonsFetchKeyRequest.Value>,
        showUnreadOnly: Bool,
        searchText: String) async {
            await withErrorReporting {
                await withErrorReporting {
                    try await fetch.load(
                        ComparisonsFetchKeyRequest(
                            searchText: searchText,
                            showUnreadOnly: showUnreadOnly
                        ),
                        animation: Animation.default
                    )
                }
            }
    }
}

// Separate Equatable conformance to work around @Fetch property wrapper limitation
extension ComparisonHistoryListFeature.State: Equatable {
    static func == (lhs: ComparisonHistoryListFeature.State, rhs: ComparisonHistoryListFeature.State) -> Bool {
        lhs.searchText == rhs.searchText &&
        lhs.showUnreadOnly == rhs.showUnreadOnly &&
        lhs.alert == rhs.alert
    }
}

struct ComparisonsFetchKeyRequest: FetchKeyRequest, Equatable {
    var searchText: String = ""
    var showUnreadOnly: Bool = false
    
    struct Value: Equatable {
        var comparisons: [ComparisonHistory] = []
        var allComparisons: [ComparisonHistory] = []
    }
    
    func fetch(_ db: Database) throws -> Value {
        var query = ComparisonHistory.order { $0.date.desc() }
        
        // Filter by search text
        if !searchText.isEmpty {
            query = query.where {
                $0.word1.contains(searchText) ||
                $0.word2.contains(searchText)
            }
        }
        
        // Filter by read status
        if showUnreadOnly {
            query = query.where { !$0.isRead }
        }
        
        return try Value(
            comparisons: query.fetchAll(db),
            allComparisons: ComparisonHistory.order { $0.date.desc() }.fetchAll(db)
        )
    }
}
