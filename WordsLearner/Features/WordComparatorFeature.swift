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
    
    struct BackgroundTask: Equatable, Identifiable {
        let id: UUID
        let word1: String
        let word2: String
        let sentence: String
        var status: Status
        var response: String = ""
        var error: String?
        
        enum Status: Equatable {
            case pending
            case generating
            case completed
            case failed
        }
        
        init(id: UUID = UUID(), word1: String, word2: String, sentence: String, status: Status = .pending) {
            self.id = id
            self.word1 = word1
            self.word2 = word2
            self.sentence = sentence
            self.status = status
        }
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
        
        // Background generation state
        var backgroundTasks: [BackgroundTask] = []
        var currentGeneratingTaskId: UUID?
        @Presents var alert: AlertState<Action.Alert>?
        
        var isGeneratingInBackground: Bool {
            currentGeneratingTaskId != nil
        }
        
        var pendingTasksCount: Int {
            backgroundTasks.filter { $0.status == .pending }.count
        }
        
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
        case generateInBackgroundButtonTapped
        case settingsButtonTapped
        case historyListButtonTapped
        case path(StackActionOf<Path>)
        case settings(PresentationAction<SettingsFeature.Action>)
        case apiKeyStatusChanged(Bool)
        case recentComparisons(RecentComparisonsFeature.Action)
        case alert(PresentationAction<Alert>)
        case backgroundTaskAdded(BackgroundTask)
        case processNextBackgroundTask
        case backgroundTaskStarted(UUID)
        case backgroundTaskCompleted(UUID, String)
        case backgroundTaskFailed(UUID, Error)
        case backgroundTaskSaved(UUID)
        case removeBackgroundTask(UUID)
        case clearCompletedTasks
        case clearInputFields
        
        enum Alert: Equatable {
            case taskAddedToQueue(Int)
        }
    }
    
    @Dependency(\.apiKeyManager) var apiKeyManager
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.aiService) var aiService
    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid
    
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
                
                let task = BackgroundTask(
                    id: uuid(),
                    word1: state.word1,
                    word2: state.word2,
                    sentence: state.sentence
                )
                return .concatenate(
                    [
                        .send(.clearInputFields),
                        .send(.backgroundTaskAdded(task))
                    ]
                )
                
            case .clearInputFields:
                state.word1 = ""
                state.word2 = ""
                state.sentence = ""
                return .none
                
            case let .backgroundTaskAdded(task):
                state.backgroundTasks.append(task)
                let queuePosition = state.pendingTasksCount
                state.alert = AlertState {
                    TextState("Task Added")
                } actions: {
                    ButtonState(role: .cancel, action: .taskAddedToQueue(queuePosition)) {
                        TextState("OK")
                    }
                } message: {
                    TextState("Comparison task added to queue. Position: \(queuePosition)")
                }
                
                if state.currentGeneratingTaskId == nil {
                    return .send(.processNextBackgroundTask)
                }
                return .none
                
            case .processNextBackgroundTask:
                guard let nextTask = state.backgroundTasks.first(where: { $0.status == .pending }) else {
                    state.currentGeneratingTaskId = nil
                    return .none
                }
                
                return .send(.backgroundTaskStarted(nextTask.id))
                
            case let .backgroundTaskStarted(taskId):
                guard let taskIndex = state.backgroundTasks.firstIndex(where: { $0.id == taskId }) else {
                    return .none
                }
                
                state.backgroundTasks[taskIndex].status = .generating
                state.currentGeneratingTaskId = taskId
                
                let task = state.backgroundTasks[taskIndex]
                let prompt = buildPrompt(word1: task.word1, word2: task.word2, sentence: task.sentence)
                
                return .run { send in
                    do {
                        var fullResponse = ""
                        for try await chunk in aiService.streamResponse(prompt) {
                            fullResponse += chunk
                        }
                        await send(.backgroundTaskCompleted(taskId, fullResponse))
                    } catch {
                        await send(.backgroundTaskFailed(taskId, error))
                    }
                }
                
            case let .backgroundTaskCompleted(taskId, response):
                guard let taskIndex = state.backgroundTasks.firstIndex(where: { $0.id == taskId }) else {
                    return .none
                }
                
                state.backgroundTasks[taskIndex].status = .completed
                state.backgroundTasks[taskIndex].response = response
                state.currentGeneratingTaskId = nil
                
                let task = state.backgroundTasks[taskIndex]
                let draft = ComparisonHistory.Draft(
                    word1: task.word1,
                    word2: task.word2,
                    sentence: task.sentence,
                    response: response,
                    date: now
                )
                
                return .run { send in
                    do {
                        try await database.write { db in
                            try ComparisonHistory.insert {
                                draft
                            }
                            .execute(db)
                        }
                        await send(.backgroundTaskSaved(taskId))
                    } catch {
                        await send(.backgroundTaskFailed(taskId, error))
                    }
                }
                
            case let .backgroundTaskSaved(taskId):
                return .run { send in
                    try await Task.sleep(for: .milliseconds(500))
                    await send(.processNextBackgroundTask)
                }
                
            case let .backgroundTaskFailed(taskId, error):
                guard let taskIndex = state.backgroundTasks.firstIndex(where: { $0.id == taskId }) else {
                    return .none
                }
                
                state.backgroundTasks[taskIndex].status = .failed
                state.backgroundTasks[taskIndex].error = error.localizedDescription
                state.currentGeneratingTaskId = nil
                
                return .send(.processNextBackgroundTask)
                
            case let .removeBackgroundTask(taskId):
                state.backgroundTasks.removeAll { $0.id == taskId }
                return .none
                
            case .clearCompletedTasks:
                state.backgroundTasks.removeAll {
                    $0.status == .completed || $0.status == .failed
                }
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
                
            case .path:
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

extension WordComparatorFeature.Path.State: Equatable {}

private func buildPrompt(word1: String, word2: String, sentence: String) -> String {
    return """
    Help me compare the target English vocabularies "\(word1)" and "\(word2)" by telling me some simple stories that reveal what their means naturally in that specific context. And what's the key difference between them. These stories should illustrate not only the literal meaning but also the figurative meaning, if applicable.
    
    I'm an English learner, so tell this story at an elementary third-grade level, using only simple words and sentences, and without slang, phrasal verbs, or complex grammar.
    
    After the story, give any background or origin information (if it's known or useful), and explain the meaning of the vocabulary clearly.
    
    Finally, give 10 numbered example sentences that show the phrase used today in each context, with different tenses and sentence types, including questions. Use **bold** formatting for the target vocabulary throughout.

    If there are some situations we can use both of them without changing the meaning, and some other contexts which they can't be used interchangeably, please give me examples separately.

    At the end, tell me that if I can use them interchangeably in this sentence "\(sentence)"
    
    IMPORTANT: Format your response using proper Markdown syntax:
    - Use ## for main headings
    - Use ### for subheadings  
    - Use **text** for bold formatting
    - Use numbered lists (1. 2. 3.) for examples
    - Use - for bullet points when appropriate
    """
}
