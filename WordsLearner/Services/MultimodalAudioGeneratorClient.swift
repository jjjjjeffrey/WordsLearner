//
//  MultimodalAudioGeneratorClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct MultimodalAudioGeneratorClient: Sendable {
    static let defaultVoiceID = ElevenLabsAudioGeneratorClient.defaultVoiceID
    static let defaultModelID = ElevenLabsAudioGeneratorClient.defaultModelID

    var generateAudio: @Sendable (_ narration: String) async throws -> Data
}

extension MultimodalAudioGeneratorClient: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.elevenLabsAudioGenerator) var elevenLabsAudioGenerator
        return Self(
            generateAudio: { narration in
                try await elevenLabsAudioGenerator.generateAudio(
                    narration,
                    defaultVoiceID,
                    defaultModelID
                )
            }
        )
    }

    static var previewValue: Self {
        Self(
            generateAudio: { _ in Data() }
        )
    }

    static var testValue: Self { previewValue }
}

extension DependencyValues {
    var multimodalAudioGenerator: MultimodalAudioGeneratorClient {
        get { self[MultimodalAudioGeneratorClient.self] }
        set { self[MultimodalAudioGeneratorClient.self] = newValue }
    }
}
