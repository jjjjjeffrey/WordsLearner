//
//  AIService.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/12/25.
//

import Foundation

class StreamingAIService {
    private let apiEndpoint = "https://aihubmix.com/v1/chat/completions"
    private let apiKeyManager = APIKeyManager.shared
    
    func streamResponse(prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let apiKey = apiKeyManager.getAPIKey()
                    guard !apiKey.isEmpty else {
                        throw AIError.authenticationError
                    }
                    
                    guard let url = URL(string: apiEndpoint) else {
                        throw AIError.invalidURL
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    
                    var payload: [String: Any] = [
                        "model": "gpt-4o-mini",
                        "messages": [
                            [
                                "role": "user",
                                "content": prompt
                            ]
                        ],
                        "stream": true,
                        "temperature": 0.7
                    ]
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                    
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIError.networkError
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        throw AIError.apiError(statusCode: httpResponse.statusCode)
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

