//
//  ComparisonGenerationService.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/27/25.
//

import ComposableArchitecture
import Foundation
import SQLiteData

/// Shared service for generating word comparisons
// @unchecked Sendable safety: DatabaseWriter instances used here are GRDB DatabaseQueue/Pool types
// which serialize access internally. Follow-up: replace `any DatabaseWriter` with a Sendable
// wrapper (or an actor) and remove @unchecked Sendable.
nonisolated struct ComparisonGenerationService: @unchecked Sendable {
    let aiService: AIServiceClient
    let database: any DatabaseWriter
    
    /// Generate a comparison with streaming response
    func generateComparison(
        word1: String,
        word2: String,
        sentence: String
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let prompt = buildPrompt(
                        word1: word1,
                        word2: word2,
                        sentence: sentence
                    )
                    
                    for try await chunk in aiService.streamResponse(prompt) {
                        continuation.yield(chunk)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Save comparison to history
    func saveToHistory(
        word1: String,
        word2: String,
        sentence: String,
        response: String,
        date: Date
    ) async throws {
        try await database.write { db in
            try ComparisonHistory.insert {
                ComparisonHistory.Draft(
                    word1: word1,
                    word2: word2,
                    sentence: sentence,
                    response: response,
                    date: date,
                    isRead: false
                )
            }
            .execute(db)
        }
    }
    
    /// Build prompt for AI
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
}

// MARK: - Dependency Client

nonisolated struct ComparisonGenerationServiceClient: Sendable {
    var generateComparison: @Sendable (String, String, String) -> AsyncThrowingStream<String, Error>
    var saveToHistory: @Sendable (String, String, String, String) async throws -> Void
}

extension ComparisonGenerationServiceClient: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.aiService) var aiService
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date.now) var now
        let service = ComparisonGenerationService(aiService: aiService, database: database)
        return Self.make(service: service, now: now)
    }

    nonisolated static var previewValue: Self {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date.now) var now
        let service = ComparisonGenerationService(aiService: .previewValue, database: database)
        return Self.make(service: service, now: now)
    }
    
    nonisolated static var testValue: Self {
        Self(
            generateComparison: { _, _, _ in
                AsyncThrowingStream { continuation in
                    let message = AIServiceClient.previewStreamString
                    continuation.yield(message)
                    continuation.finish()
                }
            },
            saveToHistory: { _, _, _, _ in }
        )
    }

    private static func make(
        service: ComparisonGenerationService,
        now: Date
    ) -> Self {
        Self(
            generateComparison: { word1, word2, sentence in
                service.generateComparison(
                    word1: word1,
                    word2: word2,
                    sentence: sentence
                )
            },
            saveToHistory: { word1, word2, sentence, response in
                try await service.saveToHistory(
                    word1: word1,
                    word2: word2,
                    sentence: sentence,
                    response: response,
                    date: now
                )
            }
        )
    }
}

extension DependencyValues {
    var comparisonGenerator: ComparisonGenerationServiceClient {
        get { self[ComparisonGenerationServiceClient.self] }
        set { self[ComparisonGenerationServiceClient.self] = newValue }
    }
}
