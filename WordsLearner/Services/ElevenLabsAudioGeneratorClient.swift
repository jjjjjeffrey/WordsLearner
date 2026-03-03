//
//  ElevenLabsAudioGeneratorClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation

enum ElevenLabsAudioError: LocalizedError {
    case invalidResponse(statusCode: Int)
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let statusCode):
            return "ElevenLabs request failed with status code: \(statusCode)"
        case .missingAPIKey:
            return "Missing ElevenLabs API key."
        }
    }
}

@DependencyClient
struct ElevenLabsAudioGeneratorClient: Sendable {
    static let defaultVoiceID = "JBFqnCBsd6RMkjVDRZzb"
    static let defaultModelID = "eleven_multilingual_v2"

    var generateAudio: @Sendable (_ text: String, _ voiceID: String, _ modelID: String) async throws -> Data
}

extension ElevenLabsAudioGeneratorClient: DependencyKey {
    static var liveValue: Self {
        Self(
            generateAudio: { text, voiceID, modelID in
                let apiKey = await MainActor.run {
                    APIKeyManager.shared.getElevenLabsAPIKey()
                }
                guard !apiKey.isEmpty else {
                    throw ElevenLabsAudioError.missingAPIKey
                }

                guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)") else {
                    throw AIError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("audio/mpeg", forHTTPHeaderField: "Accept")
                request.addValue(apiKey, forHTTPHeaderField: "xi-api-key")
                let payload: [String: Any] = [
                    "text": text,
                    "model_id": modelID,
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIError.networkError
                }
                guard httpResponse.statusCode == 200 else {
                    throw ElevenLabsAudioError.invalidResponse(statusCode: httpResponse.statusCode)
                }
                return data
            }
        )
    }

    static var previewValue: Self {
        Self(
            generateAudio: { _, _, _ in Data() }
        )
    }

    static var testValue: Self { previewValue }
}

extension DependencyValues {
    var elevenLabsAudioGenerator: ElevenLabsAudioGeneratorClient {
        get { self[ElevenLabsAudioGeneratorClient.self] }
        set { self[ElevenLabsAudioGeneratorClient.self] = newValue }
    }
}
