//
//  MultimodalAudioGeneratorClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation

enum MultimodalAudioError: LocalizedError {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing ElevenLabs API key."
        }
    }
}

@DependencyClient
struct MultimodalAudioGeneratorClient: Sendable {
    var generateAudio: @Sendable (_ narration: String) async throws -> Data
}

extension MultimodalAudioGeneratorClient: DependencyKey {
    static var liveValue: Self {
        Self(
            generateAudio: { narration in
                let apiKey = await MainActor.run {
                    APIKeyManager.shared.getElevenLabsAPIKey()
                }
                guard !apiKey.isEmpty else {
                    throw MultimodalAudioError.missingAPIKey
                }
                guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/JBFqnCBsd6RMkjVDRZzb") else {
                    throw AIError.invalidURL
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("audio/mpeg", forHTTPHeaderField: "Accept")
                request.addValue(apiKey, forHTTPHeaderField: "xi-api-key")
                let payload: [String: Any] = [
                    "text": narration,
                    "model_id": "eleven_multilingual_v2",
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (data, response) = try await URLSession.shared.data(for: request)
                guard
                    let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 200
                else {
                    throw AIError.networkError
                }
                return data
            }
        )
    }

    static var previewValue: Self {
        Self(
            generateAudio: { _ in Data() }
        )
    }

    static var testValue: Self {
        previewValue
    }
}

extension DependencyValues {
    var multimodalAudioGenerator: MultimodalAudioGeneratorClient {
        get { self[MultimodalAudioGeneratorClient.self] }
        set { self[MultimodalAudioGeneratorClient.self] = newValue }
    }
}
