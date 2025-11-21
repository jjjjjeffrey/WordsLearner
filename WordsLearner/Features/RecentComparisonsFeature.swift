//
//  RecentComparisonsFeature.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/21/25.
//

import ComposableArchitecture
import Foundation
import SQLiteData
import SwiftUI

@Reducer
struct RecentComparisonsFeature {
    @ObservableState
    struct State: Equatable {
        @ObservationStateIgnored
        @FetchAll(
            ComparisonHistory
                .order { $0.date.desc() }
                .limit(10),
            animation: .default
        )
        var recentComparisons: [ComparisonHistory] = []
        
        var searchText: String = ""
        var isLoading: Bool = false
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case comparisonTapped(ComparisonHistory)
        case deleteComparisons(IndexSet)
        case clearAllButtonTapped
        case clearAllConfirmed
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case comparisonSelected(ComparisonHistory)
        }
    }
    
    @Dependency(\.defaultDatabase) var database
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
                
            case let .comparisonTapped(comparison):
                return .send(.delegate(.comparisonSelected(comparison)))
                
            case let .deleteComparisons(indexSet):
                return .run { [comparisons = state.recentComparisons] send in
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
                // Will trigger alert in the view
                return .none
                
            case .clearAllConfirmed:
                return .run { send in
                    await withErrorReporting {
                        try await database.write { db in
                            try ComparisonHistory.delete().execute(db)
                        }
                    }
                }
                
            case .delegate:
                return .none
                
            case .binding:
                return .none
            }
        }
    }
}
