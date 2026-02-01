//
//  BackgroundTaskManager.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/26/25.
//

import ComposableArchitecture
import Foundation
import SQLiteData
import OSLog

/// Centralized manager for background task processing
actor BackgroundTaskManager {
    nonisolated private let logger = Logger(subsystem: "WordsLearner", category: "BackgroundTaskManager")
    private let database: any DatabaseWriter
    private let generator: ComparisonGenerationService
    
    private var processingTask: Task<Void, Never>?
    private var isRunning = false
    private var currentTaskId: UUID?
    
    init(database: any DatabaseWriter, generator: ComparisonGenerationService) {
        self.database = database
        self.generator = generator
    }
    
    // MARK: - Public Interface
    
    /// Start the background processing loop
    func startProcessingLoop() {
        guard !isRunning else {
            logger.info("Processing loop already running")
            return
        }
        
        isRunning = true
        logger.info("Starting background task processing loop")
        
        processingTask = Task {
            await processTasksLoop()
        }
    }
    
    /// Stop the processing loop
    func stopProcessingLoop() {
        logger.info("Stopping background task processing loop")
        isRunning = false
        processingTask?.cancel()
        processingTask = nil
        currentTaskId = nil
    }
    
    /// Add a new task to the queue
    func addTask(word1: String, word2: String, sentence: String) async throws {
        logger.info("Adding new task: \(word1) vs \(word2)")
        
        try await database.write { db in
            try BackgroundTask.insert {
                BackgroundTask.create(
                    word1: word1,
                    word2: word2,
                    sentence: sentence,
                    now: Date()
                )
            }
            .execute(db)
        }
        
        logger.info("Task added successfully")
    }
    
    /// Get the current processing task ID
    func getCurrentTaskId() -> UUID? {
        return currentTaskId
    }
    
    /// Check if currently processing
    func isProcessing() -> Bool {
        return currentTaskId != nil
    }
    
    /// Get pending tasks count
    func getPendingTasksCount() async throws -> Int {
        return try await database.read { db in
            try BackgroundTask
                .where { $0.status == BackgroundTask.Status.pending.rawValue }
                .count()
                .fetchOne(db) ?? 0
        }
    }
    
    /// Regenerate a failed task by resetting it to pending status
    func regenerateTask(taskId: UUID) async throws {
        logger.info("Regenerating task: \(taskId)")
        
        try await database.write { db in
            try BackgroundTask
                .where { $0.id == taskId }
                .update {
                    $0.status = BackgroundTask.Status.pending.rawValue
                    $0.error = nil
                    $0.response = ""
                    $0.updatedAt = Date()
                }
                .execute(db)
        }
        
        logger.info("Task \(taskId) reset to pending status")
    }
    
    // MARK: - Private Processing Logic
    
    private func processTasksLoop() async {
        logger.info("Background task processing loop started")
        
        while isRunning {
            do {
                // Check for pending tasks
                let pendingTask = try await fetchNextPendingTask()
                
                if let task = pendingTask {
                    await processTask(task)
                } else {
                    // No pending tasks, wait a bit before checking again
                    try await Task.sleep(for: .seconds(2))
                }
            } catch is CancellationError {
                logger.info("Processing loop cancelled")
                break
            } catch {
                logger.error("Error in processing loop: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(5))
            }
        }
        
        logger.info("Background task processing loop ended")
    }
    
    private func fetchNextPendingTask() async throws -> BackgroundTask? {
        return try await database.read { db in
            try BackgroundTask
                .where { $0.status == BackgroundTask.Status.pending.rawValue }
                .order { $0.createdAt.asc() }
                .limit(1)
                .fetchOne(db)
        }
    }
    
    private func processTask(_ task: BackgroundTask) async {
        logger.info("Processing task: \(task.id) - \(task.word1) vs \(task.word2)")
        currentTaskId = task.id
        
        do {
            // Update status to generating
            try await updateTaskStatus(taskId: task.id, status: .generating)
            
            // Generate AI response using shared service
            var fullResponse = ""
            for try await chunk in generator.generateComparison(
                word1: task.word1,
                word2: task.word2,
                sentence: task.sentence
            ) {
                fullResponse += chunk
            }
            
            logger.info("Task \(task.id) completed, response length: \(fullResponse.count)")
            
            // Update task with response
            try await updateTaskWithResponse(
                taskId: task.id,
                response: fullResponse,
                status: .completed
            )
            
            // Save to comparison history using shared service
            try await generator.saveToHistory(
                word1: task.word1,
                word2: task.word2,
                sentence: task.sentence,
                response: fullResponse,
                date: Date()
            )
            
            logger.info("Task \(task.id) saved successfully")
            
        } catch {
            logger.error("Task \(task.id) failed: \(error.localizedDescription)")
            
            // Update task status to failed
            try? await updateTaskWithWithError(
                taskId: task.id,
                error: error.localizedDescription
            )
        }
        
        currentTaskId = nil
        
        // Small delay before processing next task
        try? await Task.sleep(for: .milliseconds(500))
    }
    
    // MARK: - Database Operations
    
    private func updateTaskStatus(taskId: UUID, status: BackgroundTask.Status) async throws {
        try await database.write { db in
            try BackgroundTask
                .where { $0.id == taskId }
                .update {
                    $0.status = status.rawValue
                    $0.updatedAt = Date()
                }
                .execute(db)
        }
    }
    
    private func updateTaskWithResponse(
        taskId: UUID,
        response: String,
        status: BackgroundTask.Status
    ) async throws {
        try await database.write { db in
            try BackgroundTask
                .where { $0.id == taskId }
                .update {
                    $0.response = response
                    $0.status = status.rawValue
                    $0.updatedAt = Date()
                }
                .execute(db)
        }
    }
    
    private func updateTaskWithWithError(taskId: UUID, error: String) async throws {
        try await database.write { db in
            try BackgroundTask
                .where { $0.id == taskId }
                .update {
                    $0.error = error
                    $0.status = BackgroundTask.Status.failed.rawValue
                    $0.updatedAt = Date()
                }
                .execute(db)
        }
    }
}

// MARK: - Dependency Client

nonisolated struct BackgroundTaskManagerClient: Sendable {
    var startProcessingLoop: @Sendable () async -> Void
    var stopProcessingLoop: @Sendable () async -> Void
    var addTask: @Sendable (String, String, String) async throws -> Void
    var getCurrentTaskId: @Sendable () async -> UUID?
    var isProcessing: @Sendable () async -> Bool
    var getPendingTasksCount: @Sendable () async throws -> Int
    var regenerateTask: @Sendable (UUID) async throws -> Void
}

extension BackgroundTaskManagerClient: DependencyKey {
    @MainActor
    static var liveValue: BackgroundTaskManagerClient {
        let dependencies = DependencyValues._current
        let database = dependencies.defaultDatabase
        let aiService = dependencies.aiService
        
        let generator = ComparisonGenerationService(
            aiService: aiService,
            database: database
        )
        
        let manager = BackgroundTaskManager(
            database: database,
            generator: generator
        )
        
        return Self(
            startProcessingLoop: { await manager.startProcessingLoop() },
            stopProcessingLoop: { await manager.stopProcessingLoop() },
            addTask: { word1, word2, sentence in
                try await manager.addTask(word1: word1, word2: word2, sentence: sentence)
            },
            getCurrentTaskId: { await manager.getCurrentTaskId() },
            isProcessing: { await manager.isProcessing() },
            getPendingTasksCount: { try await manager.getPendingTasksCount() },
            regenerateTask: { taskId in
                try await manager.regenerateTask(taskId: taskId)
            }
        )
    }
    
    static let testValue = Self(
        startProcessingLoop: { },
        stopProcessingLoop: { },
        addTask: { _, _, _ in },
        getCurrentTaskId: { nil },
        isProcessing: { false },
        getPendingTasksCount: { 0 },
        regenerateTask: { _ in }
    )
}

extension DependencyValues {
    var backgroundTaskManager: BackgroundTaskManagerClient {
        get { self[BackgroundTaskManagerClient.self] }
        set { self[BackgroundTaskManagerClient.self] = newValue }
    }
}
