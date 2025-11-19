//
//  WordComparatorFeature.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/18/25.
//

import ComposableArchitecture
import Foundation

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
        var recentComparisons: IdentifiedArrayOf<ComparisonHistory> = []
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
        case recentComparisonsLoaded(IdentifiedArrayOf<ComparisonHistory>)
        case apiKeyStatusChanged(Bool)
    }
    
    @Dependency(\.apiKeyManager) var apiKeyManager
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.hasValidAPIKey = apiKeyManager.hasValidAPIKey()
                return .run { send in
                    let comparisons = loadRecentComparisonsFromUserDefaults()
                    await send(.recentComparisonsLoaded(comparisons))
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
                guard let comparison = state.recentComparisons[id: id] else { return .none }
                
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
                
            case let .destination(.presented(.detail(.delegate(.comparisonCompleted(comparison))))):
                state.recentComparisons.insert(comparison, at: 0)
                if state.recentComparisons.count > 10 {
                    state.recentComparisons.removeLast()
                }
                return .run { [recentComparisons = state.recentComparisons] send in
                    saveRecentComparisonsToUserDefaults(recentComparisons)
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
}

extension WordComparatorFeature.Destination.State: Equatable {}

// MARK: - Helper Functions

private func loadRecentComparisonsFromUserDefaults() -> IdentifiedArrayOf<ComparisonHistory> {
    if let data = UserDefaults.standard.data(forKey: "RecentComparisons"),
       let comparisons = try? JSONDecoder().decode(IdentifiedArrayOf<ComparisonHistory>.self, from: data) {
        return comparisons
    }
    return []
}

private func saveRecentComparisonsToUserDefaults(_ comparisons: IdentifiedArrayOf<ComparisonHistory>) {
    if let data = try? JSONEncoder().encode(comparisons) {
        UserDefaults.standard.set(data, forKey: "RecentComparisons")
    }
}



