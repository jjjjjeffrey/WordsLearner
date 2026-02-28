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
        case history
        case backgroundTasks
        case multimodalLessons

        var id: Self { self }

        var title: String {
            switch self {
            case .history:
                return "History"
            case .backgroundTasks:
                return "Background Tasks"
            case .multimodalLessons:
                return "Multimodal History"
            }
        }

        var systemImage: String {
            switch self {
            case .history:
                return "clock"
            case .backgroundTasks:
                return "line.3.horizontal.decrease.circle"
            case .multimodalLessons:
                return "photo.on.rectangle.angled"
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        var word1: String = ""
        var word2: String = ""
        var sentence: String = ""
        var hasValidAPIKey: Bool = false
        var hasValidElevenLabsAPIKey: Bool = false
        var isGeneratingMultimodalLesson: Bool = false
        var activeMultimodalLessonID: UUID?
        var multimodalGenerationStatusText: String?
        var multimodalGenerationStep: Int = 0
        var multimodalGenerationTotalSteps: Int = 0
        
        // For observing background tasks in the main view
        @ObservationStateIgnored
        @FetchAll(
            BackgroundTask
                .where { $0.status == BackgroundTask.Status.pending.rawValue },
            animation: .default
        )
        var pendingTasks: [BackgroundTask] = []
        
        var sidebarSelection: SidebarItem? = .history
        var isComposerSheetPresented = false
        var historyList: ComparisonHistoryListFeature.State?
        var backgroundTasks: BackgroundTasksFeature.State?
        var multimodalLessons: MultimodalLessonsFeature.State?
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

        var multimodalGenerationProgressFraction: Double? {
            guard multimodalGenerationTotalSteps > 0 else { return nil }
            let clamped = min(max(multimodalGenerationStep, 0), multimodalGenerationTotalSteps)
            return Double(clamped) / Double(multimodalGenerationTotalSteps)
        }

        var multimodalGenerationStepText: String? {
            guard multimodalGenerationTotalSteps > 0 else { return nil }
            return "\(multimodalGenerationStep)/\(multimodalGenerationTotalSteps)"
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case lastReadComparisonLoaded(ComparisonHistory?)
        case newComparisonButtonTapped
        case generateButtonTapped
        case generateMultimodalButtonTapped
        case generateInBackgroundButtonTapped
        case multimodalGenerationProgressUpdated(MultimodalGenerationProgress)
        case multimodalLessonGenerated(UUID)
        case multimodalLessonGenerationFailed(String)
        case settingsButtonTapped
        case historyListButtonTapped
        case backgroundTasksButtonTapped
        case settings(PresentationAction<SettingsFeature.Action>)
        case historyList(ComparisonHistoryListFeature.Action)
        case backgroundTasks(BackgroundTasksFeature.Action)
        case multimodalLessons(MultimodalLessonsFeature.Action)
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
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.lastReadComparisonStore) var lastReadComparisonStore
    @Dependency(\.multimodalLessonGenerator) var multimodalLessonGenerator
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.hasValidAPIKey = apiKeyManager.hasValidAPIKey()
                state.hasValidElevenLabsAPIKey = apiKeyManager.hasValidElevenLabsAPIKey()
                activateSelection(&state)
                return .merge(
                    .run { [taskManager] _ in
                        await taskManager.startProcessingLoop()
                    },
                    .run { [database, lastReadComparisonStore] send in
                        let storedID = lastReadComparisonStore.get()
                        guard
                            let idString = storedID,
                            let id = UUID(uuidString: idString)
                        else {
                            if storedID != nil {
                                lastReadComparisonStore.clear()
                            }
                            return
                        }

                        let comparison = try? await database.read { db in
                            try ComparisonHistory
                                .where { $0.id == id }
                                .fetchOne(db)
                        }

                        if comparison == nil {
                            lastReadComparisonStore.clear()
                            return
                        }
                        await send(.lastReadComparisonLoaded(comparison))
                    }
                )

            case let .lastReadComparisonLoaded(comparison):
                guard state.sidebarSelection == .history, let comparison else { return .none }
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

            case .newComparisonButtonTapped:
                state.isComposerSheetPresented = true
                return .none
                
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
                
                state.isComposerSheetPresented = false
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

            case .generateMultimodalButtonTapped:
                guard
                    !state.word1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    !state.word2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    state.hasValidAPIKey,
                    state.hasValidElevenLabsAPIKey,
                    !state.isGeneratingMultimodalLesson
                else { return .none }

                let word1 = state.word1
                let word2 = state.word2
                let sentence = state.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                state.isGeneratingMultimodalLesson = true
                state.activeMultimodalLessonID = nil
                state.multimodalGenerationStatusText = "Starting multimodal lesson..."
                state.multimodalGenerationStep = 0
                state.multimodalGenerationTotalSteps = 0
                state.isComposerSheetPresented = false
                state.sidebarSelection = .multimodalLessons
                activateSelection(&state)

                return .run { [multimodalLessonGenerator] send in
                    do {
                        let lessonID = try await multimodalLessonGenerator.generateLesson(
                            word1,
                            word2,
                            sentence.isEmpty ? nil : sentence
                        ) { progress in
                            await send(.multimodalGenerationProgressUpdated(progress))
                        }
                        await send(.multimodalLessonGenerated(lessonID))
                        await send(.clearInputFields)
                    } catch {
                        await send(.multimodalLessonGenerationFailed(error.localizedDescription))
                    }
                }

            case let .multimodalGenerationProgressUpdated(progress):
                switch progress {
                case let .planning(lessonID):
                    state.activeMultimodalLessonID = lessonID
                    state.multimodalGenerationStatusText = "Planning storyboard..."
                    state.multimodalGenerationStep = 0
                    state.multimodalGenerationTotalSteps = 0
                    if state.sidebarSelection == .multimodalLessons {
                        return .send(.multimodalLessons(.lessonTapped(lessonID)))
                    }
                    return .none

                case let .generatingFrame(lessonID, step, totalSteps, _):
                    state.activeMultimodalLessonID = lessonID
                    state.multimodalGenerationStep = step
                    state.multimodalGenerationTotalSteps = totalSteps
                    state.multimodalGenerationStatusText = "Generating scene \(step)/\(totalSteps)..."
                    return .none

                case .completed:
                    state.multimodalGenerationStatusText = "Finalizing lesson..."
                    return .none
                }

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
                state.isComposerSheetPresented = false
                return .none

            case let .multimodalLessonGenerated(lessonID):
                state.isGeneratingMultimodalLesson = false
                state.activeMultimodalLessonID = nil
                state.multimodalGenerationStatusText = nil
                state.multimodalGenerationStep = 0
                state.multimodalGenerationTotalSteps = 0
                state.sidebarSelection = .multimodalLessons
                activateSelection(&state)
                return .send(.multimodalLessons(.lessonTapped(lessonID)))

            case let .multimodalLessonGenerationFailed(errorMessage):
                state.isGeneratingMultimodalLesson = false
                state.activeMultimodalLessonID = nil
                state.multimodalGenerationStatusText = nil
                state.multimodalGenerationStep = 0
                state.multimodalGenerationTotalSteps = 0
                state.alert = AlertState {
                    TextState("Multimodal Generation Failed")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("OK")
                    }
                } message: {
                    TextState(errorMessage)
                }
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
                state.hasValidElevenLabsAPIKey = apiKeyManager.hasValidElevenLabsAPIKey()
                return .none
                
            case let .historyList(.delegate(.comparisonSelected(comparison))):
                lastReadComparisonStore.set(comparison.id.uuidString)
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

            case .historyList:
                return .none
                
            case .backgroundTasks:
                return .none

            case .multimodalLessons:
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
        .ifLet(\.multimodalLessons, action: \.multimodalLessons) {
            MultimodalLessonsFeature()
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
            state.sidebarSelection = .history
            state.historyList = nil
            state.backgroundTasks = nil
            state.multimodalLessons = nil
            state.detail = nil
            return
        }

        switch selection {
        case .history:
            if state.historyList == nil {
                state.historyList = ComparisonHistoryListFeature.State()
            }
            state.backgroundTasks = nil
            state.multimodalLessons = nil

        case .backgroundTasks:
            if state.backgroundTasks == nil {
                state.backgroundTasks = BackgroundTasksFeature.State()
            }
            state.historyList = nil
            state.multimodalLessons = nil
        case .multimodalLessons:
            if state.multimodalLessons == nil {
                state.multimodalLessons = MultimodalLessonsFeature.State()
            }
            state.historyList = nil
            state.backgroundTasks = nil
        }

        if selection != .history {
            state.detail = nil
        }
    }

    private func showDetail(_ state: inout State, _ detail: ResponseDetailFeature.State) {
        state.detail = detail
        state.detailPresentationToken &+= 1
    }
}

struct LastReadComparisonStoreClient: Sendable {
    var get: @Sendable () -> String?
    var set: @Sendable (String) -> Void
    var clear: @Sendable () -> Void
}

extension LastReadComparisonStoreClient: DependencyKey {
    private static let key = "wordComparatorLastReadComparisonID"

    static let liveValue = Self(
        get: {
            UserDefaults.standard.string(forKey: key)
        },
        set: { value in
            UserDefaults.standard.set(value, forKey: key)
        },
        clear: {
            UserDefaults.standard.removeObject(forKey: key)
        }
    )

    static let testValue = Self(
        get: { nil },
        set: { _ in },
        clear: {}
    )
}

extension DependencyValues {
    var lastReadComparisonStore: LastReadComparisonStoreClient {
        get { self[LastReadComparisonStoreClient.self] }
        set { self[LastReadComparisonStoreClient.self] = newValue }
    }
}
