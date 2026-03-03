//
//  AIServiceClient.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/18/25.
//

import ComposableArchitecture
import Foundation

// MARK: - AI Service Dependency

struct AIServiceClient: Sendable {
    var streamResponse: @Sendable (String) -> AsyncThrowingStream<String, Error>
}

extension AIServiceClient: DependencyKey {
    nonisolated static let previewStreamString = """
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

    static var liveValue: Self {
        Self(
            streamResponse: { prompt in
                return AsyncThrowingStream { continuation in
                    Task {
                        do {
                            let apiKey = await MainActor.run {
                                APIKeyManager.shared.getAPIKey()
                            }

                            guard !apiKey.isEmpty else {
                                throw AIError.authenticationError
                            }
                            
                            guard let url = URL(string: "https://zenmux.ai/api/v1/chat/completions") else {
                                throw AIError.invalidURL
                            }
                            
                            var request = URLRequest(url: url)
                            request.httpMethod = "POST"
                            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                            let model: String
                            #if DEBUG
                            model = "openai/gpt-4o-mini"
                            #else
                            model = "google/gemini-3-pro-preview"
                            #endif
                            let payload: [String: Any] = [
                                "model": model,
                                "messages": [["role": "user", "content": prompt]],
                                "stream": true,
                                "temperature": 0.7
                            ]
                            
                            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                            
                            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                            
                            guard let httpResponse = response as? HTTPURLResponse else {
                                throw AIError.networkError
                            }
                            
                            guard httpResponse.statusCode == 200 else {
                                switch httpResponse.statusCode {
                                case 401, 403:
                                    throw AIError.authenticationError
                                case 429:
                                    throw AIError.rateLimitError
                                default:
                                    throw AIError.apiError(statusCode: httpResponse.statusCode)
                                }
                            }
                            
                            for try await line in asyncBytes.lines {
                                if line.hasPrefix("data: ") {
                                    let jsonString = String(line.dropFirst(6))
                                    
                                    if jsonString == "[DONE]" {
                                        continuation.finish()
                                        return
                                    }
                                    
                                    if let data = jsonString.data(using: .utf8),
                                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                       let choices = json["choices"] as? [[String: Any]],
                                       let firstChoice = choices.first,
                                       let delta = firstChoice["delta"] as? [String: Any],
                                       let content = delta["content"] as? String {
                                        continuation.yield(content)
                                    }
                                }
                            }
                            
                            continuation.finish()
                        } catch let urlError as URLError {
                            switch urlError.code {
                            case .notConnectedToInternet,
                                 .networkConnectionLost,
                                 .cannotFindHost,
                                 .cannotConnectToHost,
                                 .dnsLookupFailed,
                                 .timedOut:
                                continuation.finish(throwing: AIError.networkError)
                            default:
                                continuation.finish(throwing: urlError)
                            }
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                }
            }
        )
    }

    static var previewValue: Self {
        Self(
            streamResponse: { _ in
                AsyncThrowingStream { continuation in
                    Task {
                        let message = previewStreamString
                        for line in message.split(separator: "\n", omittingEmptySubsequences: false) {
                            continuation.yield(String(line) + "\n")
                            try? await Task.sleep(for: .milliseconds(40))
                        }
                        continuation.finish()
                    }
                }
            }
        )
    }
    
    static var testValue: Self {
        Self(
            streamResponse: { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield("Test response")
                    continuation.finish()
                }
            }
        )
    }
}

extension DependencyValues {
    var aiService: AIServiceClient {
        get { self[AIServiceClient.self] }
        set { self[AIServiceClient.self] = newValue }
    }
}

// MARK: - API Key Manager Dependency

struct APIKeyManagerClient: Sendable {
    var hasValidAPIKey: @Sendable () -> Bool
    var getAPIKey: @Sendable () -> String
    var saveAPIKey: @Sendable (String) -> Bool
    var deleteAPIKey: @Sendable () -> Bool
    var validateAPIKey: @Sendable (String) -> Bool
    var hasValidElevenLabsAPIKey: @Sendable () -> Bool
    var getElevenLabsAPIKey: @Sendable () -> String
    var saveElevenLabsAPIKey: @Sendable (String) -> Bool
    var deleteElevenLabsAPIKey: @Sendable () -> Bool
    var validateElevenLabsAPIKey: @Sendable (String) -> Bool

    init(
        hasValidAPIKey: @escaping @Sendable () -> Bool,
        getAPIKey: @escaping @Sendable () -> String,
        saveAPIKey: @escaping @Sendable (String) -> Bool,
        deleteAPIKey: @escaping @Sendable () -> Bool,
        validateAPIKey: @escaping @Sendable (String) -> Bool,
        hasValidElevenLabsAPIKey: @escaping @Sendable () -> Bool = { false },
        getElevenLabsAPIKey: @escaping @Sendable () -> String = { "" },
        saveElevenLabsAPIKey: @escaping @Sendable (String) -> Bool = { _ in false },
        deleteElevenLabsAPIKey: @escaping @Sendable () -> Bool = { false },
        validateElevenLabsAPIKey: @escaping @Sendable (String) -> Bool = { _ in false }
    ) {
        self.hasValidAPIKey = hasValidAPIKey
        self.getAPIKey = getAPIKey
        self.saveAPIKey = saveAPIKey
        self.deleteAPIKey = deleteAPIKey
        self.validateAPIKey = validateAPIKey
        self.hasValidElevenLabsAPIKey = hasValidElevenLabsAPIKey
        self.getElevenLabsAPIKey = getElevenLabsAPIKey
        self.saveElevenLabsAPIKey = saveElevenLabsAPIKey
        self.deleteElevenLabsAPIKey = deleteElevenLabsAPIKey
        self.validateElevenLabsAPIKey = validateElevenLabsAPIKey
    }
}

extension APIKeyManagerClient: DependencyKey {
    // These accessors are invoked from main-actor reducers; keep keychain access on MainActor.
    static let liveValue = Self(
        hasValidAPIKey: {
            MainActor.assumeIsolated { !APIKeyManager.shared.getAPIKey().isEmpty }
        },
        getAPIKey: {
            MainActor.assumeIsolated { APIKeyManager.shared.getAPIKey() }
        },
        saveAPIKey: { key in
            MainActor.assumeIsolated { APIKeyManager.shared.saveAPIKey(key) }
        },
        deleteAPIKey: {
            MainActor.assumeIsolated { APIKeyManager.shared.deleteAPIKey() }
        },
        validateAPIKey: { key in
            MainActor.assumeIsolated { APIKeyManager.shared.validateAPIKey(key) }
        },
        hasValidElevenLabsAPIKey: {
            MainActor.assumeIsolated { !APIKeyManager.shared.getElevenLabsAPIKey().isEmpty }
        },
        getElevenLabsAPIKey: {
            MainActor.assumeIsolated { APIKeyManager.shared.getElevenLabsAPIKey() }
        },
        saveElevenLabsAPIKey: { key in
            MainActor.assumeIsolated { APIKeyManager.shared.saveElevenLabsAPIKey(key) }
        },
        deleteElevenLabsAPIKey: {
            MainActor.assumeIsolated { APIKeyManager.shared.deleteElevenLabsAPIKey() }
        },
        validateElevenLabsAPIKey: { key in
            MainActor.assumeIsolated { APIKeyManager.shared.validateElevenLabsAPIKey(key) }
        }
    )
    
    static let testValue = Self(
        hasValidAPIKey: { true },
        getAPIKey: { "test-api-key" },
        saveAPIKey: { _ in true },
        deleteAPIKey: { true },
        validateAPIKey: { _ in true },
        hasValidElevenLabsAPIKey: { true },
        getElevenLabsAPIKey: { "test-elevenlabs-api-key-1234567890" },
        saveElevenLabsAPIKey: { _ in true },
        deleteElevenLabsAPIKey: { true },
        validateElevenLabsAPIKey: { _ in true }
    )
    
    static let testNoValidAPIKeyValue: Self = Self(
        hasValidAPIKey: { false },
        getAPIKey: { "" },
        saveAPIKey: { _ in false },
        deleteAPIKey: { false },
        validateAPIKey: { _ in false },
        hasValidElevenLabsAPIKey: { false },
        getElevenLabsAPIKey: { "" },
        saveElevenLabsAPIKey: { _ in false },
        deleteElevenLabsAPIKey: { false },
        validateElevenLabsAPIKey: { _ in false }
    )
}

extension DependencyValues {
    var apiKeyManager: APIKeyManagerClient {
        get { self[APIKeyManagerClient.self] }
        set { self[APIKeyManagerClient.self] = newValue }
    }
}

// Enhanced error handling
enum AIError: LocalizedError {
    case invalidURL
    case jsonEncodingError
    case networkError
    case authenticationError
    case rateLimitError
    case apiError(statusCode: Int)
    case apiResponseError(message: String)
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL configuration"
        case .jsonEncodingError:
            return "Failed to encode request data"
        case .networkError:
            return "Network connection failed"
        case .authenticationError:
            return "Authentication failed. Please check your API key."
        case .rateLimitError:
            return "Rate limit exceeded. Please try again later."
        case .apiError(let statusCode):
            return "API request failed with status code: \(statusCode)"
        case .apiResponseError(let message):
            return "API Error: \(message)"
        case .parsingError:
            return "Failed to parse AI response"
        }
    }
}
