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

@Reducer
struct WordComparatorFeature {
    enum SidebarItem: String, CaseIterable, Equatable, Hashable, Identifiable {
        case composer
        case history
        case backgroundTasks

        var id: Self { self }

        var title: String {
            switch self {
            case .composer:
                return "Comparator"
            case .history:
                return "History"
            case .backgroundTasks:
                return "Background Tasks"
            }
        }

        var systemImage: String {
            switch self {
            case .composer:
                return "text.book.closed"
            case .history:
                return "clock"
            case .backgroundTasks:
                return "line.3.horizontal.decrease.circle"
            }
        }
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
        
        var sidebarSelection: SidebarItem? = .composer
        var recentComparisons = RecentComparisonsFeature.State()
        var historyList: ComparisonHistoryListFeature.State?
        var backgroundTasks: BackgroundTasksFeature.State?
        var detail: ResponseDetailFeature.State?
        var detailPresentationToken: Int = 0

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
        case settings(PresentationAction<SettingsFeature.Action>)
        case recentComparisons(RecentComparisonsFeature.Action)
        case historyList(ComparisonHistoryListFeature.Action)
        case backgroundTasks(BackgroundTasksFeature.Action)
        case detail(ResponseDetailFeature.Action)
        case detailDismissed
        case alert(PresentationAction<Alert>)
        case clearInputFields
        case taskAddedSuccessfully
        
        enum Alert: Equatable {
            case taskQueued(Int)
        }
    }
    
    @Dependency(\.apiKeyManager) var apiKeyManager
    @Dependency(\.backgroundTaskManager) var taskManager
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Scope(state: \.recentComparisons, action: \.recentComparisons) {
            RecentComparisonsFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.hasValidAPIKey = apiKeyManager.hasValidAPIKey()
                activateSelection(&state)
                return .run { [taskManager] _ in
                    await taskManager.startProcessingLoop()
                }
                
            case .settingsButtonTapped:
                state.settings = SettingsFeature.State()
                return .none
                
            case .backgroundTasksButtonTapped:
                state.sidebarSelection = .backgroundTasks
                activateSelection(&state)
                return .none
                
            case .generateButtonTapped:
                guard state.canGenerate && state.hasValidAPIKey else { return .none }
                
                let word1 = state.word1
                let word2 = state.word2
                let sentence = state.sentence
                
                state.sidebarSelection = .composer
                activateSelection(&state)
                showDetail(
                    &state,
                    ResponseDetailFeature.State(
                    word1: word1,
                    word2: word2,
                    sentence: sentence
                    )
                )

                return .concatenate(
                    .send(.clearInputFields),
                    .send(.detail(.startStreaming))
                )
                
            case .generateInBackgroundButtonTapped:
                guard state.canGenerate && state.hasValidAPIKey else { return .none }
                
                let word1 = state.word1
                let word2 = state.word2
                let sentence = state.sentence
                
                return .run { [taskManager] send in
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
                state.sidebarSelection = .history
                activateSelection(&state)
                return .none
                
            case .settings(.presented(.delegate(.apiKeyChanged))):
                state.hasValidAPIKey = apiKeyManager.hasValidAPIKey()
                return .none
                
            case let .recentComparisons(.delegate(.comparisonSelected(comparison))):
                state.sidebarSelection = .composer
                activateSelection(&state)
                showDetail(
                    &state,
                    ResponseDetailFeature.State(
                    word1: comparison.word1,
                    word2: comparison.word2,
                    sentence: comparison.sentence,
                    streamingResponse: comparison.response,
                    shouldStartStreaming: false
                    )
                )
                return .send(.detail(.hydrateStoredResponse))

            case let .historyList(.delegate(.comparisonSelected(comparison))):
                showDetail(
                    &state,
                    ResponseDetailFeature.State(
                    word1: comparison.word1,
                    word2: comparison.word2,
                    sentence: comparison.sentence,
                    streamingResponse: comparison.response,
                    shouldStartStreaming: false
                    )
                )
                return .send(.detail(.hydrateStoredResponse))

            case let .backgroundTasks(.delegate(.comparisonSelected(comparison))):
                showDetail(
                    &state,
                    ResponseDetailFeature.State(
                    word1: comparison.word1,
                    word2: comparison.word2,
                    sentence: comparison.sentence,
                    streamingResponse: comparison.response,
                    shouldStartStreaming: false
                    )
                )
                return .send(.detail(.hydrateStoredResponse))

            case .binding(\.sidebarSelection):
                activateSelection(&state)
                return .none

            case .recentComparisons:
                return .none
                
            case .historyList:
                return .none
                
            case .backgroundTasks:
                return .none

            case .detail:
                return .none

            case .detailDismissed:
                state.detail = nil
                return .none
                
            case .settings:
                return .none
                
            case .alert:
                return .none
                
            case .binding:
                return .none
            }
        }
        .ifLet(\.historyList, action: \.historyList) {
            ComparisonHistoryListFeature()
        }
        .ifLet(\.backgroundTasks, action: \.backgroundTasks) {
            BackgroundTasksFeature()
        }
        .ifLet(\.detail, action: \.detail) {
            ResponseDetailFeature()
        }
        .ifLet(\.$settings, action: \.settings) {
            SettingsFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func activateSelection(_ state: inout State) {
        guard let selection = state.sidebarSelection else {
            state.sidebarSelection = .composer
            state.historyList = nil
            state.backgroundTasks = nil
            state.detail = nil
            return
        }

        switch selection {
        case .composer:
            state.historyList = nil
            state.backgroundTasks = nil

        case .history:
            if state.historyList == nil {
                state.historyList = ComparisonHistoryListFeature.State()
            }
            state.backgroundTasks = nil

        case .backgroundTasks:
            if state.backgroundTasks == nil {
                state.backgroundTasks = BackgroundTasksFeature.State()
            }
            state.historyList = nil
        }

        if selection != .composer {
            state.detail = nil
        }
    }

    private func showDetail(_ state: inout State, _ detail: ResponseDetailFeature.State) {
        state.detail = detail
        state.detailPresentationToken &+= 1
    }
}
