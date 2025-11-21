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
    struct State: Equatable {
        @ObservationStateIgnored
        @FetchAll(
            ComparisonHistory
                .order { $0.date.desc() },
            animation: .default
        )
        var allComparisons: [ComparisonHistory] = []
        
        var searchText: String = ""
        
        var filteredComparisons: [ComparisonHistory] {
            if searchText.isEmpty {
                return allComparisons
            }
            let lowercasedSearch = searchText.lowercased()
            return allComparisons.filter {
                $0.word1.lowercased().contains(lowercasedSearch) ||
                $0.word2.lowercased().contains(lowercasedSearch) ||
                $0.sentence.lowercased().contains(lowercasedSearch)
            }
        }
        
        @Presents var alert: AlertState<Action.Alert>?
    }
    
    enum Action {
        case comparisonTapped(ComparisonHistory)
        case deleteComparisons(IndexSet)
        case clearAllButtonTapped
        case textChanged(String)
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
                return .send(.delegate(.comparisonSelected(comparison)))
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
            case .textChanged:
                return .none
                
            case .delegate:
                return .none
                
            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
