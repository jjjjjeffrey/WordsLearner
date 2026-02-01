//
//  WordComparatorFeature.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/18/25.
//

import ComposableArchitecture
import Foundation
import SQLiteData
import SwiftUI

@MainActor
@Reducer
struct WordComparatorFeature {
    
    @MainActor
    @Reducer
    enum Path {
        @CasePathable
        @dynamicMemberLookup
        @ObservableState
        enum State {
            typealias StateReducer = Path
            
            case detail(ResponseDetailFeature.State)
            case historyList(ComparisonHistoryListFeature.State)
            case backgroundTasks(BackgroundTasksFeature.State)
        }
        
        @CasePathable
        enum Action {
            case detail(ResponseDetailFeature.Action)
            case historyList(ComparisonHistoryListFeature.Action)
            case backgroundTasks(BackgroundTasksFeature.Action)
        }
        
        case detail(ResponseDetailFeature)
        case historyList(ComparisonHistoryListFeature)
        case backgroundTasks(BackgroundTasksFeature)
    }

    @ObservableState
    struct State: Equatable {
        var word1: String = ""
        var word2: String = ""
        var sentence: String = ""
        var hasValidAPIKey: Bool = false
        
        // For observing background tasks in the main view
        @ObservationStateIgnored
        @FetchAll(
            BackgroundTask
                .where { $0.status == BackgroundTask.Status.pending.rawValue },
            animation: .default
        )
        var pendingTasks: [BackgroundTask] = []
        
        var recentComparisons = RecentComparisonsFeature.State()
        
        var path = StackState<Path.State>()
        @Presents var settings: SettingsFeature.State?
        @Presents var alert: AlertState<Action.Alert>?
        
        var canGenerate: Bool {
            !word1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !word2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        var pendingTasksCount: Int {
            pendingTasks.count
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case generateButtonTapped
        case generateInBackgroundButtonTapped
        case settingsButtonTapped
        case historyListButtonTapped
        case backgroundTasksButtonTapped
        case path(StackActionOf<Path>)
        case settings(PresentationAction<SettingsFeature.Action>)
        case recentComparisons(RecentComparisonsFeature.Action)
        case alert(PresentationAction<Alert>)
        case clearInputFields
        case taskAddedSuccessfully
        
        enum Alert: Equatable {
            case taskQueued(Int)
        }
    }
    
    private var apiKeyManager: APIKeyManagerClient { DependencyValues._current.apiKeyManager }
    private var taskManager: BackgroundTaskManagerClient { DependencyValues._current.backgroundTaskManager }
    
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
                
            case .backgroundTasksButtonTapped:
                state.path.append(.backgroundTasks(BackgroundTasksFeature.State()))
                return .none
                
            case .generateButtonTapped:
                guard state.canGenerate && state.hasValidAPIKey else { return .none }
                
                let word1 = state.word1
                let word2 = state.word2
                let sentence = state.sentence
                
                state.path.append(.detail(
                    ResponseDetailFeature.State(
                        word1: word1,
                        word2: word2,
                        sentence: sentence
                    )
                ))
                
                return .send(.clearInputFields)
                
            case .generateInBackgroundButtonTapped:
                guard state.canGenerate && state.hasValidAPIKey else { return .none }
                
                let word1 = state.word1
                let word2 = state.word2
                let sentence = state.sentence
                
                return .run { send in
                    do {
                        try await taskManager.addTask(word1, word2, sentence)
                        await send(.taskAddedSuccessfully)
                        await send(.clearInputFields)
                    } catch {
                        print("Failed to add task: \(error)")
                    }
                }
                
            case .taskAddedSuccessfully:
                return .none
                
            case .clearInputFields:
                state.word1 = ""
                state.word2 = ""
                state.sentence = ""
                return .none
                
            case .historyListButtonTapped:
                state.path.append(.historyList(ComparisonHistoryListFeature.State()))
                return .none
                
            case .settings(.presented(.delegate(.apiKeyChanged))):
                state.hasValidAPIKey = apiKeyManager.hasValidAPIKey()
                return .none
                
            case let .recentComparisons(.delegate(.comparisonSelected(comparison))):
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
                    
                case .element(id: _, action: .backgroundTasks(.delegate(.comparisonSelected(let comparison)))):
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
                
            case .alert:
                return .none
                
            case .binding:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$settings, action: \.settings) {
            SettingsFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension WordComparatorFeature.Path.State: @MainActor CaseReducerState {}

extension WordComparatorFeature.Path.State: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.detail(let lhsState), .detail(let rhsState)):
            return lhsState == rhsState
        case (.historyList(let lhsState), .historyList(let rhsState)):
            // Compare only equatable properties, ignoring @Fetch
            return lhsState.searchText == rhsState.searchText &&
                   lhsState.showUnreadOnly == rhsState.showUnreadOnly &&
                   lhsState.alert == rhsState.alert
        case (.backgroundTasks(let lhsState), .backgroundTasks(let rhsState)):
            return lhsState == rhsState
        default:
            return false
        }
    }
}
