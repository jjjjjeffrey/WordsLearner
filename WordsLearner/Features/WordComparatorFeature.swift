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
    enum Path {
        case detail(ResponseDetailFeature)
        case historyList(ComparisonHistoryListFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        var word1: String = ""
        var word2: String = ""
        var sentence: String = ""
        var hasValidAPIKey: Bool = false
        
        var recentComparisons = RecentComparisonsFeature.State()
        
        var path = StackState<Path.State>()
        @Presents var settings: SettingsFeature.State?
        
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
        case historyListButtonTapped
        case path(StackActionOf<Path>)
        case settings(PresentationAction<SettingsFeature.Action>)
        case apiKeyStatusChanged(Bool)
        case recentComparisons(RecentComparisonsFeature.Action)
    }
    
    @Dependency(\.apiKeyManager) var apiKeyManager
    @Dependency(\.defaultDatabase) var database
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Scope(state: \.recentComparisons, action: \.recentComparisons) {
            RecentComparisonsFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.hasValidAPIKey = apiKeyManager.hasValidAPIKey()
                return .none
                
            case .settingsButtonTapped:
                state.settings = SettingsFeature.State()
                return .none
                
            case .generateButtonTapped:
                guard state.canGenerate && state.hasValidAPIKey else { return .none }
                state.path.append(.detail(
                    ResponseDetailFeature.State(
                        word1: state.word1,
                        word2: state.word2,
                        sentence: state.sentence
                    )
                ))
                return .none
                
            case .historyListButtonTapped:
                state.path.append(.historyList(ComparisonHistoryListFeature.State()))
                return .none
                
            case let .apiKeyStatusChanged(hasKey):
                state.hasValidAPIKey = hasKey
                return .none
                
            case .settings(.presented(.delegate(.apiKeyChanged))):
                state.hasValidAPIKey = apiKeyManager.hasValidAPIKey()
                return .none
                
            case let .recentComparisons(.delegate(.comparisonSelected(comparison))):
                state.word1 = comparison.word1
                state.word2 = comparison.word2
                state.sentence = comparison.sentence
                state.path.append(.detail(
                    ResponseDetailFeature.State(
                        word1: comparison.word1,
                        word2: comparison.word2,
                        sentence: comparison.sentence,
                        streamingResponse: comparison.response,
                        shouldStartStreaming: false
                    )
                ))
                return .none
                
            case let .path(action):
                switch action {
                case .element(id: _, action: .historyList(.delegate(.comparisonSelected(let comparison)))):
                    state.word1 = comparison.word1
                    state.word2 = comparison.word2
                    state.sentence = comparison.sentence
                    state.path.append(.detail(
                        ResponseDetailFeature.State(
                            word1: comparison.word1,
                            word2: comparison.word2,
                            sentence: comparison.sentence,
                            streamingResponse: comparison.response,
                            shouldStartStreaming: false
                        )
                    ))
                    return .none
                    
                default:
                    return .none


                }
                
            case .recentComparisons:
                return .none
            case .settings:
                return .none
            case .binding:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$settings, action: \.settings) {
            SettingsFeature()
        }
    }
}

extension WordComparatorFeature.Path.State: Equatable {}
