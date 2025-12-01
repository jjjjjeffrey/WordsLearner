//
//  AIServiceClient.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/18/25.
//

import ComposableArchitecture
import Foundation

// MARK: - AI Service Dependency

struct AIServiceClient {
    var streamResponse: @Sendable (String) -> AsyncThrowingStream<String, Error>
}

extension AIServiceClient: DependencyKey {
    static let liveValue = Self(
        streamResponse: { prompt in
            let apiKeyManager = APIKeyManager.shared
            let apiKey = apiKeyManager.getAPIKey()
            
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        guard !apiKey.isEmpty else {
                            throw AIError.authenticationError
                        }
                        
                        guard let url = URL(string: "https://aihubmix.com/v1/chat/completions") else {
                            throw AIError.invalidURL
                        }
                        
                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                        
                        let payload: [String: Any] = [
                            "model": "gemini-3-pro-preview",
                            "messages": [["role": "user", "content": prompt]],
                            "stream": true,
                            "temperature": 0.7
                        ]
                        
                        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                        
                        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                        
                        guard let httpResponse = response as? HTTPURLResponse,
                              httpResponse.statusCode == 200 else {
                            throw AIError.networkError
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
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    )
    
    static let testValue = Self(
        streamResponse: { _ in
            AsyncThrowingStream { continuation in
                continuation.yield("Test response")
                continuation.finish()
            }
        }
    )
}

extension DependencyValues {
    var aiService: AIServiceClient {
        get { self[AIServiceClient.self] }
        set { self[AIServiceClient.self] = newValue }
    }
}

// MARK: - API Key Manager Dependency

struct APIKeyManagerClient {
    var hasValidAPIKey: @Sendable () -> Bool
    var getAPIKey: @Sendable () -> String
    var saveAPIKey: @Sendable (String) -> Bool
    var deleteAPIKey: @Sendable () -> Bool
    var validateAPIKey: @Sendable (String) -> Bool
}

extension APIKeyManagerClient: DependencyKey {
    static let liveValue = Self(
        hasValidAPIKey: { !APIKeyManager.shared.getAPIKey().isEmpty },
        getAPIKey: { APIKeyManager.shared.getAPIKey() },
        saveAPIKey: { APIKeyManager.shared.saveAPIKey($0) },
        deleteAPIKey: { APIKeyManager.shared.deleteAPIKey() },
        validateAPIKey: { APIKeyManager.shared.validateAPIKey($0) }
    )
    
    static let testValue = Self(
        hasValidAPIKey: { true },
        getAPIKey: { "test-api-key" },
        saveAPIKey: { _ in true },
        deleteAPIKey: { true },
        validateAPIKey: { _ in true }
    )
    
    static let testNoValidAPIKeyValue: Self = Self(
        hasValidAPIKey: { false },
        getAPIKey: { "" },
        saveAPIKey: { _ in false },
        deleteAPIKey: { false },
        validateAPIKey: { _ in false }
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
