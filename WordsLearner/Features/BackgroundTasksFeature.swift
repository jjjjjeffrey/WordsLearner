//
//  BackgroundTasksFeature.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/26/25.
//

import ComposableArchitecture
import Foundation
import SQLiteData
import SwiftUI

@Reducer
struct BackgroundTasksFeature {
    
    @ObservableState
    struct State: Equatable {
        @ObservationStateIgnored
        @FetchAll(
            BackgroundTask
                .order { $0.createdAt.desc() },
            animation: .default
        )
        var tasks: [BackgroundTask] = []
        
        var currentGeneratingTaskId: UUID?
        
        var isGenerating: Bool {
            currentGeneratingTaskId != nil
        }
        
        var pendingTasksCount: Int {
            tasks.filter { $0.taskStatus == .pending }.count
        }
        
        var completedTasksCount: Int {
            tasks.filter { $0.taskStatus == .completed || $0.taskStatus == .failed }.count
        }
        
        var isEmpty: Bool {
            tasks.isEmpty
        }
    }
    
    enum Action: Equatable {
        case onAppear
        case syncCurrentTaskId
        case currentTaskIdUpdated(UUID?)
        case removeTask(UUID)
        case regenerateTask(UUID)
        case clearCompletedTasks
        case clearAllTasks
        case viewComparisonHistory(ComparisonHistory)
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case comparisonSelected(ComparisonHistory)
        }
    }
    
    private var taskManager: BackgroundTaskManagerClient { DependencyValues._current.backgroundTaskManager }
    @Dependency(\.defaultDatabase) var database
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    await send(.syncCurrentTaskId)
                }
                
            case .syncCurrentTaskId:
                return .run { send in
                    // Poll for current task ID every 0.5 seconds
                    while true {
                        let currentId = await taskManager.getCurrentTaskId()
                        await send(.currentTaskIdUpdated(currentId))
                        try await Task.sleep(for: .milliseconds(500))
                    }
                }
                
            case let .currentTaskIdUpdated(taskId):
                state.currentGeneratingTaskId = taskId
                return .none
                
            case let .removeTask(taskId):
                return .run { send in
                    await withErrorReporting {
                        try await database.write { db in
                            try BackgroundTask
                                .where { $0.id == taskId }
                                .delete()
                                .execute(db)
                        }
                    }
                }
                
            case let .regenerateTask(taskId):
                return .run { send in
                    await withErrorReporting {
                        try await taskManager.regenerateTask(taskId)
                    }
                }
                
            case .clearCompletedTasks:
                return .run { send in
                    await withErrorReporting {
                        try await database.write { db in
                            try BackgroundTask
                                .where { $0.status.in(["completed", "failed"]) }
                                .delete()
                                .execute(db)
                        }
                    }
                }
                
            case .clearAllTasks:
                return .run { send in
                    await taskManager.stopProcessingLoop()
                    
                    await withErrorReporting {
                        try await database.write { db in
                            try BackgroundTask.delete().execute(db)
                        }
                    }
                    
                    // Restart processing loop
                    await taskManager.startProcessingLoop()
                }
                
            case let .viewComparisonHistory(comparison):
                return .send(.delegate(.comparisonSelected(comparison)))
                
            case .delegate:
                return .none
            }
        }
    }
}

