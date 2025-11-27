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

private let logger = Logger(subsystem: "WordsLearner", category: "BackgroundTaskManager")

/// Centralized manager for background task processing
actor BackgroundTaskManager {
    private let database: any DatabaseWriter
    private let aiService: AIServiceClient
    
    private var processingTask: Task<Void, Never>?
    private var isRunning = false
    private var currentTaskId: UUID?
    
    init(database: any DatabaseWriter, aiService: AIServiceClient) {
        self.database = database
        self.aiService = aiService
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
            
            // Generate AI response
            let prompt = buildPrompt(
                word1: task.word1,
                word2: task.word2,
                sentence: task.sentence
            )
            
            var fullResponse = ""
            for try await chunk in aiService.streamResponse(prompt) {
                fullResponse += chunk
            }
            
            logger.info("Task \(task.id) completed, response length: \(fullResponse.count)")
            
            // Update task with response
            try await updateTaskWithResponse(
                taskId: task.id,
                response: fullResponse,
                status: .completed
            )
            
            // Save to comparison history
            try await saveToComparisonHistory(task: task, response: fullResponse)
            
            logger.info("Task \(task.id) saved successfully")
            
        } catch {
            logger.error("Task \(task.id) failed: \(error.localizedDescription)")
            
            // Update task status to failed
            try? await updateTaskWithError(
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
    
    private func updateTaskWithError(taskId: UUID, error: String) async throws {
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
    
    private func saveToComparisonHistory(task: BackgroundTask, response: String) async throws {
        try await database.write { db in
            try ComparisonHistory.insert {
                ComparisonHistory.Draft(
                    word1: task.word1,
                    word2: task.word2,
                    sentence: task.sentence,
                    response: response,
                    date: Date()
                )
            }
            .execute(db)
        }
    }
}

// MARK: - Prompt Builder

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

// MARK: - Dependency Client

struct BackgroundTaskManagerClient {
    var startProcessingLoop: @Sendable () async -> Void
    var stopProcessingLoop: @Sendable () async -> Void
    var addTask: @Sendable (String, String, String) async throws -> Void
    var getCurrentTaskId: @Sendable () async -> UUID?
    var isProcessing: @Sendable () async -> Bool
    var getPendingTasksCount: @Sendable () async throws -> Int
}

extension BackgroundTaskManagerClient: DependencyKey {
    static let liveValue: BackgroundTaskManagerClient = {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.aiService) var aiService
        
        let manager = BackgroundTaskManager(database: database, aiService: aiService)
        
        return Self(
            startProcessingLoop: { await manager.startProcessingLoop() },
            stopProcessingLoop: { await manager.stopProcessingLoop() },
            addTask: { word1, word2, sentence in
                try await manager.addTask(word1: word1, word2: word2, sentence: sentence)
            },
            getCurrentTaskId: { await manager.getCurrentTaskId() },
            isProcessing: { await manager.isProcessing() },
            getPendingTasksCount: { try await manager.getPendingTasksCount() }
        )
    }()
    
    static let testValue = Self(
        startProcessingLoop: { },
        stopProcessingLoop: { },
        addTask: { _, _, _ in },
        getCurrentTaskId: { nil },
        isProcessing: { false },
        getPendingTasksCount: { 0 }
    )
}

extension DependencyValues {
    var backgroundTaskManager: BackgroundTaskManagerClient {
        get { self[BackgroundTaskManagerClient.self] }
        set { self[BackgroundTaskManagerClient.self] = newValue }
    }
}


