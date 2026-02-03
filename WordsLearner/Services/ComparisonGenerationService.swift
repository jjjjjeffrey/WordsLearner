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
    
    nonisolated static let streamString: String =
                    """
                    ## Understanding "Character" and "Characteristic"
                    
                    ### Simple Stories
                    
                    #### Story 1: "Character"
                    Once upon a time, in a small town, there was a kind girl named Lily. Everyone said that her **character** was special. She always helped others and shared her toys. One day, she saw a little boy crying because he lost his puppy. Lily ran to him and said, "Don't worry! Let's find your puppy together." Because of her good **character**, everyone loved Lily. She was not just a nice girl; her **character** showed that she cared for others.
                    
                    #### Story 2: "Characteristic"
                    In the same town, there was a tall tree in the park. This tree had many **characteristics**. It had green leaves, a thick trunk, and beautiful flowers. Every spring, the tree would bloom with bright pink flowers. The tall tree’s main **characteristic** was its height. All the children loved to play under it because it provided shade. The tree’s **characteristics** made it special, just like Lily’s **character** made her special.
                    
                    ### Key Difference
                    The key difference between **character** and **characteristic** is that **character** refers to the moral qualities of a person, while **characteristic** refers to a feature or trait that describes something.
                    
                    ### Background Information
                    - **Character** comes from the Greek word "kharaktēr," meaning a mark or engraving. Over time, it has come to mean the moral qualities of a person.
                    - **Characteristic** comes from the Greek word "kharakteristikos," meaning something that describes a person or thing.
                    
                    ### Vocabulary Meaning
                    - **Character**: The moral qualities or nature of a person.
                    - **Characteristic**: A feature or trait that helps to describe something.
                    
                    ### Example Sentences
                    
                    1. My friend has a friendly **character** that everyone enjoys.
                    2. Can you tell me one **characteristic** of your favorite animal?
                    3. Lily showed her good **character** when she helped the lost puppy.
                    4. The **characteristic** of this fruit is its sweet taste.
                    5. He has a strong **character** because he always does what is right.
                    6. What is the main **characteristic** of a good friend?
                    7. Her **character** shines brightly in difficult times.
                    8. One **characteristic** of cats is that they love to sleep a lot.
                    9. The teacher praised her for her caring **character**.
                    10. Is being brave an important **characteristic** for a hero?
                    
                    ### Interchangeability
                    - You can use **character** and **characteristic** in some situations where they seem to describe something about a person or thing, but they are not always interchangeable. For example:
                      - "The **character** of this wine is unique." (This means the overall quality or nature of the wine.)
                      - "The **characteristic** of this wine is its fruity flavor." (This describes a specific feature of the wine.)
                    
                    In the sentence "The **character** of this wine is unique," you cannot replace **character** with **characteristic** without changing the meaning. 
                    
                    - **Use of both in a similar context**: "The **character** of this park is peaceful," vs. "The **characteristic** of this park is its quietness." Here, both sentences talk about the park but in different ways.
                    
                    ### Conclusion
                    Remember, **character** is about a person's nature, while **characteristic** is about the features or traits of something.
                    """
    
    static let liveValue: Self = {
        @Dependency(\.aiService) var aiService
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date.now) var now
        
        let service = ComparisonGenerationService(
            aiService: aiService,
            database: database
        )
        
        return Self(
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
    }()
    
    nonisolated static let previewValue = Self(
        generateComparison: { _, _, _ in
            AsyncThrowingStream { continuation in
                Task {
                    let message = streamString
                    let words = message.split(separator: " ", omittingEmptySubsequences: false)
                    for (index, word) in words.enumerated() {
                        // Re-add a space after each word except the last one
                        let yieldString: String
                        if index < words.count - 1 {
                            yieldString = word + " "
                        } else {
                            yieldString = String(word)
                        }
                        continuation.yield(yieldString)
                        try? await Task.sleep(nanoseconds: 60_000_000) // 60ms lag
                    }
                    continuation.finish()
                }
            }
        },
        saveToHistory: { _, _, _, _ in }
    )
    
    nonisolated static let testValue = Self(
        generateComparison: { _, _, _ in
            AsyncThrowingStream { continuation in
                let message = streamString
                continuation.yield(message)
                continuation.finish()
            }
        },
        saveToHistory: { _, _, _, _ in }
    )
}

extension DependencyValues {
    var comparisonGenerator: ComparisonGenerationServiceClient {
        get { self[ComparisonGenerationServiceClient.self] }
        set { self[ComparisonGenerationServiceClient.self] = newValue }
    }
}
