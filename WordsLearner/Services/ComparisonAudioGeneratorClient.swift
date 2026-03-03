//
//  ComparisonAudioGeneratorClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct ComparisonAudioGeneratorClient: Sendable {
    static let defaultVoiceID = ElevenLabsAudioGeneratorClient.defaultVoiceID
    static let defaultModelID = ElevenLabsAudioGeneratorClient.defaultModelID

    var generateAudio: @Sendable (_ text: String) async throws -> Data
}

extension ComparisonAudioGeneratorClient: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.elevenLabsAudioGenerator) var elevenLabsAudioGenerator
        return Self(
            generateAudio: { text in
                try await elevenLabsAudioGenerator.generateAudio(
                    text,
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
    var comparisonAudioGenerator: ComparisonAudioGeneratorClient {
        get { self[ComparisonAudioGeneratorClient.self] }
        set { self[ComparisonAudioGeneratorClient.self] = newValue }
    }
}
